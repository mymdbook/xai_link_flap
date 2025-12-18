# Impact and Detection

## Observed Impact
- User-facing: short bursts of 5xx/4xx from the xAI serving API due to partial request fan-out hitting unhealthy nodes.
- Platform: BFD and BGP churn on the affected TOR uplink; ECMP hashing occasionally pinned flows to the bad member causing retransmits.
- Duration: elevated error/latency for roughly 12 minutes until the link member was drained; no data loss reported from storage backends.

## Detection Signals
- Network alerts: link flap detector and BFD flap alerts fired for the TOR uplink port-channel member; CRC and input error counters incremented rapidly.
- Service alerts: p95/p99 latency and 5xx rate alarms from the xAI service SLO dashboards; retries per request rose above 2x baseline.
- Logs: noisy interface down/up entries in syslog, corresponding BGP neighbor resets, and application connection resets from affected hosts.

## Dashboards & Queries
- `Grafana -> xAI Networking -> TOR Uplink Health` for flaps, CRCs, and error rate per interface.
- `Grafana -> xAI Service SLOs -> Errors/Latency` for user impact confirmation and regression tracking.
- `Prometheus -> rate(node_network_carrier_changes_total[5m])` and CRC counters for proactive detection.

## Quick Triage Checklist
- Confirm whether flaps are limited to a single port-channel member or across the bundle.
- Check for correlated maintenance (code upgrades, optic swaps, topology changes) around the alert window.
- Verify redundant path health before draining: interface status, BFD, and error counters on the surviving links.
