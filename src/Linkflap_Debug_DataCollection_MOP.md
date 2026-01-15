# Link Flap Debug – Data Collection MOP

## Document Purpose
This document describes the data collection procedure and scripts used to help root-cause link flap issues on Juniper QFX5240-64OD platforms.

---

## 1. Scope and Applicability
- **Device**: QFX5240-64OD
- **Junos Evolved Version**: 23.4X100-D40.7-EVO
- **JSU Version**: 1.2

---

## 2. Overview of Data Collection Scripts
Three scripts are used to collect telemetry and diagnostic data:

1. **Periodic Script** – Captures chassis environmental data at regular intervals.
2. **Event-based Script** – Captures detailed system and PHY state immediately after a link-down event.
3. **Server Script** – Gathers NIC and link-related information from connected servers.

Script details are provided in Appendix A.

---

## 3. Baseline Data Collection (Post Boot)

### 3.1 From QFX5240-64OD Switch
- RSI
- Output of Event-based Script

### 3.2 From Connected Server
- Amber logs for connected interfaces
- Output of Server Script

This data serves as baseline reference.

---

## 4. Continuous Monitoring

### 4.1 Start Periodic Script
Run the Periodic Script from Appendix A.

### 4.2 Install Event-based Script
Configure the Event-based Script to trigger after link-down events.

---

## 5. Post Link-Flap Data Collection (≤10 Hours)

### 5.1 From QFX5240-64OD
- RSI
- Periodic Script output
- Event-based Script output
- Trace outputs:
```
show trace application clockd time 840
show trace application evo-pfemand time 840
show trace application picd time 840
show trace application hwdre time 840
```

### 5.2 From Affected Server
- Amber logs
- Server Script output

---

## Appendix A – Scripts

### A.1 Periodic Script
The periodic script will gather information about the environmental conditions in the chassis.  This will indicate if there is a correlation of changing environmental conditions and link flaps.

```sh
#!/bin/sh
echo "#### New Iteration at $(date) ####" >> /var/log/i2c_output.txt
( date ; echo "command: sensors" ; sensors ) >> /var/log/i2c_output.txt
( date ; echo "command: show chassis environment no-forwarding | no-more" ; /usr/sbin/cli -c 'show chassis environment no-forwarding | no-more' ) >> /var/log/i2c_output.txt
( date ; echo "command: jbcmcmd.py -show temp" ; /usr/sbin/jbcmcmd.py "show temp" ) >> /var/log/i2c_output.txt
```

### A.2 Event-based Script
This script will capture state of the system right after a link-down event, which will help identify if there is a change in state which would have caused the flap.  This includes EEPROM Dump and diagnostic information from AEC cables, port status and PCS/PLL/FEC register values at Broadcom TH5, and sensors output to get environment data at the time of link-down.  It is recommended to run this script once initially as well to get the baseline values with all links up.

