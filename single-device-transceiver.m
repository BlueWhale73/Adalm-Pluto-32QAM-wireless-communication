%% pluto_bch_32qam_loopback.m
% Transmit and receive "Hello World" on one ADALM-Pluto.
% Coding: BCH(31,16), t = 3 correctable bit errors.
% Modulation: 32-QAM (5 bits/symbol).
%
% Requires: Communications Toolbox + Support Package for ADALM-Pluto Radio.
%
% IMPORTANT (hardware safety): connect Pluto's TX output to its RX input
% through a coax cable with a fixed attenuator (30-40+ dB), not free-space
% radiation between two antennas a few cm apart. Simultaneous TX/RX at
% close range risks saturating the RX front end.


clear; close all;

%% ---------------- Parameters ----------------
msg   = 'Hello World';
M     = 32;             % 32-QAM
bps   = log2(M);        % 5 bits per symbol
N     = 31;             % BCH codeword length
K     = 16;             % BCH message length
sps   = 4;              % samples per symbol
Fs    = 1e6;            % baseband sample rate (Hz)
Fc    = 915e6;          % carrier frequency (Hz)
nRep  = 20;             % frame repetitions in the transmit buffer

%% ---------------- Transmitter ----------------
% text -> bits (MSB first)
txBits = int2bit(double(msg).', 8);

% zero-pad to a multiple of K, reshape into K-bit blocks, then BCH encode
padK   = mod(-numel(txBits), K);
msgBits = [txBits; zeros(padK,1)];
msgBlocks = reshape(msgBits, K, []).';            
codedGF   = bchenc(gf(msgBlocks), N, K);          
codedBits = reshape(double(codedGF.x).', [], 1);  

% zero-pad to a multiple of bps, then 32-QAM modulate
padS    = mod(-numel(codedBits), bps);
dataSym = qammod([codedBits; zeros(padS,1)], M, ...
                 'InputType','bit', 'UnitAveragePower',true);

% BPSK preamble (Barker-13 x2) for frame sync + channel estimation
barker   = comm.BarkerCode('Length',13,'SamplesPerFrame',13);
pre      = barker();
preamble = [pre; pre];                    
frameSym = [preamble; dataSym];
nData    = numel(dataSym);

% pulse shaping
txFilt = comm.RaisedCosineTransmitFilter('RolloffFactor',0.35, ...
    'FilterSpanInSymbols',10, 'OutputSamplesPerSymbol',sps);
txWave = txFilt(repmat(frameSym, nRep, 1));
txWave = 0.6 * txWave / max(abs(txWave));  % keep inside [-1,1]

%% ---------------- Radio ----------------
tx = sdrtx('Pluto', 'CenterFrequency',Fc, 'BasebandSampleRate',Fs, 'Gain',-20);
rx = sdrrx('Pluto', 'CenterFrequency',Fc, 'BasebandSampleRate',Fs, ...
    'GainSource','AGC Slow Attack', 'OutputDataType','double', ...
    'SamplesPerFrame', 2*numel(txWave));

transmitRepeat(tx, txWave);
for k = 1:5              
    rxWave = rx();
end
release(tx); release(rx);

%% ---------------- Receiver ----------------
agc    = comm.AGC();
rxFilt = comm.RaisedCosineReceiveFilter('RolloffFactor',0.35, ...
    'FilterSpanInSymbols',10, 'InputSamplesPerSymbol',sps, ...
    'DecimationFactor',1);
symSync = comm.SymbolSynchronizer('SamplesPerSymbol',sps, ...
    'TimingErrorDetector','Gardner (non-data-aided)');

rxSym = symSync(rxFilt(agc(rxWave)));

% frame sync: matched filter against the preamble, magnitude -> phase invariant
L = numel(preamble);
c = abs(filter(flipud(conj(preamble)), 1, rxSym));   

% only consider positions where a complete frame fits
valid = false(size(c));
valid(L : numel(rxSym)-nData) = true;
c(~valid) = 0;

[peak, idx] = max(c);
assert(peak > 0, 'No valid frame position found - capture too short or no signal.');

% channel estimate (gain + phase) from the preamble, then equalize
rxPre  = rxSym(idx-numel(preamble)+1 : idx);
h      = (preamble' * rxPre) / (preamble' * preamble);
rxData = rxSym(idx+1 : idx+nData) / h;

%% ---------------- Demod + BCH decode ----------------
rxBits = qamdemod(rxData, M, 'OutputType','bit', 'UnitAveragePower',true);
rxBits = rxBits(1:end-padS);                       

rxBlocks = reshape(rxBits, N, []).';               
[decGF, nErrors] = bchdec(gf(rxBlocks), N, K);
if any(nErrors < 0)
    warning('BCH decode failed (uncorrectable errors) on %d of %d codeword(s).', ...
        sum(nErrors < 0), numel(nErrors));
end
decBits = reshape(double(decGF.x).', [], 1);
decBits = decBits(1:end-padK);                     
rxText = char(bit2int(decBits, 8)).';

fprintf('Sent    : %s\n', msg);
fprintf('Received: %s\n', rxText);
scatterplot(rxData); title('Received 32-QAM constellation');
