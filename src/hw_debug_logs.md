# HW Debug Logs - BCM

```
[vrf:none] root@xai-qfx5240-03:~# python3 port_group.py --dump-mapping 
Physical Interfaces displaying their forwarding pipe mappings
------------------------------------------------------
Interface               Asic       Pipe   ITM   Port
Name                    Port       No     No    Name
-------------------------------------------------------
et-0/0/64               164        3      1     xe1   
et-0/0/65               76         1      0     xe0   
et-0/0/0:0              11         0      0     cd4   
et-0/0/0:1              12         0      0     cd5   
et-0/0/18:0             88         2      1     cd32  
et-0/0/18:1             89         2      1     cd33  
et-0/0/34:0             176        4      1     cd64  
et-0/0/34:1             177        4      1     cd65  
et-0/0/53               294        6      0     d3c17 
et-0/0/7:0              41         0      0     cd14  
et-0/0/7:1              42         0      0     cd15  
et-0/0/21:0             118        2      1     cd42  
et-0/0/21:1             119        2      1     cd43  
et-0/0/37               206        4      1     d3c1  
et-0/0/49               272        6      0     d3c13 
et-0/0/54               286        6      0     d3c16 
et-0/0/33:0             184        4      1     cd66  
et-0/0/33:1             185        4      1     cd67  
et-0/0/5:0              30         0      0     cd10  
et-0/0/5:1              31         0      0     cd11  
et-0/0/17:0             96         2      1     cd34  
et-0/0/17:1             97         2      1     cd35  
et-0/0/51               283        6      0     d3c15 
et-0/0/38               198        4      1     d3c0  
et-0/0/55               305        6      0     d3c19 
et-0/0/8:0              55         1      0     cd20  
et-0/0/8:1              56         1      0     cd21  
et-0/0/22:0             110        2      1     cd40  
et-0/0/22:1             111        2      1     cd41  
et-0/0/35:0             195        4      1     cd70  
et-0/0/35:1             196        4      1     cd71  
et-0/0/48               275        6      0     d3c14 
et-0/0/19:0             107        2      1     cd38  
et-0/0/19:1             108        2      1     cd39  
et-0/0/39               217        4      1     d3c3  
et-0/0/56               319        7      0     d3c22 
et-0/0/4:0              33         0      0     cd12  
et-0/0/4:1              34         0      0     cd13  
et-0/0/9:0              52         1      0     cd18  
et-0/0/9:1              53         1      0     cd19  
et-0/0/52               297        6      0     d3c18 
et-0/0/23:0             129        2      1     cd46  
et-0/0/23:1             130        2      1     cd47  
et-0/0/32:0             187        4      1     cd68  
et-0/0/32:1             188        4      1     cd69  
et-0/0/57               316        7      0     d3c21 
et-0/0/16:0             99         2      1     cd36  
et-0/0/16:1             100        2      1     cd37  
et-0/0/40               231        5      1     d3c6  
et-0/0/50               264        6      0     d3c12 
et-0/0/6:0              22         0      0     cd8   
et-0/0/6:1              23         0      0     cd9   
et-0/0/10:0             44         1      0     cd16  
et-0/0/10:1             45         1      0     cd17  
et-0/0/36               209        4      1     d3c2  
et-0/0/58               308        7      0     d3c20 
et-0/0/24:0             143        3      1     cd52  
et-0/0/24:1             144        3      1     cd53  
et-0/0/41               228        5      1     d3c5  
et-0/0/59               327        7      0     d3c23 
et-0/0/20:0             121        2      1     cd44  
et-0/0/20:1             122        2      1     cd45  
et-0/0/42               220        5      1     d3c4  
et-0/0/60               341        7      0     d3c26 
et-0/0/11:0             63         1      0     cd22  
et-0/0/11:1             64         1      0     cd23  
et-0/0/12:0             77         1      0     cd28  
et-0/0/12:1             78         1      0     cd29  
et-0/0/43               239        5      1     d3c7  
et-0/0/61               338        7      0     d3c25 
et-0/0/25:0             140        3      1     cd50  
et-0/0/25:1             141        3      1     cd51  
et-0/0/44               253        5      1     d3c10 
et-0/0/62               330        7      0     d3c24 
et-0/0/26:0             132        3      1     cd48  
et-0/0/26:1             133        3      1     cd49  
et-0/0/63               349        7      0     d3c27 
et-0/0/1:0              9          0      0     cd2   
et-0/0/1:1              10         0      0     cd3   
et-0/0/45               250        5      1     d3c9  
et-0/0/13:0             74         1      0     cd26  
et-0/0/13:1             75         1      0     cd27  
et-0/0/46               242        5      1     d3c8  
et-0/0/27:0             151        3      1     cd54  
et-0/0/27:1             152        3      1     cd55  
et-0/0/47               261        5      1     d3c11 
et-0/0/28:0             165        3      1     cd60  
et-0/0/28:1             166        3      1     cd61  
et-0/0/2:0              1          0      0     cd0   
et-0/0/2:1              2          0      0     cd1   
et-0/0/3:0              19         0      0     cd6   
et-0/0/3:1              20         0      0     cd7   
et-0/0/29:0             162        3      1     cd58  
et-0/0/29:1             163        3      1     cd59  
et-0/0/30:0             154        3      1     cd56  
et-0/0/30:1             155        3      1     cd57  
et-0/0/14:0             66         1      0     cd24  
et-0/0/14:1             67         1      0     cd25  
et-0/0/15:0             85         1      0     cd30  
et-0/0/15:1             86         1      0     cd31  
et-0/0/31:0             173        3      1     cd62  
et-0/0/31:1             174        3      1     cd63  
```

