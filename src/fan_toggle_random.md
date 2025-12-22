# Toggle Fan Speed Randomly

[vrf:none] root@xai-qfx5240-01:/var/tmp/fan# cat usage 
chmod +x fan_toggle_random.py

#DEFAULT_SPEEDS = [60, 69, 63, 72, 75, 79, 85, 83, 85, 86, 90, 91, 93, 95, 100]
#Fan Speed Random Toggle Script
#- Randomly selects fan speed from a given list every interval seconds
#- Applies the selected speed to trays 0..4 using Junos 'cli -c' commands
#- Ctrl+C to stop gracefully
#

 
Example: 

Trays 0-3, run 10 iterations, 2-minute interval
##### ./fan_toggle_random.py --trays 0,1,2,3 --iterations 10 --interval 120

```python
#fan_toggle_random.py
#!/usr/bin/env python3
"""
Fan Speed Random Toggle Script
- Randomly selects fan speed from a given list every interval seconds
- Applies the selected speed to trays 0..4 using Junos 'cli -c' commands
- Ctrl+C to stop gracefully
"""

import argparse
import random
import subprocess
import sys
import time
from datetime import datetime


DEFAULT_SPEEDS = [60, 69, 63, 72, 75, 79, 85, 83, 85, 86, 90, 91, 93, 95, 100]


def ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def run_cmd(cmd: str, dry_run: bool = False) -> int:
    if dry_run:
        print(f"{ts()} - DRYRUN: {cmd}")
        return 0
    # Using shell=True because 'cli' is typically a shell command on Junos
    p = subprocess.run(cmd, shell=True)
    return p.returncode


def set_fan_speed(speed: int, trays: list[int], dry_run: bool = False) -> None:
    print(f"{ts()} - Setting fan speed to {speed}%...")
    for tray in trays:
        cmd = f'cli -c "request chassis fan speed {speed} tray {tray}"'
        rc = run_cmd(cmd, dry_run=dry_run)
        if rc != 0:
            raise RuntimeError(f"Command failed (rc={rc}): {cmd}")
    print(f"{ts()} - Fan speed set to {speed}% for trays: {', '.join(map(str, trays))}")


def pick_speed(speeds: list[int], avoid_repeat: bool, last_speed: int | None) -> int:
    if not avoid_repeat or last_speed is None:
        return random.choice(speeds)

    # Try to avoid repeating the same speed back-to-back
    candidates = [s for s in speeds if s != last_speed]
    return random.choice(candidates) if candidates else last_speed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--interval", type=int, default=120, help="Seconds between changes (default: 120)")
    parser.add_argument("--iterations", type=int, default=0,
                        help="Number of iterations (0 = run forever)")
    parser.add_argument("--trays", default="0,1,2,3,4", help="Comma-separated tray IDs (default: 0,1,2,3,4)")
    parser.add_argument("--no-repeat", action="store_true", help="Avoid repeating the same speed consecutively")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without executing")
    args = parser.parse_args()

    trays = [int(x.strip()) for x in args.trays.split(",") if x.strip() != ""]
    speeds = DEFAULT_SPEEDS

    print("Fan Speed Random Toggle Script Started")
    print(f"Speed list: {speeds}")
    print(f"Trays: {trays}")
    print(f"Interval: {args.interval} seconds")
    print("Press Ctrl+C to stop")
    print("========================================")

    last_speed = None
    iteration = 1

    try:
        while True:
            if args.iterations and iteration > args.iterations:
                print(f"{ts()} - Completed {args.iterations} iterations. Exiting.")
                break

            speed = pick_speed(speeds, args.no_repeat, last_speed)

            print(f"\n--- Iteration {iteration} ---")
            set_fan_speed(speed, trays, dry_run=args.dry_run)
            last_speed = speed

            print(f"{ts()} - Waiting {args.interval} seconds before next change...")
            time.sleep(args.interval)

            iteration += 1

    except KeyboardInterrupt:
        print(f"\n{ts()} - Script stopped by user (Ctrl+C)")
        return 0
    except Exception as e:
        print(f"{ts()} - ERROR: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())


```
