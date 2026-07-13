%% ============================ tx_2pluto.m ============================
% TRANSMIT laptop (Pluto A on USB).
%
% Frame:
%   [ 64-symbol PN preamble (BPSK) | BCH(31,16)-coded, whitened,
%     32-QAM payload with a 2-byte length header at the front ]
%
% WHAT CHANGED vs the loopback (and WHY it needs to):
%   * PN preamble (64 sym) instead of Barker-13x2 -> clean |corr| sidelobes.
%   * Whitening (scrambling) -> balances long space runs so the RX loops
%     stay locked. (The loopback got away without it: shared clock.)
%   * 2-BYTE LENGTH HEADER at the front of the payload. **This is the bit
%     that was missing.** rx_2pluto reads bytes 1-2 as the message length
%     and starts the text at byte 3. Without the header the receiver treats
%     the first two message characters as a length field and drops them --
%     which is exactly why "CommSys" was arriving as "mmSys".
%   * Seamless loop boundary (filter 3 copies, keep the middle one).
%
% USAGE:
%   1. (Optional) put your text in 'message.txt' in this folder.
%   2. Run tx_2pluto.m once. It returns immediately; the Pluto keeps
%      transmitting. LEAVE MATLAB OPEN and do NOT 'clear'.
%   3. Stop deliberately with:  release(tx)
%
% The SHARED PARAMETERS block MUST be byte-identical to rx_2pluto.m.
% =====================================================================

clear; clc;

%% ---------- SHARED PARAMETERS (IDENTICAL in tx_2pluto & rx_2pluto) ----
Fc        = 915e6;    % RF centre frequency (use the band you're assigned)
Fs        = 1e6;      % baseband sample rate (Hz)
sps       = 4;        % samples per symbol at the transmitter
M         = 32;       % 32-QAM (5 bits/symbol)
N         = 31; K = 16;   % BCH(31,16) -> corrects up to t = 3 errors/word
numChars  = 280;      % fixed payload length (bytes) known to both sides
preLen    = 64;       % PN preamble length (symbols)
preSeed   = 77;       % RNG seed for the preamble
scramSeed = 4093;     % RNG seed for the whitening sequence
rolloff   = 0.35;     % RRC roll-off
span      = 10;       % RRC span (symbols)
txGain    = -10;      % Pluto Tx gain, dB (-89.75 .. 0).
                      %   Over-the-air ~1 m apart: -10 is a good "no noise"
                      %   start. DIRECT CABLE: use -30 or lower AND a
                      %   ~30 dB inline attenuator -- never cable the ports
                      %   at high gain, you will clip/damage the RX front end.

%% ---------- Derived sizes (identical maths on both sides) -------------
bps      = log2(M);
msgBitsN = numChars*8;
padK     = mod(-msgBitsN, K);
numWords = (msgBitsN + padK)/K;
codedN   = numWords*N;
padS     = mod(-codedN, bps);
paySyms  = (codedN + padS)/bps;
frameSyms  = preLen + paySyms;
frameSamps = frameSyms*sps;

rng(preSeed);   preamble = 2*randi([0 1], preLen, 1) - 1;         % +/-1 BPSK
rng(scramSeed); scram    = logical(randi([0 1], codedN+padS, 1)); % whitening

%% ---------- Message -> bits (with 2-byte length prefix) ---------------
if isfile('message.txt')
    txt = fileread('message.txt');
else
    txt = ['No message.txt found - transmitting this fallback text. ' ...
           'The quick brown fox jumps over the lazy dog 0123456789.'];
end
txt = txt(:).';

hdrBytes = 2;                               % 2-byte big-endian length header
maxMsg   = numChars - hdrBytes;             % room left for real text (278)
if numel(txt) > maxMsg, txt = txt(1:maxMsg); end   % truncate if too long
Lmsg = numel(txt);

body = [floor(Lmsg/256), mod(Lmsg,256), ... % length header (front of frame)
        double(txt), ...                    % the actual message
        32*ones(1, maxMsg - Lmsg)];         % pad the rest with spaces (0x20)
bits = int2bit(body(:), 8);                 % 8 bits/byte, MSB first

%% ---------- BCH(31,16) encoding ---------------------------------------
msgBits   = [bits; zeros(padK,1)];
msgBlocks = reshape(msgBits, K, []).';                   % L-by-K
codedGF   = bchenc(gf(msgBlocks), N, K);                 % L-by-N
codedBits = reshape(double(codedGF.x).', [], 1);         % codedN-by-1
assert(numel(codedBits) == codedN, 'size mismatch - check parameters');

%% ---------- Whiten + map to 32-QAM ------------------------------------
txBits     = double(xor(logical([codedBits; zeros(padS,1)]), scram));
paySymbols = qammod(txBits, M, 'InputType','bit', 'UnitAveragePower',true);

frame = [preamble; paySymbols];

%% ---------- RRC pulse shaping with a SEAMLESS loop boundary -----------
txFilt = comm.RaisedCosineTransmitFilter( ...
    'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, ...
    'OutputSamplesPerSymbol', sps);
w3     = txFilt(repmat(frame, 3, 1));           % filter 3 copies...
txWave = w3(frameSamps+1 : 2*frameSamps);       % ...keep the steady middle
txWave = 0.8 * txWave / max(abs(txWave));       % |samples| < 1

%% ---------- Start the Pluto -------------------------------------------
radios = findPlutoRadio;
assert(~isempty(radios), 'No ADALM-Pluto found. Check USB / drivers.');

tx = sdrtx('Pluto', ...
    'RadioID',            'usb:0', ...
    'CenterFrequency',    Fc, ...
    'BasebandSampleRate', Fs, ...
    'Gain',               txGain);

transmitRepeat(tx, txWave);

fprintf('--------------------------------------------------------------\n');
fprintf('Transmitting on repeat:\n');
fprintf('  Fc = %.3f MHz | Fs = %g MHz | %d-QAM | %d-byte payload\n', ...
        Fc/1e6, Fs/1e6, M, numChars);
fprintf('  message = %d chars + %d pad | header carries the true length\n', ...
        Lmsg, maxMsg - Lmsg);
fprintf('  frame = %d symbols (%d preamble + %d payload) = %.2f ms\n', ...
        frameSyms, preLen, paySyms, frameSamps/Fs*1e3);
fprintf('  Tx gain = %d dB\n', txGain);
fprintf('Keep MATLAB open. Stop with:  release(tx)\n');
fprintf('--------------------------------------------------------------\n');
