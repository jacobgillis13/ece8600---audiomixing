%% ECE 8600 Project Demo: Audio Mixing & Filtering

clear; clc;

%% USER-ADJUSTABLE SETTINGS
Fs_target = 44100;

preSeconds  = 20;
fadeSeconds = 6;
postSeconds = 20;

bassGain   = 3.0;
trebleGain = 1.2;

fc_bass   = 650;
fc_treble = 2500;

useDesigns = ["fir1_lowOrder","fir1_highOrder","firpm_equiripple"];
plotDesign = "firpm_equiripple";

%% SELECT INPUT FILES FROM COMPUTER
[fileAName, fileAPath] = uigetfile({'*.wav;*.mp3;*.m4a','Audio Files (*.wav, *.mp3, *.m4a)'}, ...
    'Select the first audio file');
if isequal(fileAName,0)
    error('No first audio file selected.');
end
fileA = fullfile(fileAPath, fileAName);

[fileBName, fileBPath] = uigetfile({'*.wav;*.mp3;*.m4a','Audio Files (*.wav, *.mp3, *.m4a)'}, ...
    'Select the second audio file');
if isequal(fileBName,0)
    error('No second audio file selected.');
end
fileB = fullfile(fileBPath, fileBName);

%% OUTPUT PATH FOR SAVED FILES
% outputs sabed to file on computer
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder)
    scriptFolder = pwd;
end

outFolder = fullfile(scriptFolder, "ECE8600_outputs");

baseOut = outFolder;
k = 2;
while exist(outFolder, "dir")
    outFolder = baseOut + "_" + string(k);
    k = k + 1;
end

mkdir(outFolder);

disp("Saving output WAV files to:")
disp(outFolder)

%% LOAD AND PREPROCESS AUDIO
[xA,FsA] = audioread(fileA);
[xB,FsB] = audioread(fileB);

% Convert stereo to mono if needed
if size(xA,2) > 1, xA = mean(xA,2); end
if size(xB,2) > 1, xB = mean(xB,2); end

% Resample to a common sampling rate
if FsA ~= Fs_target, xA = resample(xA, Fs_target, FsA); end
if FsB ~= Fs_target, xB = resample(xB, Fs_target, FsB); end
Fs = Fs_target;

% Normalize input levels
xA = xA / max(abs(xA)) * 0.8;
xB = xB / max(abs(xB)) * 0.8;

%% DESIGN FIR FILTERS
Wn_bass   = fc_bass/(Fs/2);
Wn_treble = fc_treble/(Fs/2);

filters = struct();

for kk = 1:numel(useDesigns)

    name = useDesigns(kk);

    switch name

        case "fir1_lowOrder"
            N = 80;
            hLP = fir1(N, Wn_bass,   "low",  hamming(N+1));
            hHP = fir1(N, Wn_treble, "high", hamming(N+1));

        case "fir1_highOrder"
            N = 300;
            hLP = fir1(N, Wn_bass,   "low",  hamming(N+1));
            hHP = fir1(N, Wn_treble, "high", hamming(N+1));

        case "firpm_equiripple"
            N = 180;
            m1 = 40/(Fs/2);
            m2 = 200/(Fs/2);

            F_lp = [0 Wn_bass min(Wn_bass+m1,1) 1];
            A_lp = [1 1 0 0];
            hLP = firpm(N, F_lp, A_lp);

            F_hp = [0 max(Wn_treble-m2,0) Wn_treble 1];
            A_hp = [0 0 1 1];
            hHP = firpm(N, F_hp, A_hp);
    end

    filters.(name).hLP = hLP(:);
    filters.(name).hHP = hHP(:);
end

%% APPLY FILTERING AND DJ MIX 
results = struct();
designNames = string(fieldnames(filters));

