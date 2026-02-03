function tailPathRecord = tailPathRec(recordName, dataset_Name)
% 
% tailPathRecord = tailPathRec(recordName, dataset_Name)
%  
%   Support function. Given the recordName (the full path to the processed
%   ECG record, without any file extension) and dataset_Name (the name of
%   the folder containing all dataset data), this function returns the part
%   after the last "/" (tailPathRecord), i.e., the name of the processed
%   ECG record separated from the rest of the path.
%
% Contributors:
%   Alessandro Carotenuto, 2024
%   Pierluigi Reali, Ph.D., 2025
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano


% Look for the correct path of the record
% splitting the full path using the appropriate delimiter for the current OS
parts = strsplit(recordName, {'/','\'});

% Search the dataset_Name position index
index = find(strcmp(parts, dataset_Name));
if ~isempty(index) && index < numel(parts)
    tailPathRecord = strjoin(parts(index + 1:end), '/');
else
    [~, tailPathRecord, ~] = fileparts(recordName);
end
end