# Log Collection Script

## QFX5240 Script
```bash
#!/bin/bash
# Function to print timestamp
timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

echo "#### sensor info at $(timestamp)#####"
sensors
echo "#### temperature info at $(timestamp)#####"
jbcmcmd.py "show temp"
echo "#### Running bcm command for port 35:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:0 -v
echo

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE eeprom_rescan for port 2, 17, 35 at $(timestamp) ####"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 2 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 17 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 35 cmd eeprom_rescan"

echo "#### Running bcm command for port 2:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:0 -v
echo

echo "#### Running bcm command for port 2:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:1 -v
echo

echo "#### Running bcm command for port 17:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/17:0 -v
echo

echo "#### Running bcm command for port 17:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/17:1 -v
echo

echo "#### Running bcm command for port 35:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:0 -v
echo

echo "#### Running bcm command for port 35:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:1 -v
echo

echo "#### Sleep for 4s from $(timestamp) ####"
sleep 4

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd identifier | no-more"

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd identifier | no-more"

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for Port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for Port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for Port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd identifier | no-more"

##### Running lspci command ####
echo "#### Running lspci command at $(timestamp) ####"
lspci
```

## Event-Options Config

```text
root@xai-qfx5240-01# show event-options 
policy server_links {
    events snmp_trap_link_down;
    within 1 {
        trigger on 1;
    }
    attributes-match {
        event.snmp_trap_link_down matches "^SNMP_TRAP_LINK_DOWN$";
    }
    then {
        execute-commands {
            commands {
                "request routing-engine execute command \"sh /var/tmp/cs_event-based-script.sh >> /var/log/interface_flap.txt\"";
            }
            output-filename event_option_execution.txt;
            destination destination;
            output-format text;
        }
        raise-trap;
    }
}
destinations {
    destination {
        archive-sites {
            /var/log/;
        }
    }
}
```

## Server Logs - BF3 NIC

```sh
#!/bin/sh

OUT_DIR="/dev/shm/mnt/persist"
SLEEP=1
HOST=$(hostname)

mkdir -p "$OUT_DIR" || exit 1

while true; do
  TS=$(date +%Y%m%d%H%M%S)

  # 1) Ensure MST devices are created
  mst start >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "[$(date)] ERROR: mst start failed on $HOST" >&2
    sleep "$SLEEP"
    continue
  fi

  # 2) Discover MST device nodes from "mst status"
  DEVS=$(mst status 2>/dev/null | awk '/^\/dev\/mst\//{print $1}')

  if [ -z "$DEVS" ]; then
    echo "[$(date)] WARN: No /dev/mst devices found in mst status on $HOST" >&2
    sleep "$SLEEP"
    continue
  fi

  # 3) Collect amber logs per device
  for dev in $DEVS; do
    devname=$(basename "$dev")
    fname="${OUT_DIR}/amber_${HOST}_${devname}_${TS}.csv"

    echo "[$(date)] Collecting amber: $dev -> $fname"
    mlxlink -d "$dev" --amber_collect "$fname" >> "${OUT_DIR}/amber_collect_${HOST}.log" 2>&1
  done

  sleep "$SLEEP"
done
```

## Stress Testing 

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

BANNER = r"""
Debug CLI & Interface Control (Python)

-------------------------------------
*** Must be run using root login ****
-------------------------------------
- Logs outputs into debug_cli.log (override with --logfile)
- Shows live [INFO]/[WARN]/[RESULT] messages on console
- Disable/enable/status/flap interface ops via arguments
- --brcm_cli [disable|enable IFACES]
    * With args: run one-shot Broadcom action on IFACES (iface names; auto-map to ports)
    * Without args: act as a flag to make --flap use Broadcom (jbcmcmd.py) instead of Junos
- Honors argument order across all ops (executes in the sequence you pass)
- --flap <ifaces> [--flap-wait <sec>] [--flap-count <n>] [--post-up-wait <sec>]
Tunables (verify): 
 -   --down-timeout / --up-timeout: max seconds to wait for the link to reach down / up. Defaults: 12s down, 24s up.
 -   --down-interval / --up-interval: how often to poll show interfaces terse during that wait. Defaults: 1.5s down, 2.0s up.
 -   --attempts: optional override for number of polls. If set, it ignores the timeout/interval-derived count and uses exactly this many attempts.
- Bare port numbers auto-map to et-0/0/<port> for flaps/status/enable/disable (override with --iface-prefix, e.g., xe-0/0/)
Junos commands used:
- Disable:  configure; set interfaces <iface> disable; commit and-quit
- Enable:   configure; delete interfaces <iface> disable; commit and-quit
- Status 1: show interfaces terse | match ^<iface>
- Status 2: show interfaces terse | no-more

Broadcom commands used:
- Toggle:   <brcm_cli> "port <port> enable=false|true" (via jbcmcmd.py/brcm_cli/brcmcli/brckcli)
- Status:   qfx.brcm.pfe.port.link_status <iface>

Optics OIR test:
- Actions:  request pfe execute command "test picd optics fpc_slot <fpc> pic_slot <pic> port <port> cmd [oir_enable|remove|insert|oir_disable]" target fpc<fpc>
- Inventory: show chassis hardware detail | display xml | no-more (fallback: | no-more | match "Xcvr ")
- Defaults: --fpc-slot 0 --pic-slot 0 --oir-poll-delay 1.0 --oir-retries 20
- Cycles:   --flap-count controls number of OIR cycles per port (default: 1)
- No ports?  --oir-test can reuse the --flap list (if given) when provided without args.
- Optional link check: add --check-status to verify link DOWN after remove and UP after insert (uses --down-timeout/--up-timeout)
- Inter-cycle wait: --flap-wait applies between OIR cycles
- Modes: --remove-only (skip insert), --insert-only (skip remove)

Examples:
- Disable: ./evo_link_flap.py --disable xe-0/0/1
- Enable:  ./evo_link_flap.py --enable xe-0/0/1
- Status:  ./evo_link_flap.py --status xe-0/0/1
- Flap (Junos): ./evo_link_flap.py --flap 21,22 --flap-count 2 --flap-wait 5   # maps to et-0/0/21, et-0/0/22
- Flap (BRCM):  ./evo_link_flap.py --flap 21,22 --brcm_cli --flap-count 2 --flap-wait 5
- Flap+OIR:     ./evo_link_flap.py --flap 21,22 --oir-test --flap-count 2 --flap-wait 5 --check-status
- OIR only:     ./evo_link_flap.py --oir-test 21,22 --flap-count 3 --flap-wait 5 --check-status
- OIR remove:   ./evo_link_flap.py --oir-test 21,22 --remove-only --check-status
- OIR insert:   ./evo_link_flap.py --oir-test 21,22 --insert-only --check-status
"""

