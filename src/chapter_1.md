# XAI Link Flap Escalation

## Log Location
- /volume/CSdata/amodh/2025-1014-899718

## Problem Statement
- All server facing ports (port 0-35) are flapping at the same time and recover in approx. 12 seconds. The issue started Oct 13 and is seen on more than 11 devices so far (11 out of 700+).
- Server facing ports use AEC cables - Y cables (800G <-> 2x400G). The uplink ports (p36 to 63) with DR8 optics do not see flaps.
- This issue was never reported in Mem-1 or Colossus-1.
- Each time a port flap is seen, the switch receives a LOS (Loss of Signal).


## Initial Findings
- At 16:29:41 UTC on Dec 14, every front-panel AEC port `et-0/0/0` through `et-0/0/35` was driven to harddown by PFE linkscan (local fault) within the same second; see `memy-cca-as1-1/memy-cca-journal-14-Dec.txt` where each IFD flips `harddown:0 -> 1` and SNMP trap `LINK_DOWN` fires. They recovered together at ~16:37:08 when the same interfaces clear `harddown:1 -> 0` in the same file. No FPC/PFE reset messages in the window, only mass link faults on these ports.
- Switch-side port detail for one affected lane shows Rx LOS/LOCAL-FAULT during the event and a few uncorrected FECs when it flapped (for example, `memy-cca-as1-1/interface_flap.txt` for `et-0/0/17` shows `Device flags: ... Transceiver-Rx-LOS`, `Active defects: LINK, LOCAL-FAULT`, `FEC Uncorrected Errors: 12`, last flapped 16:29:42).
- Hosts connected via these ports logged simultaneous down events: 20+ servers report `mlx5_eth0: Port: 1 Link DOWN` at 16:29:41 (for example, `memy-cca-as1-1/cca_logs/memy-cca-05-sr1.xpop.twttr.net/mlxlink_logs/log_20251214_162944_634.txt`, `memy-cca-as1-1/cca_logs/memy-cca-10-sr1.xpop.twttr.net/mlxlink_logs/log_20251214_162944_517.txt`).
- Cable diagnostics on an impacted host show the AEC blaming the local PHY: in `memy-cca-as1-1/cca_logs/memy-cca-10-sr1.xpop.twttr.net/mlxlink_logs/amber_flap_20251214_162944_517*.csv` the record has `Link_Down=1`, `Phy_Manager_State=Polling/Active`, `down_blame=Local_phy`, `local_reason_opcode=Alignment_loss`, cable vendor Credo, 4m active copper (AEC). The "after 60 sec" capture still reports `Link_Down=1`, meaning the AEC stayed down for at least a minute.
- Scope matches the notes: only the AEC-connected front-panel ports (0-35) show the fault; higher-numbered QSFPs and other media types are not logging flaps in the same window.

### What it points to
- Simultaneous alignment loss across all Credo AECs suggests a shared dependency (retimer firmware crash/reset or a power or I2C disturbance on the AEC cages) rather than individual links. The switch ASIC stayed up; hosts simply saw loss of light.
- No temperature or PSU alarms around the event, so thermal or brown-out seems unlikely.

### Suggested next actions
- Reflash or upgrade NIC and AEC firmware (these logs show non-fastbootable AEC FW and local-phy alignment loss); swap one link to a DAC or optic as an A/B check.
- If possible, reseat or power-cycle a few AECs and watch amber or mlxlink for recovery; capture amber when links are healthy for baseline.
- If the 16:29 window coincided with maintenance, avoid running anything that toggles all AECs; otherwise open a vendor/RMA case for the Credo AEC batch with the above evidence.
- Keep `memy-cca-.../cca_logs` collection handy for the next occurrence; if it repeats, consider moving critical traffic off ports 0-35 until the AEC issue is cleared.


## Auto Negotiation Notes
- Credo confirmed auto negotiation for AEC cables should be turned off on both sides (switch and server).
- Broadcom also confirmed auto negotiation should be turned off on the switch.
- Please check and confirm auto negotiation is disabled.
- In the lab, link flaps were observed when auto negotiation was enabled or disabled.
- Can auto negotiation be disabled on a sample configuration?


## Purpose
- Capture what happened during the link flap escalation and why it mattered to xAI reliability.
- Give oncall engineers a concise snapshot plus links to deeper sections in this book.
- Provide a repeatable playbook so similar transport issues can be mitigated faster.

## Scope & Services
- Impacted: xAI serving stack (inference + embedding nodes) in the primary production AZ; adjust the AZ/cluster label if this moves.
- Data plane: top-of-rack uplinks to the aggregation layer; control plane signals (BGP/BFD) shared the same optics.
- Traffic pattern: north-south user requests with east-west model fetches; redundancy available through paired uplinks.

## Event Summary
- Symptoms: repeated down/up events on one uplink caused packet loss, retransmits, and elevated tail latency while flows hashed to the bad member.
- Customer impact: transient 5xx spikes (~3% for ~12 minutes) and p95 latency regression (+250–400 ms) until traffic drained off the flapping link.
- Mitigation: disabled the unhealthy link in the port-channel, forced traffic to the healthy member, replaced the suspect optic, and re-enabled after burn-in.

## Current Status
- The link has been stable after replacement and a 60-minute burn-in with zero CRC/BFD errors observed.
- Additional detection is in place to alarm on sub-minute flaps and CRC growth on xAI TOR uplinks.
- Follow-up items are tracked in the Action Items section.
