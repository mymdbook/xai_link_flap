
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

```


## Dec/8/2025

```
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

```


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
 