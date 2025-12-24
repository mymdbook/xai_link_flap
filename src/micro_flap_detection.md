# Micro Flap Detection
```python

#!/usr/bin/env python3
"""
micro_flap_detection.py

Default user CLI:
  - python3 micro_flap_detection.py -o temp_grouped_by_port.txt
Behavior:
- If --input is NOT provided, the script generates ./journalctl.log automatically by running:
    journalctl -o short-precise -a | grep brcm_linkscan_handler
  Then it groups by `port : <number>` and maps ports to interfaces via:
    show evo-pfemand filter port-pipe-info

Other modes:
- Dump full brcm port to interfacee mapping:
    python3 micro_flap_detection.py --dump-mapping

Optional:
- Use an existing input file:
    python3 micro_flap_detection.py -i journalctl.log -o out.txt
"""

import argparse
import re
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple


PORT_RE_DEFAULT = r"\bport\s*:\s*(\d+)\b"
PFE_SHOW_CMD = "show evo-pfemand filter port-pipe-info"
DEFAULT_INPUT_FILE = "journalctl.log"
DEFAULT_GREP_TOKEN = "brcm_linkscan_handler"


def run_cmd(cmd: List[str], timeout: int = 30) -> Tuple[int, str, str]:
    p = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
    return p.returncode, p.stdout, p.stderr


def generate_journalctl_log(out_path: Path, grep_token: str, timeout: int = 60) -> None:
    """
    Generate out_path by running:
      journalctl -o short-precise -a | grep <token>

    Note: We overwrite out_path each run for determinism (avoids duplicate lines).
    """
    # Use bash for the pipe; ensure pipeline fails if journalctl fails.
    bash_cmd = (
        "set -o pipefail; "
        "journalctl -o short-precise -a | "
        f"grep -F {sh_quote(grep_token)} || true"
    )

    try:
        rc, out, err = run_cmd(["bash", "-lc", bash_cmd], timeout=timeout)
    except FileNotFoundError:
        raise SystemExit("ERROR: bash not found; cannot run journalctl pipeline")

    # journalctl might require privileges; capture stderr explicitly
    if "Failed to" in (err or "") and not out.strip():
        raise SystemExit(f"ERROR: journalctl failed: {err.strip()}")

    # Overwrite file
    out_path.write_text(out)
    if not out.strip():
        # Still produce file (empty) but warn; grouping will then find zero ports.
        print(f"WARNING: No lines matched '{grep_token}'. Wrote empty {out_path}.")


def sh_quote(s: str) -> str:
    """Simple shell-escape for a single argument."""
    return "'" + s.replace("'", "'\"'\"'") + "'"


def parse_port_pipe_info(mapping_text: str) -> Dict[int, str]:
    """
    Parse rows like:
      et-0/0/26:0             132        3      1     cd48
    Build:
      { asic_port_int: interface_name }
    """
    port_to_if: Dict[int, str] = {}
    row_re = re.compile(r"^\s*(et-\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s*$")

    for line in mapping_text.splitlines():
        m = row_re.match(line)
        if not m:
            continue
        iface = m.group(1)
        asic_port = int(m.group(2))
        port_to_if[asic_port] = iface

    return port_to_if


def get_mapping_text_local(timeout: int = 30) -> Tuple[bool, str, str]:
    """
    Execute the PFE command from Linux shell using supported wrappers.

    Returns:
      (ok, output, method_used_or_error)
    """
    attempts: List[Tuple[List[str], str]] = []

    attempts.append((
        ["cli", "-c", f'request pfe execute command "{PFE_SHOW_CMD}" | no-more'],
        "cli:request pfe execute command"
    ))
    attempts.append((
        ["cli", "-c", f'request pfe execute command "{PFE_SHOW_CMD}"'],
        "cli:request pfe execute command (no no-more)"
    ))
    attempts.append((
        ["cprod", "-A", "fpc0", "-c", PFE_SHOW_CMD],
        "cprod:-A fpc0"
    ))
    attempts.append((
        ["cprod", "-A", "fpc0", "-c", f"{PFE_SHOW_CMD} | no-more"],
        "cprod:-A fpc0 (no-more)"
    ))

    for cmd, method in attempts:
        try:
            rc, out, err = run_cmd(cmd, timeout=timeout)
            combined = (out or "") + ("\n" + err if err else "")
            if rc == 0 and combined.strip() and ("et-" in combined or "Physical Interfaces" in combined):
                return True, (out if out.strip() else combined), method
        except FileNotFoundError:
            continue
        except subprocess.TimeoutExpired:
            continue

    return False, "", "Unable to run PFE mapping command via cli/cprod (permission/command unavailable)"


def get_mapping_text_ssh(device: str, ssh_user: str, timeout: int = 30) -> Tuple[bool, str, str]:
    remote = f"{ssh_user}@{device}"
    cmd = [
        "ssh",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=8",
        remote,
        "cli",
        "-c",
        f'request pfe execute command "{PFE_SHOW_CMD}" | no-more'
    ]
    try:
        rc, out, err = run_cmd(cmd, timeout=timeout)
        combined = (out or "") + ("\n" + err if err else "")
        if rc == 0 and combined.strip() and ("et-" in combined or "Physical Interfaces" in combined):
            return True, (out if out.strip() else combined), f"ssh:{device} (request pfe execute)"
        return False, "", f"ssh:{device} failed rc={rc}: {err.strip() or 'no stderr'}"
    except subprocess.TimeoutExpired:
        return False, "", f"ssh:{device} timed out"
    except FileNotFoundError:
        return False, "", "ssh binary not found"


def group_lines_by_port(lines: List[str], port_regex: re.Pattern) -> Tuple[dict, List[str]]:
    groups = defaultdict(list)
    unmatched: List[str] = []

    for line in lines:
        m = port_regex.search(line)
        if m:
            port = int(m.group(1))
            groups[port].append(line.rstrip("\n"))
        else:
            if line.strip():
                unmatched.append(line.rstrip("\n"))

    return groups, unmatched


def fetch_mapping(args) -> Tuple[Dict[int, str], str, str]:
    """
    Returns:
      (port_to_if, mapping_status, mapping_source)
    """
    port_to_if: Dict[int, str] = {}
    mapping_status = "DISABLED"
    mapping_source = "none"

    if args.no_mapping:
        return port_to_if, mapping_status, mapping_source

    ok, txt, method = get_mapping_text_local(timeout=args.mapping_timeout)
    if (not ok) and args.device:
        ok, txt, method = get_mapping_text_ssh(args.device, args.ssh_user, timeout=args.mapping_timeout)

    if ok:
        port_to_if = parse_port_pipe_info(txt)
        if port_to_if:
            mapping_status = f"OK ({len(port_to_if)} mappings)"
            mapping_source = method
        else:
            mapping_status = "FAILED: parsed zero mappings (row format mismatch)"
            mapping_source = method
    else:
        mapping_status = f"FAILED: {method}"
        mapping_source = "failed"

    return port_to_if, mapping_status, mapping_source


def dump_mapping_only(args) -> None:
    if args.no_mapping:
        raise SystemExit("ERROR: --dump-mapping requires mapping; remove --no-mapping")

    ok, txt, method = get_mapping_text_local(timeout=args.mapping_timeout)
    if (not ok) and args.device:
        ok, txt, method = get_mapping_text_ssh(args.device, args.ssh_user, timeout=args.mapping_timeout)

    if not ok:
        raise SystemExit(f"ERROR: mapping failed: {method}")

    # Print full output and exit
    print(txt.rstrip("\n"))


def main() -> None:
    ap = argparse.ArgumentParser(description="Group brcm_linkscan_handler logs by port and map to Junos interfaces.")
    ap.add_argument("-o", "--output", required=False, help="Output grouped file path (required unless --dump-mapping)")
    ap.add_argument("-i", "--input", help="Optional input file path; if omitted, script auto-generates journalctl.log")
    ap.add_argument("--device", help="Optional: SSH to this Junos device to fetch mapping (if not on-box)")
    ap.add_argument("--ssh-user", default="root", help="SSH user for --device (default: root)")
    ap.add_argument("--no-mapping", action="store_true", help="Skip mapping lookup; group by port only")
    ap.add_argument("--include-unmatched", action="store_true", help="Append non-matching lines at the end")
    ap.add_argument("--regex", default=PORT_RE_DEFAULT, help=f"Port regex (default: {PORT_RE_DEFAULT})")
    ap.add_argument("--mapping-timeout", type=int, default=30, help="Mapping command timeout seconds (default: 30)")
    ap.add_argument("--journal-timeout", type=int, default=60, help="journalctl pipeline timeout seconds (default: 60)")
    ap.add_argument("--grep", dest="grep_token", default=DEFAULT_GREP_TOKEN, help=f"grep token (default: {DEFAULT_GREP_TOKEN})")
    ap.add_argument(
        "--dump-mapping",
        action="store_true",
        help="Dump FULL `show evo-pfemand filter port-pipe-info` output and exit.",
    )
    args = ap.parse_args()

    # Dump mapping-only mode
    if args.dump_mapping:
        dump_mapping_only(args)
        return

    if not args.output:
        raise SystemExit("ERROR: -o/--output is required (unless using --dump-mapping).")

    # Determine input file
    if args.input:
        in_path = Path(args.input)
        if not in_path.exists():
            raise SystemExit(f"ERROR: input file not found: {in_path}")
    else:
        # Auto-generate ./journalctl.log
        in_path = Path(DEFAULT_INPUT_FILE)
        generate_journalctl_log(in_path, args.grep_token, timeout=args.journal_timeout)

    out_path = Path(args.output)
    port_regex = re.compile(args.regex, re.IGNORECASE)

    # Read input log
    lines = in_path.read_text(errors="ignore").splitlines()
    groups, unmatched = group_lines_by_port(lines, port_regex)

    # Mapping
    port_to_if, mapping_status, mapping_source = fetch_mapping(args)
    if "FAILED" in mapping_status:
        print(f"WARNING: Port->Interface mapping {mapping_status}")

    # Write output
    out_lines: List[str] = []
    out_lines.append(f"Grouped logs by port from: {in_path.name}")
    out_lines.append(f"Port->Interface mapping: {mapping_status}")
    out_lines.append(f"Mapping source: {mapping_source}")
    out_lines.append("=" * 80)
    out_lines.append("")

    for port in sorted(groups.keys()):
        iface = port_to_if.get(port)
        out_lines.append(f"PORT {port}  (iface: {iface if iface else 'UNKNOWN'})")
        out_lines.append("-" * 80)
        out_lines.extend(groups[port])
        out_lines.append("")

    if args.include_unmatched and unmatched:
        out_lines.append("UNMATCHED LINES (no 'port : <number>' pattern found)")
        out_lines.append("-" * 80)
        out_lines.extend(unmatched)
        out_lines.append("")

    out_path.write_text("\n".join(out_lines) + "\n")

    print(f"OK: wrote {out_path}")
    print(f"Ports grouped: {len(groups)}")
    if port_to_if:
        mapped = sum(1 for p in groups.keys() if p in port_to_if)
        print(f"Ports mapped to interface: {mapped}/{len(groups)}")
    else:
        print("Ports mapped to interface: 0 (mapping unavailable)")


if __name__ == "__main__":
    main()
```