print(BANNER)

import argparse
import os
import subprocess
import sys
import time
from typing import List, Optional, Tuple
from xml.etree import ElementTree as ET

LOGFILE = "/var/tmp/debug_cli.log"
OIR_FLAG_SENTINEL = "__OIR_FLAG__"
IFACE_PREFIX = "et-0/0/"
IFACE_FAMILY = "et"
PREFERRED_FAMILIES = ["et", "xe", "ge"]
IFACE_PREFIX = "et-0/0/"
IFACE_FAMILY = "et"

# -------------------
# Logging helpers
# -------------------
def _ensure_log_dir(path: str):
    d = os.path.dirname(path) or "."
    try:
        os.makedirs(d, exist_ok=True)
    except Exception:
        pass

def set_logfile(path: str):
    global LOGFILE
    LOGFILE = os.path.abspath(path)
    _ensure_log_dir(LOGFILE)

def _write(line: str):
    with open(LOGFILE, "a", encoding="utf-8", errors="replace") as f:
        f.write(line + "\n")

def user_msg(msg: str):
    line = f"[INFO] {msg}"
    print(line)
    _write(line)

def warn_msg(msg: str):
    line = f"[WARN] {msg}"
    print(line)
    _write(line)

def result_msg(msg: str):
    line = f"[RESULT] {msg}"
    print(line)
    _write(line)

def run_command(cmd, shell=True) -> bool:
    with open(LOGFILE, "a", encoding="utf-8", errors="replace") as f:
        try:
            subprocess.run(cmd, shell=shell, stdout=f, stderr=f, check=True)
            return True
        except subprocess.CalledProcessError:
            return False

def junos_cli(cmd: str) -> bool:
    return run_command(f'cli -c "{cmd}"', shell=True)

def junos_cli_capture(cmd: str) -> str:
    try:
        out = subprocess.check_output(["cli", "-c", cmd], text=True)
        _write(f"\n$ cli -c \"{cmd}\"\n{out}\n")
        return out
    except subprocess.CalledProcessError as e:
        warn_msg(f"CLI failed: {cmd} rc={e.returncode}")
        return ""

def junos_cli_capture_quiet(cmd: str) -> str:
    try:
        out = subprocess.check_output(["cli", "-c", cmd], text=True)
        return out
    except subprocess.CalledProcessError as e:
        warn_msg(f"CLI failed: {cmd} rc={e.returncode}")
        return ""

# -------------------
# General helpers
# -------------------
def normalize_iflist(arg: Optional[str]) -> List[str]:
    if not arg:
        return []
    seen = set()
    out: List[str] = []
    for x in (p.strip() for p in arg.split(",") if p.strip()):
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

def set_iface_prefix(prefix: str):
    """
    Configure how bare port numbers map to interface names.
    Examples: 'et-0/0/' (default), 'xe-0/0/'.
    """
    global IFACE_PREFIX, IFACE_FAMILY
    p = (prefix or "").strip()
    if not p:
        p = "et-0/0/"
    if not p.endswith("/"):
        p = p + "/"
    IFACE_PREFIX = p
    IFACE_FAMILY = p.split("-", 1)[0] if "-" in p else "et"

def normalize_iface_token(token: str) -> str:
    """
    Map bare port numbers (e.g. '23' or '0/0/23') to IFACE_PREFIX + <port> (family derived from prefix).
    Leave anything with letters or a hyphen untouched (assume full name).
    """
    t = token.strip()
    if not t:
        return ""
    if any(c.isalpha() for c in t) or "-" in t:
        return t
    parts = t.split("/")
    if len(parts) == 3 and all(p.isdigit() for p in parts):
        return f"{IFACE_FAMILY}-{parts[0]}/{parts[1]}/{parts[2]}"
    if t.isdigit():
        return f"{IFACE_PREFIX}{t}"
    return t

def normalize_iface_list(arg: Optional[str]) -> List[str]:
    raw = normalize_iflist(arg)
    out: List[str] = []
    seen = set()
    for tok in raw:
        mapped = normalize_iface_token(tok)
        if mapped and mapped not in seen:
            out.append(mapped)
            seen.add(mapped)
    return out

