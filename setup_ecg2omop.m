function setup_ecg2omop()

% This function adds all paths needed to run the ETL pipeline. To avoid
% masking possible homonymous functions, paths are added only to the
% current MATLAB session (i.e., they are not permanent); thus,
% "setup_ecg2omop()" must be executed every time we need to use the ETL
% pipeline.

% Define ecg2omop toolbox folders to be added to the MATLAB path
relativeToolboxPaths = {'01-Extraction','02-Transform','03-Load','supportFun'};

% Obtain full paths on this system
baseToolboxPath = fileparts(mfilename('fullpath'));
fullToolboxPaths = strcat(baseToolboxPath,'/',relativeToolboxPaths);

% Add these toolbox paths to MATLAB path, if they are not there yet
currMatlabPath = path;
pAdd = cellfun(@(s) ~contains(currMatlabPath,s),fullToolboxPaths);
if any(pAdd)
    cellfun(@(s) addpath(s), fullToolboxPaths(pAdd));
end