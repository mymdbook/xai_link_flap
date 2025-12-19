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

### Probe Status (Dec 19, 2025)
- Scope data shows no major abnormality on the voltage rails probed.
- Probing 3V3 to port 2, 3V3 for Group3 (parent power net for ports 0-21), 12V Vin_4 (parent for this 3V3), and current through the 12V zone 4.

![Probe status Dec 19 2025](images/Probe-status-dec19-2025.png)

