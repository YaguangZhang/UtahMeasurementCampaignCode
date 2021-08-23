function [rxLats, rxLons, rxGpsTimestamps, routeName] ...
    ... %[rxLats, rxLons, routeName, txLat, txLon]
    = loadGpsForRoute(absDirForRouteFolder)
% LOADGPSFORROUTE Load GPS information from the .json files published by
% the Odin system.
%
% Yaguang Zhang, Purdue, 08/21/2021

[~, routeName] = fileparts(absDirForRouteFolder);

%% TX Loc.
% The TX is fixed so we only need to load the data from one log file.
%  dirToTxMsgs = fullfile(absDirForRouteFolder, ...
%     'tx-realm', 'gps-subscription-messages');
% curGpsLogs = rdir(dirToTxMsgs, ...
%     'regexp(name, ''(gps_event_\d+\.json$)'')');
% curGpsLog = curGpsLogs(1).name;
%  [txLat, txLon] = loadLatLonFromGpsEventFile(curGpsLog);

%% RX Locs.
dirToRxMsgs = fullfile(absDirForRouteFolder, ...
    'rx-realm', 'gps-publishes');
curGpsLogs = rdir(dirToRxMsgs, ...
    'regexp(name, ''(gps_event_\d+\.json$)'')');

% Make sure the log files are sorted by name before loading. Example file
% name: gps_event_5.json.
[~, sortedIs] = sort( str2double(cellfun(@(ts) ts{1} , ...
    regexp( {curGpsLogs.name}, ...
    'gps_event_(\d+)\.json', 'tokens') ...
    )));
curGpsLogs = curGpsLogs(sortedIs);

numOfRxLocs = length(curGpsLogs);
[rxLats, rxLons] = deal(nan(numOfRxLocs,1));
rxGpsTimestamps = cell(numOfRxLocs,1);
for idxRxLoc = 1:numOfRxLocs
    curGpsLogDir = curGpsLogs(idxRxLoc).name;
    [rxLats(idxRxLoc), rxLons(idxRxLoc), rxGpsTimestamps{idxRxLoc}] ...
        = loadLatLonTimeFromGpsEventFile(curGpsLogDir);
end

end
% EOF