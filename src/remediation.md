
## **Date:** 2-Jan-2025

# Write-up for the Clock Changes Proposed for QFX5240-64OD
---

## Problem Statement
All server-facing ports flap at random across multiple Juniper QFX5240-64OD access switches.

---

## Description
There are multiple fronts for the issue of troubleshooting ranging from temperature to power to internal clocks. The depth of individual testing might be time-consuming and hence we propose a preventive measure by isolating a source of clock from the critical path.

The plan is to roll out the changes in **5 devices** where we have seen flaps recently and observe if there are any undesirable issues. Based on the outcome, we can roll out the same changes to other switches in **DH3**.

---

## Proposed Rollout Plan

### **Phase 1 – DH3 through Scripts**
- **Day 0:** 5 devices  
- **Day 1:** Additional 25 devices  
- **Day 2:** Entire data hall  
- **Monitor:** Overall DH3 health for a week  
- **Caveats:** Script requires execution after every power cycle/reboot  

### **Phase 2 – Software Patch**
- All data halls  
- **Targeted timeline:** 01/08/2025  

### **Phase 3 – Software Upgrade**
- Upcoming deployments  
- D44 image will also have enhancements for other xAI asks  
- **Targeted timeline:** 4th week of January  

---

## Detailed Description
The QFX5240 uses a clock synthesizer to generate TH5 reference clocks. This synthesizer has its own crystal and can generate TH5 clocks independently, but it can also synchronize its clock output to another clock source. On the QFX5240, the other clock source comes from a second clocking device used for synchronous ethernet and PTP boundary clocking.

Since these modes are not in use, the first change is to have the clock synthesizer generate the TH5 clock on its own rather than synchronizing to the second device. The second change involves updating a synthesizer parameter recommended by the vendor to improve stability.

---

## Commands

### **To Configure**
```bash
i2cset -y 1 9 0xfd 0x5; i2cset -y 1 9 0x4 0x62
i2cset -y 1 9 0xfd 0x2; i2cset -y 1 9 0x40 0x18
```

---

## To Verify
```bash
i2cset -y 1 9 0xfd 0x5; i2cget -y 1 9 0x4
# Expected: 0x62 (verifies last written)
```

```bash
i2cset -y 1 9 0xfd 0x2; i2cget -y 1 9 0x40
# Expected: 0x18 (verifies last written)
```

---

## Rollback Strategies

### **Option 1 – Power Cycle (Preferred)**
- i2c registers reset after a power cycle.  
- A normal reboot will **not** reset these values.

### **Option 2 – Unset i2c values via command**
```bash
i2cset -y 1 9 0xfd 0x5; i2cset -y 1 9 0x4 0x66
i2cset -y 1 9 0xfd 0x2; i2cset -y 1 9 0x40 0x78
```
> ⚠️ This option puts the isolated clock back in the critical path and may lead to interface flaps. Contact JTAC if undesired behavior occurs.

---

## JSU Installation and Options

**Image location:**  
`/volume/evoimages/release/evo/rel/23.4X100-D40-J1/rel_23.4X100-D40-J1.1`  
Apply on top of `23.4X100-D40.7-EVO`.

### **Test Scenarios**

#### **Scenario 1: System already configured with i2cset commands**
Do not reboot after JSU installation. Stage JSU and let the system run for a day, then power-cycle and verify:
```bash
request system software add /var/tmp/junos-evo-install-qfx-ms-x86-64-23.4X100-D40-J1.1-EVO.iso
```
Verify:
```bash
i2cset -y 1 9 0xfd 0x5; i2cget -y 1 9 0x4
i2cset -y 1 9 0xfd 0x2; i2cget -y 1 9 0x40
show trace application clockd | grep RS32312
```

#### **Scenario 2: System not configured with i2cset commands**
Use reboot option:
```bash
request system software add /var/tmp/junos-evo-install-qfx-ms-x86-64-23.4X100-D40-J1.1-EVO.iso reboot
```

#### **Scenario 3: Apply JSU with restart option**
Recommended for X.AI if systems are on UTC:
```bash
request system software add /var/tmp/junos-evo-install-qfx-ms-x86-64-23.4X100-D40-J1.1-EVO.iso restart
```

---

**Juniper Business Use Only**
