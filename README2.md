# Function Reference

**ADALM-Pluto QAM + BCH Digital Communications Link (MATLAB)**

Every function, method, and System object called across the three scripts, grouped by origin.

> **Dependency note:** the project needs **Communications Toolbox** + the **ADALM-Pluto Support Package**, and also quietly pulls in **Signal Processing Toolbox** (via `rms` and `findpeaks`) — easy to miss when listing prerequisites, since neither is a `comm.*` call.

---

## Base MATLAB — language & control

| Category | Functions |
|----------|-----------|
| Session / figure | `clear`, `clc`, `close`, `hold`, `drawnow` |
| Error handling | `assert`, `warning` |
| Predicates | `isempty`, `isinf`, `isfile`, `any` |
| I/O | `fprintf`, `fileread` |

## Base MATLAB — math & array manipulation

| Category | Functions |
|----------|-----------|
| Numeric | `mod`, `log2`, `max`, `min`, `abs`, `sum`, `mean`, `round`, `exp`, `angle`, `conj`, `real`, `imag` |
| Array shaping | `reshape`, `flipud`, `repmat`, `numel`, `size`, `zeros`, `false` |
| Type / logical | `double`, `logical`, `char`, `xor` |
| Linear filtering | `conv`, `filter` |
| Data structure | `struct` (the `best` frame record) |
| Seeded PRNG | `rng`, `randi` (preamble + whitening sequence) |

---

## Signal Processing Toolbox

| Function | Purpose |
|----------|---------|
| `rms` | unit-power normalization and EVM-based SNR estimate |
| `findpeaks` | locating preamble-correlation peaks (dual-device RX) |

---

## Communications Toolbox — functions

| Function | Purpose |
|----------|---------|
| `bchenc`, `bchdec`, `gf` | BCH(31,16) encode/decode over the Galois field |
| `qammod`, `qamdemod` | 32-QAM modulation / demodulation |
| `int2bit`, `bit2int` | byte ↔ bit conversion (incl. 2-byte length header) |

## Communications Toolbox — System objects

| Object | Purpose |
|--------|---------|
| `comm.BarkerCode` | Barker-13 preamble (single-device) |
| `comm.RaisedCosineTransmitFilter` | RRC pulse shaping |
| `comm.RaisedCosineReceiveFilter` | RRC matched filtering |
| `comm.SymbolSynchronizer` | Gardner symbol-timing recovery |
| `comm.AGC` | automatic gain control (single-device only) |
| `comm.CoarseFrequencyCompensator` | coarse CFO removal (dual-device only) |
| `comm.CarrierSynchronizer` | fine freq/phase recovery (dual-device only) |

**System-object methods:** `reset` (clears loop state each pass in the looping receiver), `release` (frees the object/radio), and `step` (invoked implicitly via `obj(...)` syntax).

---

## ADALM-Pluto Support Package

| Function | Purpose |
|----------|---------|
| `findPlutoRadio` | device discovery |
| `sdrrx`, `sdrtx` | receiver / transmitter radio objects |
| `transmitRepeat` | continuous buffered transmit (single-device) |

---

## Plotting / visualization

`figure`, `plot`, `hold`, `clf`, `yline`, `xlabel`, `ylabel`, `title`, `legend`, `scatterplot`, `drawnow`

---

## Custom helper (defined in-repo)

| Function | Purpose |
|----------|---------|
| `ternary` | inline conditional (single-capture dual-device receiver) |