```

BCM.0> dsh -c "phy diag 118-119 dsc config"
 peregrine5_pc_phy_pmd_info_dump:587 type = 4096 laneMask  = 0xF
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG
 
[vrf:none] root@xai-qfx5240-03:~# jbcmsh
BCM.0> 


BCM.0> dsh -c "phy diag 118-119 dsc"
 peregrine5_pc_phy_pmd_info_dump:587 type = 16384 laneMask  = 0xF

**** SERDES DISPLAY DIAG DATA ****
Rev ID Letter        = 00
Rev ID Process       = 01
Rev ID Model         = 2A
Rev ID 2             = 01
Rev ID # Lanes       = 8
Core  = 0;    LANE  = 0
SERDES API Version   = A00410
Common Ucode Version = D002_17
AFE Hardware Version = 0xA0
SerDes type          = peregrine5_pc
Silicon Version      = 1
FLR supported        = 0x1
lane_select          = 0xf


Passed timestamp check : Lane 0:        uC timestamp: 40028             Resolution: 10.0us/count. Passing resolution limits:    Max: 11.0us/count       Min: 9.0us/count
SerDes type = peregrine5_pc
CORE RST_ST  PLL_PWDN  UC_ATV   COM_CLK   UCODE_VER  API_VER  AFE_VER   LIVE_TEMP   AVG_TMON   RESCAL   VCO_RATE  ANA_VCO_RANGE  PLL_DIV  PLL_LOCK
 00   0,00      0        1     312.50MHz   D002_17   A00410     0xA0       70C      (10) 70C    0x08    53.125GHz     059         170        1   

LN (P RX  , CDRxN , UC_CFG,   UC_STS,  RST, STP) SD LCK RXPPM PF(M,L,H) VGA  DCO  TP(0,1,2)      RXFFE(n3,n2,n1,m,p1,p2)      DFE(1,2)  FLT(M,S) TXPPM        TXEQ(n3,n2,n1,m,p1,p2) NLC(U,L)    EYE(U,M,L)  LINK_TIME  SNR     BER
 0 (--P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*    0  ( 3, 9, 5)  56   -1 ( 0,16, 2) (  -4,   5,  -21, 142,   35,  -4)  (13, 0) ( -2, 15)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 88, 88, 86)   330.8    26.16  !chk_en 
 1 (++P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*   -2  ( 0,11, 6)  56   -9 ( 0,17, 2) (  -4,   5,  -19, 146,   35,  -2)  (13, 0) ( -3, 19)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 82, 82, 84)   458.8    24.98  !chk_en 
 2 (--P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*    0  (10, 5, 0)  48  -15 ( 0,15, 2) (  -6,   9,  -28, 149,   45,  -5)  (13, 0) (  3, 22)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 84, 86, 82)   418.8    25.35  !chk_en 
 3 (--P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*   -1  ( 0,12, 1)  56    2 ( 0,14, 2) (  -5,   7,  -24, 148,   38,  -5)  (13, 0) ( -3, 22)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 82, 84, 82)   485.1    25.09  !chk_en 

**** SERDES DISPLAY DIAG DATA END ****


 peregrine5_pc_phy_pmd_info_dump:587 type = 16384 laneMask  = 0xF0

**** SERDES DISPLAY DIAG DATA ****
Rev ID Letter        = 00
Rev ID Process       = 01
Rev ID Model         = 2A
Rev ID 2             = 01
Rev ID # Lanes       = 8
Core  = 0;    LANE  = 4
SERDES API Version   = A00410
Common Ucode Version = D002_17
AFE Hardware Version = 0xA0
SerDes type          = peregrine5_pc
Silicon Version      = 1
FLR supported        = 0x1
lane_select          = 0xf0


Passed timestamp check : Lane 4:        uC timestamp: 40017             Resolution: 10.0us/count. Passing resolution limits:    Max: 11.0us/count       Min: 9.0us/count
SerDes type = peregrine5_pc
CORE RST_ST  PLL_PWDN  UC_ATV   COM_CLK   UCODE_VER  API_VER  AFE_VER   LIVE_TEMP   AVG_TMON   RESCAL   VCO_RATE  ANA_VCO_RANGE  PLL_DIV  PLL_LOCK
 00   0,00      0        1     312.50MHz   D002_17   A00410     0xA0       70C      (10) 70C    0x08    53.125GHz     059         170        1   

LN (P RX  , CDRxN , UC_CFG,   UC_STS,  RST, STP) SD LCK RXPPM PF(M,L,H) VGA  DCO  TP(0,1,2)      RXFFE(n3,n2,n1,m,p1,p2)      DFE(1,2)  FLT(M,S) TXPPM        TXEQ(n3,n2,n1,m,p1,p2) NLC(U,L)    EYE(U,M,L)  LINK_TIME  SNR     BER
 4 (--P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*    0  ( 5, 8, 1)  53   12 ( 0,15, 2) (  -6,   9,  -26, 148,   41,  -9)  (13, 0) (  2, 18)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 84, 86, 84)   351.3    25.63  !chk_en 
 5 (+-P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*    2  ( 5, 8, 2)  53   -1 ( 0,15, 2) (  -4,   5,  -20, 144,   36,  -2)  (13, 0) (  5, 21)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 82, 82, 84)   443.8    24.73  !chk_en 
 6 (-+P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*    1  ( 4, 6, 8)  51    1 ( 0,16, 2) (  -3,   2,  -13, 143,   35,   2)  (13, 0) (  5, 25)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 84, 84, 84)   413.7    25.46  !chk_en 
 7 (--P4N ,BRx1:x1, 0x5004, 0x00_0000, 0,0, 01 ) 1* 1*    0  ( 0,12, 2)  55    8 ( 0,15, 2) (  -4,   5,  -20, 147,   36,  -3)  (13, 0) ( -4, 24)    0      (  0,  0,-24,140, -4,  0)( +0, +0) ( 82, 86, 82)   398.7    24.96  !chk_en 

**** SERDES DISPLAY DIAG DATA END ****



BCM.0> dsh -c "phydiag 118-119 fdrstat STArt bin_group=both Interval=30"
FDRStat: bin_group is not used on this device.
FDRStat thread started ...
BCM.0> 
BCM.0> sleep 30
Sleeping for 30 seconds
BCM.0> 
BCM.0> dsh -c "phydiag 118-119 fdrstat counter"
port 118: Collecting Data ...
FDR start to collect data timestamp: 6607.960207872 sec 
FDR end to collect data timestamp: 6667.958069248 sec 
Number of Uncorrected codewords:                            0                               0
Number of codewords:                                172454978                       142226314
Symbol errors:                                              0                               0
code words err S0:                                  172454918                       142226310
code words err S1:                                          0                               0
code words err S2:                                          0                               0
code words err S3:                                          0                               0
code words err S4:                                          0                               0
code words err S5:                                          0                               0
code words err S6:                                          0                               0
code words err S7:                                          0                               0
code words err S8:                                          0                               0
code words err S9:                                          0                               0
code words err S10:                                         0                               0
code words err S11:                                         0                               0
code words err S12:                                         0                               0
code words err S13:                                         0                               0
code words err S14:                                         0                               0
code words err S15:                                         0                               0
code words err S16:                                         0                               0
port 119: Collecting Data ...
FDR start to collect data timestamp: 6607.960252416 sec 
FDR end to collect data timestamp: 6667.958084608 sec 
Number of Uncorrected codewords:                            0                               0
Number of codewords:                                172066500                       142021770
Symbol errors:                                              0                               0
code words err S0:                                  172066542                       142021764
code words err S1:                                          0                               0
code words err S2:                                          0                               0
code words err S3:                                          0                               0
code words err S4:                                          0                               0
code words err S5:                                          0                               0
code words err S6:                                          0                               0
code words err S7:                                          0                               0
code words err S8:                                          0                               0
code words err S9:                                          0                               0
code words err S10:                                         0                               0
code words err S11:                                         0                               0
code words err S12:                                         0                               0
code words err S13:                                         0                               0
code words err S14:                                         0                               0
code words err S15:                                         0                               0
code words err S16:                                         0                               0
```

