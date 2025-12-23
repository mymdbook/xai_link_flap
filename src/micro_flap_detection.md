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


Example Captured output
```
[vrf:none] root@xai-qfx5240-03:~# python3 micro_flap_detection.py -o temp_grouped_by_port.txt
OK: wrote temp_grouped_by_port.txt
Ports grouped: 91
Ports mapped to interface: 91/91

[vrf:none] root@xai-qfx5240-03:~# more temp_grouped_by_port.txt
Grouped logs by port from: journalctl.log
Port->Interface mapping: OK (102 mappings)
Mapping source: cprod:-A fpc0
================================================================================

PORT 2  (iface: et-0/0/2:1)
--------------------------------------------------------------------------------
Dec 22 13:08:52.878371 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 
2
Dec 22 21:13:10.266265 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port
: 2
Dec 22 21:17:46.190493 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 2
Dec 22 21:21:30.739211 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port:
 2
Dec 22 21:26:06.383292 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 2

PORT 9  (iface: et-0/0/1:0)
--------------------------------------------------------------------------------
Dec 22 13:08:42.133606 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 
9
Dec 22 21:13:10.182198 xai-qfx5240-03 evo-pfemand[10992]: [t:16310] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port
: 9
Dec 22 21:17:28.185393 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 9
Dec 22 21:21:30.680595 xai-qfx5240-03 evo-pfemand[9900]: [t:15904] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is down for port:
 9
Dec 22 21:25:49.203241 xai-qfx5240-03 evo-pfemand[9936]: [t:15855] [Info] BrcmPlusPfe: void brcm_linkscan_handler(int, bcm_port_t, bcm_port_info_t*): link state is up for port: 9




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
