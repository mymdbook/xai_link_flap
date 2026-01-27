
## Dec/4/2025
```
First time replication: 12/4/2025

Made the connection around 6PM and left it overnight.
san-rt-ai-srv01 and srv02 connected to san-q5240-09
et-0/0/25:1        -                   c4:cb:e1:f2:aa:0c                        enp180s0f0np0       san-rt-ai-srv01     
et-0/0/25:0        -                   c4:cb:e1:f2:aa:14                        enp13s0f0np0        san-rt-ai-srv02.englab.juniper.net

Run the below tests: midnight on srv01
 sudo ethtool -s enp180s0f0np0 autoneg off speed 1000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg on duplex full
 sudo ethtool -s enp180s0f0np0 autoneg off speed 1000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg on speed 400000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg off speed 1000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg on speed 400000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg off speed 1000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg on speed 400000 duplex full
 sudo ethtool -s enp180s0f0np0 autoneg off
 sudo ethtool -s enp180s0f0np0 autoneg on
 sudo ethtool -s enp180s0f0np0 autoneg off
 sudo ethtool -s enp180s0f0np0 autoneg off
 sudo ethtool -s enp180s0f0np0 autoneg on

 
12/5/25:

port et-0/0/25 from san-q5240-09 moved to et-0/0/24 in XAI setup

Dec  5 12:41:18  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_UP: ifIndex 751, ifAdminStatus up(1), ifOperStatus up(1), ifName et-0/0/24:0
Dec  5 12:41:18  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_UP: ifIndex 752, ifAdminStatus up(1), ifOperStatus up(1), ifName et-0/0/24:0.0
Dec  5 12:41:25  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_UP: ifIndex 753, ifAdminStatus up(1), ifOperStatus up(1), ifName et-0/0/24:1
Dec  5 12:41:25  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_UP: ifIndex 754, ifAdminStatus up(1), ifOperStatus up(1), ifName et-0/0/24:1.0

Link et-0/0/24:0 got removed 

Dec  5 14:08:51  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_DOWN: ifIndex 751, ifAdminStatus up(1), ifOperStatus down(2), ifName et-0/0/24:0

Device populated with other optics. Sequence is in this file.  
Issue seen first at
Dec  5 17:51:31  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_UP: ifIndex 753, ifAdminStatus up(1), ifOperStatus up(1), ifName et-0/0/24:1
Dec  5 17:51:31  xai-qfx5240-01 mib2d[14567]: SNMP_TRAP_LINK_UP: ifIndex 754, ifAdminStatus up(1), ifOperStatus up(1), ifName et-0/0/24:1.0

Then at Dec 02:08 , 02:56:, 08:00, 08:12,08:49,11:24,11:46,13:46,13:57,16:04,16:51 … until Dec 7 11:15 AM when ports were changed.

root@xai-qfx5240-01> show chassis hardware 
Hardware inventory:
Item             Version  Part number  Serial number     Description
Chassis                                AO40023030        QFX5240-64OD
PSM 0                                  6U6LX010130122W   AC AFO 3000W PSU
PSM 1                                  6U6LX010130124P   AC AFO 3000W PSU
Routing Engine 0          BUILTIN      BUILTIN           RE-QFX5240
CB 0             REV 03   650-175147   AO40023030        QFX5240-64OD
FPC 0                     BUILTIN      BUILTIN           QFX5240-64OD
  PIC 0                   BUILTIN      BUILTIN           64X800G-OSFP
    Xcvr 0       XXXX     NON-JNPR     BL8J44X515001K6   UNKNOWN
    Xcvr 1       REV 01   740-174933   1A1CVWA91103U     OSFP-800G-DR8-P
    Xcvr 2       REV 01   740-177856   1G1CHTF917018     OSFP-800G-VR8-DUAL-MPO
    Xcvr 3       REV 01   740-177856   1G1CHTF91702N     OSFP-800G-VR8-DUAL-MPO
    Xcvr 4       REV 01   740-174938   1G1THKA946002     OSFP-800G-8x100G-FR1
    Xcvr 5       REV 01   740-174933   1A1CVWA911024     OSFP-800G-DR8-P
    Xcvr 6       REV 01   740-183989   1W1CJAAA0200L     OSFP-800G-DR8-LPO
    Xcvr 7       REV 01   740-174933   1A1CVWA91102P     OSFP-800G-DR8-P
    Xcvr 8       REV 01   740-174933   1A1CVWA91104H     OSFP-800G-DR8-P
    Xcvr 9       REV 01   740-174933   1G1TVWA93704T     OSFP-800G-DR8-P
    Xcvr 10      REV 01   740-174933   1G1TVWA937061     OSFP-800G-DR8-P
    Xcvr 11      REV 01   740-174933   1G1TVWA9360SF     OSFP-800G-DR8-P
    Xcvr 12      REV 01   720-183903   1M1C8JA948021     OSFP-2x400G-CR4-CU-1M
    Xcvr 13      REV 01   740-174933   1A1CVWA9090C2     OSFP-800G-DR8-P
    Xcvr 14      REV 01   740-174933   1G1TVWA9230DP     OSFP-800G-DR8-P
    Xcvr 15      REV 01   740-174933   1G1TVWA9230D7     OSFP-800G-DR8-P
    Xcvr 16      REV 01   740-174937   1F1CVYA84100B     OSFP-2x400G-LR4-10
    Xcvr 17      REV 01   740-174937   1F1CVYA841007     OSFP-2x400G-LR4-10
    Xcvr 18      REV 01   740-174933   1G1TVWA92302J     OSFP-800G-DR8-P
    Xcvr 19      REV 01   740-174933   1A1CVWA91102Z     OSFP-800G-DR8-P
    Xcvr 20      REV 01   720-183903   1M1C8JA948039     OSFP-2x400G-CR4-CU-1M
    Xcvr 21      REV 01   740-174933   1A1CVWA911023     OSFP-800G-DR8-P
    Xcvr 22      REV 01   740-174933   1A1MVWA9290GL     OSFP-800G-DR8-P
    Xcvr 23      REV 01   740-174933   1A1CVWA90901N     OSFP-800G-DR8-P
    Xcvr 24      XXXX     NON-JNPR     BL8J435515000KY   UNKNOWN
    Xcvr 25      REV 01   720-183903   1M1C8JA948044     OSFP-2x400G-CR4-CU-1M
    Xcvr 26      REV 02   740-177856   1G3CHTF9474LW     OSFP-800G-VR8-DUAL-MPO
    Xcvr 27      REV 01   740-177856   2Q1CHTF918H22     OSFP-800G-VR8-DUAL-MPO
    Xcvr 28      REV 01   720-183903   1M1C8JA948026     OSFP-2x400G-CR4-CU-1M
    Xcvr 29      REV 01   720-183903   1M1C8JA948009     OSFP-2x400G-CR4-CU-1M
    Xcvr 30      XXXX     NON-JNPR     BL8J44X515002M4   UNKNOWN
    Xcvr 31      REV 01   740-174933   1A1CVWA9090C5     OSFP-800G-DR8-P
    Xcvr 32      REV 01   720-183903   1M1C8JA948019     OSFP-2x400G-CR4-CU-1M
    Xcvr 33      REV 01   720-183903   1M1C8JA948034     OSFP-2x400G-CR4-CU-1M
    Xcvr 34      XXXX     NON-JNPR     BL8J435515000F7   UNKNOWN
    Xcvr 35      REV 01   740-174933   1A1CVWA908009     OSFP-800G-DR8-P
    Xcvr 60      REV 01   740-174933   1G1TVWA9361T9     OSFP-800G-DR8-P
    Xcvr 61      REV 01   740-174933   1A1CVWA9090C3     OSFP-800G-DR8-P
    Xcvr 62      REV 01   740-174933   1A1CVWA91101V     OSFP-800G-DR8-P
    Xcvr 63      REV 01   740-174933   1A1CVWA911007     OSFP-800G-DR8-P
Fan Tray 0                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
Fan Tray 1                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
Fan Tray 2                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
Fan Tray 3                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
 
 
```