def oir_ports_from_tokens(tokens: List[str]) -> List[str]:
    """
    Extract numeric port identifiers from a list of tokens.
    Accepts bare numbers or interface strings ending with a number.
    """
    out: List[str] = []
    seen = set()
    for tok in tokens:
        t = tok.strip()
        if not t:
            continue
        candidate = None
        if t.isdigit():
            candidate = t
        elif "/" in t:
            tail = t.rsplit("/", 1)[-1]
            if tail.isdigit():
                candidate = tail
        if candidate and candidate not in seen:
            out.append(candidate)
            seen.add(candidate)
    return out

def parse_terse_line(line: str) -> Tuple[str, str, str]:
    # Expect: Interface | Admin | Link | ...
    parts = line.split()
    if len(parts) >= 3:
        return parts[0], parts[1].lower(), parts[2].lower()
    if len(parts) >= 1:
        return parts[0], "unknown", "unknown"
    return "", "unknown", "unknown"

def first_physical_lines_from_terse(out: str, ifaces: List[str]) -> List[str]:
    lines = []
    want = set(ifaces)
    # collect physical matches first; if none, allow first logical match as fallback
    logical_fallback = []
    for l in out.splitlines():
        l = l.strip()
        if not l:
            continue
        name = l.split()[0] if l.split() else ""
        if not name:
            continue
        base = name.split(".", 1)[0].split(":", 1)[0]
        if base not in want:
            continue
        if "." in name or ":" in name:
            logical_fallback.append(l)
        else:
            lines.append(l)
    if not lines and logical_fallback:
        return logical_fallback
    return lines

def show_iface_terse(iface: str) -> str:
    return junos_cli_capture(f"show interfaces terse | match ^{iface}")

def verify_oper_state(
    iface: str,
    expect: str,
    timeout_s: int,
    interval_s: float,
    attempts: Optional[int] = None
) -> bool:
    """
    Poll 'show interfaces terse' until Link matches expect ('up'/'down').
    If attempts is provided, it overrides timeout/interval derived attempts.
    """
    expect = expect.lower()
    if attempts is None:
        attempts = max(1, int(round(timeout_s / max(0.1, interval_s))))
    for attempt in range(1, attempts + 1):
        out = show_iface_terse(iface)
        # Try to find the specific line; if not present, state=unknown
        state = "unknown"
        for l in out.splitlines():
            if not l.startswith(iface):
                continue
            name, admin, oper = parse_terse_line(l)
            base = name.split(".", 1)[0].split(":", 1)[0]
            if base != iface:
                continue
            state = oper
            if "." not in name and ":" not in name:  # physical preferred
                break
        user_msg(f"[{iface}] observed link='{state}' (attempt {attempt}/{attempts})")
        if state == expect:
            return True
        time.sleep(interval_s)
    return False

def status_interfaces(ifaces: List[str]) -> None:
    for i in ifaces:
        user_msg(f"--- Status: {i} ---")
        out = junos_cli_capture("show interfaces terse | no-more")
        lines = first_physical_lines_from_terse(out, [i])
        # print a concise summary first
        if not lines:
            warn_msg(f"{i}: no terse output")
        else:
            for l in lines:
                name, admin, oper = parse_terse_line(l)
                if admin == "up" and oper == "up":
                    user_msg(f"[UP ] {name}: admin={admin}, oper={oper}")
                else:
                    user_msg(f"[DOWN] {name}: admin={admin}, oper={oper}")
        # also echo the raw matched lines for visibility
        if lines:
            for l in lines:
                print(l)
                _write(l)
        result_msg(f"Status checked for: {', '.join(ifaces)}")

# -------------------
# Junos interface ops
# -------------------
def disable_interfaces_junos(ifaces: List[str]) -> bool:
    if not ifaces:
        warn_msg("No interfaces provided to disable.")
        return False
    user_msg(f"Disabling interfaces (Junos, single commit): {', '.join(ifaces)}")
    cfg = ["configure"] + [f"set interfaces {i} disable" for i in ifaces] + ["commit and-quit"]
    return junos_cli("; ".join(cfg))

def enable_interfaces_junos(ifaces: List[str]) -> bool:
    if not ifaces:
        warn_msg("No interfaces provided to enable.")
        return False
    user_msg(f"Enabling interfaces (Junos, single commit): {', '.join(ifaces)}")
    cfg = ["configure"] + [f"delete interfaces {i} disable" for i in ifaces] + ["commit and-quit"]
    return junos_cli("; ".join(cfg))

# -------------------
# Broadcom helpers
# -------------------
_BRCM_BIN_CANDIDATES = (
    "/usr/sbin/jbcmcmd.py",
    "jbcmcmd.py",
    "brckcli",
    "brcm_cli",
    "brcmcli",
)

def _find_brcm_cli() -> Optional[str]:
    for b in _BRCM_BIN_CANDIDATES:
        try:
            rc = subprocess.run(["bash", "-lc", f"command -v {b}"], capture_output=True, text=True)
            if rc.returncode == 0:
                path = rc.stdout.strip()
                if path:
                    return path
        except Exception:
            pass
    return None

