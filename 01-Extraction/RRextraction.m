function rrIntDurTable = RRextraction(recordName, dataset_Name, varargin)
% 
% rrIntDurTable = RRextraction(recordName, dataset_Name, varargin))
%  
%   Extracts RR interval durations from an ECG record and returns:
% 
% - rrIntDurTable
%           table with the time intervals between two R peaks
%
% Required parameters:
% - recordName
%           name of the record being analyzed
% - dataset_Name
%           name of the dataset the analyzed record belongs to
%
% Optional parameters (Name-value parameters):
% - id
%           starting id used to begin reporting in the rows the
%           extracted information (primary key). Default: 1
% - creaCSV
%           flag specifying whether or not to create the .csv file containing
%           the extracted information (only useful for debug).
%           Default: false
% - ext_bool
%           flag specifying whether there is an extension associated with a
%           file from which to extract annotations
% - ext
%           flag specifying the possible extension associated with a
%           file from which to extract annotations
% - toEnd        
%           maximum number of found RR intervals that the function should
%           return
% - fk_id
%           id to associate a main reference table (foreign key)
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
ip.addParameter('ext_bool', false, @(x) islogical(x));
ip.addParameter('ext', [], @(x) ischar(x) || isstring(x) || isempty(x));
ip.addParameter('toEnd', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Parse inputs
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
ext_bool = ip.Results.ext_bool;
ext = ip.Results.ext;
toEnd = ip.Results.toEnd;
fk_id = ip.Results.fk_id;

% Extract record_Name
record_Name = tailPathRec(recordName, dataset_Name);

%% If the record is provided with the ANNOTATORS file, choose how to extract the data

% This flag will be set to "false" if the extraction of R peaks from
% the annotation file works
needRpeakDetect = true;

% If an annotation file is available, try to read the R peaks from there
if ext_bool
    % Extract the data through wfdb-physionet-toolbox.
    % Output vectors (RR, ini_tms) returned in seconds, to match the
    % output produced by mhrv (useful to have same outputs as in the
    % section with if needRpeakDetect==true, for optimizing the code),
    % which is the same expected by TMSextraction
    try
        [RR, ini_tms] = mhrv.wfdb.ecgrr(recordName,'ann_ext',ext);
        needRpeakDetect = false;
    catch ME
        warning('RRextraction:ecgrr',['mhrv.wfdb.ecgrr function exited with an error (possibly invalid annotation file):\n %s\n',...
                ' -> Detecting R peaks from raw signals!'],ME.message);
    end
end

% If an annotation file is unavailable or is invalid, detect R peaks
% from the ECG
if needRpeakDetect
    % Extract RR intervals from raw data through mhrv-physiozoo-toolbox
    [RR, ini_tms] = mhrv.wfdb.ecgrr(recordName);
end
fin_tms = ini_tms + RR;

%...
% Pier: Check the position of the found peaks (just for DEBUG)
% VERIFIED: After modifying the function mhrv.wfdb.wfdb_header
%           (called by mhrv.wfdb.ecgrr), the code works and identifies the
%           correct peaks both by extracting them from annotation files,
%           when present, and by deriving them directly from the signal.
%header_info_debug = mhrv.wfdb.wfdb_header(recordName);
%ecg_channel_debug = mhrv.wfdb.get_signal_channel(recordName, 'header_info', header_info_debug);
%[qrs_dg, tm_dg, sig_dg] = mhrv.wfdb.rqrs(recordName, 'header_info', header_info_debug,...
%                                         'ecg_channel', ecg_channel_debug, ...
%                                         'from', 1, 'to', []);
%figure; plot(tm_dg,sig_dg); hold on; xline(fin_tms,'--r');
%...

% Check that all values are positive otherwise they will be deleted along
% with the other corresponding values
posRem = unique([find(ini_tms < 0); find(fin_tms < 0); find(RR < 0)]);
if ~isempty(posRem)
    ini_tms(posRem) = [];
    RR(posRem) = [];
    fin_tms(posRem) = [];
end


%% Create the rrIntDurTable
% Evaluate how many RRI values to save
l = length(ini_tms);
if l >= trace(toEnd)
    n_rows = (~isempty(toEnd))*(trace(toEnd)) + (isempty(toEnd))*l;
else
    fprintf(['The number of samples that can be extracted from record %s is %d,' ...
        ' lower than %d, the number of samples requested\n'], record_Name, l, toEnd);
    n_rows = l;
end

% Initialize table to hold the values to be stored in the output table,
% checking whether a table with or without a foreign key is required
if isempty(fk_id)
    rrIntDurTable = tableBuilder('rrIntDur_no_fk', n_rows);
    rrIntDurTable.RecordName = repmat(record_Name, n_rows,1);
    rrIntDurTable.DatasetName = repmat(dataset_Name, n_rows,1);
else
    rrIntDurTable = tableBuilder('rrIntDur', n_rows);
    rrIntDurTable.FK_ID = repmat(fk_id, n_rows,1);
end

%% Load data into the columns of rrIntDurTable
% Fill the (currently empty) table only if RR intervals to save were found.
if n_rows > 0
    rrIntDurTable.ID = (id:id+n_rows-1)';
    rrIntDurTable.StartTimestamp = TMSextraction(ini_tms(1:n_rows), n_rows);
    rrIntDurTable.RRIntervalDuration = RR(1:n_rows);
    rrIntDurTable.EndTimestamp = TMSextraction(fin_tms(1:n_rows), n_rows);
end

%% Create the .csv file if requested
if creaCSV
    % outputPath = strcat("C:/Users/UTENTE/Drive/Documents/MATLAB/ECGdataset/Outputs/", dataset_Name);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name);
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/rrid_',recordName,'.csv');
    % Write the table to the CSV file
    writetable(rrIntDurTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Final message
fprintf('%i) RR-Intervals extraction from %s completed!\n', fk_id, record_Name);
end