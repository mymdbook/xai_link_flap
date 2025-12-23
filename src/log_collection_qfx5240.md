# QFX5240 Script
- Logs to be connected during flap 

```bash
#!/bin/bash
# Function to print timestamp
timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

echo "#### sensor info at $(timestamp)#####"
sensors
echo "#### temperature info at $(timestamp)#####"
jbcmcmd.py "show temp"
echo "#### Running bcm command for port 35:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:0 -v
echo

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE eeprom_rescan for port 2, 17, 35 at $(timestamp) ####"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 2 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 17 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 35 cmd eeprom_rescan"

echo "#### Running bcm command for port 2:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:0 -v
echo

echo "#### Running bcm command for port 2:1 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:1 -v
echo

echo "#### Running bcm command for port 17:0 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/17:0 -v
echo

echo "#### Running bcm command for port 17:1 at $(timestamp) ####"
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
echo "#### Running CLI-PFE info for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd info | no-more"

##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 17 at $(timestamp) ####"
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