```
root@xai-qfx5240-03:pfe> test clockd idt burst-read burst-size 1 slot 0 num-reads 1 register 0xc1bd 
IDT read:
    Reg: 0xc1bd, Val: 0x01


```
```
***********************************
**** SERDES CORE CONFIGURATION ****
***********************************

uC Config VCO Rate        = 193 (~53.125GHz)
Core Config from PCS      = 0

Tx (physical) Lane Addr 0 = 7 (logical)
Rx (physical) Lane Addr 0 = 0 (logical)
Tx (physical) Lane Addr 1 = 1 (logical)
Rx (physical) Lane Addr 1 = 2 (logical)
Tx (physical) Lane Addr 2 = 0 (logical)
Rx (physical) Lane Addr 2 = 7 (logical)
Tx (physical) Lane Addr 3 = 3 (logical)
Rx (physical) Lane Addr 3 = 3 (logical)
Tx (physical) Lane Addr 4 = 6 (logical)
Rx (physical) Lane Addr 4 = 1 (logical)
Tx (physical) Lane Addr 5 = 2 (logical)
Rx (physical) Lane Addr 5 = 4 (logical)
Tx (physical) Lane Addr 6 = 4 (logical)
Rx (physical) Lane Addr 6 = 5 (logical)
Tx (physical) Lane Addr 7 = 5 (logical)
Rx (physical) Lane Addr 7 = 6 (logical)


*************************************
**** SERDES LANE 0 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 1
RX Polarity Invert          = 1

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


*************************************
**** SERDES LANE 1 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 0
RX Polarity Invert          = 0

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


*************************************
**** SERDES LANE 2 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 1
RX Polarity Invert          = 1

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


*************************************
**** SERDES LANE 3 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 1
RX Polarity Invert          = 1

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:587 type = 4096 laneMask  = 0xF0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


***********************************
**** SERDES CORE CONFIGURATION ****
***********************************

uC Config VCO Rate        = 193 (~53.125GHz)
Core Config from PCS      = 0

Tx (physical) Lane Addr 0 = 7 (logical)
Rx (physical) Lane Addr 0 = 0 (logical)
Tx (physical) Lane Addr 1 = 1 (logical)
Rx (physical) Lane Addr 1 = 2 (logical)
Tx (physical) Lane Addr 2 = 0 (logical)
Rx (physical) Lane Addr 2 = 7 (logical)
Tx (physical) Lane Addr 3 = 3 (logical)
Rx (physical) Lane Addr 3 = 3 (logical)
Tx (physical) Lane Addr 4 = 6 (logical)
Rx (physical) Lane Addr 4 = 1 (logical)
Tx (physical) Lane Addr 5 = 2 (logical)
Rx (physical) Lane Addr 5 = 4 (logical)
Tx (physical) Lane Addr 6 = 4 (logical)
Rx (physical) Lane Addr 6 = 5 (logical)
Tx (physical) Lane Addr 7 = 5 (logical)
Rx (physical) Lane Addr 7 = 6 (logical)


*************************************
**** SERDES LANE 4 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 1
RX Polarity Invert          = 1

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


*************************************
**** SERDES LANE 5 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 0
RX Polarity Invert          = 1

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


*************************************
**** SERDES LANE 6 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 1
RX Polarity Invert          = 0

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
 peregrine5_pc_phy_pmd_info_dump:639 type = CFG


*************************************
**** SERDES LANE 7 CONFIGURATION ****
*************************************

Lane Config from PCS        = 0

Auto-Neg Enabled            = 0
DFE on                      = 1
RX low power                = 0
CDR Mode                    = 0
Media Type                  = 0
Unreliable LOS              = 0
Fast Link Recovery Enable   = 0
Link Training Enable        = 0
Link Training Auto Polarity   Enable = 0
Link Training Restart timeout Enable = 0
Force ER Mode               = 0
Force NR Mode               = 1
Link Partner has Precoder En= 0
Force PAM4 mode             = 1
Force NRZ mode              = 0
TX OSR Mode Force           = 1
TX OSR Mode Force Val       = 0
RX OSR Mode Force           = 1
RX OSR Mode Force Val       = 0
TX Polarity Invert          = 1
RX Polarity Invert          = 1

TXFIR Range                 = PAM4
TXFIR Pre3                  = 0
TXFIR Pre2                  = 0
TXFIR Pre1                  = -24
TXFIR Main                  = 140
TXFIR Post1                 = -4
TXFIR Post2                 = 0
TXFIR NLC Upper Eye percent = 0
TXFIR NLC Lower Eye percent = 0
BCM.0> 


### EPROM Page Dump et-0/0/21

root@xai-qfx5240-03:pfe> show picd optics fpc_slot 0 pic_slot 0 port 21 cmd info 

  PICD optics info
   fpc_num:         0
   pic_num:         0
   port_num:        21
   run_periodic:    true
   periodic_ticks:  38191
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
   
   EEPROM details for XCVR: xcvr-0/0/21
   QSFP-DD Lower Page:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x00:19 50 00 07 00 00 00 00 00 00 00 00 00 00 3a fe
  0x10:82 46 00 00 00 00 00 00 00 00 40 00 00 00 00 00
  0x20:00 00 00 00 00 00 00 01 04 00 00 00 00 00 00 00
  0x30:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x40:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x50:00 00 00 00 00 04 4b 04 11 ff 4c 04 11 ff 4d 04
  0x60:22 55 4e 04 22 55 4f 04 44 11 50 04 44 11 ff 00
  0x70:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
   QSFP-DD Upper Page 00h:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
  0x80:19 43 72 65 64 6f 20 20 20 20 20 20 20 20 20 20
  0x90:20 9a ad ca 43 41 43 38 34 35 33 30 31 41 32 4e
  0xa0:43 32 58 41 20 20 42 4c 38 4a 34 34 35 35 31 35
  0xb0:30 30 30 32 4c 20 32 35 30 34 30 39 20 20 20 20
  0xc0:20 20 20 20 20 20 20 20 c0 34 2d 23 00 00 00 00
  0xd0:00 00 00 03 0c 00 00 00 00 00 00 00 00 00 ff 00
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

```
