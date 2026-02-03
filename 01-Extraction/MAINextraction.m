function [record_list, comTableFull, smpTableFull, dgnTableFull, rrdTableFull, annTableFull, hrvTableFull] = ...
               MAINextraction(varargin)
% 
% [record_list, comTableFull, smpTableFull, dgnTableFull, rrTableFull, annTableFull, hrvTableFull] = ...
%         MAINextraction(varargin)
%  
%   Main function to manage extraction of data and metadata from datasets
%   to be executed in the dataset's root directory. It returns:
% 
% - record_list
%       list of records available in a dataset, extracted from the RECORDS
%       file. Non-processed records, if any, will be returned in a
%       failedRecords_<datasetName>.txt file in the output folder, if
%       'writeFullCSVs' is set to true (default).
% - comTableFull
%       table with all the information extracted from a record
% - smpTableFull
%       table with signal samples extracted based on lead/derivation and timestamp
% - dgnTableFull
%       table with the diagnoses automatically detected from ECG signals
% - rrdTableFull
%       table with the time intervals between two R-peaks
% - annTableFull
%       table with the extracted annotations
% - hrvTableFull
%       table with the various HRV-based metrics selected in
%       MTRextraction.m
%
% Optional inputs (Name-value parameters):
% - RECORDSpath
%           path where the "RECORDS" file of the Physionet dataset to be
%           processed can be found. Default: pwd
% - writeFullCSVs
%           if this flag is true, one .csv file for each "Full" table
%           documented above will be written record-by-record, once the
%           related ECG data have been processed. All the output tables of
%           this function, except for comTableFull, will be returned empty
%           to save memory. If this flag is set to false, the opposite will
%           happen, namely no .csv will be created, but the output tables
%           will be returned with the expected content. Default: true
% - linkTablesWithFKid
%           if this flag is true, output tables other than comTableFull
%           will be provided with an fk_id column, which presents foreign
%           keys linking each table entry to the primary key of
%           comTableFull. Each entry in comTableFull refers to a single ECG
%           exam in the RECORDS file. If this flag is set to false, foreign
%           keys will not be used and all tables will be provided with
%           explicit "RecordName" and "DatasetName" columns. Proceeding
%           with MAINtransform requires this setting to be true.
%           Default: true
% - toEndSmp
%           defines the maximum number of ECG samples per ECG recording
%           that will be extracted in the smpTableFull table (or relevant CSV
%           file). This option is useful to spare system memory and
%           processing time. If there is no interest in exporting the
%           pre-processed signals in a tabular form (e.g., to insert them
%           into a database), it is advised to use a small value (>0) for this
%           input argument (e.g., 10) to speed-up the Transform step of the
%           ETL pipeline.
%           Default: [], which stands for 'all available samples'.
% - toEndRR
%           defines the maximum number of RR intervals per ECG recording
%           that will be extracted in the rrdTableFull table (or relevant CSV
%           file). As opposed to the previous one, this option doesn't have
%           a real impact on system storage or resource usage and can be
%           left to its default value.
%           Default: [], which stands for 'all available RR intervals'.
% - toEndAnn
%           defines the maximum number of beat annotations per ECG recording
%           that will be extracted in the annTableFull table (or relevant
%           CSV file). Like toEndRR, this option doesn't have a real impact
%           on system storage or resource usage and it is advised to leave
%           it to its default value. Besides, MAINtransform will use the
%           information in the annTableFull output table (or relevant CSV
%           file) to derive useful patient diagnoses. Thus, extracting all
%           the available annotations for each patient is fundamental for
%           correct execution of the Transform step of the ETL.
%           Default: [], which stands for 'all available beat annotations'.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2024-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

%% Check input arguments

% All the inputs to this function are optional
ip = inputParser;
ip.addParameter( 'RECORDSpath', pwd, @(x) (isstring(x) && isscalar(x)) || (ischar(x) && isvector(x)) );
ip.addParameter( 'outputPath', '', @(x) (isstring(x) && isscalar(x)) || (ischar(x) && isvector(x)) )
ip.addParameter( 'writeFullCSVs', true, @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'linkTablesWithFKid', true, @(x) islogical(x) && isscalar(x) )
ip.addParameter( 'toEndSmp', [], @(x) isnumeric(x) && isscalar(x) )
ip.addParameter( 'toEndRR', [], @(x) isnumeric(x) && isscalar(x) )
ip.addParameter( 'toEndAnn', [], @(x) isnumeric(x) && isscalar(x) )

