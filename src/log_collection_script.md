# Log Collection Script

## QFX5240 Script
```bash
#!/bin/bash
# Function to print timestamp
timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

echo "#### sensor info at $(timestamp)#####"
sensors
echo "#### sensor info at $(timestamp)#####"
jbcmcmd.py "show temp"
echo "#### Running bcm command for port 35:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:0 -v
echo

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE eeprom_rescan for port 2, 0, 35 at $(timestamp) ####"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 2 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 17 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 35 cmd eeprom_rescan"

echo "#### Running bcm command for port 2:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:0 -v
echo

echo "#### Running bcm command for port 2:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:1 -v
echo

echo "#### Running bcm command for port 0:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/17:0 -v
echo

echo "#### Running bcm command for port 0:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/17:1 -v
echo

echo "#### Running bcm command for port 35:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:0 -v
echo

echo "#### Running bcm command for port 35:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:1 -v
echo

echo "#### Sleep for 4s from $(timestamp) ####"
sleep 4

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd identifier | no-more"

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 0 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 0 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 0 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd identifier | no-more"

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for Port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for Port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for Port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd identifier | no-more"

##### Running lspci command ####
echo "#### Running lspci command at $(timestamp) ####"
lspci
```

## Event-Options Config

```text
root@xai-qfx5240-01# show event-options 
policy server_links {
    events snmp_trap_link_down;
    within 1 {
        trigger on 1;
    }
    attributes-match {
        event.snmp_trap_link_down matches "^SNMP_TRAP_LINK_DOWN$";
    }
    then {
        execute-commands {
            commands {
                "request routing-engine execute command \"sh /var/tmp/cs_event-based-script.sh >> /var/log/interface_flap.txt\"";
            }
            output-filename event_option_execution.txt;
            destination destination;
            output-format text;
        }
        raise-trap;
    }
}
destinations {
    destination {
        archive-sites {
            /var/log/;
        }
    }
}
```

## Server Logs - BF3 NIC

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
