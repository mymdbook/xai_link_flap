# Timeline (relative, UTC)

| Time from T0 | Event |
| --- | --- |
| T0 | Link flap detectors fire for TOR uplink member; BFD neighbors begin flapping and packet loss is observed on xAI serving hosts. |
| T+5m | Oncall acknowledges; traffic health checked on redundant uplink to confirm capacity headroom. |
| T+12m | Unhealthy port-channel member is administratively disabled; 5xx/latency regressions begin to clear. |
| T+18m | CRC and error counters captured; optic and cable reseated for quick validation. |
| T+25m | Replacement optic installed; interface comes up clean with zero errors after 5-minute monitoring. |
| T+45m | Burn-in extended to 20 minutes; BFD/BGP neighbors stable, no further flaps. |
| T+60m | Incident comms closed; post-incident review scheduled and action items created. |

Notes:
- Times are relative to the first alert; replace with absolute UTC timestamps if available from alert history.
- Correlate against maintenance windows to confirm or rule out planned work.
