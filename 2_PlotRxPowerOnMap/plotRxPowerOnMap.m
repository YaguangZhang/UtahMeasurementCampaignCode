% PLOTRXPOWERONMAP Plot recieved signal power on a map.
%
% Yaguang Zhang, Purdue, 08/21/2021

clear; clc; close all;

%% Configurations

% Add libs to current path and set ABS_PATH_TO_SHARED_FOLDER according to
% the machine name.
cd(fileparts(mfilename('fullpath')));
addpath(fullfile(pwd));
cd('..'); setPath;

% Configure other paths accordingly.
ROUTES_OF_INTEREST = { ...
    fullfile('fully-autonomous', 'suburban-fraternities'), ...
    fullfile('fully-autonomous', 'urban-campus-I'), ...
    fullfile('fully-autonomous', 'urban-campus-II'), ...
    fullfile('fully-autonomous', 'urban-campus-III'), ...
    fullfile('fully-autonomous', 'urban-vegetation')};
INDICES_ROUTES_FORCE_REPROCESS = [];
ABS_PATH_TO_MEAS_DATA = fullfile(ABS_PATH_TO_SHARED_FOLDER, ...
    'Odin', 'POWDER', 'measurement-logs');
ABS_PATH_TO_SAVE_PLOTS = fullfile(ABS_PATH_TO_SHARED_FOLDER, ...
    'PostProcessingResults', '2_RxPowerOnMap');

% Create directories if necessary.
if exist(ABS_PATH_TO_SAVE_PLOTS, 'dir')~=7
    mkdir(ABS_PATH_TO_SAVE_PLOTS);
end

% We will need the function genCalibrationFct.m for calibration.
addpath(fullfile(pwd, '1_Calibration'));

% We will use the Google service for RX altitudes.
FLAG_USE_GOOGLE_FOR_ALT = true;
cachedApiKey = load(fullfile('lib', 'ext', ...
    'zoharby-plot_google_map-08b192d', 'api_key.mat'));
GOOGLE_MAPS_API = cachedApiKey.apiKey;

% Reuse results from calibrateRx.m.
ABS_PATH_TO_CALI_LINES_FILE = fullfile(ABS_PATH_TO_SHARED_FOLDER, ...
    'PostProcessingResults', '1_Calibration', 'lsLinesPolys.mat');
ABS_PATH_TO_CALI_SETTINGS = fullfile(ABS_PATH_TO_SHARED_FOLDER, ...
    'PostProcessingResults', '1_Calibration', 'sigPowerCompSettings.mat');

% The TX location and the RX/USRP gain were fixed during the campaign.
TX_LAT_LON = [40.76617367, -111.84793933];
rxGain = 76;

% The symbol to separate route type and route name.
routeNameDelimiter = ':';

% We will find the nearest RX signal smaple for each GPS point.
MAX_ALLOWED_TIME_DIFF_IN_S = 3;

%% Reuse History Results

disp(' ------------------ ')
disp('  plotRxPowerOnMap ')
disp(' ------------------ ')

disp(' ')
disp('    Reusing history results if possible...')
pathToSaveResults = fullfile( ...
    ABS_PATH_TO_SAVE_PLOTS, 'rxPowerWithGps.mat');
numOfRoutes = length(ROUTES_OF_INTEREST);

if exist(pathToSaveResults, 'file')
    disp(' ')
    disp('    Loading history results...')
    historyResults = load(pathToSaveResults);
    disp('    Done!')
else
    historyResults.routeNames = {};
end

[routeNames, txLatLons, rxLatLonTracks, rxGpsTimestamps, ...
    rxSigPowers, rxUsrpStartTimestamps] ...
    = deal(cell(numOfRoutes, 1));

% Construct a list of identifiers of all the routes to process.
for idxRoute = 1:numOfRoutes
    curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
    [rType, rName] = fileparts(curRouteOfInterest);
    routeNames{idxRoute} = [rType, routeNameDelimiter, rName];
end

% Find routes that have already been processed. We assume only new routes
% can be added, i.e., no processed routes will ever be removed.
numOfProcessedRoutes = length(historyResults.routeNames);
indicesProcessedRoutes = nan(numOfProcessedRoutes, 1);
for idxProcessedRoute = 1:numOfProcessedRoutes
    curNewRouteIdx = find(strcmp(routeNames, ...
        historyResults.routeNames{idxProcessedRoute}));
    indicesProcessedRoutes(idxProcessedRoute) = curNewRouteIdx;
    
    txLatLons{curNewRouteIdx} ...
        = historyResults.txLatLons{idxProcessedRoute};
    rxLatLonTracks{curNewRouteIdx} ...
        = historyResults.rxLatLonTracks{idxProcessedRoute};
    rxGpsTimestamps{curNewRouteIdx} ...
        = historyResults.rxGpsTimestamps{idxProcessedRoute};
    
    rxSigPowers{curNewRouteIdx} ...
        = historyResults.rxSigPowers{idxProcessedRoute};
    rxUsrpStartTimestamps{curNewRouteIdx} ...
        = historyResults.rxUsrpStartTimestamps{idxProcessedRoute};
