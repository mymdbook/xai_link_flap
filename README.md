#URL for this Page
https://mymdbook.github.io/xai_link_flap/


# XAI Link Flap Escalation

## Log Location
- /volume/CSdata/amodh/2025-1014-899718

## Problem Statement
- All server facing ports (port 0-35) are flapping at the same time and recover in approx. 12 seconds. The issue started Oct 13 and is seen on more than 11 devices so far (11 out of 700+).
- Server facing ports use AEC cables - Y cables (800G <-> 2x400G). The uplink ports (p36 to 63) with DR8 optics do not see flaps.
- This issue was never reported in Mem-1 or Colossus-1.
- Each time a port flap is seen, the switch receives a LOS (Loss of Signal).
