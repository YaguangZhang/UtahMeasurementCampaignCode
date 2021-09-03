function [ timestampsStr, timestampsDatetime ] ...
    = parseUsrpTimestampsLog(dirToLog)
%PARSEUSRPTIMESTAMPSLOG Load the timestamps from the RX USRP timestamp.log
%file generated in the Utah measurement campaign.
%
% Example log content:
%   UTC Timestamp: 
%   1. 2021-07-02 18:19:09.241678
%   2. 2021-07-02 18:50:51.138574
%
% Yaguang Zhang, Purdue, 09/02/2021

fId = fopen(dirToLog, 'r');
timestampStr = fgetl(fId);

assert(strcmpi(timestampStr, 'UTC Timestamps'), ...
    'Unexpected timestamp log format!');

% Read the timestamps one by one.
timestampsStr = {};
timestampCnt = 0;
timestampStr = fgetl(fId);
while sum(~isspace(timestampStr))>0
    timestampCnt = timestampCnt+1;
    
    idxFirstColon = strfind(timestampStr, ': ');
    timestampsStr{end+1} = timestampStr( ...
        (idxFirstColon(1)+2):end ); %#ok<AGROW>
    
    if ~feof(fId)
        timestampStr = fgetl(fId);
    else
        timestampStr = '';
    end
end
fclose(fId);

timestampsStr = timestampsStr';
timestampsDatetime = datetime(timestampsStr);
end
% EOF