# HW FA #2 - Bad Batch Investigation

## Goal
- Investigate the possibility of any bad batch or bad lot issue causing failures.
- 11 failures out of 700+ systems in xAI deployment; customer reports once a failing unit is replaced, the new unit is stable and does not show the same failure mode.

## Results
- Build Date: 11 failed S/Ns are from 9 different assembly dates (Oct 2024 - June 2025).
- Mfg Site: 11 failed units from 3 different Accton production lines in 3 locations (VN, TW-ZB, TW-ZN).
- Broadcom TH5: 3 different date codes, 5 different lot codes.

## Next Steps
- Investigating DC/LC trends for timing module and components.

Dec/20/2025

Key observations from Bangalore HW lab test conducted today day time:
- Under normal operating conditions (without cold spray), clock stability is ±0.0057 ppm.
- Frequency jump observed on the frequency counter (±2483 ppm) when cold spray was applied to the 73 MHz XTAL.
- We also collaborated with Accton and the SW team to read the RC32312A DPLL Loss-of-Lock counter
- Monitoring PLL register DPLL_LOL_CNT_STS at offset 0x572 → spray causes clock disturbance and counter increments


![HW Analysis status Dec/20/2025](images/DPLL_LOL_CNT_STS.png)

Commandsused for register read:
- To read the current values 
	- i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72
- To reset the counter 
	- i2cset -y 1 0x9 0xfd 0x5; i2cset -y 1 0x9 0x72 0x0
- To read the values periodically or after the flap - 
	- i2cset -y 1 0x9 0xfd 0x5; i2cget -y 1 0x9 0x72


Next steps:
- Over the weekend, we plan to continue experiments by varying fan speeds and assess any impact on clock ppm or the DPLL Loss-of-Lock counter