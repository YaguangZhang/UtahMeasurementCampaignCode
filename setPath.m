% SETPATH Add lib folders into Matlab path.
%
% Yaguang Zhang, Purdue, 08/18/2021

cd(fileparts(mfilename('fullpath')));
addpath(fullfile(pwd));
addpath(genpath(fullfile(pwd, 'lib')));

% The absolute path to the folder holding the data for the Utah data.
% Please make sure it is correct for the machine which will run this
% script.
%  - On (quite powerful) Windows Artsy:
absPathWinArtsy = 'F:\';
unknownComputerErrorMsg = ...
    ['Compute not recognized... \n', ...
    '    Please update setPath.m for your machine. '];
unknownComputerErrorId = 'setPath:computerNotKnown';
switch getenv('computername')
    case 'ARTSY'
        % ZYG's lab desktop.
        ABS_PATH_TO_SHARED_FOLDER = absPathWinArtsy;
    otherwise
        error(unknownComputerErrorId, unknownComputerErrorMsg);
end
%EOF