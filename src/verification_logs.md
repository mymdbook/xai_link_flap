## Repro with Probes Attached - Dec/19/2025
### Amber logs from server

![Probe status Dec 19 2025](images/Server-amber-logs-dec19-2025.png)

## System Overview

### CLI Summary
````

- EVO Version: 			show version 
- FA Chassis details: 		show chassis hardware detail 
- Fan Speed: 			show chassis fan 
- System Environment: 		show chassis environment no-forwarding 
- Temperature Threshold: 	show chassis enhanced-temperature-thresholds  
- AEC Optics Info: 		show picd optics fpc_slot 0 pic_slot 0 port 0 cmd info 
- DR8 Optics Info : 		show picd optics fpc_slot 0 pic_slot 0 port 40 cmd info
- AEC Advertised Speed: 	show picd optics qsfpdd fpc_slot 0 pic_slot 0 port 0 cmd advertised_applications 
- DR8 Advertised Speed: 	show picd optics qsfpdd fpc_slot 0 pic_slot 0 port 40 cmd advertised_applications   
- Server NIC: 			lshw -c net -businfo
- LLDP Neighbor: 		show lldp neighbors   
````

### CLI Output
```
root@xai-qfx5240-01> show version 
Hostname: xai-qfx5240-01
Model: qfx5240-64od
Junos: 23.4X100-D40.7-EVO
Yocto: 3.0.2
Linux Kernel: 5.2.60-yocto-standard-g72d147e
JUNOS-EVO OS 64-bit [junos-evo-install-qfx-ms-x86-64-23.4X100-D40.7-EVO]

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



root@xai-qfx5240-01> show chassis environment no-forwarding          
Class Item                           Status     Measurement
Power PSM 0                          OK         39 degrees C / 102 degrees F
      PSM 1                          OK         39 degrees C / 102 degrees F
Temp  FPC 0 Sensor TH5 Max Reading   OK         78 degrees C / 172 degrees F
      FPC 0 xcvr-0/0/0               OK         50 degrees C / 122 degrees F
      FPC 0 xcvr-0/0/1               OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/2               OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/3               OK         50 degrees C / 122 degrees F
      FPC 0 xcvr-0/0/4               OK         53 degrees C / 127 degrees F
      FPC 0 xcvr-0/0/5               OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/6               OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/7               OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/8               OK         51 degrees C / 123 degrees F
      FPC 0 xcvr-0/0/9               OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/10              OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/11              OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/12              OK         52 degrees C / 125 degrees F
      FPC 0 xcvr-0/0/13              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/14              OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/15              OK         51 degrees C / 123 degrees F
      FPC 0 xcvr-0/0/16              OK         53 degrees C / 127 degrees F
      FPC 0 xcvr-0/0/17              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/18              OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/19              OK         54 degrees C / 129 degrees F
      FPC 0 xcvr-0/0/20              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/21              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/22              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/23              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/24              OK         57 degrees C / 134 degrees F
      FPC 0 xcvr-0/0/25              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/26              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/27              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/28              OK         55 degrees C / 131 degrees F
      FPC 0 xcvr-0/0/29              OK         60 degrees C / 140 degrees F
      FPC 0 xcvr-0/0/30              OK         58 degrees C / 136 degrees F
      FPC 0 xcvr-0/0/31              OK         54 degrees C / 129 degrees F
      FPC 0 xcvr-0/0/32              OK         56 degrees C / 132 degrees F
      FPC 0 xcvr-0/0/33              OK         62 degrees C / 143 degrees F
      FPC 0 xcvr-0/0/34              OK         61 degrees C / 141 degrees F
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
      FPC 0 xcvr-0/0/60              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/61              OK         59 degrees C / 138 degrees F
      FPC 0 xcvr-0/0/62              OK         57 degrees C / 134 degrees F
      FPC 0 MB Middle Right Rear     OK         51 degrees C / 123 degrees F
      FPC 0 MB Middle Left Rear      OK         52 degrees C / 125 degrees F
      FPC 0 MB Left Rear             OK         45 degrees C / 113 degrees F
      FPC 0 MB Left Front            OK         44 degrees C / 111 degrees F
      FPC 0 MB Right Rear            OK         41 degrees C / 105 degrees F
      FPC 0 MB Right Front           OK         40 degrees C / 104 degrees F
      FPC 0 MB OPTICS_GRP1_3V3       OK         51 degrees C / 123 degrees F
      FPC 0 MB OPTICS_GRP2_3V3       OK         52 degrees C / 125 degrees F
      FPC 0 MB OPTICS_GRP3_3V3       OK         51 degrees C / 123 degrees F
      FPC 0 MB VDD_0P75              OK         63 degrees C / 145 degrees F
      FPC 0 MB TRVDD1_0V9_0V75       OK         52 degrees C / 125 degrees F
      FPC 0 MB TRVDD0_0V9_0V75       OK         53 degrees C / 127 degrees F
      FPC 0 FB Exhaust Left          OK         41 degrees C / 105 degrees F
      FPC 0 FB Exhaust Right         OK         41 degrees C / 105 degrees F
      Routing Engine 0 CPU Temperature OK       75 degrees C / 167 degrees F
      Routing Engine 0 Ch-0 DIMM-0 Temp OK      58 degrees C / 136 degrees F
      Routing Engine 0 Ch-1 DIMM-0 Temp OK      60 degrees C / 140 degrees F
Fan   Fan Tray 0 Fan 1               OK         12000 RPM
      Fan Tray 0 Fan 2               OK         11850 RPM
      Fan Tray 1 Fan 1               OK         12000 RPM
      Fan Tray 1 Fan 2               OK         12000 RPM
      Fan Tray 2 Fan 1               OK         12000 RPM
      Fan Tray 2 Fan 2               OK         12000 RPM
      Fan Tray 3 Fan 1               OK         12000 RPM
      Fan Tray 3 Fan 2               OK         12000 RPM


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


root@xai-qfx5240-01> show chassis enhanced-temperature-thresholds    
                                        Fan speed     Fan speed      Yellow alarm          Red alarm      Fire Shutdown
                                       (degrees C)   (degrees C)      (degrees C)         (degrees C)      (degrees C)
Item                                  Normal  High   Full  Bad fan    Normal  Bad fan     Normal  Bad fan     Normal
Routing Engine 0 CPU Temperature          75    85      99     96       101       98        103      100        105
Routing Engine 0 Ch-0 DIMM-0 Temp         63    70      80     77        82       79         85       82         88
Routing Engine 0 Ch-1 DIMM-0 Temp         63    70      80     77        82       79         85       82         88
FPC 0 Sensor TH5 Max Reading              75    80      95     92       100       97        105      102        110
FPC 0 xcvr-0/0/0                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/1                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/2                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/3                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/4                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/5                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/6                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/7                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/8                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/9                          50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/10                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/11                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/12                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/13                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/14                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/15                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/16                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/17                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/18                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/19                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/20                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/21                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/22                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/23                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/24                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/25                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/26                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/27                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/28                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/29                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/30                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/31                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/32                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/33                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/34                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/35                         50    57      67     67        70       70         75       75         76
FPC 0 xcvr-0/0/36                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/37                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/38                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/39                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/40                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/41                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/42                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/43                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/44                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/45                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/46                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/47                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/48                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/49                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/50                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/51                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/52                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/53                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/54                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/55                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/56                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/57                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/58                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/59                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/60                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/61                         53    60      70     70        73       73         76       76         77
FPC 0 xcvr-0/0/62                         53    60      70     70        73       73         76       76         77
FPC 0 MB Middle Right Rear                45    50      75     72        80       77         85       82         90
FPC 0 MB Middle Left Rear                 45    50      75     72        80       77         85       82         90
FPC 0 MB Left Rear                        45    50      75     72        80       77         85       82         90
FPC 0 MB Left Front                       45    50      75     72        80       77         85       82         90
FPC 0 MB Right Rear                       45    50      75     72        80       77         85       82         90
FPC 0 MB Right Front                      45    50      75     72        80       77         85       82         90
FPC 0 MB OPTICS_GRP1_3V3                  75    80     110    107       115      112        120      117        125
FPC 0 MB OPTICS_GRP2_3V3                  75    80     110    107       115      112        120      117        125
FPC 0 MB OPTICS_GRP3_3V3                  75    80     110    107       115      112        120      117        125
FPC 0 MB VDD_0P75                         75    80     110    107       115      112        120      117        125
FPC 0 MB TRVDD1_0V9_0V75                  75    80     110    107       115      112        120      117        125
FPC 0 MB TRVDD0_0V9_0V75                  75    80     110    107       115      112        120      117        125
FPC 0 FB Exhaust Left                     40    45      60     57        65       62         70       67         75
FPC 0 FB Exhaust Right                    40    45      60     57        65       62         70       67         75


root@xai-qfx5240-01:pfe> show picd optics fpc_slot 0 pic_slot 0 port 0 cmd info 

  PICD optics info
   fpc_num:         0
   pic_num:         0
   port_num:        0
   run_periodic:    true
   periodic_ticks:  7507
   is_diagnostics:  false
   QSFP_presence:  true
   is_channelized:  true
   config_mismatch: false
   Module firmware revision: 1.4
   Module HW revision: 10.0
   CMIS version:          0x50
   Module State Machine: active_ready
   DP State Machine
        DP 0:    dp_ready
        DP 1:    dp_ready
   
   EEPROM details for XCVR: xcvr-0/0/0
   QSFP-DD Lower Page:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x00:19 50 00 07 00 00 00 00 00 00 00 00 00 00 33 44
  0x10:80 d4 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x20:00 00 00 00 00 00 00 01 04 00 00 00 00 00 00 00
  0x30:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x40:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x50:00 00 00 00 00 04 4b 04 11 ff 4c 04 11 ff 4d 04
  0x60:22 55 4e 04 22 55 4f 04 44 11 50 04 44 11 ff 00
  0x70:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 11
   QSFP-DD Upper Page 00h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:19 43 72 65 64 6f 20 20 20 20 20 20 20 20 20 20
  0x90:20 9a ad ca 43 41 43 38 34 35 33 30 31 41 32 4e
  0xa0:43 32 58 41 20 20 42 4c 38 4a 34 34 35 35 31 35
  0xb0:30 30 30 37 56 20 32 35 30 34 30 39 20 20 20 20
  0xc0:20 20 20 20 20 20 20 20 c0 34 2d 23 00 00 00 00
  0xd0:00 00 00 03 0c 00 00 00 00 00 00 00 00 00 0e 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
   QSFP-DD Upper Page 01h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:01 04 0a 00 00 00 00 00 00 00 00 00 00 00 20 00
  0x90:59 60 46 00 00 02 9d 00 00 70 77 0b 03 06 06 03
  0xa0:00 09 3d 67 0f 00 00 67 44 00 00 00 00 00 00 00
  0xb0:ff ff 55 55 11 11 00 00 00 00 00 00 00 00 00 00
  0xc0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xd0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 fd
   QSFP-DD Upper Page 02h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:4b 00 fb 00 46 00 00 00 8b 42 76 8e 87 5a 7a 76
  0x90:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xa0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xb0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xc0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xd0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 2e
   Upper Page 10h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x90:00 50 50 50 50 58 58 58 58 ff 00 00 00 00 00 00
  0xa0:ff ff 55 55 55 55 00 00 00 00 11 11 11 11 00 00
  0xb0:00 00 00 00 10 12 14 16 18 1a 1c 1e ff 00 00 00
  0xc0:00 00 00 ff ff 55 55 55 55 00 00 00 00 11 11 11
  0xd0:11 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
   Upper Page 11h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:44 44 44 44 ff ff 00 00 00 00 00 00 00 00 00 00
  0x90:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xa0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xb0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xc0:00 00 00 00 00 00 00 00 00 00 11 11 11 11 50 50
  0xd0:50 50 58 58 58 58 ff 00 00 00 00 00 00 ff ff 55
  0xe0:55 55 55 00 00 00 00 11 11 11 11 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  Warning: Page 10h,11h maybe stale
  Warning: Please run test picd optics cmd eeprom_rescan

root@xai-qfx5240-01:pfe> show picd optics qsfpdd fpc_slot 0 pic_slot 0 port 0 cmd advertised_applications 

xcvr-0/0/0:
Ap Sel  Host Intf Code                          Media Intf Code                         Host Lanes          Media Lanes         Host Assign         Media Assign
1       100GAUI-1-S C2M (Annex 120G)  (75)   AOC with BER < 10^(-6)        (4)   1                   1                   255                 255
2       100GAUI-1-L C2M (Annex 120G)  (76)   AOC with BER < 10^(-6)        (4)   1                   1                   255                 255
3       200GAUI-2-S C2M (Annex 120G)  (77)   AOC with BER < 10^(-6)        (4)   2                   2                   85                  85
4       200GAUI-2-L C2M (Annex 120G)  (78)   AOC with BER < 10^(-6)        (4)   2                   2                   85                  85
5       400GAUI-4-S C2M (Annex 120G)  (79)   AOC with BER < 10^(-6)        (4)   4                   4                   17                  17
6       400GAUI-4-L C2M (Annex 120G)  (80)   AOC with BER < 10^(-6)        (4)   4                   4                   17                  17

root@xai-qfx5240-01:pfe> show picd optics qsfpdd fpc_slot 0 pic_slot 0 port 2 cmd advertised_applications    

xcvr-0/0/2:
Ap Sel  Host Intf Code                          Media Intf Code                         Host Lanes          Media Lanes         Host Assign         Media Assign
1       100GAUI-1-S C2M (Annex 120G)  (75)   AOC with BER < 10^(-6)        (4)   1                   1                   255                 255
2       100GAUI-1-L C2M (Annex 120G)  (76)   AOC with BER < 10^(-6)        (4)   1                   1                   255                 255
3       200GAUI-2-S C2M (Annex 120G)  (77)   AOC with BER < 10^(-6)        (4)   2                   2                   85                  85
4       200GAUI-2-L C2M (Annex 120G)  (78)   AOC with BER < 10^(-6)        (4)   2                   2                   85                  85
5       400GAUI-4-S C2M (Annex 120G)  (79)   AOC with BER < 10^(-6)        (4)   4                   4                   17                  17
6       400GAUI-4-L C2M (Annex 120G)  (80)   AOC with BER < 10^(-6)        (4)   4                   4                   17                  17

root@xai-qfx5240-01:pfe> show picd optics qsfpdd fpc_slot 0 pic_slot 0 port 40 cmd advertised_applications   

xcvr-0/0/40:
Ap Sel  Host Intf Code                          Media Intf Code                         Host Lanes          Media Lanes         Host Assign         Media Assign
1       400GAUI-4-S C2M (Annex 120G)  (79)   400GBASE-DR4 (Clause 124)     (28)   4                   4                   17                  17
2       400GAUI-4-L C2M (Annex 120G)  (80)   400GBASE-DR4 (Clause 124)     (28)   4                   4                   17                  17
3       100GAUI-1-S C2M (Annex 120G)  (75)   100GBASE-DR (Clause 140)      (20)   1                   1                   255                 255
4       100GAUI-1-L C2M (Annex 120G)  (76)   100GBASE-DR (Clause 140)      (20)   1                   1                   255                 255
5       800GAUI-8 S C2M (Annex 120G)  (81)   800GBASE-DR8 (placeholder)    (86)   8                   8                   1                   1
6       800GAUI-8 L C2M (Annex 120G)  (82)   800GBASE-DR8 (placeholder)    (86)   8                   8                   1                   1
7       200GAUI-2-S C2M (Annex 120G)  (77)   Vendor Specific/Custom        (224)   2                   2                   85                  85
8       200GAUI-2-L C2M (Annex 120G)  (78)   Vendor Specific/Custom        (224)   2                   2                   85                  85

root@xai-qfx5240-01:pfe> show picd optics fpc_slot 0 pic_slot 0 port 40 cmd info

  PICD optics info
   fpc_num:         0
   pic_num:         0
   port_num:        40
   run_periodic:    true
   periodic_ticks:  6895
   is_diagnostics:  false
   QSFP_presence:  true
   is_channelized:  false
   config_mismatch: false
   Module firmware revision: 0.13
   Module HW revision: 1.2
   CMIS version:          0x51
   Module State Machine: active_ready
   DP State Machine
        DP 0:    dp_ready
   
   EEPROM details for XCVR: xcvr-0/0/40
   QSFP-DD Lower Page:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x00:19 51 00 07 00 00 00 00 00 00 00 00 00 00 39 ee
  0x10:81 21 df fd 37 04 00 00 00 00 60 00 00 00 00 00
  0x20:00 00 f0 00 ff 00 00 00 0d 00 00 00 00 00 00 00
  0x30:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x40:00 00 00 01 00 00 d1 17 00 00 00 00 00 00 00 00
  0x50:00 00 00 00 00 02 4f 1c 44 11 50 1c 44 11 4b 14
  0x60:11 ff 4c 14 11 ff 51 56 88 01 52 56 88 01 4d e0
  0x70:22 55 4e e0 22 55 00 00 00 00 00 00 00 00 00 00
   QSFP-DD Upper Page 00h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:19 4a 55 4e 49 50 45 52 2d 31 47 31 20 20 20 20
  0x90:20 20 1b c9 37 34 30 2d 31 37 34 39 33 32 20 20
  0xa0:20 20 20 20 30 31 31 47 31 54 4b 31 41 41 33 35
  0xb0:30 41 5a 20 20 20 32 35 30 38 32 36 20 20 43 4d
  0xc0:55 49 41 5a 37 42 41 41 e0 42 00 28 00 00 00 00
  0xd0:00 00 00 00 06 00 00 00 00 00 00 00 00 00 ec 31
  0xe0:47 31 4b 31 41 20 20 20 20 20 20 20 20 20 20 30
  0xf0:31 03 01 00 00 00 00 00 00 00 00 00 00 00 00 00
   QSFP-DD Upper Page 01h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:00 00 01 02 05 00 00 00 00 00 66 6c 05 14 64 00
  0x90:37 e9 46 00 00 00 9d 18 00 f0 77 bb 03 07 06 0f
  0xa0:07 09 1d 77 ff 1f 80 47 34 00 00 00 00 00 00 00
  0xb0:11 11 ff ff 01 01 55 55 55 55 00 00 00 00 00 00
  0xc0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xd0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 4d
  0xe0:00 22 55 4e 00 22 55 ff 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 6e
   QSFP-DD Upper Page 02h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:4c 00 fa 00 49 00 fd 00 90 88 75 30 8c a0 77 24
  0x90:7f ff 80 00 79 98 86 67 3c 00 2d 00 3a 00 2f 00
  0xa0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xb0:9b 82 0a 0a 7b 86 0c a3 fd e8 13 88 f4 24 1d 4c
  0xc0:ba f7 05 08 94 82 07 1b 00 00 00 00 00 00 00 00
  0xd0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 b6
  QSFP-DD Upper Page 03h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x90:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xa0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xb0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xc0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xd0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
   Upper Page 10h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x90:00 50 50 50 50 50 50 50 50 ff 00 00 00 00 00 00
  0xa0:ff ff 22 22 22 22 00 00 00 00 11 11 11 11 00 00
  0xb0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xc0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xd0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xe0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0xf0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
   Upper Page 11h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:44 44 44 44 ff ff 00 00 00 00 00 00 00 00 00 00
  0x90:00 00 00 00 00 00 00 00 00 00 4d 0b 3a 21 3b 9e
  0xa0:35 21 45 38 2d c1 48 ff 3b c5 88 af 88 af 88 af
  0xb0:88 af 88 af 88 af 88 af 88 af 42 32 42 85 52 1b
  0xc0:42 de 40 a9 4b 4f 29 d3 3b 8f 11 11 11 11 50 50
  0xd0:50 50 50 50 50 50 ff 00 00 00 00 00 00 ff ff 22
  0xe0:22 22 22 00 00 00 00 11 11 11 11 00 00 00 00 00
  0xf0:11 22 33 44 55 66 77 88 11 22 33 44 55 66 77 88
  Warning: Page 10h,11h maybe stale
  Warning: Please run test picd optics cmd eeprom_rescan





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