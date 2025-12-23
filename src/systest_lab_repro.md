# Systest lab Repro - Dec/23/2025

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
 
 
 