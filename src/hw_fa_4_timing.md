# HW FA #4 - Timing

## Goal
- Looking for jitter, temperature variation, and other issues with clocks driving SerDes / TH5.
- Evaluate timing as a potential source of disruption that could impact multiple optical links simultaneously.

## Status
- 8 separate 312.5MHz clock signals for 64 SerDes on TH5. Difficult to access these signals directly for phase noise type measurements due to routing (BGA to BGA, buried vias).
- Re-tracing the clock tree upstream has shown a couple of promising areas where we can scope and look for instability or other issues.

## Next Steps
- Attaching probes and working through different parts of the clock tree.
