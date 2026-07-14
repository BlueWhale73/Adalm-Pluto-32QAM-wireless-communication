# ADALM-Pluto QAM + BCH Digital Communications Link (MATLAB)

A hands-on digital communications link built in **MATLAB** and run over the air (or over coax) using **ADALM-Pluto** software-defined radios. The link sends text through a full DSP chain — **32-QAM** modulation, **BCH(31,16)** forward error correction, RRC pulse shaping, preamble-based frame sync, symbol-timing recovery, and carrier synchronization — and recovers the original message on the far end.

---

## What is the ADALM-Pluto?

The **ADALM-Pluto (PlutoSDR)** is a low-cost, USB-powered software-defined radio from Analog Devices. It contains a transmitter and receiver that can tune roughly **325 MHz – 3.8 GHz**, streaming complex (I/Q) baseband samples to and from a host computer. Instead of building a radio in hardware, you define the entire signal-processing chain — modulation, filtering, synchronization, decoding — **in software**.

Here we drive the Pluto entirely from **MATLAB** using the *Communications Toolbox* and the *Communications Toolbox Support Package for ADALM-Pluto Radio*. MATLAB generates the transmit waveform, streams it to the Pluto's DAC/RF front end, captures the received samples back from the Pluto's RF/ADC, and runs the full receiver DSP on the captured stream.

---

## The three code files

| File | Role | Radios needed |
|------|------|---------------|
| `single-device-transceiver.m` | **One Pluto, loopback.** Transmits and receives on the *same* device through a coax cable. Since a single crystal drives both TX and RX, there is **no carrier frequency offset** — so the receiver is minimal: AGC → matched filter → Gardner timing → single-tap channel estimate/equalize → 32-QAM demod → BCH decode. Best starting point to verify the whole chain works. | 1 |
| `dual-device-transmitter-code.m` | **TX side of a two-Pluto link.** Runs on the transmit laptop/Pluto: text → BCH(31,16) encode → whiten → 32-QAM → RRC pulse shape → preamble → stream continuously over the air. | 1 (of 2) |
| `dual-device-receiver-code.m` | **RX side of a two-Pluto link.** Runs on the receive laptop/Pluto. Because the two radios have **independent crystals**, they disagree in frequency and phase, so this receiver adds the full recovery chain: coarse frequency compensation → RRC matched filter → Gardner symbol timing → carrier synchronizer (fine freq/phase) → preamble correlation (frame detect + derotate) → decision-directed residual-phase clean-up → 32-QAM demod → de-whiten → BCH(31,16) decode → text. | 1 (of 2) |

`message.txt` holds the text payload that the transmitter sends (padded/truncated to the configured frame length). Keep it present so the receiver can compute a character-error count against the ground truth.

**Shared parameters must match.** The block `Fc, Fs, sps, M, N, K, numChars, preLen, preSeed, scramSeed, rolloff, span` at the top of the TX and RX scripts must be **byte-identical**, or the receiver will not decode.

---

## Requirements

- MATLAB (R2021b or newer recommended)
- **Communications Toolbox**
- **Communications Toolbox Support Package for ADALM-Pluto Radio**
- One ADALM-Pluto (single-device demo) or two (dual-device link)
- Coax cable + a **30–40 dB inline attenuator** (for loopback / cabled tests)
- Two SMA antennas (for the over-the-air dual-device link)

---

## How to run it (step by step)

### 1. Install the support package
In MATLAB: **Home → Add-Ons → Get Hardware Support Packages** → search for *ADALM-Pluto Radio* → install. Follow the guided setup to install USB drivers and update the Pluto firmware if prompted.

### 2. Connect and verify the Pluto
- Plug the Pluto into USB. Wait for the OS to enumerate it as a network/USB device.
- In MATLAB, run:
  ```matlab
  findPlutoRadio
  ```
  You should see the radio listed with its RadioID (e.g. `usb:0`). If nothing appears, fix drivers/USB before continuing.

### 3. Choose your test

**A) Single-device loopback (start here):**
1. Connect the Pluto's **TX** SMA port to its **RX** SMA port through a coax cable **with a 30–40 dB attenuator inline**.
2. Open and run `single-device-transceiver.m`.
3. Check the console: `Sent` vs `Received` should match, and the constellation plot should show clean 32-QAM points.