end

boolsRoutesForceProcess = false(1, length(ROUTES_OF_INTEREST));
boolsRoutesForceProcess(INDICES_ROUTES_FORCE_REPROCESS) = true;

indicesNewRoutesToProcess ...
    = find( (~ismember(1:numOfRoutes, indicesProcessedRoutes)) ...
    | boolsRoutesForceProcess );

disp('    Done!')

%% Read In the Log Files

disp(' ')
disp('    Loading calibration results...')
load(ABS_PATH_TO_CALI_LINES_FILE);
load(ABS_PATH_TO_CALI_SETTINGS);
disp('    Done!')

disp(' ')
disp('    Loading GPS records for the routes of interest...')
for idxRoute = indicesNewRoutesToProcess
    curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
    
    [rxLats, rxLons, rxGpsTs, ~] ...
        = loadGpsForRoute(fullfile( ...
        ABS_PATH_TO_MEAS_DATA, curRouteOfInterest));
    
    txLatLons{idxRoute} = TX_LAT_LON;
    rxLatLonTracks{idxRoute} = [rxLats, rxLons];
    rxGpsTimestamps{idxRoute} = rxGpsTs;
end

disp('    Done!')

%% Compute RX Signal Strength

disp(' ')
disp('    Computing the RX signal strength...')

for idxRoute = indicesNewRoutesToProcess
    curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
    
    curUsrpStartTimeLog = fullfile( ...
        ABS_PATH_TO_MEAS_DATA, curRouteOfInterest, ...
        'rx-realm', 'power-delay-profiles', 'timestamp.log');
    curUsrpLog = fullfile(ABS_PATH_TO_MEAS_DATA, curRouteOfInterest, ...
        'rx-realm', 'power-delay-profiles', 'samples.log');
    
    curUsrpLogInfo = dir(curUsrpLog);
    
    if length(curUsrpLogInfo)==1
        % Load the stamp for the start time of the USRP recording.
        rxUsrpStartTimestamps{idxRoute} ...
            = parseUsrpTimestampLog(curUsrpStartTimeLog);
        
        rxSigPowers{idxRoute} = compRxSigPowersFromUsrpSamps( ...
            curUsrpLogInfo, Fs, rxGain);
    else
        % For some routes we have multiple sample log files.
        rxUsrpStartTimestamps{idxRoute} ...
            = parseUsrpTimestampsLog(curUsrpStartTimeLog);
        
        numOfSampLogs = length(rxUsrpStartTimestamps{idxRoute});
        curRxSigPowers = cell(numOfSampLogs, 1);
        for idxLog = 1:numOfSampLogs
            curUsrpLog = fullfile(ABS_PATH_TO_MEAS_DATA, curRouteOfInterest, ...
                'rx-realm', 'power-delay-profiles', ...
                ['samples_', num2str(idxLog), '.log']);
            curUsrpLogInfo = dir(curUsrpLog);
            curRxSigPowers{idxLog} = compRxSigPowersFromUsrpSamps( ...
                curUsrpLogInfo, Fs, rxGain);
        end
        rxSigPowers{idxRoute} = curRxSigPowers;
    end
end

disp('    Done!')

%% Export Results

disp(' ')
disp('    Saving results...')

save(pathToSaveResults, ...
    'routeNames', 'txLatLons', 'rxLatLonTracks', 'rxGpsTimestamps', ...
    'rxSigPowers', 'rxUsrpStartTimestamps');

disp('    Done!')

%% Match RX Power Results with GPS Records

