# Running PRBS Test on QFX5240

## What is PRBS

PRBS (Pseudo-Random Bit Sequence) is a deterministic test pattern used to validate the physical layer (PHY) of high-speed links such as Ethernet ports, SerDes lanes, optics, and cables.

PRBS operates below the Ethernet and packet layers and focuses purely on raw bit transmission quality.

### Why PRBS Is Used
PRBS testing helps answer a fundamental question:
Can this physical link reliably transmit bits at line rate?

It is commonly used to:
- Validate signal integrity on high-speed links (400G / 800G)
- Detect marginal optics, DAC/AEC cables, or connectors
- Identify lane-level issues in SerDes
- Expose clocking, jitter, or power-related instability
- Perform hardware bring-up and post-RMA validation

### Common PRBS Patterns

| Pattern | Description | Typical Use |
|------|------------|-------------|
| PRBS7 | Short pattern | Basic sanity tests |
| PRBS15 | Medium pattern | Extended stress testing |
| **PRBS31** | Long pattern | Industry standard for 400G/800G |

PRBS31 is the most stressful pattern and is recommended for high-speed validation.

### How PRBS Works

- **Transmitter (Generator)** generates a known PRBS pattern and sends raw bits.
- **Receiver (Checker)** regenerates the same pattern and compares incoming bits.
- Any mismatch is counted as a bit error.

### PRBS on QFX5240

When PRBS is enabled on QFX5240:
- Normal Ethernet traffic is stopped
- The physical link goes Down (expected behavior)
- Interfaces enter PHY test mode
- Error counters are tracked per SerDes lane

Typical output:
```
PRBS Mode : Enabled
PRBS Pattern : 31
Lane X : Error Count : N
```

### Interpreting Results

- **Zero errors over time** → Healthy link
- **Slowly increasing errors** → Marginal link
- **Rapid error increase or failures** → Faulty cable, optic, or lane

Lane-specific errors usually indicate:
- Defective SerDes lane
- Bad connector or cable
- Optical power or signal quality issue

### PRBS vs Real Traffic

| Aspect | PRBS | Normal Traffic |
|------|------|----------------|
| Layer tested | PHY only | PHY + MAC + Network |
| Error sensitivity | Very high | Errors may be masked |
| Traffic | None | Packet-based |
| Use case | Hardware validation | Functional testing |

A link may pass traffic but fail PRBS, indicating marginal signal integrity.

---

## I. Command Reference

### Start / Stop PRBS Test
```bash
test chassis prbs fpc <fpc-slot> pic-slot <pic-slot> port <port-number | port-range> \
[channel <channel-number>] pattern <31> direction <tx|rx>-<start|stop>
```

### Clear PRBS Statistics
```bash
clear interfaces statistics <interface-name>
```

### Verify PRBS Status
```bash
show interfaces <interface-name>
```

---

## II. Examples

## A. PRBS Test on Non-Channelized 1x800G Ports

### 1. Check Initial State
```bash
show interfaces et-0/0/10
show interfaces et-0/0/11
```

### 2. Enable PRBS
```bash
test chassis prbs fpc 0 pic-slot 0 port 11 pattern 31 direction rx-start
test chassis prbs fpc 0 pic-slot 0 port 10 pattern 31 direction tx-start
```

### 3. Verify PRBS Statistics
```bash
show interfaces et-0/0/11
```

### 4. Stop PRBS
```bash
test chassis prbs fpc 0 pic-slot 0 port 10 pattern 31 direction tx-stop
test chassis prbs fpc 0 pic-slot 0 port 11 pattern 31 direction rx-stop
```

---

## B. PRBS Test on Channelized 2x400G Ports

### 1. Configure Channelization
```bash
set interfaces et-0/0/20 number-of-sub-ports 2
set interfaces et-0/0/20 speed 400g
set interfaces et-0/0/24 number-of-sub-ports 2
set interfaces et-0/0/24 speed 400g
commit
```

### 2. Enable PRBS
```bash
test chassis prbs fpc 0 pic-slot 0 port 24 channel 0 pattern 31 direction rx-start
test chassis prbs fpc 0 pic-slot 0 port 24 channel 1 pattern 31 direction rx-start
test chassis prbs fpc 0 pic-slot 0 port 20 channel 0 pattern 31 direction tx-start
test chassis prbs fpc 0 pic-slot 0 port 20 channel 1 pattern 31 direction tx-start
```

### 3. Stop PRBS
```bash
test chassis prbs fpc 0 pic-slot 0 port 24 channel 0 pattern 31 direction rx-stop
test chassis prbs fpc 0 pic-slot 0 port 24 channel 1 pattern 31 direction rx-stop
test chassis prbs fpc 0 pic-slot 0 port 20 channel 0 pattern 31 direction tx-stop
test chassis prbs fpc 0 pic-slot 0 port 20 channel 1 pattern 31 direction tx-stop
```
