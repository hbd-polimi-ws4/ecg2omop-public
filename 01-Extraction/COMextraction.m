function [notesTable, comments] = COMextraction(recordName, dataset_Name, varargin)
% 
% [notesTable, comments] = COMextraction(recordName, dataset_Name, varargin)
%  
%   Extracts various information from the .hea file and returns:
% 
% - notesTable
%           table with all the information extracted from a record
% - comments
%           list of all comments extracted from the .hea file of a record
%
% Required inputs:
% - recordName
%           name of the record analyzed
% - dataset_Name
%           name of the dataset the analyzed record belongs to
%
% Optional inputs (Name-Value parameters):
% - id
%           starting id to begin reporting the extracted information in the rows
% - creaCSV
%           flag to specify whether to create the .csv file containing
%           the extracted information
% - date        
%           creation date of the extracted record
% 
% Contributors:
%   Pierluigi Reali, Ph.D., 2024-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

%% Check arguments
ip = inputParser;
ip.addRequired('recordName');
ip.addRequired('dataset_Name');
ip.addParameter('id', 1, @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('creaCSV', false, @(x) islogical(x));
ip.addParameter('date', [], @(x) ischar(x) || isstring(x) || isempty(x));

% Parse arguments
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
recordDate = ip.Results.date;

%% Extract comments from the header file
[ header_info ] = mhrv.wfdb.wfdb_header(recordName);
comments = header_info.comments;

% Variables to save:
% End of the record
if ~isempty(recordDate)
    len = header_info.total_seconds;
    d = datetime(recordDate, 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
    endRecord = string(d + seconds(len));
end
% Patient age
age = '';
% Patient gender
sex = '';
% Diagnosis
diagnosis = '';
% Patient identifier
patient = '';
% Other notes
otherNotes = '';
% Extract record_Name
record_Name = tailPathRec(recordName, dataset_Name);

%% Loop through the lines
for i = 1:numel(comments)
    line = comments{i};

    % Regex for patient age
    ageMatch = regexpi(line, '(?:<)?(?:\<age\>)(?:>)?(?::)?\s*(\d+)', 'tokens');

    % Regex for patient gender
    sexMatch = regexpi(line, '(?:<)?(?:\<sex\>)(?:>)?(?::)?\s*(\S+)', 'tokens');

    % Regex for diagnosis
    diagnosisPattern = '(?:<)?(?:\<diagnoses\>|\<diagnose\>|\<diagnosis report\>|\<diagnosis\>)(?:>)?(?::)?\s*(.*)';
    diagnosisMatch = regexpi(line, diagnosisPattern, 'tokens');

    % Regex for patient identifier
    patientMatch = regexpi(line, '(?:<)?(?:\<patient\>|\<subject_id\>|\<subject id\>|\<subject-id\>|\<id\>|\<subject\>)(?:>)?(?::)?\s*(.+)', 'tokens');
    % If it is not indicated in the .hea file, search in the path (if
    % none of the "fancier" regExp are matched, the record name will be
    % considered as patient name
    if isempty(patientMatch)
        patientMatch = regexpi(recordName, '(?:patient|subject_id|subject id|subject-id|id|subject)\s*([^\\]+)', 'tokens');
    end

    % Regex for other notes
    lastCommentMatch = regexpi(line, '([^#]*)$', 'tokens', 'once');

    % Extract age
    if ~isempty(ageMatch), age = single(str2double(ageMatch{1}{1})); end
    % Extract sex
    if ~isempty(sexMatch), sex = sexMatch{1}{1}; end
    % Extract diagnosis
    if ~isempty(diagnosisMatch), diagnosis = strtrim(diagnosisMatch); end
    % Extract patient number
    if ~isempty(patientMatch), patient = patientMatch{1}{1}; end
    % Extract last comments
    if isempty(ageMatch) && isempty(sexMatch) && isempty(diagnosisMatch) && isempty(patientMatch)
        otherNotes = strcat(otherNotes," ", strtrim(lastCommentMatch{1}));
    end
end

comments = comments';

% Initialize table to hold the extracted values
notesTable = tableBuilder('notes', 1);

%% Load the data into the notesTable columns
if ~isempty(id), notesTable.ID = id; end
notesTable.RecordName = record_Name;
notesTable.DatasetName = dataset_Name;
if ~isempty(recordDate), notesTable.RecordDate = recordDate; end
if ~isempty(endRecord), notesTable.RecordEnd = endRecord; end
if ~isempty(patient), notesTable.Patient = patient; end
if ~isempty(age), notesTable.Age = age; end
if ~isempty(sex), notesTable.Sex = sex; end
if ~isempty(diagnosis), notesTable.Diagnosis = diagnosis; end
if ~isempty(otherNotes), notesTable.OtherNotes = otherNotes; end

%% Decide whether to create the .csv file
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name);
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/comm_',record_Name,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(notesTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Final message
fprintf('%i) Extraction of GeneralComments from %s completed!\n', id, record_Name);
end