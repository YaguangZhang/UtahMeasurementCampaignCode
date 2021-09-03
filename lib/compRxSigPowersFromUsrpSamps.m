function [ curSigPs ] = compRxSigPowersFromUsrpSamps(usrpLogDirInfo, ...
    Fs, rxGain)
%COMPRXSIGPOWERSFROMUSRPSAMPS Compute the RX signal power from a USRP sample
%log file.
%
% One RX signal power is evaluated for each 1-second segment of the
% recording.
%
% Yaguang Zhang, Purdue, 09/02/2021

% Extract full path.
curUsrpLog = fullfile(usrpLogDirInfo.folder, usrpLogDirInfo.name);

% In a GnuRadio .out file, we have:
%     Complex - 32 bit floating point for both I and Q readings (8 bytes in
%     total per sample).
curUsrpLogSizeInByte = usrpLogDirInfo.bytes;
curNumOfSamps = floor(curUsrpLogSizeInByte/8);

% Segment the coninuous recording to 1-s pieces.
numOfSigPs = floor(curNumOfSamps/Fs);
if numOfSigPs*Fs<curNumOfSamps
    numOfSigPs = numOfSigPs+1;
end

curSigPs = nan(numOfSigPs, 1);
for idxSigP = 1:numOfSigPs
    % Avoid reading the whole log file to save RAM.
    sigSeg = readComplexBinaryInRange(curUsrpLog, ...
        [Fs*(idxSigP-1)+1, min(idxSigP*Fs, curNumOfSamps)]);
    
    FlagCutHead = (idxSigP==1);
    curSigPs(idxSigP) = computeRxSigPower(sigSeg, rxGain, FlagCutHead);
end
end
% EOF