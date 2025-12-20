# Server Logs - BF3 NIC

```sh
#!/bin/sh

OUT_DIR="/dev/shm/mnt/persist"
SLEEP=1
HOST=$(hostname)

mkdir -p "$OUT_DIR" || exit 1

while true; do
  TS=$(date +%Y%m%d%H%M%S)

  # 1) Ensure MST devices are created
  mst start >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "[$(date)] ERROR: mst start failed on $HOST" >&2
    sleep "$SLEEP"
    continue
  fi

  # 2) Discover MST device nodes from "mst status"
  DEVS=$(mst status 2>/dev/null | awk '/^\/dev\/mst\//{print $1}')

  if [ -z "$DEVS" ]; then
    echo "[$(date)] WARN: No /dev/mst devices found in mst status on $HOST" >&2
    sleep "$SLEEP"
    continue
  fi

  # 3) Collect amber logs per device
  for dev in $DEVS; do
    devname=$(basename "$dev")
    fname="${OUT_DIR}/amber_${HOST}_${devname}_${TS}.csv"

    echo "[$(date)] Collecting amber: $dev -> $fname"
    mlxlink -d "$dev" --amber_collect "$fname" >> "${OUT_DIR}/amber_collect_${HOST}.log" 2>&1
  done

  sleep "$SLEEP"
done
```

```sh
#!/bin/sh

OUT="/dev/shm/mnt/persist/interface_flap_new.txt"
SLEEP=2
HOST=$(hostname)

while true; do
  TS="$(date)"
  echo "$TS" >> "$OUT"
  echo "#### running mlxlink for MST devices on $HOST ####" >> "$OUT"

  # Ensure MST devices exist
  mst start >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: mst start failed on $HOST" >> "$OUT"
    echo "========================================" >> "$OUT"
    echo >> "$OUT"
    sleep "$SLEEP"
    continue
  fi

  # Discover MST device nodes from mst status
  DEVS=$(mst status 2>/dev/null | awk '/^\/dev\/mst\//{print $1}')

  if [ -z "$DEVS" ]; then
    echo "WARN: No /dev/mst devices found in mst status on $HOST" >> "$OUT"
    echo "========================================" >> "$OUT"
    echo >> "$OUT"
    sleep "$SLEEP"
    continue
  fi

  for dev in $DEVS; do
    echo "---- $dev ----" >> "$OUT"
    mlxlink -d "$dev" --cable --dump -m >> "$OUT" 2>&1
    echo >> "$OUT"
  done

  echo "========================================" >> "$OUT"
  echo >> "$OUT"
  sleep "$SLEEP"
done
```
