function [ext, description, ext_bool] = EXTextraction()
% 
% [ext, description, ext_bool] = EXTextraction()
%  
%   Support function that returns information about the annotation files,
%   retrieved by analyzing the ANNOTATORS file, if available for the
%   processed dataset.
%
% Contributors:
%   Alessandro Carotenuto, 2024
%   Pierluigi Reali, Ph.D., 2025
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano
%

% Initialize boolean search variable
ext_bool = false;
% Initialize a variable for extensions
ext = '';
% Initialize a variable for descriptions
description = '';

% Check if the ANNOTATORS file is present in the directory
dir_info = dir(fullfile(pwd, '**', 'ANNOTATORS'));
if ~isempty(dir_info)
    % Set the flag to true
    ext_bool = true;
    % Retrieve information about the folder containing the file
    filePath = dir_info.folder;
    % Open the input file for reading
    fid = fopen([filePath, '/ANNOTATORS'], 'r');
    % Read the file line by line
    comments = fgetl(fid);
    % Extract the type of extension used
    comm = strsplit(strtrim(comments),'\t');
    ext = comm{1};
    % Extract the description of the extension used
    description = comm{2};
else
    disp('No valid extension for annotations found.')
end