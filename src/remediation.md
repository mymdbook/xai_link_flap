# Remediation and Root Cause

## Root Cause
- The failing optic on one TOR-to-aggregation uplink introduced intermittent loss, triggering link flaps and BFD resets.
- CRC/input error counters spiked prior to each flap; no corresponding errors on the peer interface, pointing to a local optic/cable issue.
- No concurrent config changes or software upgrades were recorded, reducing likelihood of a control-plane bug.

## Immediate Remediation Steps
1. Validate redundancy and available capacity on the healthy uplink.
2. Administratively disable the flapping port-channel member to force ECMP hashing away from it.
3. Capture interface counters and logs for the post-incident review.
4. Swap the optic (and cable if needed), bring the member back up, and monitor for 20–30 minutes.
5. Re-enable the member once error-free and restore normal traffic distribution.

## Validation Performed
- 60-minute burn-in showed zero CRC/BFD events on the replaced optic.
- Service SLOs (p95 latency, 5xx rate) returned to baseline within minutes of draining the bad link.
- Packet captures on the affected hosts no longer showed retransmit bursts once the link was stable.

## Preventative Actions
- Add CRC growth and sub-minute flap alerts for all xAI TOR uplinks.
- Ensure paired uplinks are load-tested monthly to verify failover capacity.
- Keep a small pool of tested spare optics per AZ and document serials in the asset tracker.
- Include interface error deltas in the oncall dashboard to shorten detection-to-mitigation time.
