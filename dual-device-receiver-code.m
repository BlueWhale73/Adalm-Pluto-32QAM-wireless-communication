%% ============================ rx_2pluto.m ============================
% RECEIVE laptop (Pluto B on USB). Run while tx_2pluto.m is transmitting.
%
% Chain: capture -> DC removal -> coarse freq comp -> RRC matched filter
%   -> Gardner timing -> carrier sync -> preamble |corr| (find + derotate)
%   -> DD phase clean-up -> 32-QAM demod -> de-whiten -> BCH decode -> text
%
% The 2-byte length header at the front of the payload is read here to
% show exactly the real message and hide the space padding. The
% transmitter MUST send that header (tx_2pluto.m) or the first two
% characters are consumed as a bogus length -> "CommSys" -> "mmSys".
%
% The SHARED PARAMETERS block MUST be byte-identical to tx_2pluto.m.
% =====================================================================

clear; clc; close all;

%% ---------- SHARED PARAMETERS (IDENTICAL in tx_2pluto & rx_2pluto) ----
Fc        = 915e6;    % must match tx_2pluto
Fs        = 1e6;
sps       = 4;
M         = 32;       % must equal M in tx_2pluto.m (32-QAM = 5 bits/sym)
N         = 31; K = 16;
numChars  = 280;
preLen    = 64;
preSeed   = 77;
scramSeed = 4093;
rolloff   = 0.35;
span      = 10;

%% ---------- Receiver tuning knobs (rx-only) ---------------------------
freqRes   = 100;      % coarse-comp resolution (Hz)
loopBW    = 0.01;     % carrier synchronizer normalized loop bandwidth
useDD     = true;     % decision-directed residual-phase clean-up on/off
ddGain    = 0.01;     % DD loop gain (small)
showPlots = true;     % live correlation + constellation figures

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

hdrBytes = 2;                       % <-- must match tx_2pluto header size
maxMsg   = numChars - hdrBytes;     % 278

rng(preSeed);   preamble = 2*randi([0 1], preLen, 1) - 1;
rng(scramSeed); scram    = logical(randi([0 1], codedN+padS, 1));

%% ---------- Reference (rebuilt EXACTLY like the tx body) --------------
% Build the reference the same way tx_2pluto builds `body`: 2-byte header
% + message + space padding. This is what makes the char-error count line
% up now that the transmitter sends a header.
haveRef = isfile('message.txt');
if haveRef
    reftxt = fileread('message.txt'); reftxt = reftxt(:).';
    if numel(reftxt) > maxMsg, reftxt = reftxt(1:maxMsg); end
    Lref    = numel(reftxt);
    refBody = [floor(Lref/256), mod(Lref,256), double(reftxt), ...
               32*ones(1, maxMsg - Lref)];        % 1-by-numChars
end

%% ---------- Create the radio ONCE -------------------------------------
radios = findPlutoRadio;
assert(~isempty(radios), 'No ADALM-Pluto found. Check USB / drivers.');

rx = sdrrx('Pluto', ...
    'RadioID',            'usb:0', ...
    'CenterFrequency',    Fc, ...
    'BasebandSampleRate', Fs, ...
    'GainSource',         'AGC Slow Attack', ...
    'OutputDataType',     'double', ...
    'SamplesPerFrame',    10*frameSamps);

% DIRECT CABLE (only with ~30 dB inline attenuator!): manual gain:
% rx.GainSource = 'Manual';  rx.Gain = 10;

for i = 1:4, rx(); end                             % let hardware AGC settle

%% ---------- Create the sync System objects ONCE -----------------------
cfc = comm.CoarseFrequencyCompensator('Modulation','QAM', ...
    'SampleRate', Fs, 'FrequencyResolution', freqRes);

rxFilt = comm.RaisedCosineReceiveFilter('RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps, ...
    'DecimationFactor', sps/2);                    % 4 sps -> 2 sps

symSync = comm.SymbolSynchronizer( ...
    'TimingErrorDetector','Gardner (non-data-aided)', 'SamplesPerSymbol', 2);

carSync = comm.CarrierSynchronizer('Modulation','QAM', ...
    'SamplesPerSymbol', 1, 'NormalizedLoopBandwidth', loopBW);

%% ---------- Figures (created once, reused each pass) ------------------
if showPlots
    figCorr = figure('Name','Preamble correlation','NumberTitle','off');
    figScat = figure('Name','Payload constellation','NumberTitle','off');
end

fprintf('--------------------------------------------------------------\n');
fprintf('Receiving in a LOOP. Fc = %.3f MHz | Fs = %g MHz | %d-QAM\n', ...
        Fc/1e6, Fs/1e6, M);
fprintf('Press Ctrl+C to stop, then run:  release(rx)\n');
fprintf('--------------------------------------------------------------\n');