## Dec/8/2025


## 2nd replication attempt: 12/8/2025


 Below steps were done
1.	Remove all the ports from XAI and power cycle the box.
2.	Post device comes up. make all the optics/dac connection based on the sequence in the file. 
  Et-0/0/24:0 connects to san-rt-srv01 and et-0/0/24:1 connects to san-rt-ai-srv02.
New AEC cables from q5240-05 are moved to ports 13 and 14 peering with QD. Removed existing optics in port 13 and 14.

3.	Run the script to flap san-rt-ai-srv02-AEC cable, periodic of 10 min overnight – no issues seen.
12/9: Try to attempt same sequence from attempt #1. Idea was to see if the issue can be recreated with same type of sequence without making significant changes in the process.
1.	Moved port 13 and port 14 from xai-qfx5240-01 to san-q5240-06. Connected DR8 optics that were removed before. 
2.	One of the AEC (port 14) was connected to srv02 (connection 2 in the Y-cable), other was left as is. The other AEC cable was already connected to QD ports.
3.	Executed below on srv02 BF3 nic card port 
   sudo ethtool -s enp13s0f0np0 autoneg off speed 1000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg on duplex full
  sudo ethtool -s enp13s0f0np0 autoneg off speed 1000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg on speed 400000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg off speed 1000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg on speed 400000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg off speed 1000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg on speed 400000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg off speed 400000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg on speed 400000 duplex full
  sudo ethtool -s enp13s0f0np0 autoneg off
  sudo ethtool -s enp13s0f0np0 autoneg on
