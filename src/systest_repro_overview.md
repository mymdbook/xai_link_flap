# Overview

- We have reproduced the issue in more than 3 instances (multiple times in each instance).
- The behavior is the same: `local_reason_opcode = alignment loss` on the NIC end (Amber log).
- NIC initializes; link goes down.
- Link comes back up.
- Resulting in a ~12-second link flap.
- One leg of the AEC cable was connected to BF-3; the other was dangling.
- Voltage margin variation: -5% to +3.16% of nominal.
- Built a scaled-up FA unit (2 occurrences of flap on one AEC, same signature as above) with:
  - 32x 800G AEC to 2x400G BF-3140
  - 22x 800G AEC to QFX5240-64QD
  - 28x 800G OSFP 800G DR8 to QFX5240-64OD


## Repro with Probes Attached - Dec/19/2025
### Amber logs from server

![Probe status Dec 19 2025](images/Server-amber-logs-dec19-2025.png)

```
root@xai-qfx5240-01> show version 
Hostname: xai-qfx5240-01
Model: qfx5240-64od
Junos: 23.4X100-D40.7-EVO
Yocto: 3.0.2
Linux Kernel: 5.2.60-yocto-standard-g72d147e
JUNOS-EVO OS 64-bit [junos-evo-install-qfx-ms-x86-64-23.4X100-D40.7-EVO]


root@xai-qfx5240-01> show chassis fan   
      Item                      Status   % RPM     Measurement
      Fan Tray 0 Fan 1          OK       89%       12150 RPM                
      Fan Tray 0 Fan 2          OK       77%       12000 RPM                
      Fan Tray 1 Fan 1          OK       88%       12000 RPM                
      Fan Tray 1 Fan 2          OK       77%       12000 RPM                
      Fan Tray 2 Fan 1          OK       88%       12000 RPM                
      Fan Tray 2 Fan 2          OK       77%       12000 RPM                
      Fan Tray 3 Fan 1          OK       88%       12000 RPM                
      Fan Tray 3 Fan 2          OK       77%       12000 RPM                

root@xai-qfx5240-01> show chassis environment no-forwarding 
Class Item                           Status     Measurement
Power PSM 0                          OK         38 degrees C / 100 degrees F
      PSM 1                          OK         38 degrees C / 100 degrees F
Temp  FPC 0 Sensor TH5 Max Reading   OK         77 degrees C / 170 degrees F
      FPC 0 xcvr-0/0/0               OK         50 degrees C / 122 degrees F
      FPC 0 xcvr-0/0/1               OK         54 degrees C / 129 degrees F
      FPC 0 xcvr-0/0/2               OK         54 degrees C / 129 degrees F
      FPC 0 xcvr-0/0/3               OK         50 degrees C / 122 degrees F
      FPC 0 xcvr-0/0/4               OK         53 degrees C / 127 degrees F
      FPC 0 xcvr-0/0/5               OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/6               OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/7               OK         51 degrees C / 123 degrees F
      FPC 0 xcvr-0/0/8               OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/9               OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/10              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/11              OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/12              OK         51 degrees C / 123 degrees F
      FPC 0 xcvr-0/0/13              OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/14              OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/15              OK         51 degrees C / 123 degrees F
      FPC 0 xcvr-0/0/16              OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/17              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/18              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/19              OK         54 degrees C / 129 degrees F
      FPC 0 xcvr-0/0/20              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/21              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/22              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/23              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/24              OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/25              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/26              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/27              OK         54 degrees C / 129 degrees F
      FPC 0 xcvr-0/0/28              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/29              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/30              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/31              OK         53 degrees C / 127 degrees F
      FPC 0 xcvr-0/0/32              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/33              OK         62 degrees C / 143 degrees F
      FPC 0 xcvr-0/0/34              OK         62 degrees C / 143 degrees F
      FPC 0 xcvr-0/0/35              OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/36              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/37              OK         64 degrees C / 147 degrees F
      FPC 0 xcvr-0/0/38              OK         66 degrees C / 150 degrees F
      FPC 0 xcvr-0/0/39              OK         61 degrees C / 141 degrees F
      FPC 0 xcvr-0/0/40              OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/41              OK         61 degrees C / 141 degrees F
      FPC 0 xcvr-0/0/42              OK         67 degrees C / 152 degrees F
      FPC 0 xcvr-0/0/43              OK         62 degrees C / 143 degrees F
      FPC 0 xcvr-0/0/44              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/45              OK         64 degrees C / 147 degrees F
      FPC 0 xcvr-0/0/46              OK         66 degrees C / 150 degrees F
      FPC 0 xcvr-0/0/47              OK         63 degrees C / 145 degrees F
      FPC 0 xcvr-0/0/48              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/49              OK         64 degrees C / 147 degrees F
      FPC 0 xcvr-0/0/50              OK         67 degrees C / 152 degrees F
      FPC 0 xcvr-0/0/51              OK         63 degrees C / 145 degrees F
      FPC 0 xcvr-0/0/52              OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/53              OK         66 degrees C / 150 degrees F
      FPC 0 xcvr-0/0/54              OK         66 degrees C / 150 degrees F
      FPC 0 xcvr-0/0/55              OK         62 degrees C / 143 degrees F
      FPC 0 xcvr-0/0/56              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/57              OK         66 degrees C / 150 degrees F
      FPC 0 xcvr-0/0/58              OK         61 degrees C / 141 degrees F
      FPC 0 xcvr-0/0/59              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/60              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/61              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/62              OK         57 degrees C / 134 degrees F
      FPC 0 MB Middle Right Rear     OK         51 degrees C / 123 degrees F
      FPC 0 MB Middle Left Rear      OK         51 degrees C / 123 degrees F
      FPC 0 MB Left Rear             OK         45 degrees C / 113 degrees F
      FPC 0 MB Left Front            OK         44 degrees C / 111 degrees F
      FPC 0 MB Right Rear            OK         41 degrees C / 105 degrees F
      FPC 0 MB Right Front           OK         40 degrees C / 104 degrees F
      FPC 0 MB OPTICS_GRP1_3V3       OK         51 degrees C / 123 degrees F
      FPC 0 MB OPTICS_GRP2_3V3       OK         52 degrees C / 125 degrees F
      FPC 0 MB OPTICS_GRP3_3V3       OK         52 degrees C / 125 degrees F
      FPC 0 MB VDD_0P75              OK         62 degrees C / 143 degrees F
      FPC 0 MB TRVDD1_0V9_0V75       OK         52 degrees C / 125 degrees F
      FPC 0 MB TRVDD0_0V9_0V75       OK         52 degrees C / 125 degrees F
      FPC 0 FB Exhaust Left          OK         41 degrees C / 105 degrees F
      FPC 0 FB Exhaust Right         OK         41 degrees C / 105 degrees F
      Routing Engine 0 CPU Temperature OK       76 degrees C / 168 degrees F
      Routing Engine 0 Ch-0 DIMM-0 Temp OK      57 degrees C / 134 degrees F
      Routing Engine 0 Ch-1 DIMM-0 Temp OK      60 degrees C / 140 degrees F
Fan   Fan Tray 0 Fan 1               OK         12000 RPM
      Fan Tray 0 Fan 2               OK         12000 RPM
      Fan Tray 1 Fan 1               OK         12000 RPM
      Fan Tray 1 Fan 2               OK         12000 RPM
      Fan Tray 2 Fan 1               OK         12000 RPM
      Fan Tray 2 Fan 2               OK         12000 RPM
      Fan Tray 3 Fan 1               OK         12000 RPM
      Fan Tray 3 Fan 2               OK         12000 RPM


root@xai-qfx5240-01> show chassis hardware detail 
Hardware inventory:
Item             Version  Part number  Serial number     Description
Chassis                                AO40023030        QFX5240-64OD
PSM 0                                  6U6LX010130122W   AC AFO 3000W PSU
PSM 1                                  6U6LX010130124P   AC AFO 3000W PSU
Routing Engine 0          BUILTIN      BUILTIN           RE-QFX5240
  nvme0 480103 MB  EPM3750-M8480GB5    511240703133000269 NVMe Solid State Disk
  nvme1 480103 MB  EPM3750-M8480GB5    511240703133001074 NVMe Solid State Disk
CB 0             REV 03   650-175147   AO40023030        QFX5240-64OD
FPC 0                     BUILTIN      BUILTIN           QFX5240-64OD
  PIC 0                   BUILTIN      BUILTIN           64X800G-OSFP
    Xcvr 0       XXXX     NON-JNPR     BL8J4455150007V   UNKNOWN
    Xcvr 1       XXXX     NON-JNPR     BL8J44551500031   UNKNOWN
    Xcvr 2       XXXX     NON-JNPR     BL8J45X5150012J   UNKNOWN
    Xcvr 3       XXXX     NON-JNPR     BL8J4455150000B   UNKNOWN
    Xcvr 4       XXXX     NON-JNPR     BL8J435539000XH   UNKNOWN
    Xcvr 5       XXXX     NON-JNPR     BL8J435539001U4   UNKNOWN
    Xcvr 6       XXXX     NON-JNPR     BL8J43X5440009W   UNKNOWN
    Xcvr 7       XXXX     NON-JNPR     BL8J43X544000BU   UNKNOWN
    Xcvr 8       XXXX     NON-JNPR     BL8J4355390012C   UNKNOWN
    Xcvr 9       XXXX     NON-JNPR     BL8J45X5150017N   UNKNOWN
    Xcvr 10      XXXX     NON-JNPR     BL8J44X515002M7   UNKNOWN
    Xcvr 11      XXXX     NON-JNPR     BL8J435539001RL   UNKNOWN
    Xcvr 12      XXXX     NON-JNPR     BL8J45X5150000W   UNKNOWN
    Xcvr 13      XXXX     NON-JNPR     BL8J45X51500173   UNKNOWN
    Xcvr 14      XXXX     NON-JNPR     BL8J4455150008U   UNKNOWN
    Xcvr 15      XXXX     NON-JNPR     BL8J45X515000TU   UNKNOWN
    Xcvr 16      XXXX     NON-JNPR     BL8J44X51500272   UNKNOWN
    Xcvr 17      XXXX     NON-JNPR     BL8J44X51500254   UNKNOWN
    Xcvr 18      XXXX     NON-JNPR     BL8J45X5150000F   UNKNOWN
    Xcvr 19      XXXX     NON-JNPR     BL8J43X544000L0   UNKNOWN
    Xcvr 20      XXXX     NON-JNPR     BL8J44X5150028X   UNKNOWN
    Xcvr 21      XXXX     NON-JNPR     BL8J4455150002L   UNKNOWN
    Xcvr 22      XXXX     NON-JNPR     BL8J4455150004R   UNKNOWN
    Xcvr 23      XXXX     NON-JNPR     BL8J4455150001D   UNKNOWN
    Xcvr 24      XXXX     NON-JNPR     BL8J435515000F7   UNKNOWN
    Xcvr 25      XXXX     NON-JNPR     BL8J4455150006E   UNKNOWN
    Xcvr 26      XXXX     NON-JNPR     BL8J4455150006G   UNKNOWN
    Xcvr 27      XXXX     NON-JNPR     BL8J4455150000G   UNKNOWN
    Xcvr 28      XXXX     NON-JNPR     BL8J43X544000GE   UNKNOWN
    Xcvr 29      XXXX     NON-JNPR     BL8J44551500061   UNKNOWN
    Xcvr 30      XXXX     NON-JNPR     BL8J44X515002M4   UNKNOWN
    Xcvr 31      XXXX     NON-JNPR     BL8J44X515001Y8   UNKNOWN
    Xcvr 32      XXXX     NON-JNPR     BL8J435515000NZ   UNKNOWN
    Xcvr 33      XXXX     NON-JNPR     BL8J44X515001K6   UNKNOWN
    Xcvr 34      XXXX     NON-JNPR     BL8J435539001K2   UNKNOWN
    Xcvr 35      XXXX     NON-JNPR     BL8J435515000KY   UNKNOWN
    Xcvr 36      REV 01   740-174932   1G1TK1AA350HD     OSFP-800G-DR8
    Xcvr 37      REV 01   740-174933   1A1CVWA91100G     OSFP-800G-DR8-P
    Xcvr 38      REV 01   740-174933   1A1CVWA91102T     OSFP-800G-DR8-P
    Xcvr 39      REV 01   740-174933   1A1CVWA911007     OSFP-800G-DR8-P
    Xcvr 40      REV 01   740-174932   1G1TK1AA350AZ     OSFP-800G-DR8
    Xcvr 41      REV 01   740-174933   1G1TVWA9361T9     OSFP-800G-DR8-P
    Xcvr 42      REV 01   740-174933   1A1CVWA908009     OSFP-800G-DR8-P
    Xcvr 43      REV 01   740-174933   1A1CVWA911037     OSFP-800G-DR8-P
    Xcvr 44      REV 01   740-174933   1A1CVWA911018     OSFP-800G-DR8-P
    Xcvr 45      REV 01   740-174933   1A1CVWA91101A     OSFP-800G-DR8-P
    Xcvr 46      REV 01   740-174933   1A1CVWA91104J     OSFP-800G-DR8-P
    Xcvr 47      REV 01   740-174933   1A1CVWA91101S     OSFP-800G-DR8-P
    Xcvr 48      REV 01   740-174933   1A1CVWA91100V     OSFP-800G-DR8-P
    Xcvr 49      REV 01   740-174933   1A1CVWA911014     OSFP-800G-DR8-P
    Xcvr 50      REV 01   740-174933   1A1CVWA91104L     OSFP-800G-DR8-P
    Xcvr 51      REV 01   740-174933   1A1CVWA911015     OSFP-800G-DR8-P
    Xcvr 52      REV 01   740-174932   1G1TK1AA3509S     OSFP-800G-DR8
    Xcvr 53      REV 01   740-174933   1A1CVWA90901N     OSFP-800G-DR8-P
    Xcvr 54      REV 01   740-174933   1A1CVWA911019     OSFP-800G-DR8-P
    Xcvr 55      REV 01   740-174933   1A1CVWA91100W     OSFP-800G-DR8-P
    Xcvr 56      REV 01   740-174932   1G1TK1A94602E     OSFP-800G-DR8
    Xcvr 57      REV 01   740-174933   1A1CVWA91101V     OSFP-800G-DR8-P
    Xcvr 58      REV 01   740-174933   1A1CVWA9090C5     OSFP-800G-DR8-P
    Xcvr 59      REV 01   740-174933   1A1CVWA91102L     OSFP-800G-DR8-P
    Xcvr 60      REV 01   740-174933   1A1CVWA911011     OSFP-800G-DR8-P
    Xcvr 61      REV 01   740-174933   1A1CVWA9090C3     OSFP-800G-DR8-P
    Xcvr 62      REV 01   740-174933   1A1CVWA91100R     OSFP-800G-DR8-P
Fan Tray 0                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
Fan Tray 1                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
Fan Tray 2                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO
Fan Tray 3                                               QFX5240-64OD/QFX5240-64QD Fan Tray, Front to Back Airflow - AFO



root@xai-qfx5240-01> show lldp neighbors   
Local Interface    Parent Interface    Chassis Id                               Port info          System Name
et-0/0/17:1        -                   6c:92:cf:06:91:3e                        ens5f0np0           svl-hp-ai-srv01.englab.juniper.net
et-0/0/16:1        -                   6c:92:cf:06:91:3e                        ens6f0np0           svl-hp-ai-srv01.englab.juniper.net
et-0/0/2:1         -                   6c:92:cf:06:91:3e                        ens3f0np0           svl-hp-ai-srv01.englab.juniper.net
et-0/0/12:1        -                   6c:92:cf:06:91:3e                        ens1f0np0           svl-hp-ai-srv01.englab.juniper.net
et-0/0/15:1        -                   6c:92:cf:06:91:3e                        ens4f0np0           svl-hp-ai-srv01.englab.juniper.net
et-0/0/13:1        -                   6c:92:cf:06:91:3e                        ens2f0np0           svl-hp-ai-srv01.englab.juniper.net
re0:mgmt-0         -                   80:43:3f:1d:a7:80                        ge-1/0/42           sd-mgmt-a25.englab.juniper.net
et-0/0/29:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/15           san-q5240-q09.englab.juniper.net
et-0/0/26:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/19           san-q5240-q09.englab.juniper.net
et-0/0/27:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/21           san-q5240-q09.englab.juniper.net
et-0/0/25:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/23           san-q5240-q09.englab.juniper.net
et-0/0/21:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/17           san-q5240-q09.englab.juniper.net
et-0/0/20:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/29           san-q5240-q09.englab.juniper.net
et-0/0/31:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/37           san-q5240-q09.englab.juniper.net
et-0/0/34:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/49           san-q5240-q09.englab.juniper.net
et-0/0/22:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/7            san-q5240-q09.englab.juniper.net
et-0/0/23:1        -                   ac:a0:9d:b3:0c:50                        et-0/0/11           san-q5240-q09.englab.juniper.net
et-0/0/33:1        -                   b4:16:78:54:dc:4b                        et-0/0/42           san-q5240-q08.englab.juniper.net
et-0/0/30:0        -                   b4:16:78:54:dc:4b                        et-0/0/43           san-q5240-q08.englab.juniper.net
et-0/0/30:1        -                   b4:16:78:54:dc:4b                        et-0/0/44           san-q5240-q08.englab.juniper.net
et-0/0/24:0        -                   b4:16:78:54:dc:4b                        et-0/0/45           san-q5240-q08.englab.juniper.net
et-0/0/24:1        -                   b4:16:78:54:dc:4b                        et-0/0/46           san-q5240-q08.englab.juniper.net
et-0/0/53:0        -                   b4:16:78:54:dc:4b                        et-0/0/49           san-q5240-q08.englab.juniper.net
et-0/0/53:1        -                   b4:16:78:54:dc:4b                        et-0/0/50           san-q5240-q08.englab.juniper.net
et-0/0/58:0        -                   b4:16:78:54:dc:4b                        et-0/0/51           san-q5240-q08.englab.juniper.net
et-0/0/58:1        -                   b4:16:78:54:dc:4b                        et-0/0/52           san-q5240-q08.englab.juniper.net
et-0/0/42:0        -                   b4:16:78:54:dc:4b                        et-0/0/53           san-q5240-q08.englab.juniper.net
et-0/0/42:1        -                   b4:16:78:54:dc:4b                        et-0/0/54           san-q5240-q08.englab.juniper.net
et-0/0/32:0        -                   b4:16:78:54:dc:4b                        et-0/0/56           san-q5240-q08.englab.juniper.net
et-0/0/32:1        -                   b4:16:78:54:dc:4b                        et-0/0/57           san-q5240-q08.englab.juniper.net
et-0/0/28:0        -                   b4:16:78:54:dc:4b                        et-0/0/60           san-q5240-q08.englab.juniper.net
et-0/0/28:1        -                   b4:16:78:54:dc:4b                        et-0/0/61           san-q5240-q08.englab.juniper.net
et-0/0/19:0        -                   b4:16:78:54:dc:4b                        et-0/0/62           san-q5240-q08.englab.juniper.net
et-0/0/19:1        -                   b4:16:78:54:dc:4b                        et-0/0/63           san-q5240-q08.englab.juniper.net
et-0/0/44:0        -                   bc:0f:fe:09:ca:6e                        Connected to R0 Spine1 san-q5240-06.englab.juniper.net
et-0/0/44:1        -                   bc:0f:fe:09:ca:6e                        Connected to R0 Spine1 san-q5240-06.englab.juniper.net
et-0/0/51:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/60:0         san-q5240-06.englab.juniper.net
et-0/0/51:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/60:1         san-q5240-06.englab.juniper.net
et-0/0/57:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/58:0         san-q5240-06.englab.juniper.net
et-0/0/57:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/58:1         san-q5240-06.englab.juniper.net
et-0/0/55:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/63:0         san-q5240-06.englab.juniper.net
et-0/0/55:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/63:1         san-q5240-06.englab.juniper.net
et-0/0/61:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/57:0         san-q5240-06.englab.juniper.net
et-0/0/61:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/57:1         san-q5240-06.englab.juniper.net
et-0/0/60:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/48:0         san-q5240-06.englab.juniper.net
et-0/0/41:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/56:0         san-q5240-06.englab.juniper.net
et-0/0/41:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/56:1         san-q5240-06.englab.juniper.net
et-0/0/39:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/59:0         san-q5240-06.englab.juniper.net
et-0/0/39:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/59:1         san-q5240-06.englab.juniper.net
et-0/0/60:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/48:1         san-q5240-06.englab.juniper.net
et-0/0/56:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/35:0         san-q5240-06.englab.juniper.net
et-0/0/56:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/35:1         san-q5240-06.englab.juniper.net
et-0/0/50:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/36:0         san-q5240-06.englab.juniper.net
et-0/0/50:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/36:1         san-q5240-06.englab.juniper.net
et-0/0/40:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/40:0         san-q5240-06.englab.juniper.net
et-0/0/40:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/40:1         san-q5240-06.englab.juniper.net
et-0/0/36:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/41:0         san-q5240-06.englab.juniper.net
et-0/0/36:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/41:1         san-q5240-06.englab.juniper.net
et-0/0/62:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/42:0         san-q5240-06.englab.juniper.net
et-0/0/62:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/42:1         san-q5240-06.englab.juniper.net
et-0/0/37:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/43:0         san-q5240-06.englab.juniper.net
et-0/0/37:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/43:1         san-q5240-06.englab.juniper.net
et-0/0/52:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/44:0         san-q5240-06.englab.juniper.net
et-0/0/52:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/44:1         san-q5240-06.englab.juniper.net
et-0/0/54:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/45:0         san-q5240-06.englab.juniper.net
et-0/0/54:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/45:1         san-q5240-06.englab.juniper.net
et-0/0/45:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/46:0         san-q5240-06.englab.juniper.net
et-0/0/45:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/46:1         san-q5240-06.englab.juniper.net
et-0/0/38:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/47:0         san-q5240-06.englab.juniper.net
et-0/0/38:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/47:1         san-q5240-06.englab.juniper.net
et-0/0/46:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/49:0         san-q5240-06.englab.juniper.net
et-0/0/46:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/49:1         san-q5240-06.englab.juniper.net
et-0/0/48:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/50:0         san-q5240-06.englab.juniper.net
et-0/0/48:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/50:1         san-q5240-06.englab.juniper.net
et-0/0/43:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/51:0         san-q5240-06.englab.juniper.net
et-0/0/43:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/51:1         san-q5240-06.englab.juniper.net
et-0/0/49:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/53:0         san-q5240-06.englab.juniper.net
et-0/0/49:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/53:1         san-q5240-06.englab.juniper.net
et-0/0/47:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/54:1         san-q5240-06.englab.juniper.net
et-0/0/59:0        -                   bc:0f:fe:09:ca:6e                        et-0/0/55:0         san-q5240-06.englab.juniper.net
et-0/0/59:1        -                   bc:0f:fe:09:ca:6e                        et-0/0/55:1         san-q5240-06.englab.juniper.net
et-0/0/10:1        -                   c4:cb:e1:d5:d5:a6                        enp97s0f0np0        svl-d-ai-srv04      
et-0/0/7:1         -                   c4:cb:e1:d5:d5:a6                        enp202s0f0np0       svl-d-ai-srv04      
et-0/0/11:1        -                   c4:cb:e1:d5:d5:a6                        enp74s0f0np0        svl-d-ai-srv04      
et-0/0/1:1         -                   c4:cb:e1:d5:d5:a6                        enp13s0f0np0        svl-d-ai-srv04      
et-0/0/0:1         -                   c4:cb:e1:d5:d5:a6                        enp55s0f0np0        svl-d-ai-srv04      
et-0/0/6:1         -                   c4:cb:e1:d5:d5:a6                        enp225s0f0np0       svl-d-ai-srv04      
et-0/0/14:1        -                   c4:cb:e1:d5:d5:a6                        enp181s0f0np0       svl-d-ai-srv04      
et-0/0/3:1         -                   c4:cb:e1:d5:d5:a6                        enp160s0f0np0       svl-d-ai-srv04      
et-0/0/0:0         -                   c4:cb:e1:d5:ed:a6                        enp55s0f0np0        localhost           
et-0/0/1:0         -                   c4:cb:e1:d5:ed:a6                        enp13s0f0np0        localhost           
et-0/0/3:0         -                   c4:cb:e1:d5:ed:a6                        enp160s0f0np0       localhost           
et-0/0/14:0        -                   c4:cb:e1:d5:ed:a6                        enp181s0f0np0       localhost           
et-0/0/6:0         -                   c4:cb:e1:d5:ed:a6                        enp225s0f0np0       localhost           
et-0/0/11:0        -                   c4:cb:e1:d5:ed:a6                        enp74s0f0np0        localhost           
et-0/0/10:0        -                   c4:cb:e1:d5:ed:a6                        enp97s0f0np0        localhost           
et-0/0/7:0         -                   c4:cb:e1:d5:ed:a6                        enp202s0f0np0       localhost           
et-0/0/18:0        -                   c4:cb:e1:f2:aa:0c                        enp180s0f0np0       san-rt-ai-srv01     
et-0/0/5:0         -                   c4:cb:e1:f2:aa:0c                        enp73s0f0np0        san-rt-ai-srv01     
et-0/0/9:0         -                   c4:cb:e1:f2:aa:0c                        enp201s0f0np0       san-rt-ai-srv01     
et-0/0/4:0         -                   c4:cb:e1:f2:aa:0c                        enp225s0f0np0       san-rt-ai-srv01     
et-0/0/18:1        -                   c4:cb:e1:f2:aa:14                        enp13s0f0np0        san-rt-ai-srv02.englab.juniper.net
et-0/0/5:1         -                   c4:cb:e1:f2:aa:14                        enp73s0f0np0        san-rt-ai-srv02.englab.juniper.net
et-0/0/4:1         -                   c4:cb:e1:f2:aa:14                        enp225s0f0np0       san-rt-ai-srv02.englab.juniper.net
et-0/0/9:1         -                   c4:cb:e1:f2:aa:14                        enp201s0f0np0       san-rt-ai-srv02.englab.juniper.net
et-0/0/8:1         -                   c4:cb:e1:f2:aa:14                        enp97s0f0np0        san-rt-ai-srv02.englab.juniper.net


# Server info

root@svl-d-ai-srv04:~# lshw -c net -businfo
USB                         
Bus info          Device         Class          Description
===========================================================
pci@0000:02:00.0  eno8303        network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:02:00.1  eno8403        network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:0d:00.0  enp13s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:22:00.0  eno12399np0    network        BCM57414 NetXtreme-E 10Gb/25Gb RDMA Ethernet Controller
pci@0000:22:00.1  eno12409np1    network        BCM57414 NetXtreme-E 10Gb/25Gb RDMA Ethernet Controller
pci@0000:37:00.0  enp55s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:4a:00.0  enp74s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:61:00.0  enp97s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:a0:00.0  enp160s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:b5:00.0  enp181s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:ca:00.0  enp202s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:e1:00.0  enp225s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller


root@svl-d-ai-srv03:~# lshw -c net -businfo
Bus info          Device         Class          Description
===========================================================
pci@0000:02:00.0  eno8303        network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:02:00.1  eno8403        network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:0d:00.0  enp13s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:22:00.0  eno12399np0    network        BCM57414 NetXtreme-E 10Gb/25Gb RDMA Ethernet Controller
pci@0000:22:00.1  eno12409np1    network        BCM57414 NetXtreme-E 10Gb/25Gb RDMA Ethernet Controller
pci@0000:37:00.0  enp55s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:4a:00.0  enp74s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:61:00.0  enp97s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:a0:00.0  enp160s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:b5:00.0  enp181s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:ca:00.0  enp202s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:e1:00.0  enp225s0f0np0  network        MT43244 BlueField-3 integrated ConnectX-7 network controller


root@san-rt-ai-srv01:~# lshw -c net -businfo
Bus info          Device          Class          Description
============================================================
pci@0000:02:00.0  eno8303         network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:02:00.1  eno8403         network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:0d:00.0  enp13s0np0      network        MT2910 Family [ConnectX-7]
pci@0000:3a:00.0  enp58s0         network        DSC Ethernet Controller
pci@0000:49:00.0  enp73s0f0np0    network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:9f:00.0                  network        Broadcom Inc. and subsidiaries
pci@0000:b4:00.0  enp180s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:c9:00.0  enp201s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:e1:00.0  enp225s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
usb@1:10.3        idrac           network        Ethernet interface


root@san-rt-ai-srv02:~# lshw -c net -businfo
Bus info          Device          Class          Description
============================================================
pci@0000:02:00.0  eno8303         network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:02:00.1  eno8403         network        NetXtreme BCM5720 Gigabit Ethernet PCIe
pci@0000:0d:00.0  enp13s0f0np0    network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:37:00.0  enp55s0np0      network        MT2910 Family [ConnectX-7]
pci@0000:49:00.0  enp73s0f0np0    network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:61:00.0  enp97s0f0np0    network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:9f:00.0                  network        Broadcom Inc. and subsidiaries
pci@0000:b4:00.0  enp180s0np0     network        MT2910 Family [ConnectX-7]
pci@0000:c9:00.0  enp201s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:e1:00.0  enp225s0f0np0   network        MT43244 BlueField-3 integrated ConnectX-7 network controller

root@svl-hp-ai-srv01:~# lshw -c net -businfo
Bus info          Device          Class          Description
============================================================
pci@0000:12:00.0  ens3f0np0       network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:26:00.0  ens2f0np0       network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:3a:00.0  ens14f0         network        NetXtreme BCM5719 Gigabit Ethernet PCIe
pci@0000:3a:00.1  ens14f1         network        NetXtreme BCM5719 Gigabit Ethernet PCIe
pci@0000:3a:00.2  ens14f2         network        NetXtreme BCM5719 Gigabit Ethernet PCIe
pci@0000:3a:00.3  ens14f3         network        NetXtreme BCM5719 Gigabit Ethernet PCIe
pci@0000:62:00.0  ens1f0np0       network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:8a:00.0  ens5f0np0       network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:9f:00.0  ens6f0np0       network        MT43244 BlueField-3 integrated ConnectX-7 network controller
pci@0000:c9:00.0  ens4f0np0       network        MT43244 BlueField-3 integrated ConnectX-7 network controller






```