FUNCTION REFERENCE
==============================================================
ADALM-Pluto QAM + BCH Digital Communications Link (MATLAB)
==============================================================

Every function, method, and System object called across the three
scripts, grouped by origin. Dependency note: the project needs
Communications Toolbox + the ADALM-Pluto Support Package, and also
quietly pulls in Signal Processing Toolbox (via rms and findpeaks).


--------------------------------------------------------------
BASE MATLAB - language & control
--------------------------------------------------------------
Session / figure : clear, clc, close, hold, drawnow
Error handling   : assert, warning
Predicates       : isempty, isinf, isfile, any
I/O              : fprintf, fileread


--------------------------------------------------------------
BASE MATLAB - math & array manipulation
--------------------------------------------------------------
Numeric          : mod, log2, max, min, abs, sum, mean, round,
                   exp, angle, conj, real, imag
Array shaping    : reshape, flipud, repmat, numel, size, zeros, false
Type / logical   : double, logical, char, xor
Linear filtering : conv, filter
Data structure   : struct        (the "best" frame record)
Seeded PRNG      : rng, randi     (preamble + whitening sequence)


--------------------------------------------------------------
SIGNAL PROCESSING TOOLBOX
--------------------------------------------------------------
rms         - unit-power normalization and EVM-based SNR estimate
findpeaks   - locating preamble-correlation peaks (dual-device RX)


--------------------------------------------------------------
COMMUNICATIONS TOOLBOX - functions
--------------------------------------------------------------
bchenc, bchdec, gf   - BCH(31,16) encode/decode over the Galois field
qammod, qamdemod     - 32-QAM modulation / demodulation
int2bit, bit2int     - byte <-> bit conversion (incl. 2-byte length header)


--------------------------------------------------------------
COMMUNICATIONS TOOLBOX - System objects
--------------------------------------------------------------
comm.BarkerCode                 - Barker-13 preamble (single-device)
comm.RaisedCosineTransmitFilter - RRC pulse shaping
comm.RaisedCosineReceiveFilter  - RRC matched filtering
comm.SymbolSynchronizer         - Gardner symbol-timing recovery
comm.AGC                        - automatic gain control (single-device only)
comm.CoarseFrequencyCompensator - coarse CFO removal (dual-device only)
comm.CarrierSynchronizer        - fine freq/phase recovery (dual-device only)

System-object methods:
reset    - clears loop state each pass (looping receiver)
release  - frees the object / radio
step     - invoked implicitly via obj(...) syntax


--------------------------------------------------------------
ADALM-PLUTO SUPPORT PACKAGE
--------------------------------------------------------------
findPlutoRadio   - device discovery
sdrrx, sdrtx     - receiver / transmitter radio objects
transmitRepeat   - continuous buffered transmit (single-device)


--------------------------------------------------------------
PLOTTING / VISUALIZATION
--------------------------------------------------------------
figure, plot, hold, clf, yline, xlabel, ylabel, title,
legend, scatterplot, drawnow


--------------------------------------------------------------
CUSTOM HELPER (defined in-repo)
--------------------------------------------------------------
ternary   - inline conditional (single-capture dual-device receiver)

==============================================================