4.	Removed ports from san-q5240-06 and connected them back to port 13 and port 14 of xai-qfx5240-01. Port 14:1 has the connection to the server.
5.	Left the system as-is for few hours but the issue did not happen.
6.	From QD device flapped the ports that connects to et-0/0/13:0 and 13:1 in xai-qfx5240-01. The script ran till Dec 10 2AM.
7.	At 4:34AM issue is seen again.

If the issue goes away ( to have some logic) would prefer running the autoneg/speed/duplex change sequence in one or both servers without moving the AEC cable out of the FA box for say two hours and later monitor for the issue over 24 hours. If the issue not seen, may be try OIR of the specific AEC cables.




## Dec/23/2025

Dec/23/2025: Lab Repro Attempt by changing PLL Value

```
-> Computer Center: Check the PLL value
i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x02


Auto ZTP Starts 
Zeroize the config
[vrf:none] root@re0:~# i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x03


manual upgrade to D40.5 >>>> already in D40
Power off switch
restart switch
[vrf:none] root@re0:~# i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x01


-> Post Racking device
Zeroize the config
restart switch 
- check the current PLL value

i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72 <<< device rebooted twice on its own
0x03

load config
[vrf:none] root@xai-qfx5240-01:~# i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x03

reboot switch- 1
- check the current PLL value
i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x04

reboot switch- 2
- check the current PLL value
i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x05

reboot switch- 3
- check the current PLL value
i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
0x06
```


## Dec/24/2025
Here are the action item for today
- Start the bursty traffic on new FA unit (xai-qfx5240-03) -> Sanjay
- Move CX8 NIC to MAitreya -> Sanjay
  - Check if links are up (CX8/Thor2); Abhijit to share the command for clock drift and check if links are flapping
  - If it flaps, how long does it flap?
- Move the FA unit from HW lab to Systest lab -> Hongrong
- Swap old FA unit xai-qfx5240-01 with new FA unit xai-qfx5240-02 -> Hongrong
- **Retain the old setup using old FA unit xai-qfx5240-01 -> Gautham**
- **Constraints**
  - X does not connect multiple server interfaces on the same switch towards the same server
  - One server connection (per NIC) from one switch
- **Key observations post repro**
  - Check clock drift when repro happens
  - FA unit with probes will capture any power events

### DPLL register value test