```bash

#!/bin/bash
# Function to print timestamp
timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

##### AEC Cables EEPROM Dump ####
echo "#### Running CLI-PFE eeprom_rescan for port 2, 17, 35 at $(timestamp) ####"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 2 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 17 cmd eeprom_rescan"
cli-pfe -c "test picd optics fpc_slot 0 pic_slot 0 port 35 cmd eeprom_rescan"


echo "#### Running bcm command for port 2 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/2:1 -v
echo
echo "#### Running bcm command for port 17 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/17:1 -v
echo
echo "#### Running bcm command for port 35 at $(timestamp) ####"
qfx.brcm.pfe.port.link_status et-0/0/35:1 -v
echo

echo "#### Running BCM PLL reg dump at $(timestamp) ####"
jbcmcmd.py "dsh -c 'g PP_PLL_STATUSr'"
echo

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd info | no-more"
##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd diagnostics | no-more"
##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 2 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 2 cmd identifier | no-more"
echo

echo "#### Running BCM reg dump for channel 1 at $(timestamp) ####"
jbcmcmd.py "dsh -c 'phy  1 TX_X4_PCS_STS_LATCHr'"
jbcmcmd.py "dsh -c 'phy  1 RX_X4_AM_LOCK_LATCH_STSr'"
jbcmcmd.py "dsh -c 'phy  1 RX_X4_PCS_LATCH_STS1r'"
jbcmcmd.py "dsh -c 'phy  1 RX_X4_RS_FEC_SYNC_STS_Ar'"
jbcmcmd.py "dsh -c 'phy  1 RX_X4_RS_FEC_SYNC_STS_Br'"
jbcmcmd.py "dsh -c 'phy  1 RX_X4_RS_FEC_RXP_STSr '"
jbcmcmd.py "dsh -c 'phy  1 RX_X4_RX_LATCH_STSr'"
jbcmcmd.py "dsh -c 'phy  1 CORE_PLL_PLL_LOCK_LOSS_STSr'"
echo
echo "#### Running BCM reg dump all for channel 1 at $(timestamp) ####"
jbcmcmd.py "dsh -c 'phy  1 *'"
echo

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd info | no-more"
##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd diagnostics | no-more"
##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 17 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 17 cmd identifier | no-more"

echo "#### Running BCM reg dump for ports 96 at $(timestamp) ####"
jbcmcmd.py "dsh -c 'phy  96 TX_X4_PCS_STS_LATCHr'"
jbcmcmd.py "dsh -c 'phy  96 RX_X4_AM_LOCK_LATCH_STSr'"
jbcmcmd.py "dsh -c 'phy  96 RX_X4_PCS_LATCH_STS1r'"
jbcmcmd.py "dsh -c 'phy  96 RX_X4_RS_FEC_SYNC_STS_Ar'"
jbcmcmd.py "dsh -c 'phy  96 RX_X4_RS_FEC_SYNC_STS_Br'"
jbcmcmd.py "dsh -c 'phy  96 RX_X4_RS_FEC_RXP_STSr '"
jbcmcmd.py "dsh -c 'phy  96 RX_X4_RX_LATCH_STSr'"
jbcmcmd.py "dsh -c 'phy  96 CORE_PLL_PLL_LOCK_LOSS_STSr'"
echo

##### Running CLI-PFE INFO####
echo "#### Running CLI-PFE info for port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd info | no-more"
##### Running CLI-PFE diagnostics####
echo "#### Running CLI-PFE diag for port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd diagnostics | no-more"

##### Running CLI-PFE identifier####
echo "#### Running CLI-PFE identifier for port 35 at $(timestamp) ####"
cli-pfe -c "show picd optics pic_slot 0 fpc_slot 0 port 35 cmd identifier | no-more"

echo "#### Running BCM reg dump for ports 195 at $(timestamp) ####"
jbcmcmd.py "dsh -c 'phy  195 TX_X4_PCS_STS_LATCHr'"
jbcmcmd.py "dsh -c 'phy  195 RX_X4_AM_LOCK_LATCH_STSr'"
jbcmcmd.py "dsh -c 'phy  195 RX_X4_PCS_LATCH_STS1r'"
jbcmcmd.py "dsh -c 'phy  195 RX_X4_RS_FEC_SYNC_STS_Ar'"
jbcmcmd.py "dsh -c 'phy  195 RX_X4_RS_FEC_SYNC_STS_Br'"
jbcmcmd.py "dsh -c 'phy  195 RX_X4_RS_FEC_RXP_STSr '"
jbcmcmd.py "dsh -c 'phy  195 RX_X4_RX_LATCH_STSr'"
jbcmcmd.py "dsh -c 'phy  195 CORE_PLL_PLL_LOCK_LOSS_STSr'"
echo

##### Running sensors command ####
echo "#### Running sensors command at $(timestamp) ####"
sensors
echo


```

### A.3 Server Script
This script collects the relevant link-status information from the server

```sh
echo "What NICs are on a server"
lshw -c net -businfo
echo "Start mst for Mellanox NICs"
mst start
echo "Get all Mellanox NICs"
alldevs=$(mst status | grep -i \/dev | awk  '{print $1}')
echo "Get all config parameters of NIC $i"
for i in  $alldevs; do echo $i; mlxconfig -d $i query ; done
echo "What is the link up setting if server is rebooted"
for i in  $alldevs; do echo $i; mlxconfig -d $i query | grep -i link; done
echo "What is the link type of the NIC"
for i in  $alldevs; do echo $i; mlxconfig -d $i query | egrep -e Device\|LINK_TYP; done
echo "Get Dmesg of the server"
SYSTEMD_TIMEZONE=UTC journalctl --dmesg --output=short-iso
echo "Get History with time"
HISTTIMEFORMAT="%d/%m/%y %T "; history

```

---

## Confidentiality
**Juniper Business Use Only**