% Deduce timestamps for the RX signal power values.
rxSigPowerDatetimes = cell(numOfRoutes, 1);
% Save the matched RX power results.
matchedGpsLatLonPowers = cell(numOfRoutes, 1);
for idxRoute = 1:numOfRoutes
    if ischar(rxUsrpStartTimestamps{idxRoute})
        % Time stamps for the signal power results.
        curUsrpStartDatetime = datetime(rxUsrpStartTimestamps{idxRoute});
        curNumOfSigPowerVs = length(rxSigPowers{idxRoute});
        
        rxSigPowerDatetimes{idxRoute} ...
            = repmat(curUsrpStartDatetime, curNumOfSigPowerVs, 1);
        for idxSigPower = 1:curNumOfSigPowerVs
            rxSigPowerDatetimes{idxRoute}(idxSigPower) ...
                = rxSigPowerDatetimes{idxRoute}(idxSigPower) ...
                + seconds(idxSigPower-0.5);
        end
        
        curRxSigPowerDatetimes = rxSigPowerDatetimes{idxRoute};
        curRxSigPowers = rxSigPowers{idxRoute};
    else
        % Multiple sample logs.
        curNumOfLogs = length(rxUsrpStartTimestamps{idxRoute});
        curNumsOfSigPowerVs = cellfun(@(c) length(c), ...
            rxSigPowers{idxRoute});
        
        curSigPowerVCnt = 0;
        rxSigPowerDatetimes{idxRoute} = cell(curNumOfLogs,1);
        for idxLog = 1:curNumOfLogs
            curUsrpStartDatetime ...
                = datetime(rxUsrpStartTimestamps{idxRoute}{idxLog});
            rxSigPowerDatetimes{idxRoute}{idxLog} ...
                = repmat(curUsrpStartDatetime, ...
                curNumsOfSigPowerVs(idxLog), 1);
            for idxSigPower = 1:curNumsOfSigPowerVs(idxLog)
                rxSigPowerDatetimes{idxRoute}{idxLog}(idxSigPower) ...
                    = rxSigPowerDatetimes{idxRoute}{idxLog}(idxSigPower) ...
                    + seconds(idxSigPower-0.5);
            end
        end
        
        curRxSigPowerDatetimes = vertcat(rxSigPowerDatetimes{idxRoute}{:});
        curRxSigPowers = vertcat(rxSigPowers{idxRoute}{:});
    end
    
    % Match the results with GPS points.
    curGpsLatLons = rxLatLonTracks{idxRoute};
    curGpsDatetimes = datetime(rxGpsTimestamps{idxRoute});
    
    curNumOfGpsPts = size(curGpsLatLons, 1);
    curIndicesNearestSigPowers = nan(curNumOfGpsPts, 1);
    for idxGpsPt = 1:curNumOfGpsPts
        [minTimeDiff, idxNearestSigPower] = ...
            min(abs(curGpsDatetimes(idxGpsPt) ...
            - curRxSigPowerDatetimes));
        if minTimeDiff<=seconds(MAX_ALLOWED_TIME_DIFF_IN_S)
            curIndicesNearestSigPowers(idxGpsPt) = idxNearestSigPower;
        end
    end
    
    curBoolsMatchedGpsPts = ~isnan(curIndicesNearestSigPowers);
    matchedGpsLatLonPowers{idxRoute} ...
        = [curGpsLatLons(curBoolsMatchedGpsPts,:), ...
        curRxSigPowers(curIndicesNearestSigPowers(curBoolsMatchedGpsPts))];
end

%% Plot 2D Overview

disp(' ')
disp('    Generating map overviews...')

for idxRoute = 1:numOfRoutes
    hFig = figure;
    plot3k([matchedGpsLatLonPowers{idxRoute}(:,2), ...
        matchedGpsLatLonPowers{idxRoute}(:,1), ...
        matchedGpsLatLonPowers{idxRoute}(:,3)], ...
        'Labels', {'', 'Longitude', 'Latitude', '', 'RX Power (dBm)'});
    view(2);
    xticklabels([]); yticklabels([]);
    
    curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
    [~, rName] = fileparts(curRouteOfInterest);
    
    saveas(hFig, fullfile( ...
        ABS_PATH_TO_SAVE_PLOTS, ['rxSigPower_', rName, '.jpg']));
    
    hFig = figure; hold on;
    plot3k([matchedGpsLatLonPowers{idxRoute}(:,2), ...
        matchedGpsLatLonPowers{idxRoute}(:,1), ...
        (matchedGpsLatLonPowers{idxRoute}(:,3) ...
        -min(matchedGpsLatLonPowers{idxRoute}(:,3)))], ...
        'ColorBar', false);
    plot3(TX_LAT_LON(2), TX_LAT_LON(1), 0, 'r^');
    plot_google_map;
    view(2);
    xticklabels([]); yticklabels([]);
    xlabel('Longitude'); ylabel('Latitude');
    
    curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
    [~, rName] = fileparts(curRouteOfInterest);
    
    saveas(hFig, fullfile( ...
        ABS_PATH_TO_SAVE_PLOTS, ['rxSigPower_', rName, '_withMap.jpg']));
    
    % Export the results to .csv files.
    writematrix(matchedGpsLatLonPowers{idxRoute}, ...
        fullfile(ABS_PATH_TO_SAVE_PLOTS, ...
        ['matchedLonLatRxPower_', rName, '.csv']));
end

disp('    Done!')

% EOF