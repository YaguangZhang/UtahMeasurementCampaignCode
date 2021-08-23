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
    fullfile('fully-autonomous', 'urban-campus-II'), ...
    fullfile('fully-autonomous', 'urban-vegetation')};
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

%% Read In the Log Files

disp(' ------------------ ')
disp('  plotRxPowerOnMap ')
disp(' ------------------ ')

pathToSaveResults = fullfile( ...
    ABS_PATH_TO_SAVE_PLOTS, 'rxPowerWithGps.mat');
if exist(pathToSaveResults, 'file')
    disp(' ')
    disp('    Loading history results...')
    load(pathToSaveResults);
    disp('    Done!')
else
    numOfRoutes = length(ROUTES_OF_INTEREST);
    [routeNames, txLatLons, rxLatLonTracks, rxGpsTimestamps, ...
        rxSigPowers, rxUsrpStartTimestamps] ...
        = deal(cell(numOfRoutes, 1));
    
    disp(' ')
    disp('    Loading calibration results...')
    load(ABS_PATH_TO_CALI_LINES_FILE);
    load(ABS_PATH_TO_CALI_SETTINGS);
    disp('    Done!')
    
    disp(' ')
    disp('    Loading GPS records for the routes of interest...')
    for idxRoute = 1:numOfRoutes
        curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
        [rType, rName] = fileparts(curRouteOfInterest);
        routeNames{idxRoute} = [rType, ':', rName];
        
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
    
    for idxRoute = 1:numOfRoutes
        curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
        curUsrpLog = fullfile(ABS_PATH_TO_MEAS_DATA, curRouteOfInterest, ...
            'rx-realm', 'power-delay-profiles', 'samples.log');
        
        curUsrpLogInfo = dir(curUsrpLog);
        curUsrpLogSizeInByte = curUsrpLogInfo.bytes;
        
        % Load the stamp for the start time of the USRP recording.
        curUsrpStartTimeLog = fullfile(ABS_PATH_TO_MEAS_DATA, curRouteOfInterest, ...
            'rx-realm', 'power-delay-profiles', 'timestamp.log');
        rxUsrpStartTimestamps{idxRoute} = parseUsrpTimestampLog(curUsrpStartTimeLog);
        
        % In a GnuRadio .out file, we have:
        %     Complex - 32 bit floating point for both I and Q readings (8
        %     bytes in total per sample).
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
            
            FlagCutHead = idxSigP==1;
            curSigPs(idxSigP) = computeRxSigPower(sigSeg, rxGain, FlagCutHead);
        end
        
        rxSigPowers{idxRoute} = curSigPs;
    end
    
    disp('    Done!')
end

%% Export Results

disp(' ')
disp('    Saving results...')

save(pathToSaveResults, ...
    'routeNames', 'txLatLons', 'rxLatLonTracks', 'rxGpsTimestamps', ...
    'rxSigPowers', 'rxUsrpStartTimestamps');

disp('    Done!')

%% Plot 2D Overview

disp(' ')
disp('    Generating map overviews...')

disp('    Done!')

% EOF