## BRCM Port Maping
Example Captured output
```

vrf:none] root@xai-qfx5240-03:~# python3 micro_flap_detection.py --dump-mapping
Physical Interfaces displaying their forwarding pipe mappings
------------------------------------------------------
Interface               Asic       Pipe   ITM   Port
Name                    Port       No     No    Name
-------------------------------------------------------
et-0/0/64               164        3      1     xe1   
et-0/0/65               76         1      0     xe0   
et-0/0/0:0              11         0      0     cd4   
et-0/0/0:1              12         0      0     cd5   
et-0/0/18:0             88         2      1     cd32  
et-0/0/18:1             89         2      1     cd33  
et-0/0/34:0             176        4      1     cd64  
et-0/0/34:1             177        4      1     cd65  
et-0/0/53               294        6      0     d3c17 
et-0/0/7:0              41         0      0     cd14  
et-0/0/7:1              42         0      0     cd15  
et-0/0/21:0             118        2      1     cd42  
et-0/0/21:1             119        2      1     cd43  
et-0/0/37               206        4      1     d3c1  
et-0/0/49               272        6      0     d3c13 
et-0/0/54               286        6      0     d3c16 
et-0/0/33:0             184        4      1     cd66  
et-0/0/33:1             185        4      1     cd67  
et-0/0/5:0              30         0      0     cd10  
et-0/0/5:1              31         0      0     cd11  
et-0/0/17:0             96         2      1     cd34  
et-0/0/17:1             97         2      1     cd35  
et-0/0/51               283        6      0     d3c15 
et-0/0/38               198        4      1     d3c0  
et-0/0/55               305        6      0     d3c19 
et-0/0/8:0              55         1      0     cd20  
et-0/0/8:1              56         1      0     cd21  
et-0/0/22:0             110        2      1     cd40  
et-0/0/22:1             111        2      1     cd41  
et-0/0/35:0             195        4      1     cd70  
et-0/0/35:1             196        4      1     cd71  
et-0/0/48               275        6      0     d3c14 
et-0/0/19:0             107        2      1     cd38  
et-0/0/19:1             108        2      1     cd39  
et-0/0/39               217        4      1     d3c3  
et-0/0/56               319        7      0     d3c22 
et-0/0/4:0              33         0      0     cd12  
et-0/0/4:1              34         0      0     cd13  
et-0/0/9:0              52         1      0     cd18  
et-0/0/9:1              53         1      0     cd19  
et-0/0/52               297        6      0     d3c18 
et-0/0/23:0             129        2      1     cd46  
et-0/0/23:1             130        2      1     cd47  
et-0/0/32:0             187        4      1     cd68  
et-0/0/32:1             188        4      1     cd69  
et-0/0/57               316        7      0     d3c21 
et-0/0/16:0             99         2      1     cd36  
et-0/0/16:1             100        2      1     cd37  
et-0/0/40               231        5      1     d3c6  
et-0/0/50               264        6      0     d3c12 
et-0/0/6:0              22         0      0     cd8   
et-0/0/6:1              23         0      0     cd9   
et-0/0/10:0             44         1      0     cd16  
et-0/0/10:1             45         1      0     cd17  
et-0/0/36               209        4      1     d3c2  
et-0/0/58               308        7      0     d3c20 
et-0/0/24:0             143        3      1     cd52  
et-0/0/24:1             144        3      1     cd53  
et-0/0/41               228        5      1     d3c5  
et-0/0/59               327        7      0     d3c23 
et-0/0/20:0             121        2      1     cd44  
et-0/0/20:1             122        2      1     cd45  
et-0/0/42               220        5      1     d3c4  
et-0/0/60               341        7      0     d3c26 
et-0/0/11:0             63         1      0     cd22  
et-0/0/11:1             64         1      0     cd23  
et-0/0/12:0             77         1      0     cd28  
et-0/0/12:1             78         1      0     cd29  
et-0/0/43               239        5      1     d3c7  
et-0/0/61               338        7      0     d3c25 
et-0/0/25:0             140        3      1     cd50  
et-0/0/25:1             141        3      1     cd51  
et-0/0/44               253        5      1     d3c10 
et-0/0/62               330        7      0     d3c24 
et-0/0/26:0             132        3      1     cd48  
et-0/0/26:1             133        3      1     cd49  
et-0/0/63               349        7      0     d3c27 
et-0/0/1:0              9          0      0     cd2   
et-0/0/1:1              10         0      0     cd3   
et-0/0/45               250        5      1     d3c9  
et-0/0/13:0             74         1      0     cd26  
et-0/0/13:1             75         1      0     cd27  
et-0/0/46               242        5      1     d3c8  
et-0/0/27:0             151        3      1     cd54  
et-0/0/27:1             152        3      1     cd55  
et-0/0/47               261        5      1     d3c11 
et-0/0/28:0             165        3      1     cd60  
et-0/0/28:1             166        3      1     cd61  
et-0/0/2:0              1          0      0     cd0   
et-0/0/2:1              2          0      0     cd1   
et-0/0/3:0              19         0      0     cd6   
et-0/0/3:1              20         0      0     cd7   
et-0/0/29:0             162        3      1     cd58  
et-0/0/29:1             163        3      1     cd59  
et-0/0/30:0             154        3      1     cd56  
et-0/0/30:1             155        3      1     cd57  
et-0/0/14:0             66         1      0     cd24  
et-0/0/14:1             67         1      0     cd25  
et-0/0/15:0             85         1      0     cd30  
et-0/0/15:1             86         1      0     cd31  
et-0/0/31:0             173        3      1     cd62  
et-0/0/31:1             174        3      1     cd63  

```
## Microflap logs
```
[vrf:none] root@xai-qfx5240-03:~# python3 micro_flap_detection.py -o temp_grouped_by_port.txt
OK: wrote temp_grouped_by_port.txt
Ports grouped: 91
Ports mapped to interface: 91/91


[vrf:none] root@xai-qfx5240-03:~# python3 micro_flap_detection.py -o temp_grouped_by_port.txt
OK: wrote temp_grouped_by_port.txt
Ports grouped: 91
Ports mapped to interface: 91/91

[vrf:none] root@xai-qfx5240-03:~# more temp_grouped_by_port.txt
Grouped logs by port from: journalctl.log
Port->Interface mapping: OK (102 mappings)
Mapping source: cprod:-A fpc0
================================================================================


Grouped logs by port from: temp.txt
================================================================================

PORT 2
--------------------------------------------------------------------------------
Dec 22 13:08:52.878371 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 2
Dec 22 21:13:10.266265 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 2
Dec 22 21:17:46.190493 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 2
Dec 22 21:21:30.739211 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 2
Dec 22 21:26:06.383292 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 2

PORT 9
--------------------------------------------------------------------------------
Dec 22 13:08:42.133606 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 9
Dec 22 21:13:10.182198 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 9
Dec 22 21:17:28.185393 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 9
Dec 22 21:21:30.680595 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 9
Dec 22 21:25:49.203241 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 9

PORT 10
--------------------------------------------------------------------------------
Dec 22 13:08:51.598640 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 10
Dec 22 21:13:10.224471 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 10
Dec 22 21:17:35.868082 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 10
Dec 22 21:21:30.704615 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 10
Dec 22 21:26:05.101771 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 10

PORT 11
--------------------------------------------------------------------------------
Dec 22 13:08:41.746433 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 11
Dec 22 21:13:10.131199 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 11
Dec 22 21:17:30.042126 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 11
Dec 22 21:21:30.605734 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 11
Dec 22 21:25:44.379196 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 11

PORT 12
--------------------------------------------------------------------------------
Dec 22 13:08:50.316530 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 12
Dec 22 21:13:10.149439 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 12
Dec 22 21:17:39.509312 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 12
Dec 22 21:17:44.006785 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 12
Dec 22 21:17:44.019143 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 12
Dec 22 21:21:30.652859 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 12
Dec 22 21:25:51.394703 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 12

PORT 19
--------------------------------------------------------------------------------
Dec 22 13:08:42.914376 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 19
Dec 22 21:13:10.283782 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 19
Dec 22 21:17:29.208858 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 19
Dec 22 21:21:30.800521 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 19
Dec 22 21:25:51.352850 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 19

PORT 20
--------------------------------------------------------------------------------
Dec 22 13:08:54.190343 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 20
Dec 22 21:13:10.363808 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 20
Dec 22 21:17:37.386476 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 20
Dec 22 21:21:30.816611 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 20
Dec 22 21:26:07.793488 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 20

PORT 22
--------------------------------------------------------------------------------
Dec 22 13:08:45.286209 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 22
Dec 22 21:13:10.475019 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 22
Dec 22 21:17:30.175741 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 22
Dec 22 21:21:30.966041 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 22
Dec 22 21:25:48.538609 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 22

PORT 23
--------------------------------------------------------------------------------
Dec 22 13:08:58.995202 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 23
Dec 22 21:13:10.510389 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 23
Dec 22 21:17:43.236471 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 23
Dec 22 21:21:30.995212 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 23
Dec 22 21:25:59.360554 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 23

PORT 30
--------------------------------------------------------------------------------
Dec 22 13:08:45.009300 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 30
Dec 22 21:13:10.428342 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 30
Dec 22 21:17:27.087833 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 30
Dec 22 21:21:30.860691 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 30
Dec 22 21:25:48.118807 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 30

PORT 31
--------------------------------------------------------------------------------
Dec 22 13:08:58.047820 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 31
Dec 22 21:13:10.460701 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 31
Dec 22 21:17:35.337710 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 31
Dec 22 21:21:30.951823 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 31
Dec 22 21:25:56.620049 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 31

PORT 33
--------------------------------------------------------------------------------
Dec 22 13:08:44.228433 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 33
Dec 22 21:13:10.391371 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 33
Dec 22 21:17:32.129224 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 33
Dec 22 21:21:30.841521 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 33
Dec 22 21:25:47.376956 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 33

PORT 34
--------------------------------------------------------------------------------
Dec 22 13:08:56.790148 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 34
Dec 22 21:13:10.411549 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 34
Dec 22 21:17:42.171078 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 34
Dec 22 21:21:30.852070 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 34
Dec 22 21:25:55.298313 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 34

PORT 41
--------------------------------------------------------------------------------
Dec 22 13:08:45.357799 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 41
Dec 22 21:13:10.526980 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 41
Dec 22 21:17:30.547336 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 41
Dec 22 21:21:31.021894 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 41
Dec 22 21:25:47.718556 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 41

PORT 42
--------------------------------------------------------------------------------
Dec 22 13:09:00.309110 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 42
Dec 22 21:13:10.532902 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 42
Dec 22 21:17:44.640444 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 42
Dec 22 21:21:31.036357 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 42
Dec 22 21:25:57.671284 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 42

PORT 44
--------------------------------------------------------------------------------
Dec 22 13:08:45.614388 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 44
Dec 22 21:13:10.582636 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 44
Dec 22 21:17:32.097338 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 44
Dec 22 21:21:31.109247 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 44
Dec 22 21:25:48.108257 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 44

PORT 45
--------------------------------------------------------------------------------
Dec 22 13:09:03.183832 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 45
Dec 22 21:13:10.588850 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 45
Dec 22 21:17:48.969217 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 45
Dec 22 21:21:31.124329 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 45
Dec 22 21:26:02.458450 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 45

PORT 52
--------------------------------------------------------------------------------
Dec 22 13:08:45.241802 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 52
Dec 22 21:13:10.565208 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 52
Dec 22 21:17:31.304166 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 52
Dec 22 21:21:31.071635 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 52
Dec 22 21:25:48.040065 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 52

PORT 53
--------------------------------------------------------------------------------
Dec 22 13:09:01.903726 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 53
Dec 22 21:13:10.573463 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 53
Dec 22 21:17:47.618710 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 53
Dec 22 21:21:31.082761 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 53
Dec 22 21:26:01.066541 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 53

PORT 56
--------------------------------------------------------------------------------
Dec 22 13:09:01.535035 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 56
Dec 22 21:13:10.553844 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 56
Dec 22 21:17:45.958690 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 56
Dec 22 21:21:31.058556 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 56
Dec 22 21:26:00.804248 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 56

PORT 63
--------------------------------------------------------------------------------
Dec 22 13:08:46.398429 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 63
Dec 22 21:13:10.613425 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 63
Dec 22 21:17:33.799175 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 63
Dec 22 21:21:31.142486 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 63
Dec 22 21:25:48.885357 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 63

PORT 64
--------------------------------------------------------------------------------
Dec 22 13:09:04.461283 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 64
Dec 22 21:13:10.628404 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 64
Dec 22 21:17:50.313160 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 64
Dec 22 21:21:31.157560 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 64
Dec 22 21:26:03.762326 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 64

PORT 66
--------------------------------------------------------------------------------
Dec 22 13:08:47.140911 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 66
Dec 22 21:13:10.656443 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 66
Dec 22 21:17:38.152025 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 66
Dec 22 21:21:31.187529 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 66
Dec 22 21:25:53.842619 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 66

PORT 67
--------------------------------------------------------------------------------
Dec 22 13:09:08.353351 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 67
Dec 22 21:13:10.671074 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 67
Dec 22 21:17:54.627320 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 67
Dec 22 21:21:31.196373 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 67
Dec 22 21:26:11.881131 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 67

PORT 75
--------------------------------------------------------------------------------
Dec 22 13:09:06.997315 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 75
Dec 22 21:13:10.690169 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 75
Dec 22 21:17:53.008655 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 75
Dec 22 21:21:31.180176 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 75
Dec 22 21:26:10.526212 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 75

PORT 78
--------------------------------------------------------------------------------
Dec 22 13:09:05.761187 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 78
Dec 22 21:13:10.643340 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 78
Dec 22 21:17:51.596345 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 78
Dec 22 21:21:31.170158 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 78
Dec 22 21:26:09.113809 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 78

PORT 86
--------------------------------------------------------------------------------
Dec 22 13:09:09.656310 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 86
Dec 22 21:13:10.697614 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 86
Dec 22 21:17:55.900477 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 86
Dec 22 21:21:31.205933 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 86
Dec 22 21:26:13.552490 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 86

PORT 88
--------------------------------------------------------------------------------
Dec 22 13:08:45.462364 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 88
Dec 22 21:13:10.757385 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 88
Dec 22 21:17:32.004529 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 88
Dec 22 21:21:31.277053 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 88
Dec 22 21:25:45.516731 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 88

PORT 89
--------------------------------------------------------------------------------
Dec 22 13:08:54.070721 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 89
Dec 22 21:13:10.777795 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 89
Dec 22 21:17:39.963708 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 89
Dec 22 21:21:31.284295 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 89
Dec 22 21:25:52.868208 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 89

PORT 97
--------------------------------------------------------------------------------
Dec 22 13:19:41.636976 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 97
Dec 22 21:13:12.026537 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 97
Dec 22 21:17:36.830256 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 97
Dec 22 21:21:31.232921 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 97
Dec 22 21:25:53.714527 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 97

PORT 99
--------------------------------------------------------------------------------
Dec 22 13:08:45.408325 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 99
Dec 22 21:13:10.710273 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 99
Dec 22 21:17:31.656795 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 99
Dec 22 21:21:31.252933 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 99
Dec 22 21:25:49.096930 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 99

PORT 100
--------------------------------------------------------------------------------
Dec 22 13:08:52.756850 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 100
Dec 22 21:13:10.741622 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 100
Dec 22 21:17:50.770773 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 100
Dec 22 21:21:31.267747 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 100
Dec 22 21:26:00.111789 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 100

PORT 107
--------------------------------------------------------------------------------
Dec 22 13:08:45.737950 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 107
Dec 22 21:13:10.797917 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 107
Dec 22 21:17:29.596298 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 107
Dec 22 21:21:31.296773 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 107
Dec 22 21:25:48.054441 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 107

PORT 108
--------------------------------------------------------------------------------
Dec 22 13:08:56.023486 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 108
Dec 22 21:13:10.817001 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 108
Dec 22 21:17:41.098076 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 108
Dec 22 21:21:31.306373 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 108
Dec 22 21:25:56.548549 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 108

PORT 110
--------------------------------------------------------------------------------
Dec 22 13:08:46.061408 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 110
Dec 22 21:13:10.868292 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 110
Dec 22 21:17:29.584004 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 110
Dec 22 21:21:31.322432 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 110
Dec 22 21:25:47.585961 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 110

PORT 111
--------------------------------------------------------------------------------
Dec 22 13:08:58.869407 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 111
Dec 22 21:13:10.881590 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 111
Dec 22 21:17:44.004119 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 111
Dec 22 21:21:31.338128 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 111
Dec 22 21:26:01.431482 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 111

PORT 118
--------------------------------------------------------------------------------
Dec 22 13:08:45.648745 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 118
Dec 22 21:13:10.908514 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 118
Dec 22 21:17:28.881006 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 118
Dec 22 21:21:31.347429 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 118
Dec 22 21:25:46.456292 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 118

PORT 119
--------------------------------------------------------------------------------
Dec 22 13:08:57.522636 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 119
Dec 22 21:13:10.928413 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 119
Dec 22 21:17:42.652215 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 119
Dec 22 21:21:31.359276 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 119
Dec 22 21:25:56.921011 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 119

PORT 121
--------------------------------------------------------------------------------
Dec 22 13:08:45.497380 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 121
Dec 22 21:13:10.830319 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 121
Dec 22 21:17:30.992291 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 121
Dec 22 21:21:31.379680 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 121
Dec 22 21:25:48.483282 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 121

PORT 122
--------------------------------------------------------------------------------
Dec 22 13:08:56.323166 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 122
Dec 22 21:13:10.855986 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 122
Dec 22 21:17:41.388941 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 122
Dec 22 21:21:31.391971 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 122
Dec 22 21:26:00.095706 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 122

PORT 129
--------------------------------------------------------------------------------
Dec 22 13:08:46.540073 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 129
Dec 22 21:13:10.947703 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 129
Dec 22 21:17:30.051525 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 129
Dec 22 21:21:31.411727 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 129
Dec 22 21:25:48.724220 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 129

PORT 130
--------------------------------------------------------------------------------
Dec 22 13:09:00.051808 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 130
Dec 22 21:13:10.955372 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 130
Dec 22 21:17:50.601433 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 130
Dec 22 21:21:31.419177 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 130
Dec 22 21:26:02.781549 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 130

PORT 132
--------------------------------------------------------------------------------
Dec 22 13:08:48.877963 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 132
Dec 22 21:13:10.976234 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 132
Dec 22 21:17:32.616667 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 132
Dec 22 21:21:31.443609 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 132
Dec 22 21:25:49.953499 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 132

PORT 133
--------------------------------------------------------------------------------
Dec 22 13:09:04.185871 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 133
Dec 22 21:13:10.981338 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 133
Dec 22 21:17:54.593480 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 133
Dec 22 21:21:31.450817 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 133
Dec 22 21:26:06.885118 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 133

PORT 140
--------------------------------------------------------------------------------
Dec 22 13:08:47.267119 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 140
Dec 22 21:13:10.998187 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 140
Dec 22 21:17:31.902088 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 140
Dec 22 21:21:31.464824 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 140
Dec 22 21:25:49.372593 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 140

PORT 141
--------------------------------------------------------------------------------
Dec 22 13:09:02.731227 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 141
Dec 22 21:13:11.005781 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 141
Dec 22 21:17:53.137031 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 141
Dec 22 21:21:31.479183 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 141
Dec 22 21:26:05.537135 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 141

PORT 144
--------------------------------------------------------------------------------
Dec 22 13:09:01.118905 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 144
Dec 22 21:13:10.966332 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 144
Dec 22 21:17:51.570788 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 144
Dec 22 21:21:31.433163 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 144
Dec 22 21:26:03.874988 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 144

PORT 151
--------------------------------------------------------------------------------
Dec 22 13:08:47.915094 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 151
Dec 22 21:13:11.032072 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 151
Dec 22 21:17:32.662849 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 151
Dec 22 21:21:31.489355 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 151
Dec 22 21:25:51.619870 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 151

PORT 152
--------------------------------------------------------------------------------
Dec 22 13:09:05.523188 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 152
Dec 22 21:13:11.049274 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 152
Dec 22 21:17:55.915609 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 152
Dec 22 21:21:31.502634 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 152
Dec 22 21:26:08.244202 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 152

PORT 154
--------------------------------------------------------------------------------
Dec 22 13:08:49.029934 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 154
Dec 22 21:13:11.064679 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 154
Dec 22 21:17:33.706488 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 154
Dec 22 21:21:31.518936 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 154
Dec 22 21:25:53.919306 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 154

PORT 155
--------------------------------------------------------------------------------
Dec 22 13:09:09.498010 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 155
Dec 22 21:13:11.077849 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 155
Dec 22 21:17:46.740256 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 155
Dec 22 21:21:31.534992 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 155
Dec 22 21:26:12.330778 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 155

PORT 162
--------------------------------------------------------------------------------
Dec 22 13:08:48.832134 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 162
Dec 22 21:13:11.109787 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 162
Dec 22 21:17:33.768522 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 162
Dec 22 21:21:31.549195 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 162
Dec 22 21:25:52.621705 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 162

PORT 163
--------------------------------------------------------------------------------
Dec 22 13:09:08.142631 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 163
Dec 22 21:13:11.122031 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 163
Dec 22 21:17:45.532855 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 163
Dec 22 21:21:31.557185 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 163
Dec 22 21:26:11.099553 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 163

PORT 165
--------------------------------------------------------------------------------
Dec 22 13:08:49.624873 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 165
Dec 22 21:13:11.134875 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 165
Dec 22 21:17:34.081316 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 165
Dec 22 21:21:31.573770 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 165
Dec 22 21:25:52.474147 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 165

PORT 166
--------------------------------------------------------------------------------
Dec 22 13:09:07.986886 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 166
Dec 22 21:13:11.153674 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 166
Dec 22 21:17:58.166173 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 166
Dec 22 21:21:31.586037 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 166
Dec 22 21:26:10.419269 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 166

PORT 173
--------------------------------------------------------------------------------
Dec 22 13:08:49.348655 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 173
Dec 22 21:13:11.170723 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 173
Dec 22 21:17:34.805984 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 173
Dec 22 21:21:31.762319 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 173
Dec 22 21:25:58.872149 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 173

PORT 174
--------------------------------------------------------------------------------
Dec 22 13:09:10.950896 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 174
Dec 22 21:13:11.189264 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 174
Dec 22 21:17:48.037097 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 174
Dec 22 21:21:31.933359 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 174
Dec 22 21:26:14.059325 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 174

PORT 176
--------------------------------------------------------------------------------
Dec 22 13:08:48.545319 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 176
Dec 22 21:13:11.213293 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 176
Dec 22 21:17:33.110351 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 176
Dec 22 21:21:31.959550 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 176
Dec 22 21:25:41.700618 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 176

PORT 177
--------------------------------------------------------------------------------
Dec 22 13:09:01.463652 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 177
Dec 22 21:13:11.226528 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 177
Dec 22 21:17:52.696911 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 177
Dec 22 21:21:32.024038 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 177
Dec 22 21:26:02.232960 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 177

PORT 184
--------------------------------------------------------------------------------
Dec 22 13:08:47.195937 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 184
Dec 22 21:13:11.241481 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 184
Dec 22 21:17:24.445969 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 184
Dec 22 21:21:32.171884 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 184
Dec 22 21:25:44.187462 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 184

PORT 185
--------------------------------------------------------------------------------
Dec 22 13:08:58.593508 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 185
Dec 22 21:13:11.249644 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 185
Dec 22 21:17:44.935643 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 185
Dec 22 21:21:32.186972 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 185
Dec 22 21:26:04.167702 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 185

PORT 187
--------------------------------------------------------------------------------
Dec 22 13:08:47.719243 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 187
Dec 22 21:13:11.269912 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 187
Dec 22 21:17:31.659563 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 187
Dec 22 21:21:32.189177 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 187
Dec 22 21:25:50.831023 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 187

PORT 188
--------------------------------------------------------------------------------
Dec 22 13:08:55.699478 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 188
Dec 22 21:13:11.286576 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 188
Dec 22 21:17:50.012883 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 188
Dec 22 21:21:32.191399 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 188
Dec 22 21:26:08.846128 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 188

PORT 198
--------------------------------------------------------------------------------
Dec 22 12:45:44.901735 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 198
Dec 22 13:06:43.315584 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 198
Dec 22 13:07:47.235880 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 198
Dec 22 21:13:11.301232 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 198
Dec 22 21:17:26.742584 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 198
Dec 22 21:21:32.193786 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 198
Dec 22 21:25:44.722386 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 198

PORT 206
--------------------------------------------------------------------------------
Dec 22 12:58:04.290953 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 206
Dec 22 13:06:43.311585 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 206
Dec 22 13:07:46.998476 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 206
Dec 22 21:13:11.407276 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 206
Dec 22 21:17:23.483623 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 206
Dec 22 21:21:32.196035 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 206
Dec 22 21:25:40.939709 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 206

PORT 209
--------------------------------------------------------------------------------
Dec 22 12:44:52.272806 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 209
Dec 22 13:06:43.309412 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 209
Dec 22 13:06:46.796331 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 209
Dec 22 21:13:11.664365 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 209
Dec 22 21:17:29.730980 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 209
Dec 22 21:21:32.198290 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 209
Dec 22 21:25:47.257981 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 209

PORT 217
--------------------------------------------------------------------------------
Dec 22 12:45:45.005976 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 217
Dec 22 13:06:43.331675 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 217
Dec 22 13:07:46.937456 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 217
Dec 22 21:13:11.702765 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 217
Dec 22 21:17:28.477461 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 217
Dec 22 21:21:32.200596 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 217
Dec 22 21:25:46.186596 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 217

PORT 220
--------------------------------------------------------------------------------
Dec 22 12:46:19.651616 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 220
Dec 22 13:06:43.351872 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 220
Dec 22 13:07:48.159238 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 220
Dec 22 21:13:11.890799 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 220
Dec 22 21:17:36.981304 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 220
Dec 22 21:21:32.269976 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 220
Dec 22 21:25:54.642470 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 220

PORT 228
--------------------------------------------------------------------------------
Dec 22 12:45:56.995514 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 228
Dec 22 13:06:43.347342 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 228
Dec 22 13:07:16.890342 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 228
Dec 22 21:13:12.031958 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 228
Dec 22 21:17:34.045480 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 228
Dec 22 21:21:32.202971 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 228
Dec 22 21:25:51.793130 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 228

PORT 231
--------------------------------------------------------------------------------
Dec 22 12:45:32.325999 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 231
Dec 22 13:06:43.336205 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 231
Dec 22 13:06:46.748169 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 231
Dec 22 21:13:11.967807 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 231
Dec 22 21:17:31.137100 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 231
Dec 22 21:21:32.205362 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 231
Dec 22 21:25:48.670156 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 231

PORT 239
--------------------------------------------------------------------------------
Dec 22 12:46:35.785739 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 239
Dec 22 13:06:43.356046 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 239
Dec 22 13:07:46.995398 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 239
Dec 22 21:13:11.970484 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 239
Dec 22 21:17:37.666362 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 239
Dec 22 21:21:32.207771 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 239
Dec 22 21:25:55.105442 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 239

PORT 242
--------------------------------------------------------------------------------
Dec 22 12:47:11.391232 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 242
Dec 22 13:06:43.410402 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 242
Dec 22 13:07:46.992635 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 242
Dec 22 21:13:11.973031 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 242
Dec 22 21:17:42.420854 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 242
Dec 22 21:21:32.210243 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 242
Dec 22 21:26:01.252992 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 242

PORT 250
--------------------------------------------------------------------------------
Dec 22 12:47:02.531872 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 250
Dec 22 13:06:43.393494 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 250
Dec 22 13:07:47.143698 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 250
Dec 22 21:13:11.975423 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 250
Dec 22 21:17:40.728397 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 250
Dec 22 21:21:32.212716 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 250
Dec 22 21:25:58.351977 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 250

PORT 253
--------------------------------------------------------------------------------
Dec 22 12:46:53.700360 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 253
Dec 22 12:47:43.437477 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 253
Dec 22 12:47:47.897825 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 253
Dec 22 13:06:43.372557 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 253
Dec 22 13:07:47.445457 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 253
Dec 22 21:13:11.977941 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 253
Dec 22 21:17:39.245936 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 253
Dec 22 21:21:32.215264 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 253
Dec 22 21:25:56.761748 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 253

PORT 261
--------------------------------------------------------------------------------
Dec 22 12:47:21.778118 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 261
Dec 22 13:06:43.434101 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 261
Dec 22 13:07:47.273599 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 261
Dec 22 21:13:11.980389 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 261
Dec 22 21:17:47.283622 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 261
Dec 22 21:21:32.217906 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 261
Dec 22 21:26:06.060747 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 261

PORT 264
--------------------------------------------------------------------------------
Dec 22 12:47:39.618713 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 264
Dec 22 13:06:43.481513 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 264
Dec 22 13:07:47.703566 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 264
Dec 22 21:13:11.982927 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 264
Dec 22 21:17:34.622228 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 264
Dec 22 21:21:32.220578 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 264
Dec 22 21:25:52.082665 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 264

PORT 272
--------------------------------------------------------------------------------
Dec 22 12:47:22.082198 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 272
Dec 22 13:06:43.460644 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 272
Dec 22 13:07:47.370313 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 272
Dec 22 21:13:11.985481 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 272
Dec 22 21:17:23.093982 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 272
Dec 22 21:21:32.223187 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 272
Dec 22 21:25:39.509388 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 272

PORT 275
--------------------------------------------------------------------------------
Dec 22 12:47:16.539179 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 275
Dec 22 12:47:38.420669 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 275
Dec 22 12:47:48.244134 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 275
Dec 22 13:06:43.457261 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 275
Dec 22 13:07:47.064734 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 275
Dec 22 21:13:11.988073 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 275
Dec 22 21:17:28.016115 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 275
Dec 22 21:21:32.226252 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 275
Dec 22 21:25:47.073495 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 275

PORT 283
--------------------------------------------------------------------------------
Dec 22 12:47:50.197404 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 283
Dec 22 13:06:43.496140 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 283
Dec 22 13:07:47.626373 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 283
Dec 22 21:13:11.990807 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 283
Dec 22 21:17:25.002518 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 283
Dec 22 21:21:32.230362 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 283
Dec 22 21:25:42.269370 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 283

PORT 286
--------------------------------------------------------------------------------
Dec 22 12:50:01.037849 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 286
Dec 22 13:06:43.534735 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 286
Dec 22 13:07:47.485392 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 286
Dec 22 21:13:11.998906 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 286
Dec 22 21:17:29.651333 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 286
Dec 22 21:21:32.241658 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 286
Dec 22 21:25:45.632113 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 286

PORT 294
--------------------------------------------------------------------------------
Dec 22 12:49:10.958401 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 294
Dec 22 13:06:43.520432 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 294
Dec 22 13:07:47.570994 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 294
Dec 22 21:13:11.993370 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 294
Dec 22 21:17:26.204225 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 294
Dec 22 21:21:32.234482 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 294
Dec 22 21:25:43.867650 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 294

PORT 297
--------------------------------------------------------------------------------
Dec 22 12:49:00.791852 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 297
Dec 22 13:06:43.515929 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 297
Dec 22 13:07:16.852459 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 297
Dec 22 21:13:11.996079 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 297
Dec 22 21:17:34.784633 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 297
Dec 22 21:21:32.238692 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 297
Dec 22 21:25:52.388301 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 297

PORT 305
--------------------------------------------------------------------------------
Dec 22 12:50:19.344980 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 305
Dec 22 13:06:43.547622 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 305
Dec 22 13:07:47.989498 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 305
Dec 22 21:13:12.002195 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 305
Dec 22 21:17:31.253628 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 305
Dec 22 21:21:32.244423 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 305
Dec 22 21:25:48.729325 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 305

PORT 308
--------------------------------------------------------------------------------
Dec 22 12:52:04.787461 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 308
Dec 22 13:06:43.580511 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 308
Dec 22 13:07:46.855350 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 308
Dec 22 21:13:12.005320 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 308
Dec 22 21:17:38.052968 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 308
Dec 22 21:21:32.247189 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 308
Dec 22 21:25:55.768719 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 308

PORT 316
--------------------------------------------------------------------------------
Dec 22 12:51:38.289108 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 316
Dec 22 13:06:43.577266 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 316
Dec 22 13:07:47.811749 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 316
Dec 22 21:13:12.008854 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 316
Dec 22 21:17:37.631037 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 316
Dec 22 21:21:32.250223 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 316
Dec 22 21:25:55.578070 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 316

PORT 319
--------------------------------------------------------------------------------
Dec 22 12:50:40.527409 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 319
Dec 22 13:06:43.560540 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 319
Dec 22 13:07:47.002214 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 319
Dec 22 21:13:12.012011 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 319
Dec 22 21:17:31.507931 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 319
Dec 22 21:21:32.253045 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 319
Dec 22 21:25:49.124253 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 319

PORT 327
--------------------------------------------------------------------------------
Dec 22 12:52:33.166585 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 327
Dec 22 13:06:43.591452 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 327
Dec 22 13:07:47.934963 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 327
Dec 22 21:13:12.015105 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 327
Dec 22 21:17:41.137429 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 327
Dec 22 21:21:32.267581 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 327
Dec 22 21:25:58.740874 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 327

PORT 330
--------------------------------------------------------------------------------
Dec 22 12:54:11.497378 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 330
Dec 22 13:06:43.625622 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 330
Dec 22 13:07:48.145230 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 330
Dec 22 21:13:12.018449 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 330
Dec 22 21:17:46.028091 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 330
Dec 22 21:21:32.255958 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 330
Dec 22 21:26:04.069541 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 330

PORT 338
--------------------------------------------------------------------------------
Dec 22 12:53:53.167450 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 338
Dec 22 13:06:43.619013 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 338
Dec 22 13:07:48.071448 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 338
Dec 22 21:13:12.021436 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 338
Dec 22 21:17:44.463063 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 338
Dec 22 21:21:32.258884 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 338
Dec 22 21:26:01.840946 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 338

PORT 341
--------------------------------------------------------------------------------
Dec 22 12:53:13.365015 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 341
Dec 22 13:06:43.613772 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 341
Dec 22 13:07:47.889740 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 341
Dec 22 21:13:12.024687 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 341
Dec 22 21:17:42.689586 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 341
Dec 22 21:21:32.261797 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 341
Dec 22 21:26:00.485546 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 341

PORT 349
--------------------------------------------------------------------------------
Dec 22 12:58:52.391513 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 349
Dec 22 12:58:56.965395 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 349
Dec 22 12:58:58.647976 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 349
Dec 22 12:59:01.386027 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 349
Dec 22 12:59:02.793805 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 349
Dec 22 13:06:43.629873 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 349
Dec 22 13:07:47.741286 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 349
Dec 22 21:13:12.029506 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 349
Dec 22 21:17:46.379015 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 349
Dec 22 21:21:32.264706 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port: 349
Dec 22 21:26:04.313019 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 349

UNMATCHED LINES (no 'port : <number>' pattern found)
--------------------------------------------------------------------------------
[vrf:none] root@xai-qfx5240-03:~# journalctl -o short-precise -a | grep brcm_linkscan_handler
Dec 22 11:14:57.878699 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 11
Dec 22 11:14:57.893709 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 9
Dec 22 11:14:57.910394 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 1
Dec 22 11:14:57.932212 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 19
Dec 22 11:14:57.945262 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 33
Dec 22 11:14:57.962797 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 30
Dec 22 11:14:57.982096 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 22
Dec 22 11:14:57.995099 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 41
Dec 22 11:14:58.012075 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 55
Dec 22 11:14:58.020432 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 52
Dec 22 11:14:58.030291 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 44
Dec 22 11:14:58.039475 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 63
Dec 22 11:14:58.056085 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 77
Dec 22 11:14:58.061336 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 74
Dec 22 11:14:58.069547 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 66
Dec 22 11:14:58.074665 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 85
Dec 22 11:14:58.079866 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 99
Dec 22 11:14:58.084897 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 96
Dec 22 11:14:58.090715 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 88
Dec 22 11:14:58.096201 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 107
Dec 22 11:14:58.104618 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 121
Dec 22 11:14:58.114753 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 118
Dec 22 11:14:58.122847 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 110
Dec 22 11:14:58.152166 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 129
Dec 22 11:14:58.161936 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 143
Dec 22 11:14:58.248098 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 140
Dec 22 11:14:58.256484 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 132
Dec 22 11:14:58.272936 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 151
Dec 22 11:14:58.281086 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 165
Dec 22 11:14:58.286640 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 162
Dec 22 11:14:58.300768 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 154
Dec 22 11:14:58.311908 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 173
Dec 22 11:14:58.318588 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 187
Dec 22 11:14:58.324360 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 184
Dec 22 11:14:58.337446 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 176
Dec 22 11:14:58.348740 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 195
Dec 22 11:14:58.364515 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 209
Dec 22 11:14:58.370090 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 206
Dec 22 11:14:58.402981 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 198
Dec 22 11:14:58.413810 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 217
Dec 22 11:14:58.420262 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 231
Dec 22 11:14:58.426313 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 228
Dec 22 11:14:58.432337 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 220
Dec 22 11:14:58.443793 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 239
Dec 22 11:14:58.453901 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 253
Dec 22 11:14:58.468670 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 250
Dec 22 11:14:58.473858 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 242
Dec 22 11:14:58.480433 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 261
Dec 22 11:14:58.492248 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 275
Dec 22 11:14:58.504813 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 272
Dec 22 11:14:58.512053 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 264
Dec 22 11:14:58.518082 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 283
Dec 22 11:14:58.524788 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 297
Dec 22 11:14:58.534155 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 294
Dec 22 11:14:58.542966 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 286
Dec 22 11:14:58.552609 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 305
Dec 22 11:14:58.571768 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 319
Dec 22 11:14:58.591530 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 316
Dec 22 11:14:58.623409 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 308
Dec 22 11:14:58.654774 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 327
Dec 22 11:14:58.663936 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 341
Dec 22 11:14:58.675564 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 338
Dec 22 11:14:58.755153 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 330
Dec 22 11:14:58.761473 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 349
Dec 22 11:14:58.770324 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 164
Dec 22 11:14:58.785617 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 76
Dec 22 11:25:09.248645 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 12
Dec 22 11:25:09.297387 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 10
Dec 22 11:25:09.348409 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 2
Dec 22 11:25:09.400509 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 20
Dec 22 11:25:09.454569 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 34
Dec 22 11:25:09.519581 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 31
Dec 22 11:25:09.577219 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 23
Dec 22 11:25:09.637655 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 42
Dec 22 11:25:09.699399 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 56
Dec 22 11:25:09.762190 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 53
Dec 22 11:25:09.846136 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 45
Dec 22 11:25:09.913426 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 64
Dec 22 11:25:09.983122 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 78
Dec 22 11:25:10.076157 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 75
Dec 22 11:25:10.155661 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 67
Dec 22 11:25:10.236440 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 86
Dec 22 11:25:10.313990 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 100
Dec 22 11:25:10.394337 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 97
Dec 22 11:25:10.475810 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 89
Dec 22 11:25:10.559330 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 108
Dec 22 11:25:10.681847 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 122
Dec 22 11:25:10.768847 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 119
Dec 22 11:25:10.859523 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 111
Dec 22 11:25:10.951037 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 130
Dec 22 11:25:11.045532 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 144
Dec 22 11:25:11.158551 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 141
Dec 22 11:25:11.273626 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 133
Dec 22 11:25:11.378996 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 152
Dec 22 11:25:11.482861 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 166
Dec 22 11:25:11.586368 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 163
Dec 22 11:25:11.692291 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 155
Dec 22 11:25:11.812295 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 174
Dec 22 11:25:11.922933 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 188
Dec 22 11:25:12.036709 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 185
Dec 22 11:25:12.169318 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 177
Dec 22 11:25:12.295219 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 196
Dec 22 11:25:12.459837 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 210
Dec 22 11:25:12.582132 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 207
Dec 22 11:25:12.706796 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 199
Dec 22 11:25:12.832273 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 218
Dec 22 11:25:12.959724 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 232
Dec 22 11:25:13.110112 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 229
Dec 22 11:25:13.259050 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 221
Dec 22 11:25:13.394343 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 240
Dec 22 11:25:13.530314 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 254
Dec 22 11:25:13.669067 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 251
Dec 22 11:25:13.823049 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 243
Dec 22 11:25:13.966238 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 262
Dec 22 11:25:14.111754 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 276
Dec 22 11:25:14.274955 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 273
Dec 22 11:25:14.445950 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 265
Dec 22 11:25:14.597915 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 284
Dec 22 11:25:14.752241 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 298
Dec 22 11:25:14.908301 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 295
Dec 22 11:25:15.066722 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 287
Dec 22 11:25:15.261321 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 306
Dec 22 11:25:15.436197 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 320
Dec 22 11:25:15.604370 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 317
Dec 22 11:25:15.774816 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 309
Dec 22 11:25:15.945093 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 328
Dec 22 11:25:16.158145 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 342
Dec 22 11:25:16.348855 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 339
Dec 22 11:25:16.533089 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 331
Dec 22 11:25:16.712277 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 350
Dec 22 11:30:01.556908 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 13
Dec 22 11:30:01.569137 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 14
Dec 22 11:30:01.599061 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 7
Dec 22 11:30:01.610689 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 8
Dec 22 11:30:01.715546 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 3
Dec 22 11:30:01.728377 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 4
Dec 22 11:30:01.759475 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 17
Dec 22 11:30:01.773814 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 18
Dec 22 11:30:01.877205 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 35
Dec 22 11:30:01.891959 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 36
Dec 22 11:30:01.924486 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 28
Dec 22 11:30:01.939151 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 29
Dec 22 11:30:02.033665 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 24
Dec 22 11:30:02.048631 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 25
Dec 22 11:30:02.083349 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 39
Dec 22 11:30:02.098794 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 40
Dec 22 11:30:02.247027 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 57
Dec 22 11:30:02.263800 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 58
Dec 22 11:30:02.299820 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 50
Dec 22 11:30:02.316625 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 51
Dec 22 11:30:02.459152 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 46
Dec 22 11:30:02.483455 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 47
Dec 22 11:30:02.520409 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 61
Dec 22 11:30:02.554997 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 62
Dec 22 11:30:02.670268 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 79
Dec 22 11:30:02.690099 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 80
Dec 22 11:30:02.727589 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 72
Dec 22 11:30:02.746928 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 73
Dec 22 11:30:02.866684 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 68
Dec 22 11:30:02.887070 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 69
Dec 22 11:30:02.925948 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 83
Dec 22 11:30:02.993717 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 84
Dec 22 11:30:03.132880 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 101
Dec 22 11:30:03.154953 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 102
Dec 22 11:30:03.196121 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 94
Dec 22 11:30:03.218350 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 95
Dec 22 11:30:03.373101 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 90
Dec 22 11:30:03.396411 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 91
Dec 22 11:30:03.439380 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 105
Dec 22 11:30:03.463003 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 106
Dec 22 11:30:03.648018 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 123
Dec 22 11:30:03.673205 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 124
Dec 22 11:30:03.720649 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 116
Dec 22 11:30:03.747340 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 117
Dec 22 11:30:03.936199 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 112
Dec 22 11:30:03.962349 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 113
Dec 22 11:30:04.007694 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 127
Dec 22 11:30:04.034854 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 128
Dec 22 11:30:04.230427 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 145
Dec 22 11:30:04.258370 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 146
Dec 22 11:30:04.305292 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 138
Dec 22 11:30:04.333360 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 139
Dec 22 11:30:04.497465 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 134
Dec 22 11:30:04.526417 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 135
Dec 22 11:30:04.616686 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 149
Dec 22 11:30:04.646794 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 150
Dec 22 11:30:04.819594 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 167
Dec 22 11:30:04.850126 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 168
Dec 22 11:30:04.903900 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 160
Dec 22 11:30:04.934542 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 161
Dec 22 11:30:05.125869 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 156
Dec 22 11:30:05.158361 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 157
Dec 22 11:30:05.209883 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 171
Dec 22 11:30:05.242158 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 172
Dec 22 11:30:05.475136 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 189
Dec 22 11:30:05.509504 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 190
Dec 22 11:30:05.564090 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 182
Dec 22 11:30:05.615001 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 183
Dec 22 11:30:05.844381 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 178
Dec 22 11:30:05.882453 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 179
Dec 22 11:30:05.938629 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 193
Dec 22 11:30:05.974745 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 194
Dec 22 11:30:06.179305 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 211
Dec 22 11:30:06.216454 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 212
Dec 22 11:30:06.295309 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 204
Dec 22 11:30:06.332503 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 205
Dec 22 11:30:06.549380 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 200
Dec 22 11:30:06.587691 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 201
Dec 22 11:30:06.661386 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 215
Dec 22 11:30:06.712757 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 216
Dec 22 11:30:06.986135 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 233
Dec 22 11:30:07.026467 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 234
Dec 22 11:30:07.085921 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 226
Dec 22 11:30:07.126300 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 227
Dec 22 11:30:07.422502 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 222
Dec 22 11:30:07.464255 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 223
Dec 22 11:30:07.525050 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 237
Dec 22 11:30:07.568126 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 238
Dec 22 11:30:07.849676 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 255
Dec 22 11:30:07.895934 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 256
Dec 22 11:30:07.959700 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 248
Dec 22 11:30:08.004013 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 249
Dec 22 11:30:08.250298 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 244
Dec 22 11:30:08.295469 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 245
Dec 22 11:30:08.391277 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 259
Dec 22 11:30:08.437243 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 260
Dec 22 11:30:08.706231 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 277
Dec 22 11:30:08.752674 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 278
Dec 22 11:30:08.817733 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 270
Dec 22 11:30:08.864524 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 271
Dec 22 11:30:09.159883 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 266
Dec 22 11:30:09.208220 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 267
Dec 22 11:30:09.275008 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 281
Dec 22 11:30:09.323482 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 282
Dec 22 11:30:09.619563 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 299
Dec 22 11:30:09.669326 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 300
Dec 22 11:30:09.754129 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 292
Dec 22 11:30:09.804592 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 293
Dec 22 11:30:10.089507 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 288
Dec 22 11:30:10.141394 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 289
Dec 22 11:30:10.212106 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 303
Dec 22 11:30:10.264280 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 304
Dec 22 11:30:10.552149 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 321
Dec 22 11:30:10.605347 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 322
Dec 22 11:30:10.731806 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 314
Dec 22 11:30:10.802641 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 315
Dec 22 11:30:11.097876 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 310
Dec 22 11:30:11.153834 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 311
Dec 22 11:30:11.229013 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 325
Dec 22 11:30:11.285464 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 326
Dec 22 11:30:11.635568 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 343
Dec 22 11:30:11.695374 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 344
Dec 22 11:30:11.770268 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 336
Dec 22 11:30:11.843489 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 337
Dec 22 11:30:12.170061 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 332
Dec 22 11:30:12.235099 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 333
Dec 22 11:30:12.351365 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 347
Dec 22 11:30:12.470918 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 348
Dec 22 11:34:56.918031 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 15
Dec 22 11:34:56.928174 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 16
Dec 22 11:34:57.033498 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 5
Dec 22 11:34:57.054403 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 6
Dec 22 11:34:57.163186 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 37
Dec 22 11:34:57.174687 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 38
Dec 22 11:34:57.328393 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 26
Dec 22 11:34:57.356614 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 27
Dec 22 11:34:57.477035 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 59
Dec 22 11:34:57.493429 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 60
Dec 22 11:34:57.617822 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 48
Dec 22 11:34:57.630878 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 49
Dec 22 11:34:57.785641 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 81
Dec 22 11:34:57.799390 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 82
Dec 22 11:34:57.918755 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 70
Dec 22 11:34:57.947366 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 71
Dec 22 11:34:58.107354 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 103
Dec 22 11:34:58.122665 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 104
Dec 22 11:34:58.318533 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 92
Dec 22 11:34:58.342872 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 93
Dec 22 11:34:58.481846 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 125
Dec 22 11:34:58.498396 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 126
Dec 22 11:34:58.667634 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 114
Dec 22 11:34:58.685370 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 115
Dec 22 11:34:58.850240 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 147
Dec 22 11:34:58.868768 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 148
Dec 22 11:34:59.018174 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 136
Dec 22 11:34:59.036575 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 137
Dec 22 11:34:59.231511 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 169
Dec 22 11:34:59.251251 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 170
Dec 22 11:34:59.431105 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 158
Dec 22 11:34:59.450978 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 159
Dec 22 11:34:59.615523 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 191
Dec 22 11:34:59.653580 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 192
Dec 22 11:34:59.847785 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 180
Dec 22 11:34:59.869223 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 181
Dec 22 11:35:00.090271 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 213
Dec 22 11:35:00.113704 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 214
Dec 22 11:35:00.313101 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 202
Dec 22 11:35:00.336282 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 203
Dec 22 11:35:00.567101 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 235
Dec 22 11:35:00.591720 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 236
Dec 22 11:35:00.784851 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 224
Dec 22 11:35:00.809506 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 225
Dec 22 11:35:01.053779 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 257
Dec 22 11:35:01.079401 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 258
Dec 22 11:35:01.284639 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 246
Dec 22 11:35:01.334497 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 247
Dec 22 11:35:01.546631 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 279
Dec 22 11:35:01.609369 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 280
Dec 22 11:35:01.835716 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 268
Dec 22 11:35:01.863345 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 269
Dec 22 11:35:02.114959 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 301
Dec 22 11:35:02.163870 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 302
Dec 22 11:35:02.431937 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 290
Dec 22 11:35:02.461214 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 291
Dec 22 11:35:02.759202 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 323
Dec 22 11:35:02.793847 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 324
Dec 22 11:35:03.065689 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 312
Dec 22 11:35:03.163420 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 313
Dec 22 11:35:03.476423 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 345
Dec 22 11:35:03.508753 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 346
Dec 22 11:35:03.760752 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 334
Dec 22 11:35:03.793221 re0 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 335
Dec 22 21:15:55.174078 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 164
Dec 22 21:15:55.182056 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 76
Dec 22 21:16:29.263774 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 30
Dec 22 21:16:29.332786 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 31
Dec 22 21:16:29.450906 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 118
Dec 22 21:16:29.519870 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 119
Dec 22 21:16:29.523111 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 206
Dec 22 21:16:29.530298 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 294
Dec 22 21:16:30.763725 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 9
Dec 22 21:16:30.839343 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 10
Dec 22 21:16:30.970428 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 96
Dec 22 21:16:31.050974 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 97
Dec 22 21:16:31.165944 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 184
Dec 22 21:16:31.248943 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 185
Dec 22 21:16:31.252997 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 272
Dec 22 21:16:31.675775 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 198
Dec 22 21:16:31.687341 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 286
Dec 22 21:16:33.308394 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 22
Dec 22 21:16:33.396496 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 23
Dec 22 21:16:33.532942 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 110
Dec 22 21:16:33.621788 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 111
Dec 22 21:16:33.626632 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 283
Dec 22 21:16:34.319831 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 195
Dec 22 21:16:34.415002 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 196
Dec 22 21:16:34.684575 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 305
Dec 22 21:16:35.293368 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 19
Dec 22 21:16:35.407106 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 20
Dec 22 21:16:35.550092 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 107
Dec 22 21:16:35.652923 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 108
Dec 22 21:16:35.657498 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 217
Dec 22 21:16:35.795693 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 275
Dec 22 21:16:37.299484 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 41
Dec 22 21:16:37.402399 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 42
Dec 22 21:16:37.545296 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 129
Dec 22 21:16:37.652611 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 130
Dec 22 21:16:37.808876 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 187
Dec 22 21:16:37.915342 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 188
Dec 22 21:16:37.920090 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 319
Dec 22 21:16:38.690870 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 297
Dec 22 21:16:39.325218 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 99
Dec 22 21:16:39.442922 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 100
Dec 22 21:16:39.805148 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 11
Dec 22 21:16:39.939973 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 12
Dec 22 21:16:39.949087 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 231
Dec 22 21:16:39.964888 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 316
Dec 22 21:16:40.816903 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 55
Dec 22 21:16:40.952168 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 56
Dec 22 21:16:40.957063 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 209
Dec 22 21:16:41.820995 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 143
Dec 22 21:16:41.971476 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 144
Dec 22 21:16:41.979428 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 264
Dec 22 21:16:42.181925 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 228
Dec 22 21:16:42.845217 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 121
Dec 22 21:16:43.017467 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 122
Dec 22 21:16:43.040567 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 308
Dec 22 21:16:43.361606 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 176
Dec 22 21:16:43.516798 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 177
Dec 22 21:16:43.832418 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 33
Dec 22 21:16:43.971444 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 34
Dec 22 21:16:44.186091 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 327
Dec 22 21:16:44.880537 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 52
Dec 22 21:16:45.036088 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 53
Dec 22 21:16:45.191551 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 341
Dec 22 21:16:45.875100 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 140
Dec 22 21:16:46.017758 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 141
Dec 22 21:16:46.023229 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 220
Dec 22 21:16:46.856574 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 88
Dec 22 21:16:47.018865 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 89
Dec 22 21:16:47.026185 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 239
Dec 22 21:16:47.046505 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 338
Dec 22 21:16:47.870050 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 1
Dec 22 21:16:48.053040 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 2
Dec 22 21:16:48.203142 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 253
Dec 22 21:16:48.214512 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 330
Dec 22 21:16:48.873479 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 44
Dec 22 21:16:49.035250 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 45
Dec 22 21:16:49.182841 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 349
Dec 22 21:16:49.882481 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 132
Dec 22 21:16:50.053456 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 133
Dec 22 21:16:50.060519 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 250
Dec 22 21:16:50.676678 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 242
Dec 22 21:16:51.372628 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 151
Dec 22 21:16:51.543309 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 152
Dec 22 21:16:51.889196 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 63
Dec 22 21:16:52.096044 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 64
Dec 22 21:16:52.223003 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 261
Dec 22 21:16:53.393687 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 77
Dec 22 21:16:53.564354 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 78
Dec 22 21:16:53.931298 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 165
Dec 22 21:16:54.121173 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 166
Dec 22 21:16:55.377937 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 162
Dec 22 21:16:55.565858 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 163
Dec 22 21:16:55.898858 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 74
Dec 22 21:16:56.081930 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 75
Dec 22 21:16:57.378337 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 66
Dec 22 21:16:57.571442 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 67
Dec 22 21:16:57.941776 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 154
Dec 22 21:16:58.155372 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 155
Dec 22 21:16:59.419842 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 173
Dec 22 21:16:59.618806 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 174
Dec 22 21:16:59.960056 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 85
Dec 22 21:17:00.193986 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 86
Dec 22 21:24:13.218144 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 164
Dec 22 21:24:13.226966 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 76
Dec 22 21:24:46.805738 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 11
Dec 22 21:24:46.872508 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 12
Dec 22 21:24:46.984883 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 88
Dec 22 21:24:47.062252 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 89
Dec 22 21:24:47.168972 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 176
Dec 22 21:24:47.251394 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 177
Dec 22 21:24:47.255694 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 294
Dec 22 21:24:47.834271 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 41
Dec 22 21:24:47.913467 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 42
Dec 22 21:24:48.331588 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 118
Dec 22 21:24:48.410152 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 119
Dec 22 21:24:48.417790 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 206
Dec 22 21:24:48.427086 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 272
Dec 22 21:24:49.220649 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 286
Dec 22 21:24:50.349169 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 184
Dec 22 21:24:50.461876 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 185
Dec 22 21:24:50.837709 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 30
Dec 22 21:24:50.939139 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 31
Dec 22 21:24:51.081014 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 96
Dec 22 21:24:51.168496 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 97
Dec 22 21:24:51.175943 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 283
Dec 22 21:24:51.421969 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 198
Dec 22 21:24:52.226761 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 305
Dec 22 21:24:52.832591 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 55
Dec 22 21:24:52.931556 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 56
Dec 22 21:24:53.367204 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 110
Dec 22 21:24:53.468049 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 111
Dec 22 21:24:53.866753 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 195
Dec 22 21:24:53.971069 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 196
Dec 22 21:24:53.977230 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 275
Dec 22 21:24:54.367952 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 107
Dec 22 21:24:54.485299 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 108
Dec 22 21:24:54.728320 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 217
Dec 22 21:24:54.736784 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 319
Dec 22 21:24:55.371204 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 33
Dec 22 21:24:55.490962 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 34
Dec 22 21:24:56.350854 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 52
Dec 22 21:24:56.483138 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 53
Dec 22 21:24:56.494179 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 297
Dec 22 21:24:57.365546 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 129
Dec 22 21:24:57.497651 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 130
Dec 22 21:24:57.668672 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 187
Dec 22 21:24:57.810711 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 188
Dec 22 21:24:57.921039 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 316
Dec 22 21:24:58.373907 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 99
Dec 22 21:24:58.513015 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 100
Dec 22 21:24:58.520982 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 231
Dec 22 21:24:58.725853 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 264
Dec 22 21:24:59.367679 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 22
Dec 22 21:24:59.528983 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 23
Dec 22 21:25:00.365250 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 44
Dec 22 21:25:00.498007 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 45
Dec 22 21:25:00.503856 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 209
Dec 22 21:25:00.524082 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 308
Dec 22 21:25:01.414494 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 143
Dec 22 21:25:01.548247 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 144
Dec 22 21:25:01.724301 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 228
Dec 22 21:25:01.743089 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 327
Dec 22 21:25:02.408488 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 121
Dec 22 21:25:02.552270 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 122
Dec 22 21:25:02.723869 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 220
Dec 22 21:25:02.732772 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 341
Dec 22 21:25:03.415682 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 63
Dec 22 21:25:03.564630 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 64
Dec 22 21:25:04.428841 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 77
Dec 22 21:25:04.575239 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 78
Dec 22 21:25:04.588135 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 239
Dec 22 21:25:04.602597 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 338
Dec 22 21:25:05.400063 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 140
Dec 22 21:25:05.588641 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 141
Dec 22 21:25:05.743039 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 253
Dec 22 21:25:05.750844 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 330
Dec 22 21:25:06.436483 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 132
Dec 22 21:25:06.616640 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 133
Dec 22 21:25:06.745256 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 349
Dec 22 21:25:07.402657 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 9
Dec 22 21:25:07.562108 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 10
Dec 22 21:25:07.567609 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 250
Dec 22 21:25:08.449744 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 74
Dec 22 21:25:08.613612 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 75
Dec 22 21:25:08.625592 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 242
Dec 22 21:25:09.450980 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 151
Dec 22 21:25:09.620563 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 152
Dec 22 21:25:09.733617 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 261
Dec 22 21:25:10.929231 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 165
Dec 22 21:25:11.101169 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 166
Dec 22 21:25:11.488583 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 1
Dec 22 21:25:11.701523 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 2
Dec 22 21:25:12.913457 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 19
Dec 22 21:25:13.097234 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 20
Dec 22 21:25:13.470807 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 162
Dec 22 21:25:13.654491 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 163
Dec 22 21:25:14.926372 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 154
Dec 22 21:25:15.117203 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 155
Dec 22 21:25:15.489719 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 66
Dec 22 21:25:15.701159 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 67
Dec 22 21:25:16.926845 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 85
Dec 22 21:25:17.127261 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 86
Dec 22 21:25:17.443966 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 173
Dec 22 21:25:17.639526 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*) No IFD for 174

```
