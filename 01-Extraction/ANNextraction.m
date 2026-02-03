function annotationTable = ANNextraction(recordName, dataset_Name, varargin)
% 
% annotationTable = ANNextraction(recordName, dataset_Name, varargin)
%  
% Extracts annotations from an ECG record and returns:
% 
% - annotationTable
%           table containing the extracted annotations
%
% Required inputs:
% - recordName
%           name of the analyzed record
% - dataset_Name
%           name of the dataset the analyzed record belongs to
%
% Optional inputs (Name-Value parameters):
% - id
%           starting id (primary key) from which to begin reporting the
%           extracted information in the output table rows. Default: 1
% - creaCSV
%           flag specifying whether or not to create the .csv file
%           containing the extracted information (only useful for debug)
%           Default: false
% - toEnd        
%           maximum number of samples after which the extraction of
%           annotations must stop
%           Default: [], which stands for 'all available beat annotations'.
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

%% Input checks
ip = inputParser;
ip.addRequired('recordName');
ip.addRequired('dataset_Name');
ip.addParameter('id', 1, @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('creaCSV', false, @(x) islogical(x));
ip.addParameter('ext_bool', false, @(x) islogical(x));
ip.addParameter('ext', [], @(x) ischar(x) || isstring(x) || isempty(x));
ip.addParameter('toEnd', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Input parsing
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
ext_bool = ip.Results.ext_bool;
ext = ip.Results.ext;
toEnd = ip.Results.toEnd;
fk_id = ip.Results.fk_id;

% record_Name extraction
record_Name = tailPathRec(recordName, dataset_Name);

% Get the sampling frequency for the timestamps
header_info = mhrv.wfdb.wfdb_header(recordName);
Fs = header_info.Fs;

%% Data extraction
% If the ANNOTATORS file is not present, use ecgpuwave or other functions
if ~ext_bool
    ext = 'zqrs';
    ecgpuwave(record_Name, ext);
    % Check the result of ecgpuwave
    s = dir([record_Name,'.',ext]);
    if isempty(s)
        % If the recordName passed to ecgpuwave is too long, the extraction
        % does not happen correctly and ecgpuwave doesn't save any file. So we
        % try again after visiting the record directory
        [path, rec, ~] = fileparts(recordName);
        org = cd(path);
        ecgpuwave(rec, ext);
        cd(org);
    elseif (~isempty(s) && s.bytes == 0)
        % If ecgpuwave, instead, returned a file but this is 0 bytes in
        % size, use the other functions and merge the annotations
        gqrs(record_Name, 'N', 1, 1, 1.00, 'gqrs');
        sqrs(record_Name);
        wqrs(record_Name);
        mrgann(record_Name, 'gqrs','wqrs','yqrs');
        mrgann(record_Name, 'yqrs','qrs','zqrs');
    end
end

[ann,anntype,subtype,chan,num,aux] = rdann(record_Name,ext);

% Cleans up any temporary files
if ~ext_bool
    % Delete files with extension .*qrs
    delete([fileparts(recordName), '/*qrs']);
    delete([fileparts(recordName), '/fort*']);
end

% Check that all values are positive otherwise they will be deleted
% together with the other corresponding values
if any(ann < 0)
    ann(ann < 0) = [];
    anntype(ann < 0) = [];
    subtype(ann < 0) = [];
    chan(ann < 0) = [];
    num(ann < 0) = [];
    aux((ann < 0),:) = [];
end

%% Creation of the annotationTable
% Evaluate how many samples to save
l = length(ann);
if l >= trace(toEnd)
    n_rows = (~isempty(toEnd))*(trace(toEnd)) + (isempty(toEnd))*l;
else
    fprintf(['The number of samples that can be extracted from record %s is %d,' ...
        ' less than the %d samples requested\n'], record_Name, l, toEnd);
    n_rows = l;
end

% Initialize table to hold the annotation values, checking whether a table
% is required with or without foreign key
if isempty(fk_id)
    annotationTable = tableBuilder('annotations_no_fk', n_rows);
    annotationTable.RecordName = repmat(record_Name, n_rows,1);
    annotationTable.DatasetName = repmat(dataset_Name, n_rows,1);
else
    annotationTable = tableBuilder('annotations', n_rows);
    annotationTable.FK_ID = repmat(fk_id, n_rows,1);
end

%% Load the data into the columns of the annotationTable
annotationTable.ID = (id:id+n_rows-1)';
annotationTable.Timestamp = TMSextraction((ann(1:end)-1)/Fs, n_rows);
annotationTable.Sample = (ann(1:n_rows)-1);
if strcmp(anntype, 'NO ANNOTATION RETRIEVED')
    annotationTable.AnnType = anntype(1:end);
    annotationTable.AnnExplanation = 'NO EXPLANATION';
else
    annotationTable.AnnType = anntype(1:n_rows);
    annotationTable.AnnExplanation = EXPLextraction(anntype, n_rows);
end
annotationTable.SubType = subtype(1:n_rows);
annotationTable.Chan = chan(1:n_rows);
annotationTable.Num = num(1:n_rows);
for i = 1:n_rows
    if isempty(aux{i,1})
        annotationTable.Comments(i) = '';
    else
        annotationTable.Comments(i) = aux{i,1};
    end
end

%% Create the .csv file if requested
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name);
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/anno_',recordName,'.csv');
    % Write the table to the CSV file
    writetable(annotationTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Final message
fprintf('%i) Estrazione Annotations da %s completata!\n', fk_id, record_Name);
end