%% ================= CONTINUOUS RECEIVE / DECODE LOOP ===================
nPass = 0;
while true
    nPass = nPass + 1;
    reset(cfc); reset(rxFilt); reset(symSync); reset(carSync);

    %% ----- Capture + DC removal -----
    raw = rx();
    maxAmp = max(abs(raw));
    if maxAmp > 0.95
        fprintf('[pass %d] WARNING max|sample| = %.3f -- likely ADC clipping!\n', ...
                nPass, maxAmp);
    end
    raw = raw - mean(raw);

    %% ----- Sync chain -----
    [sigCFO, cfoEst] = cfc(raw);
    sigMF = rxFilt(sigCFO);
    symbs = symSync(sigMF);
    symbs = carSync(symbs);
    symbs = symbs / rms(symbs);

    %% ----- Frame detection by preamble correlation -----
    c   = conv(symbs, conj(flipud(preamble)));
    cm  = abs(c);
    thr = 0.6 * max(cm);
    [pk, loc] = findpeaks(cm, 'MinPeakHeight', thr, ...
        'MinPeakDistance', round(0.8*frameSyms));

    if showPlots
        figure(figCorr); clf; plot(cm); hold on;
        if ~isempty(loc), plot(loc, pk, 'rv', 'MarkerFaceColor','r'); end
        yline(thr,'--'); xlabel('symbol index'); ylabel('|correlation|');
        title(sprintf('Preamble correlation (pass %d, %d frames)', nPass, numel(loc)));
        legend('|corr|','detected frames','threshold'); drawnow limitrate;
    end

    %% ----- Decode every detected frame, keep the best -----
    best = struct('fail', inf, 'bits', [], 'pay', [], 'startIdx', NaN, 'fixed', 0);
    for ii = 1:numel(loc)
        s = loc(ii) - preLen + 1;
        if s < 1 || s + frameSyms - 1 > numel(symbs), continue; end

        rot = c(loc(ii)) / abs(c(loc(ii)));
        pay = symbs(s + preLen : s + frameSyms - 1) * conj(rot);
        pay = pay / rms(pay);

        if useDD
            phi = 0;
            for n = 1:numel(pay)
                y  = pay(n) * exp(-1j*phi);
                d  = qammod(qamdemod(y, M, 'UnitAveragePower',true), M, ...
                            'UnitAveragePower',true);
                phi = phi + ddGain * angle(y * conj(d));
                pay(n) = y;
            end
        end

        rxBits  = qamdemod(pay, M, 'OutputType','bit', 'UnitAveragePower',true);
        rxBits  = double(xor(logical(rxBits), scram));
        rxCoded = rxBits(1:codedN);

        rxBlocks         = reshape(rxCoded, N, []).';
        [decGF, cnumerr] = bchdec(gf(rxBlocks), N, K);
        nFail   = sum(cnumerr == -1);
        decBits = reshape(double(decGF.x).', [], 1);
        decBits = decBits(1:msgBitsN);

        if nFail < best.fail
            best = struct('fail', nFail, 'bits', decBits, 'pay', pay, ...
                          'startIdx', s, 'fixed', sum(cnumerr(cnumerr > 0)));
        end
    end

    %% ----- Report this pass (non-fatal if nothing decoded) -----
    if isinf(best.fail)
        fprintf('[pass %d] no decodable frame (cfo %+.0f Hz) -- loops still settling...\n', ...
                nPass, cfoEst);
        continue;
    end

    % 2-byte length header -> exact message, discard space padding
    allBytes = bit2int(best.bits, 8).';             % 1-by-numChars
    Lmsg     = allBytes(1)*256 + allBytes(2);
    Lmsg     = min(max(Lmsg,0), maxMsg);            % clamp a corrupt header
    rxTxt    = char(allBytes(hdrBytes + (1:Lmsg))); % text starts at byte 3

    hardSyms = qammod(qamdemod(best.pay, M, 'OutputType','bit', ...
               'UnitAveragePower',true), M, 'InputType','bit', ...
               'UnitAveragePower',true);
    snrEst = -20*log10(rms(best.pay - hardSyms));

    fprintf('[pass %d] cfo %+.0f Hz | uncorrectable %d/%d | BCH-repaired bits %d | SNR ~%.1f dB\n', ...
            nPass, cfoEst, best.fail, numWords, best.fixed, snrEst);
    fprintf('   text: "%s"\n', rxTxt);

    % ----- CHANGED: compare full decoded body against the rebuilt ref -----
    if haveRef
        byteErr = sum(allBytes ~= refBody);         % header + msg + padding
        fprintf('   byte errors vs message.txt: %d / %d\n', byteErr, numChars);
    end

    if showPlots
        figure(figScat); clf;
        plot(real(best.pay), imag(best.pay), '.', 'MarkerSize', 4);
        axis equal; grid on; xlabel('In-phase'); ylabel('Quadrature');
        title(sprintf('%d-QAM payload after full sync (pass %d, SNR ~%.1f dB)', ...
              M, nPass, snrEst)); drawnow limitrate;
    end
end