def brcm_run(cmd: str) -> bool:
    """
    Run a Broadcom command via the located CLI. The command string is passed as one argument.
    Example: brcm_run('port 40 enable=false')
    """
    bin_path = _find_brcm_cli()
    if not bin_path:
        warn_msg("Broadcom CLI tool not found (tried: brckcli, brcm_cli, brcmcli, jbcmcmd.py).")
        return False
    with open(LOGFILE, "a", encoding="utf-8", errors="replace") as f:
        try:
            subprocess.run([bin_path, cmd], stdout=f, stderr=f, check=True)
            return True
        except subprocess.CalledProcessError:
            return False

def brcm_link_status_for_iface(iface: str):
    """
    Emit Broadcom link status details for a Junos iface using qfx.brcm.pfe.port.link_status.
    This prints directly to log (and console header) for visibility.
    """
    user_msg(f"[BRCM-STATUS] {iface} (via qfx.brcm.pfe.port.link_status)")
    with open(LOGFILE, "a", encoding="utf-8", errors="replace") as f:
        try:
            out = subprocess.check_output(["qfx.brcm.pfe.port.link_status", iface], text=True)
            # echo to console minimally; full details go to logfile
            print(out)
            f.write(out)
            if not out.endswith("\n"):
                f.write("\n")
        except subprocess.CalledProcessError:
            warn_msg(f"[BRCM] link_status failed for {iface}")

def map_iface_to_brcm_port(iface: str) -> Optional[int]:
    """
    Map a Junos interface to Broadcom port using qfx.brcm.pfe.port.link_status output.
    Looks for 'stream' value in the channel summary (commonly the BCM port).
    """
    try:
        out = subprocess.check_output(["qfx.brcm.pfe.port.link_status", iface], text=True)
    except subprocess.CalledProcessError:
        warn_msg(f"[BRCM-MAP] link_status failed for {iface}")
        return None

    # Heuristic: find line starting with 'channel-...' and read last column 'stream'
    stream = None
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        # table line: ... inst   stream
        if line.startswith("channel-") and "stream" not in line:
            cols = [c for c in line.split() if c]
            if len(cols) >= 1:
                try:
                    # usually the last column is stream (port number)
                    stream = int(cols[-1])
                    break
                except Exception:
                    pass
    if stream is not None:
        user_msg(f"[BRCM-MAP] {iface} -> port {stream}")
    else:
        warn_msg(f"[BRCM-MAP] Could not map {iface} to Broadcom port (no 'stream' found)")
    return stream

def disable_interfaces_brcm(ifaces: List[str]) -> bool:
    ports = []
    for i in ifaces:
        p = map_iface_to_brcm_port(i)
        if p is not None:
            ports.append(p)
    if not ports:
        return False
    user_msg(f"[BRCM] Setting enable=false for ports: {', '.join(str(p) for p in ports)}")
    ok_all = True
    for p in ports:
        if not brcm_run(f"port {p} enable=false"):
            ok_all = False
    return ok_all

def enable_interfaces_brcm(ifaces: List[str]) -> bool:
    ports = []
    for i in ifaces:
        p = map_iface_to_brcm_port(i)
        if p is not None:
            ports.append(p)
    if not ports:
        return False
    user_msg(f"[BRCM] Setting enable=true for ports: {', '.join(str(p) for p in ports)}")
    ok_all = True
    for p in ports:
        if not brcm_run(f"port {p} enable=true"):
            ok_all = False
    return ok_all

# -------------------
# Optics OIR test
# -------------------
def _xml_name_exists(xml_text: str, name_text: str) -> bool:
    if not xml_text or not name_text:
        return False
    try:
        root = ET.fromstring(xml_text)
    except Exception:
        return False
    target = name_text.strip()
    if not target:
        return False
    for n in root.iter():
        if n.tag.endswith("name") and (n.text or "").strip() == target:
            return True
    return False

def _xcvr_present_in_inventory(xcvr_name: str) -> bool:
    xml_out = junos_cli_capture_quiet("show chassis hardware detail | display xml | no-more")
    if _xml_name_exists(xml_out, xcvr_name):
        return True
    text_out = junos_cli_capture_quiet('show chassis hardware detail | no-more | match "Xcvr "')
    if xcvr_name and text_out and xcvr_name.casefold() in text_out.casefold():
        return True
    return False

def _pfe_optics_action(fpc_slot: int, pic_slot: int, port: str, action: str):
    payload = f'test picd optics fpc_slot {int(fpc_slot)} pic_slot {int(pic_slot)} port {str(port).strip()} cmd {action}'
    cli_cmd = f'request pfe execute command "{payload}" target fpc{int(fpc_slot)}'
    user_msg(f"[OIR] action={action} target={int(fpc_slot)}/{int(pic_slot)}/{str(port).strip()}")
    return junos_cli_capture(cli_cmd)

def _poll_for_xcvr_after_insert(xcvr_name: str, retries: int, poll_delay_sec: float) -> bool:
    for i in range(1, retries + 1):
        if _xcvr_present_in_inventory(xcvr_name):
            user_msg(f"[OIR] '{xcvr_name}' visible after insert (try {i}/{retries})")
            return True
        if i < retries:
            time.sleep(poll_delay_sec)
    warn_msg(f"[OIR] '{xcvr_name}' NOT visible after insert in {retries} tries")
    return False

