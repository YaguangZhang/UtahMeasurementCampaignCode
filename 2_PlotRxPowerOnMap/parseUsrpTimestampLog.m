function [ timestamp ] = parseUsrpTimestampLog(dirToLog)
%PARSEUSRPTIMESTAMPLOG Load the timestamp from the RX USRP timestamp.log
%file generated in the Utah measurement campaign.
%
% Example log content:
%   UTC Timestamp: 2021-07-02 18:19:09.241678
%
% Yaguang Zhang, Purdue, 08/23/2021

fId = fopen(dirToLog);
timestamp = fgetl(fId);
timestamp = timestamp(16:end);

end
% EOF