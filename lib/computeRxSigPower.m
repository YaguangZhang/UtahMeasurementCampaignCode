function [ measPInDb ] = computeRxSigPower(curSignal, rxGain, FlagCutHead)
%COMPUTERXSIGPOWER Compute the signal power for the input RX complex array
%curSignal.
%
% Inputs:
%   - curSignal
%     A complex array representing the Rx signal.
%   - rxGain
%     A scalar. The Gnu Radio gain (in dB) for curSignal.
%   - FlagCutHead
%     Optional. True by default. Set this to false if there is no need to
%     discard the heading numStartSampsToDiscard samples.
%
% Procedures below will be carried out one by one:
%    (1) LPF
%        A pre-filtering procedure to reduce noise in frequency domain.
%    (2) Shrink the input signal sequence
%        Only use a segment of the signal for path loss computation.
%    (3) Noise elimination
%        Further reduce noise in time domain.
%    (4) Power calculation
%        Calculate the power vis PSD.
%    (5) Rx calibration
%
% Yaguang Zhang, Purdue, 08/21/2021

%% Parameters

% We will reuse the parameters and results of the calibration procedure.
ABS_PATH_TO_SHARED_FOLDER = evalin('base', 'ABS_PATH_TO_SHARED_FOLDER');
load(fullfile(ABS_PATH_TO_SHARED_FOLDER, 'PostProcessingResults', ...
    '1_Calibration', 'sigPowerCompSettings.mat'), ...
    'Fs', 'Fp', 'Fst', 'Ap', 'Ast', ...
    'maxFreqPassed', 'minFreqPassed', ...
    'numStartSampsToDiscard', 'timeLengthAtCenterToUse');
load(fullfile(ABS_PATH_TO_SHARED_FOLDER, 'PostProcessingResults', ...
    '1_Calibration', 'lsLinesPolys.mat'), ...
    'lsLinesPolysInv', 'rxGains');

% Compute path losses (without considering the antenna gain) for this
% track. We will use the amplitude version of thresholdWaveform.m without
% plots for debugging as the noise eliminiation function.
noiseEliminationFct = @(waveform) thresholdWaveform(abs(waveform));

% By default, we need to discard the first numStartSampsToDiscard samples
% to avoid the warm-up stage of USRP. Note that this is not necessary for
% most of the Conti measurements.
if ~exist('FlagCutHead', 'var')
    FlagCutHead = true;
end

%% LPF

% Pre-filter the input with a LPF.
lpfComplex = dsp.LowpassFilter('SampleRate', Fs, ...
    'FilterType', 'FIR', 'PassbandFrequency', Fp, ...
    'StopbandFrequency', Fst, ...
    'PassbandRipple', Ap, ...
    'StopbandAttenuation', Ast ...
    );
release(lpfComplex);
curSignal = lpfComplex(curSignal);

%% Get a Segment of the Signal for Path Loss Computation

if FlagCutHead
    % Discard the first numStartSampsToDiscard of samples.
    curSignal = curSignal((numStartSampsToDiscard+1):end);
end
% Further more, only keep the middle part for calibration.
numSampsToKeep = ceil(timeLengthAtCenterToUse*Fs);
numSampsCurSeries = length(curSignal);
if numSampsToKeep > numSampsCurSeries
    warning(['There are not enough samples to keep. ', ...
        'We will use all remaining ones.']);
else
    idxRangeToKeep = floor(0.5.*numSampsCurSeries ...
        + [-1,1].*numSampsToKeep./2);
    curSignal = curSignal(max(idxRangeToKeep(1),1) ...
        :min(idxRangeToKeep(2), numSampsCurSeries));
end
% Make sure we end up with even number of samples.
if mod(length(curSignal),2)==1
    curSignal = curSignal(1:(end-1));
end

%% Noise Elimination

% Noise elimination.
[~, boolsEliminatedPts] = ...
    noiseEliminationFct(curSignal);
curSignalEliminated = curSignal;
curSignalEliminated(boolsEliminatedPts) = 0;

% Also get rid of everything below the USRP noise floor if
% USRP_NOISE_FLOOR_V is specified in the base workspace.
if evalin('base','exist(''USRP_NOISE_FLOOR_V'', ''var'')')
    USRP_NOISE_FLOOR_V = evalin('base', 'USRP_NOISE_FLOOR_V');
    curSignalEliminated(abs(curSignalEliminated)<USRP_NOISE_FLOOR_V) = 0;
end

%% Calculate Power

% For the signal to process, i.e. the noise eliminiated signal, compute the
% PSD.
X = curSignalEliminated;
L = length(X);
% FFT results.
Y = fftshift(fft(X));
% Frequency domain.
f = (-L/2:L/2-1)*(Fs/L);
idxDC = L/2+1;
% PSD.
powerSpectralDen = abs(Y).^2/L;

% Compute the power.
boolsFPassed = abs(f)<=maxFreqPassed ...
    & abs(f)>=minFreqPassed;
% Compute the power by integral. Note that we will always discard the DC
% component here (although it may be passed by the filters).
psdPassed = powerSpectralDen;
psdPassed(~boolsFPassed) = 0;
psdPassed(idxDC) = 0;
calcP = trapz(f, psdPassed);

%% Rx Calibration
powerShiftsForCali = genCalibrationFct(lsLinesPolysInv, rxGain, rxGains);

% Change to dB and remove the gain from the Gnu Radio.
calcPInDbShifted = 10.*log10(calcP) - rxGain;
measPInDb = calcPInDbShifted + powerShiftsForCali;

end

% EOF