% Input arguments parsing
ip.parse(varargin{:});
RECORDSpath = ip.Results.RECORDSpath;
outputPath = ip.Results.outputPath;
writeFullCSVs = ip.Results.writeFullCSVs;
linkTablesWithFKid = ip.Results.linkTablesWithFKid;
toEndSmp = ip.Results.toEndSmp;
toEndRR = ip.Results.toEndRR;
toEndAnn = ip.Results.toEndAnn;


%% Initialize the MHRV toolbox
% The following initializes the MHRV toolbox, if it hasn't been done
% yet during the current Matlab session.
mhrv_init;


%% Process all data files found in the RECORDS file

% Before moving to the RECORDS file path, check if this function's path is
% in the Matlab path (for correctly calling the other functions from other
% directories). If not, add it.
funPath = fileparts(which('MAINextraction'));
if ~contains(path,funPath)
    addpath(funPath);
end

% Move to the RECORDS file path given as input (remain in the current
% directory if none was given)
origPath = cd(RECORDSpath);

% Look for the RECORDS file in the current directory
dir_info = dir(fullfile(pwd, '**', 'RECORDS'));

% Check whether the RECORDS file is present in the current directory.
if ~isempty(dir_info)
    folderPath = dir_info.folder;
    % Read file paths from RECORDS
    fid = fopen([folderPath, '/RECORDS'], 'r');
    file_list = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);

    % Extract dataset name
    pathParts = split(pwd, {'/','\'});
    dataset_Name = pathParts{end};

    % Cell array containing file paths of the records to be processed
    record_list = file_list{1};

    % Retrieve the extension from the "ANNOTATORS" file, if available. If
    % there is, ECG annotations are available too for the current dataset
    [extension, ~, ext_bool] = EXTextraction();


    %% Initialization of output tables

    % Tables to be preserved in memory (most will be returned as empty if
    % writeFullCSVs is requested)
    comTableFull = tableBuilder('notes', 0);
    if linkTablesWithFKid
        smpTableFull = tableBuilder('meas', 0);
        dgnTableFull = tableBuilder('autoDiag',0);
        rrdTableFull = tableBuilder('rrIntDur', 0);
        annTableFull = tableBuilder('annotations', 0);
        hrvTableFull = tableBuilder('hrvMetrics', 0);
    else
        smpTableFull = tableBuilder('meas_no_fk', 0);
        dgnTableFull = tableBuilder('autoDiag_no_fk',0);
        rrdTableFull = tableBuilder('rrIntDur_no_fk', 0);
        annTableFull = tableBuilder('annotations_no_fk', 0);
        hrvTableFull = tableBuilder('hrvMetrics_no_fk', 0);
    end
    % Full table primary keys
    idcom = 1;
    idsmp = 1;
    iddgn = 1;
    idrrd = 1;
    idann = 1;
    idhrv = 1;

    % Path and flag for output CSV tables
    if writeFullCSVs
        if isempty(outputPath)
            % If outputPath is not provided as an input argument, the
            % output CSVs are produced in a subfolder inside the processed
            % dataset's folder
            outputPath = fullfile(pwd,'Outputs');
        else
            % If outputPath is provided as an input argument, it might
            % either be a relative (in relation to the path from where the
            % function was called) or an absolute path. In the first case,
            % it must be fixed to work correctly in this function, as we
            % had to "cd" to the dataset's directory to use WFDB functions.
            if ~isAbsolutePath(outputPath)
                outputPath = fullfile(origPath,outputPath);
            end
        end
        if ~isfolder(outputPath), mkdir(outputPath); end
    end
    firstCSVwrite = true;

    % Initialize flag to mark the presence of failed RECORDS output
    firstNotFoundRecord = true;

    %% Iterate through record file paths and Extract info and features
    for i = 1:length(record_list)
        % Get full record path
        record_path = fullfile(folderPath, record_list{i});
        % Get record name (excluding possible extensions)
        [~, recordName, ~] = fileparts(record_path);
        % Get list of files available in the record path
        folder_info = dir([fileparts(record_path),'/*']);

        % Extract record creation date from the file attributes. The header
        % files of the tested PhysioNet datasets do not contain this
        % information, though it might be available sometimes.
        % COMextraction could be modified to read the date and time of the
        % acquisition from the header file and, when it is available,
        % replace the value of dat_str.
        val = [recordName,'.hea'];
        fld = {folder_info.name};
        pos = find(strcmp(fld, val), 1);
        dat = [folder_info(pos).date, '.000'];
        dat_str = string(datetime(translateDate(dat), 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));

        % Check if the record indicated in the RECORDS file actually exists
        % before applying the Extraction functions
        regex_pattern = ['^', recordName, '\.'];
        found = any(~cellfun(@isempty, regexp({folder_info.name}, regex_pattern)));

        if found
            %% Feature and information Extraction from the record

            % If this is the first time this loop is executed, the output
            % table CSV files must be created, to which the rows will then
            % be added in subsequent iterations
            if firstCSVwrite
                wvarNames = true; wCSVMode = 'overwrite';
            else
                wvarNames = false; wCSVMode = 'append';
            end

            % Extract notes and write/append them to CSV
            [comTable, ~]  = COMextraction(record_path, dataset_Name, 'id', idcom, 'date', dat_str);
            comTableFull = [comTableFull; comTable]; %#ok<AGROW>
            if writeFullCSVs
                writetable(comTable, strcat(outputPath,'/comm_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            end
            if linkTablesWithFKid, fk_id = idcom; else, fk_id = []; end %Get the FK for the other tables

            % Extract samples and write/append them to CSV
            smpTable = SMPextraction(record_path, dataset_Name, 'id', idsmp, 'fk_id', fk_id, ...
              'toEnd', []);
            if isempty(toEndSmp)
                rf = height(smpTable);
            else
                rf = toEndSmp;
            end
            if writeFullCSVs
                writetable(smpTable(1:rf,:), strcat(outputPath,'/samp_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            else
                smpTableFull = [smpTableFull; smpTable(1:rf,:)]; %#ok<AGROW>
            end

            % Extract automated ECG diagnoses and write/append them to CSV
            dgnTable = DGNextraction(smpTable, record_path, dataset_Name, 'id', iddgn, 'fk_id', fk_id);
            if writeFullCSVs
                writetable(dgnTable, strcat(outputPath,'/dgn_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            else
                dgnTableFull = [dgnTableFull; dgnTable]; %#ok<AGROW>
            end

            % Extract RR-intervals and write/append them to CSV
            rrdTable = RRextraction(record_path, dataset_Name, 'id', idrrd, 'fk_id', fk_id, ...
              'ext_bool', ext_bool, 'ext', extension, 'toEnd', toEndRR);
            if writeFullCSVs
                writetable(rrdTable, strcat(outputPath,'/rrid_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            else
                rrdTableFull = [rrdTableFull; rrdTable]; %#ok<AGROW>
            end

            % Extract annotations and write/append them to CSV
            annTable = ANNextraction(record_path, dataset_Name, 'id', idann, 'fk_id', fk_id, ...
                'ext_bool', ext_bool, 'ext', extension, 'toEnd', toEndAnn);
            if writeFullCSVs
                writetable(annTable, strcat(outputPath,'/anno_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            else
                annTableFull = [annTableFull; annTable]; %#ok<AGROW>
            end
            
            % Extract HRV metrics and write/append them to CSV
            [hrvTable, hrvTblVarToSave] = MTRextraction(record_path, dataset_Name, 'id', idhrv, 'fk_id', fk_id, 'ext', extension);
            if writeFullCSVs
                writetable(hrvTable(:,hrvTblVarToSave), strcat(outputPath,'/mhrv_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            else
                hrvTableFull = [hrvTableFull; hrvTable]; %#ok<AGROW>
            end

            fprintf('%i) Estrazione Dati da %s completata!\n\n', i, recordName);

            % Update the full table primary keys for the next record
            idcom = idcom+1;
            if ~isempty(smpTable), idsmp = smpTable.ID(end) + 1; end
            if ~isempty(dgnTable), iddgn = dgnTable.ID(end) + 1; end
            if ~isempty(rrdTable), idrrd = rrdTable.ID(end) + 1; end
            if ~isempty(annTable), idann = annTable.ID(end) + 1; end
            idhrv = idhrv+1;

            % Change the flag to switch the CSV write mode to 'append' for
            % the following iterations
            firstCSVwrite = false;

        else
            disp(['Record file does not exist: ' recordName]);

            if writeFullCSVs
                % We add the record to the TXT containing the list of
                % unprocessed ones
                if firstNotFoundRecord, wTXTMode = 'w'; else, wTXTMode = 'a'; end
                fid_failedRecords = fopen( strcat(outputPath,'/failedRecords_',dataset_Name,'.txt'), wTXTMode );
                fprintf(fid_failedRecords,'%s\n',recordName);
                fclose(fid_failedRecords);
    
                % We change the flag to perform append in any subsequent
                % iterations
                firstNotFoundRecord = false;
            end
        end
    end

else
    disp("No RECORDS file detected in the processed path. Nothing to do.");
end

% Move back to the original directory (if changed at the beginning) before exiting
cd(origPath);

end