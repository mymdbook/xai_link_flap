# XAI Link Flap Escalation

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