for kk = 1:numel(designNames)

    dn = designNames(kk);

    hLP = filters.(dn).hLP;
    hHP = filters.(dn).hHP;

    % Low-pass and high-pass filtered versions
    A_LP = filter(hLP, 1, xA);
    A_HP = filter(hHP, 1, xA);

    B_LP = filter(hLP, 1, xB);
    B_HP = filter(hHP, 1, xB);

    % Equalized signals
    A_EQ = xA + bassGain*A_LP - trebleGain*A_HP;
    B_EQ = xB + bassGain*B_LP - trebleGain*B_HP;

    % Normalize after EQ
    A_EQ = A_EQ / max(abs(A_EQ)) * 0.85;
    B_EQ = B_EQ / max(abs(B_EQ)) * 0.85;

    % Mix timing
    Npre  = round(preSeconds*Fs);
    Nfade = round(fadeSeconds*Fs);
    Npost = round(postSeconds*Fs);

    Ntotal = Npre + Nfade + Npost;

    % Pad if needed
    if length(A_EQ) < Ntotal, A_EQ(end+1:Ntotal) = 0; end
    if length(B_EQ) < Ntotal, B_EQ(end+1:Ntotal) = 0; end

    % Crossfade weights
    wA = [ones(Npre,1); linspace(1,0,Nfade)'; zeros(Npost,1)];
    wB = 1 - wA;

    % Final mix
    mix = wA .* A_EQ(1:Ntotal) + wB .* B_EQ(1:Ntotal);

    % Normalize final output
    mix = mix / max(abs(mix)) * 0.9;

    results.(dn).A_EQ = A_EQ(1:Ntotal);
    results.(dn).mix  = mix;

    % Save each mix
    outFile = fullfile(outFolder, "mix_" + dn + ".wav");
    audiowrite(outFile, mix, Fs);

    % EXTRA AUDIO OUTPUTS TO HEAR FILTER EFFECTS
    audiowrite(fullfile(outFolder, "A_LP_" + dn + ".wav"), A_LP / max(abs(A_LP)) * 0.8, Fs);
    audiowrite(fullfile(outFolder, "A_HP_" + dn + ".wav"), A_HP / max(abs(A_HP)) * 0.8, Fs);
    audiowrite(fullfile(outFolder, "B_LP_" + dn + ".wav"), B_LP / max(abs(B_LP)) * 0.8, Fs);
    audiowrite(fullfile(outFolder, "B_HP_" + dn + ".wav"), B_HP / max(abs(B_HP)) * 0.8, Fs);
    audiowrite(fullfile(outFolder, "A_EQ_" + dn + ".wav"), A_EQ / max(abs(A_EQ)) * 0.8, Fs);
    audiowrite(fullfile(outFolder, "B_EQ_" + dn + ".wav"), B_EQ / max(abs(B_EQ)) * 0.8, Fs);

    disp("Wrote: " + outFile)
end

disp("DONE. Files saved.")

%% ANALYSIS / PLOTS 
dn = plotDesign;

Npre  = round(preSeconds*Fs);
Nfade = round(fadeSeconds*Fs);
Npost = round(postSeconds*Fs);
Ntotal = Npre + Nfade + Npost;

xA_pad = xA;
if length(xA_pad) < Ntotal, xA_pad(end+1:Ntotal) = 0; end

xB_pad = xB;
if length(xB_pad) < Ntotal, xB_pad(end+1:Ntotal) = 0; end

wA = [ones(Npre,1); linspace(1,0,Nfade)'; zeros(Npost,1)];
wB = 1 - wA;

rawMix = wA .* xA_pad(1:Ntotal) + wB .* xB_pad(1:Ntotal);
rawMix = rawMix / max(abs(rawMix)) * 0.9;

procMix = results.(dn).mix;

t = (0:Ntotal-1)' / Fs;

%% TIME DOMAIN PLOT
win = min(round(3*Fs), Ntotal);

figure
plot(t(1:win), rawMix(1:win)); hold on
plot(t(1:win), procMix(1:win))
grid on
xlabel("Time (s)")
ylabel("Amplitude")
legend("Before Mix","After DJ Mix")
title("Time Domain Comparison")

%% FFT ANALYSIS
Nfft = 2^nextpow2(Ntotal);

W1 = hann(length(rawMix));
W2 = hann(length(procMix));

RAW = fft(rawMix .* W1, Nfft);
PRC = fft(procMix .* W2, Nfft);

f = (0:Nfft-1)' * (Fs/Nfft);
half = 1:floor(Nfft/2);

figure
plot(f(half), 20*log10(abs(RAW(half))+1e-12)); hold on
plot(f(half), 20*log10(abs(PRC(half))+1e-12))
grid on
xlabel("Frequency (Hz)")
ylabel("Magnitude (dB)")
legend("Before Mix","After DJ Mix")
title("Frequency Spectrum Comparison")
xlim([0 12000])

%% SPECTROGRAMS
figure
spectrogram(rawMix, 2048, 1536, 4096, Fs, "yaxis")
title("Spectrogram Before DJ Mix")

figure
spectrogram(procMix, 2048, 1536, 4096, Fs, "yaxis")
title("Spectrogram After DJ Mix")

%% FILTERS

figure
freqz(filters.(dn).hLP, 1, 2048, Fs)
title("Low-Pass FIR Frequency Response")

figure
freqz(filters.(dn).hHP, 1, 2048, Fs)
title("High-Pass FIR Frequency Response")

% Combined EQ frequency response for the selected design
[HLP, fEQ] = freqz(filters.(dn).hLP, 1, 2048, Fs);
[HHP, ~]   = freqz(filters.(dn).hHP, 1, 2048, Fs);

HEQ = 1 + bassGain*HLP - trebleGain*HHP;

figure
plot(fEQ, 20*log10(abs(HEQ) + 1e-12))
grid on
xlabel("Frequency (Hz)")
ylabel("Magnitude (dB)")
title("Combined EQ Frequency Response")
xlim([0 12000])

disp("Plots finished.")