def optics_oir_test(
    fpc_slot: Optional[int],
    pic_slot: Optional[int],
    ports: List[str],
    poll_delay_sec: float = 1.0,
    retries: int = 20,
    cycles: int = 1,
    check_status: bool = False,
    status_timeout: int = 24,
    status_interval: float = 2.0,
    down_timeout: int = 12,
    down_interval: float = 1.5,
    inter_cycle_wait: int = 0,
    remove_only: bool = False,
    insert_only: bool = False,
    verify_attempts: Optional[int] = None,
) -> bool:
    if remove_only and insert_only:
        warn_msg("Cannot use both --remove-only and --insert-only for OIR.")
        return False

    remove_step = True
    insert_step = True
    if remove_only:
        insert_step = False
    if insert_only:
        remove_step = False
    fpc_slot = 0 if fpc_slot is None else fpc_slot
    pic_slot = 0 if pic_slot is None else pic_slot
    if not ports:
        warn_msg("No ports provided for optics OIR test.")
        return False
    cycles = max(1, int(cycles or 1))

    norm_ports = [str(p).strip() for p in ports if str(p).strip()]
    user_msg(f"[OIR] fpc={fpc_slot}, pic={pic_slot}, ports={', '.join(norm_ports)} (poll_delay={poll_delay_sec}s, retries={retries}, cycles={cycles})")
    all_ok = True

    for port in norm_ports:
        try:
            port_num = int(str(port).strip())
        except ValueError:
            warn_msg(f"[OIR] Invalid port value '{port}' (must be numeric).")
            all_ok = False
            continue

        port_disp = f"{int(fpc_slot)}/{int(pic_slot)}/{port_num}"
        xcvr_name = f"Xcvr {port_num}"
        link_iface = normalize_iface_token(str(port_num))
        mode_desc = "remove->insert" if (remove_step and insert_step) else ("remove-only" if remove_step else "insert-only")
        user_msg(f"[OIR] {port_disp}: {mode_desc} (cycles={cycles})")

        # Pre-check: ensure Xcvr is visible before starting; otherwise skip with warn (skip this if insert-only)
        if remove_step and not _xcvr_present_in_inventory(xcvr_name):
            warn_msg(f"[OIR] {port_disp}: transceiver '{xcvr_name}' not visible before test, skipping.")
            result_msg(f"[OIR] {port_disp}: SKIP (not present pre-test)")
            all_ok = False
            continue

        port_ok = True
        for cycle in range(1, cycles + 1):
            try:
                user_msg(f"[OIR] {port_disp} cycle {cycle}/{cycles}")
                _pfe_optics_action(fpc_slot, pic_slot, port_num, "oir_enable")
                time.sleep(0.5)
                if remove_step:
                    _pfe_optics_action(fpc_slot, pic_slot, port_num, "remove")
                    time.sleep(0.8)
                    if check_status:
                        user_msg(f"[OIR] {port_disp}: verifying link DOWN on {link_iface} (timeout {down_timeout}s)")
                    if not verify_oper_state(link_iface, "down", down_timeout, down_interval, attempts=verify_attempts):
                        warn_msg(f"[OIR] {port_disp}: link did not go DOWN within timeout")
                        port_ok = False
                if insert_step:
                    _pfe_optics_action(fpc_slot, pic_slot, port_num, "insert")
                    time.sleep(0.5)
                _pfe_optics_action(fpc_slot, pic_slot, port_num, "oir_disable")
                time.sleep(0.5)
            except Exception as e:
                warn_msg(f"[OIR] Error during OIR sequence for {port_disp} (cycle {cycle}): {e}")
                port_ok = False
                continue

            if insert_step:
                ok = _poll_for_xcvr_after_insert(xcvr_name, retries, poll_delay_sec)
                if not ok:
                    port_ok = False
                # Optional link status check after inventory appears
                if ok and check_status:
                    user_msg(f"[OIR] {port_disp}: verifying link UP on {link_iface} (timeout {status_timeout}s)")
                    if not verify_oper_state(link_iface, "up", status_timeout, status_interval, attempts=verify_attempts):
                        warn_msg(f"[OIR] {port_disp}: link did not come UP within timeout")
                        port_ok = False

        if port_ok:
            result_msg(f"[OIR] {port_disp}: SUCCESS (transceiver visible across {cycles} cycle{'s' if cycles != 1 else ''})")
        else:
            result_msg(f"[OIR] {port_disp}: FAIL (transceiver not visible in one or more cycles)")
            all_ok = False
        if inter_cycle_wait > 0 and cycle != cycles:
            user_msg(f"[OIR] Waiting {inter_cycle_wait}s before next cycle for {port_disp}")
            time.sleep(inter_cycle_wait)

    result_msg(f"[OIR] Summary: {'OK' if all_ok else 'PARTIAL/FAIL'} for ports {', '.join(norm_ports)}")
    return all_ok

