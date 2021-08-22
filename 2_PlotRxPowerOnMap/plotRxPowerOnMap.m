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

numOfRoutes = length(ROUTES_OF_INTEREST);
[routeNames, txLatLons, rxLatLonTracks, rxSigPowers] ...
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
    
    [rxLats, rxLons] ...
        = loadGpsForRoute(fullfile( ...
        ABS_PATH_TO_MEAS_DATA, curRouteOfInterest));
    
    txLatLons{idxRoute} = TX_LAT_LON;
    rxLatLonTracks{idxRoute} = [rxLats, rxLons];
end

disp('    Done!')

%% Compute RX Signal Strength

disp(' ')
disp('    Computing the RX signal strength...')

for idxRoute = 1:numOfRoutes
    curRouteOfInterest = ROUTES_OF_INTEREST{idxRoute};
    curUsrpLog = fullfile(ABS_PATH_TO_MEAS_DATA, curRouteOfInterest, ...
        'rx-realm', 'power-delay-profiles', 'samples.log');
    curSignal = read_complex_binary(curUsrpLog);
    curNumOfSamps = length(curSignal);
    
    numOfSigPs = floor(curNumOfSamps/Fs);
    if numOfSigPs*Fs<curNumOfSamps
        numOfSigPs = numOfSigPs+1;
    end
    
    curSigPs = nan(numOfSigPs, 1);
    for idxSigP = 1:numOfSigPs
        sigSeg = curSignal( ...
            (Fs*(idxSigP-1)+1):min(numOfSigPs*Fs, curNumOfSamps));
        
        FlagCutHead = idxSigP==1;
        curSigPs(idxSigP) = computeRxSigPower(sigSeg, rxGain, FlagCutHead);
    end
    
    rxSigPowers{idxRoute} = curSigPs;
end

disp('    Done!')

%% Plot 2D Overview

disp(' ')
disp('    Generating map overviews...')

disp('    Done!')

% EOF