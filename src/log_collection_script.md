
```
## Log to be collected for micro flap detection

RSI
show trace application hwdre
show trace application evo-pfemand
show trace application picd
cli-pfe> show picd channel summary
show chassis fan
show chassis environment fpc
i2cset -y 1 0x9 0xfd 0x5;  i2cget -y 1 0x9 0x72
```
```
## Drifting DPLL clocking

### Add 1ppm to DPLL4
test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0x0C
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0x99
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x26
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x49
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCD
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF

### Set 0.5ppm to DPLL4
test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0x06
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0x9A
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x2C
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x48
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCD
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC722 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC724 value 0x14
test clockd idt burst-write burst-size 1 slot 0 register 0xC725 value 0x5A
test clockd idt burst-write burst-size 1 slot 0 register 0xC726 value 0x62
test clockd idt burst-write burst-size 1 slot 0 register 0xC727 value 0x02

### Set 0ppm to DPLL4
test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0x9B
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x32
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x47
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCD
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC722 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC724 value 0x24
test clockd idt burst-write burst-size 1 slot 0 register 0xC725 value 0xF4
test clockd idt burst-write burst-size 1 slot 0 register 0xC726 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC727 value 0x00

### Set 0.1ppm to DPLL4
test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0xCE
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0x9A
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x64
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x47
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCD
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC722 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC724 value 0x14
test clockd idt burst-write burst-size 1 slot 0 register 0xC725 value 0xC2
test clockd idt burst-write burst-size 1 slot 0 register 0xC726 value 0xEB
test clockd idt burst-write burst-size 1 slot 0 register 0xC727 value 0x0B

### Set 0.01ppm to DPLL4
test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0xFB
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0x9A
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x37
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x47
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCD
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC722 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC724 value 0x14
test clockd idt burst-write burst-size 1 slot 0 register 0xC725 value 0x94
test clockd idt burst-write burst-size 1 slot 0 register 0xC726 value 0x35
test clockd idt burst-write burst-size 1 slot 0 register 0xC727 value 0x77

### Set 0.001ppm to DPLL4

test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0xB5
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x65
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x29
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCD
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC722 value 0xFE
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC724 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC725 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC726 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC727 value 0x00
 
### Set 0.0001ppm to DPLL4
test clockd idt burst-write burst-size 1 slot 0 register 0xC71C value 0xCC
test clockd idt burst-write burst-size 1 slot 0 register 0xC71D value 0xBC
test clockd idt burst-write burst-size 1 slot 0 register 0xC71E value 0x29
test clockd idt burst-write burst-size 1 slot 0 register 0xC71F value 0x88
test clockd idt burst-write burst-size 1 slot 0 register 0xC720 value 0xCB
test clockd idt burst-write burst-size 1 slot 0 register 0xC721 value 0x1D
test clockd idt burst-write burst-size 1 slot 0 register 0xC722 value 0xF0
test clockd idt burst-write burst-size 1 slot 0 register 0xC723 value 0xFF
test clockd idt burst-write burst-size 1 slot 0 register 0xC724 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC725 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC726 value 0x00
test clockd idt burst-write burst-size 1 slot 0 register 0xC727 value 0x00
```
 