# -------------------
# Flap logic (Junos)
# -------------------
def flap_interfaces_junos(
    ifaces: List[str],
    wait_seconds: int,
    count: int,
    down_timeout: int,
    up_timeout: int,
    down_interval: float,
    up_interval: float,
    attempts: Optional[int],
    show_status_after: bool = True,
):
    if not ifaces:
        warn_msg("No interfaces provided for flap.")
        return

    user_msg(f"[JUNOS-FLAP] {', '.join(ifaces)} x{count} (wait {wait_seconds}s)")
    for cycle in range(1, count + 1):
        user_msg(f"--- Flap cycle {cycle}/{count} ---")
        ok_disable = disable_interfaces_junos(ifaces)
        if ok_disable:
            all_down = True
            for n in ifaces:
                ok = verify_oper_state(n, "down", down_timeout, down_interval, attempts=attempts)
                if not ok:
                    warn_msg(f"{n}: did not go DOWN within timeout")
                    all_down = False
            result_msg(f"Cycle {cycle}: disable {'OK' if all_down else 'PARTIAL/FAIL'}")
        else:
            warn_msg("Disable (flap step) failed.")
            result_msg(f"Cycle {cycle}: disable FAIL")

        user_msg(f"Waiting {wait_seconds}s before enabling...")
        time.sleep(max(0, int(wait_seconds)))

        ok_enable = enable_interfaces_junos(ifaces)
        if ok_enable:
            all_up = True
            for n in ifaces:
                ok = verify_oper_state(n, "up", up_timeout, up_interval, attempts=attempts)
                if not ok:
                    warn_msg(f"{n}: did not come UP within timeout")
                    all_up = False
            result_msg(f"Cycle {cycle}: enable {'OK' if all_up else 'PARTIAL/FAIL'}")
        else:
            warn_msg("Enable (flap step) failed.")
            result_msg(f"Cycle {cycle}: enable FAIL")

    if show_status_after:
        status_interfaces(ifaces)
    result_msg(f"[JUNOS-FLAP] complete for: {', '.join(ifaces)}")

# -------------------
# Flap logic (Broadcom)
# -------------------
def flap_interfaces_brcm(
    ifaces: List[str],
    wait_seconds: int,
    count: int,
    down_timeout: int,
    up_timeout: int,
    down_interval: float,
    up_interval: float,
    attempts: Optional[int],
    post_up_wait: int = 5,
    show_status_after: bool = True,
):
    if not ifaces:
        warn_msg("No interfaces provided for flap.")
        return

    cli_path = _find_brcm_cli()
    if not cli_path:
        warn_msg("Broadcom CLI tool not found (cannot flap via BRCM).")
        return
    user_msg(f"[BRCM] Using CLI: {cli_path}")

    user_msg(f"[BRCM-FLAP] {', '.join(ifaces)} x{count} (wait {wait_seconds}s pre-enable, post-up-wait {post_up_wait}s)")
    for cycle in range(1, count + 1):
        user_msg(f"--- Flap cycle {cycle}/{count} ---")
        # Disable
        ok_disable = disable_interfaces_brcm(ifaces)
        if ok_disable:
            all_down = True
            for n in ifaces:
                ok = verify_oper_state(n, "down", down_timeout, down_interval, attempts=attempts)
                if not ok:
                    warn_msg(f"{n}: did not go DOWN within timeout")
                    all_down = False
            result_msg(f"Cycle {cycle}: BRCM disable {'OK' if all_down else 'PARTIAL/FAIL'}")
            # Show BRCM status right after disable
            for n in ifaces:
                brcm_link_status_for_iface(n)
        else:
            warn_msg("BRCM disable (flap step) failed.")
            result_msg(f"Cycle {cycle}: BRCM disable FAIL")

        user_msg(f"Waiting {wait_seconds}s before enabling...")
        time.sleep(max(0, int(wait_seconds)))

        # Enable
        ok_enable = enable_interfaces_brcm(ifaces)
        if ok_enable:
            all_up = True
            for n in ifaces:
                ok = verify_oper_state(n, "up", up_timeout, up_interval, attempts=attempts)
                if not ok:
                    warn_msg(f"{n}: did not come UP within timeout")
                    all_up = False
            result_msg(f"Cycle {cycle}: BRCM enable {'OK' if all_up else 'PARTIAL/FAIL'}")
            # Show BRCM status right after enable
            for n in ifaces:
                brcm_link_status_for_iface(n)
        else:
            warn_msg("BRCM enable (flap step) failed.")
            result_msg(f"Cycle {cycle}: BRCM enable FAIL")

    # Optional post-up wait and status
    if post_up_wait > 0:
        user_msg(f"Waiting {post_up_wait}s after final enable before status...")
        time.sleep(post_up_wait)

    if show_status_after:
        status_interfaces(ifaces)

    result_msg(f"[BRCM-FLAP] complete for: {', '.join(ifaces)}")

