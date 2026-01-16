
% Run this script to add all paths needed to run the ETL pipeline. The
% paths are added only to the current MATLAB session (i.e., they are not
% permanent).

% Define ecg2omop toolbox folders to be added to the MATLAB path
relativeToolboxPaths = {'01-Extraction','02-Transform','03-Load'};

% Obtain full paths on this system
baseToolboxPath = fileparts(mfilename('fullpath'));
fullToolboxPaths = strcat(baseToolboxPath,'/',relativeToolboxPaths);

% Add these toolbox paths to MATLAB path, if they are not there yet
currMatlabPath = path;
pAdd = cellfun(@(s) ~contains(currMatlabPath,s),fullToolboxPaths);
if any(pAdd)
    cellfun(@(s) addpath(s), fullToolboxPaths(pAdd));
end