|Device		| Action		| DPLL
|-------|------------|------------|
|ny-q5240-13	|initial value	|0x0|
| 	after 1st 	|reboot	|0x1|
| 	after 2nd 	|reboot	|0x2|
| 	after 3rd 	|reboot	|0x03|
| 	after 4th 	|reboot	|0x04|
| 	after 1st 	|power cycle	|0x02|
| 	after 2nd 	|power cycle	|0x02|
| 	after 3rd 	|power cycle	|0x02|
| 	after 4th 	|power cycle	|0x02|

reboot - request system reboot	 
power cycle - request system power-cycle	

## Jan/12/2025
```
- serve reboot: 1 server reboot; 2 servers reboot; all servers reboot
- block front air holes to check temp changes
- no AEC connections between DUT switch and supporting QD switches -> modify topo
- flap ports 25-35, 2 hours & stop to continue monitor
- re-install CX-7 NIC back to servers so the server has both BF3 / CX-7 cards
```

**Latest replication on xai-02 – 01/25**

# XAI-02 Replication Log  

## Summary of Actions

1. **Device relocation**
   - `xai-02` moved to **D44.1** to test source photonics issue and verify PRs.

2. **Power cycle testing**
   - Performed multiple power cycle tests on `xai-02` and peer device for **DR8** with `san-q5240-08`.

3. **Image validation**
   - Arun’s private image loaded to check DR8 issue.

4. **Further power cycling**
   - Device moved back to **D44.1**.
   - Power cycle tests repeated on `xai-02` and `san-q5240-08`.

5. **Rack movement and testing**
   - `xai-02` moved to **D40**, then back to **D44.1**.
   - Power cycle tests executed on `xai-02` and `san-q5240-08`.

6. **Topology change**
   - `xai-02` peered with:
     - `san-q5240-q03` using **source photonics optic**
     - `san-q5240-08` on one port  
   - This setup includes **customer QD optics**.

---

## Device Details

```
san-q5240-q03 | LAB119568 | qfx5240-64qd | San Diego (A.7.075) | A24 | 28
```

### Reservation Information

| Field     | Value |
|----------|-------|
| id       | 313168043 |
| bind_id  | 76880372 |
| unit     | san-q5240-q03 |
| model    | QFX5240-64QD-AO |
| by_userid| yuche |
| start_at | 2026-01-20 12:41 PST |
| end_at   | 2026-05-20 13:41 PDT |

**Observation:**  
Device was found **powered off** due to a **loose power cord**.

---

## Optic Movement

Moved optic **P8TT005726 – QSFP-DD800-8x100G-DR8** to `san-q5240-q03`.

```
root@san-q5240-q03> show chassis hardware | match "Xcvr 60"
Xcvr 60 XXXX NON-JNPR P8TT005726 QSFP-DD800-8x100G-DR8
```

---

## Power Cycle Events

```
482 23/01/26 17:50:00 ltPwr -f xai-qfx5240-02
483 23/01/26 17:50:12 ltPwr -f san-q5240-q03
484 23/01/26 18:21:23 ltPwr -n san-q5240-q03
485 23/01/26 18:21:39 ltPwr -n xai-qfx5240-02
```

---

## Fan Script & Flap Observations

- Fan speed changed **65% → 90% → 65%**
- All **AECs flapped**
- Server ports flapped with **12–13 seconds** between down/up
- QD ports showed micro and transient flaps

---

## Flap Timeline

### Saturday – 01/24
- Jan 24 13:30:02
- Jan 24 17:27:45

### Sunday – 01/25
- Jan 25 16:02:10
- Jan 25 20:11:23

### Monday – 01/26
- Jan 26 12:59:33 UTC
- Jan 26 13:02:00 UTC
- Jan 26 15:19:16 UTC

### Tuesday – 01/27
- Jan 27 14:29:51
- Jan 27 14:59:23

---

## Notes / Open Questions

1. Upgrade sequence **D44.1 → D40** with power cycling.
2. Fan control script impact.
3. Organic flapping on **et-0/0/27:1**.
4. Addition of customer QD optics and new device `san-q5240-q03`.