# -------------------
# Main
# -------------------
def main():
    # Early parse --logfile to set destination before any output
    pre = argparse.ArgumentParser(add_help=False)
    pre.add_argument("--logfile", help="Path to log file (default: /var/tmp/debug_cli.log)")
    known, _ = pre.parse_known_args()
    if known.logfile:
        set_logfile(known.logfile)
    else:
        set_logfile(LOGFILE)

    ap = argparse.ArgumentParser(description="Debug CLI & Interface Control", parents=[pre])
    ap.add_argument("-d", "--disable", help="Interfaces to disable (comma-separated)")
    ap.add_argument("-e", "--enable",  help="Interfaces to enable (comma-separated)")
    ap.add_argument("-s", "--status",  help="Interfaces to show status (comma-separated)")

    ap.add_argument("--flap",          help="Interfaces to flap (comma-separated)")
    ap.add_argument("--flap-wait",     type=int, default=5, help="Seconds between disable and enable (default: 5)")
    ap.add_argument("--flap-count",    type=int, default=1, help="Number of flap iterations (default: 1)")
    ap.add_argument("--post-up-wait",  type=int, default=5, help="Seconds to wait after final enable before status (default: 5)")

    # Broadcom CLI: optional sub-action or flag
    ap.add_argument("--brcm_cli", nargs="*", metavar=("ACTION", "IFACES"),
                    help="Optional Broadcom action: 'disable IFACES' or 'enable IFACES'. "
                         "Without args, acts as a flag so --flap uses Broadcom.")

    # Optics OIR test
    ap.add_argument("--oir-test", nargs="?", const=OIR_FLAG_SENTINEL,
                    help="Ports to optics OIR test (comma-separated). If provided without args, reuses --flap list.")
    ap.add_argument("--fpc-slot",       type=int, default=0, help="FPC slot for optics OIR test (default: 0)")
    ap.add_argument("--pic-slot",       type=int, default=0, help="PIC slot for optics OIR test (default: 0)")
    ap.add_argument("--oir-poll-delay", type=float, default=1.0, help="Seconds between OIR inventory polls (default: 1.0)")
    ap.add_argument("--oir-retries",    type=int, default=20, help="Retries to find transceiver after insert (default: 20)")
    ap.add_argument("--check-status", action="store_true", help="For OIR: also verify interface link comes UP after insert")
    ap.add_argument("--remove-only", action="store_true", help="For OIR: run remove-only (skip insert)")
    ap.add_argument("--insert-only", action="store_true", help="For OIR: run insert-only (skip remove)")

    # Interface mapping
    ap.add_argument("--iface-prefix", default="et-0/0/",
                    help="Prefix for mapping bare port numbers (default: et-0/0/; e.g., use xe-0/0/ for 10G)")

    # verification tunables
    ap.add_argument("--down-timeout",  type=int,   default=12,  help="Seconds to wait for link to go DOWN (default: 12)")
    ap.add_argument("--up-timeout",    type=int,   default=24,  help="Seconds to wait for link to come UP (default: 24)")
    ap.add_argument("--down-interval", type=float, default=1.5, help="Polling interval during DOWN verify (default: 1.5)")
    ap.add_argument("--up-interval",   type=float, default=2.0, help="Polling interval during UP verify (default: 2.0)")
    ap.add_argument("--attempts",      type=int,   default=5,   help="Override verify attempts (default: 5).")

    args = ap.parse_args()

    user_msg(f"Log file: {LOGFILE}")
    set_iface_prefix(args.iface_prefix)

    # Determine if brcm flag-only mode is set
    brcm_flag = False
    brcm_action = None
    brcm_ifaces: List[str] = []
    if args.brcm_cli is not None:
        if len(args.brcm_cli) >= 2:
            brcm_action = args.brcm_cli[0].lower()
            brcm_ifaces = normalize_iface_list(args.brcm_cli[1])
        else:
            brcm_flag = True
            user_msg("[BRCM] Broadcom mode flag enabled (flap will prefer BRCM via jbcmcmd.py).")

    # Build ordered ops list from argv to honor user sequence
    ordered_ops: List[Tuple[str, Optional[str]]] = []
    argv = sys.argv[1:]

    def _value_for(idx: int, fallback: Optional[str]) -> Optional[str]:
        tok = argv[idx]
        if "=" in tok:
            return tok.split("=", 1)[1]
        if idx + 1 < len(argv) and not argv[idx + 1].startswith("-"):
            return argv[idx + 1]
        return fallback

    i = 0
    while i < len(argv):
        tok = argv[i]
        if tok in ("-d", "--disable") or tok.startswith("--disable="):
            ordered_ops.append(("disable_junos", _value_for(i, args.disable)))
        elif tok in ("-e", "--enable") or tok.startswith("--enable="):
            ordered_ops.append(("enable_junos", _value_for(i, args.enable)))
        elif tok in ("-s", "--status") or tok.startswith("--status="):
            ordered_ops.append(("status", _value_for(i, args.status)))
        elif tok == "--flap" or tok.startswith("--flap="):
            ordered_ops.append(("flap", _value_for(i, args.flap)))
        elif tok == "--oir-test" or tok.startswith("--oir-test="):
            ordered_ops.append(("oir_test", _value_for(i, args.oir_test)))
        elif tok == "--brcm_cli":
            if brcm_action and brcm_ifaces:
                ordered_ops.append(("brcm_action", f"{brcm_action}:{','.join(brcm_ifaces)}"))
            else:
                # flag-only
                ordered_ops.append(("brcm_flag", None))
        i += 1

    # Execute ordered ops if any
    if ordered_ops:
        for op, val in ordered_ops:
            if op == "brcm_flag":
                user_msg("[BRCM] Broadcom mode flag noted (flap will use BRCM).")
                continue

            if op == "brcm_action":
                action, ifs = (val or "").split(":", 1)
                ifaces = normalize_iface_list(ifs)
                if not ifaces:
                    warn_msg("No IFACES supplied for --brcm_cli ACTION IFACES")
                    continue
                # map first; if mapping fails we still try per-iface mapping in helpers
                _ = [map_iface_to_brcm_port(i) for i in ifaces]  # mapping logs
                if action == "disable":
                    ok = disable_interfaces_brcm(ifaces)
                    if ok:
                        # verify down using configured attempts
                        all_down = True
                        for n in ifaces:
                            if not verify_oper_state(n, "down", args.down_timeout, args.down_interval, attempts=args.attempts):
                                all_down = False
                                warn_msg(f"{n}: did not go DOWN within timeout")
                        result_msg(f"BRCM one-shot disable: {'OK' if all_down else 'PARTIAL/FAIL'} -> {', '.join(ifaces)}")
                        for n in ifaces:
                            brcm_link_status_for_iface(n)
                    else:
                        result_msg(f"BRCM one-shot disable: FAIL -> {', '.join(ifaces)}")
                elif action == "enable":
                    ok = enable_interfaces_brcm(ifaces)
                    if ok:
                        all_up = True
                        for n in ifaces:
                            if not verify_oper_state(n, "up", args.up_timeout, args.up_interval, attempts=args.attempts):
                                all_up = False
                                warn_msg(f"{n}: did not come UP within timeout")
                        result_msg(f"BRCM one-shot enable: {'OK' if all_up else 'PARTIAL/FAIL'} -> {', '.join(ifaces)}")
                        for n in ifaces:
                            brcm_link_status_for_iface(n)
                    else:
                        result_msg(f"BRCM one-shot enable: FAIL -> {', '.join(ifaces)}")
                else:
                    warn_msg(f"Unknown --brcm_cli action: {action}")
                continue

            if op == "oir_test":
                ports: List[str] = []
                # If provided as flag-only, reuse flap list if present
                if val == OIR_FLAG_SENTINEL or not val:
                    ports = oir_ports_from_tokens(normalize_iface_list(args.flap))
                else:
                    ports = oir_ports_from_tokens(normalize_iface_list(val))
                if not ports:
                    warn_msg("No ports for --oir-test (provide ports or reuse --flap list)")
                    continue
                ok = optics_oir_test(
                    fpc_slot=args.fpc_slot,
                    pic_slot=args.pic_slot,
                    ports=ports,
                    poll_delay_sec=args.oir_poll_delay,
                    retries=args.oir_retries,
                    cycles=args.flap_count,
                    check_status=args.check_status,
                    status_timeout=args.up_timeout,
                    status_interval=args.up_interval,
                    down_timeout=args.down_timeout,
                    down_interval=args.down_interval,
                    inter_cycle_wait=args.flap_wait,
                    remove_only=args.remove_only,
                    insert_only=args.insert_only,
                    verify_attempts=args.attempts,
                )
                result_msg(f"OIR test {'OK' if ok else 'PARTIAL/FAIL'} -> {', '.join(ports)}")
                continue

            ifaces = normalize_iface_list(val) if val else []
            if op == "disable_junos":
                if not ifaces:
                    warn_msg("No interfaces for --disable")
                    continue
                ok = disable_interfaces_junos(ifaces)
                if ok:
                    all_down = True
                    for n in ifaces:
                        if not verify_oper_state(n, "down", args.down_timeout, args.down_interval, attempts=args.attempts):
                            all_down = False
                            warn_msg(f"{n}: did not go DOWN within timeout")
                    result_msg(f"Disabled (Junos): {'OK' if all_down else 'PARTIAL/FAIL'} -> {', '.join(ifaces)}")
                else:
                    result_msg(f"Disabled (Junos): FAIL -> {', '.join(ifaces)}")

            elif op == "enable_junos":
                if not ifaces:
                    warn_msg("No interfaces for --enable")
                    continue
                ok = enable_interfaces_junos(ifaces)
                if ok:
                    all_up = True
                    for n in ifaces:
                        if not verify_oper_state(n, "up", args.up_timeout, args.up_interval, attempts=args.attempts):
                            all_up = False
                            warn_msg(f"{n}: did not come UP within timeout")
                    result_msg(f"Enabled (Junos): {'OK' if all_up else 'PARTIAL/FAIL'} -> {', '.join(ifaces)}")
                else:
                    result_msg(f"Enabled (Junos): FAIL -> {', '.join(ifaces)}")

            elif op == "status":
                if not ifaces:
                    warn_msg("No interfaces for --status")
                    continue
                status_interfaces(ifaces)

            elif op == "flap":
                if not ifaces:
                    warn_msg("No interfaces for --flap")
                    continue
                # choose engine: BRCM if flag present, else Junos
                if brcm_flag:
                    user_msg(f"[PLAN] FLAP (BRCM) -> {', '.join(ifaces)}")
                    flap_interfaces_brcm(
                        ifaces,
                        wait_seconds=args.flap_wait,
                        count=args.flap_count,
                        down_timeout=args.down_timeout,
                        up_timeout=args.up_timeout,
                        down_interval=args.down_interval,
                        up_interval=args.up_interval,
                        attempts=args.attempts,
                        post_up_wait=args.post_up_wait,
                        show_status_after=True,
                    )
                else:
                    user_msg(f"[PLAN] FLAP (Junos) -> {', '.join(ifaces)}")
                    flap_interfaces_junos(
                        ifaces,
                        wait_seconds=args.flap_wait,
                        count=args.flap_count,
                        down_timeout=args.down_timeout,
                        up_timeout=args.up_timeout,
                        down_interval=args.down_interval,
                        up_interval=args.up_interval,
                        attempts=args.attempts,
                        show_status_after=True,
                    )
        print(f"[INFO] Log saved at {LOGFILE}")
        return

    # No ops
    user_msg("No interface control args provided; nothing to do.")
    print(f"[INFO] Log saved at {LOGFILE}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[WARN] Interrupted by user (Ctrl+C).")
        print(f"[INFO] Log saved at {LOGFILE}")
        sys.exit(130)

```