**B) Two-Pluto over-the-air link:**
1. Confirm the parameter block is identical in `dual-device-transmitter-code.m` and `dual-device-receiver-code.m`.
2. On the **receive** machine (Pluto B), start `dual-device-receiver-code.m` first — it will sit in a loop waiting for frames.
3. On the **transmit** machine (Pluto A), start `dual-device-transmitter-code.m` — it streams continuously.
4. Place the antennas a sensible distance apart (see precautions). Watch the receiver console print decoded text, uncorrectable-codeword counts, and an estimated SNR each pass.

### 4. Tune if needed
- **Won't lock?** On the receiver, try `loopBW` in `0.008–0.02`, and confirm `cfoEst` looks sane (tens of kHz, not wild).
- **High uncorrectable-codeword count over the air?** Reduce distance, raise `txGain`, or step down to a lower-order constellation (e.g. 16-QAM) to verify link margin.
- **Clipping warning (`max|sample| > 0.95`)?** Lower TX gain or add attenuation.

### 5. Stop cleanly
Press **Ctrl+C**, then release the radio object so the device frees up for the next run:
```matlab
release(rx)   % and release(tx) on the transmit side
```

---

## DO's

- ✅ **Do use a coax cable + attenuator for any single-device / cabled test.** The 30–40 dB pad protects the RX front end.
- ✅ **Do keep the shared parameter block identical** on both TX and RX (frequency, sample rate, M, BCH sizes, seeds, preamble).
- ✅ **Do start the receiver before the transmitter** on the two-Pluto link so it's already listening.
- ✅ **Do check for the clipping / headroom message** at the top of each capture.
- ✅ **Do prove the chain on the single-device loopback first**, then move to the harder over-the-air case.
- ✅ **Do `release()` the radio** when done or between parameter changes.
- ✅ **Do fix poor SNR at the RF layer** (gain, attenuation, distance) rather than by piling on software complexity.

## DON'Ts

- ❌ **Don't transmit and receive between two antennas a few centimetres apart on one Pluto.** Simultaneous close-range TX/RX can saturate or damage the RX front end — use the attenuated coax loopback instead.
- ❌ **Don't run the radio without an antenna or load on the TX port.**
- ❌ **Don't edit the shared parameters on only one side** — a silent mismatch (especially the length header) drops leading characters instead of throwing an error.
- ❌ **Don't add a `CarrierSynchronizer` to the single-Pluto loopback.** Both TX and RX share one crystal, so there is no offset to correct and it only manufactures phase error.
- ❌ **Don't place a time-varying AGC before the matched filter / channel estimate** — it settles differently on the constant-modulus preamble vs. the high-PAPR payload and corrupts the estimate. Prefer static post-filter RMS normalization.
- ❌ **Don't push transmit gain higher than needed**, and stay within any legal/ISM power limits for your region and band.

## Precautions

- **RF front-end protection:** the single most important rule is the inline attenuator on cabled tests. Treat the RX input as fragile.
- **Frequency selection:** the default `Fc = 915 MHz` sits in a common ISM band, but band and power rules vary by country. Pick a frequency you are permitted to transmit on, at low power, and avoid interfering with other services.
- **Thermal:** the Pluto warms up during long transmit sessions; leave it ventilated.
- **Reproducibility:** the dual-device receiver resets its sync loops each capture so passes are self-contained — expect the first few passes to read "not locked yet" while the loops settle. That's normal, not a failure.

---

## Signal chain at a glance

```
TX:  text -> BCH(31,16) encode -> whiten -> 32-QAM -> RRC shape -> preamble -> Pluto DAC/RF
RX:  Pluto RF/ADC -> DC removal -> [coarse freq comp*] -> RRC matched filter
     -> Gardner timing -> [carrier sync*] -> preamble correlation (detect + derotate)
     -> [DD phase clean-up*] -> 32-QAM demod -> de-whiten -> BCH(31,16) decode -> text

*dual-device receiver only; the single-device loopback omits these because it shares one crystal.
```
