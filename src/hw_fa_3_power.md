# HW FA #3 - Power

## Goal
- Looking for potential sources of power noise or instability in Accton power design and schematics.
- Evaluate power as a potential source of disruption that could impact multiple optical links simultaneously.

## Status
- Flapping ports [0-35] map to 3 different power groups; each group includes some ports that do not flap.
- 3.3V optics power rails have been scoped and associated circuits reviewed; no issues found so far.
- Attempts to force link flaps on an RMA QFX5240 by injecting noise have not been successful.

## Next Steps
- Instrument QFX5240 in SysTest replication test-bed with probes and attempt to replicate link flaps.
