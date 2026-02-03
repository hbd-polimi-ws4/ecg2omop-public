function measTable = SMPextraction(recordName, dataset_Name, varargin)
% 
% measTable = SMPextraction(recordName, dataset_Name, varargin)
%  
%   Extracts samples from an ECG record and returns:
% 
% - measTable
%           table with the extracted samples based on lead and
%           timestamp
%
% Required inputs:
% - recordName
%           name of the record being analyzed
% - dataset_Name
%           name of the dataset the analyzed record belongs to
%
% Optional inputs:
% - id
%           starting id used to begin reporting in the rows the
%           extracted information (primary key). Default: 1
% - creaCSV
%           flag specifying whether or not to create the .csv file containing
%           the extracted information (only useful for debug).
%           Default: false
% - toEnd        
%           maximum number of samples after which the extraction must stop.
%           Default: [], which stands for 'all available samples'
% - fk_id
%           id used to associate a main reference table (foreign key).
%           Default: []
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2024-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano
% 
% 

%% Check inputs
ip = inputParser;
ip.addRequired('recordName');
ip.addRequired('dataset_Name');
ip.addParameter('id', 1, @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('creaCSV', false, @(x) islogical(x));
ip.addParameter('toEnd', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Parsing inputs
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
toEnd = ip.Results.toEnd;
fk_id = ip.Results.fk_id;

% Extract record_Name
record_Name = tailPathRec(recordName, dataset_Name);

% Read signal data from the ECG file using the WFDB PhysioNet rdsamp
% function
[ sig, ~, tms ] = rdsamp(record_Name, [], toEnd);

% Keep only data columns recognized as the 12 standard leads
[N_samples, leads_name, leads_numb] = LEADextraction(record_Name);

%% Create the measTable
% Evaluate how many samples to save
if N_samples >= trace(toEnd)
    n_rows = (~isempty(toEnd))*(trace(toEnd)) + (isempty(toEnd))*N_samples;
else
    fprintf(['The number of samples that can be extracted from record %s is %d,' ...
        ' lower than %d, the number of samples requested\n'], record_Name, N_samples, toEnd);
    n_rows = N_samples;
end

% Initialize table to hold the values, checking whether a table with or without
% a foreign key is required
if isempty(fk_id)
    measTable = tableBuilder('meas_no_fk', n_rows);
    measTable.RecordName = repmat(record_Name, n_rows,1);
    measTable.DatasetName = repmat(dataset_Name, n_rows,1);
else
    measTable = tableBuilder('meas', n_rows);
    measTable.FK_ID = repmat(fk_id, n_rows,1);
end

% Load id and timestamp data into measTable
measTable.ID = (id:id+n_rows-1)';
measTable.Timestamp = TMSextraction(tms, n_rows);

%% Load the extracted values into measTable for each lead
for col = 1:length(leads_numb)
    if (~ismissing(leads_name(col)) && ~isempty(leads_name(col)) && ~strcmp(leads_name(col), ""))
        measTable.(leads_name(col)) = sig(:, col);
    end
end

%% Create a .csv file if requested
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", dataset_Name);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name);
    if ~isfolder(outputPath), mkdir(outputPath); end
    % Create the name of the .csv file that will collect the data
    outputFileName = strcat(outputPath,'/samp_', record_Name,'.csv');
    % Write the table to the CSV file
    writetable(measTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Final message
fprintf('%i) Samples extraction from %s completed!\n', fk_id, record_Name);
end