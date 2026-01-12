function [record_list, comTableFull, smpTableFull, dgnTableFull, rrdTableFull, annTableFull, hrvTableFull] = MAINextraction(varargin)
% 
% [record_list, comTableFull, smpTableFull, dgnTableFull, rrTableFull, annTableFull, hrvTableFull] = MAINextraction(varargin)
%  
%   Main function to manage extraction of data and metadata from datasets
%   to be executed in the dataset's root directory. It returns:
% 
% - record_list
%       list of records available in a dataset, extracted from the RECORDS file
% - comTableFull
%       table with all the information extracted from a record
% - smpTableFull
%       table with signal samples extracted based on lead/derivation and timestamp
% - rrdTableFull
%       table with the time intervals between two R-peaks
% - annTableFull
%       table with the extracted annotations
% - hrvTableFull
%       table with the various HRV-based metrics that can be computed
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
ip.addParameter( 'writeFullCSVs', true, @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'linkTablesWithFKid', true, @(x) islogical(x) && isscalar(x) )

% Input arguments parsing
ip.parse(varargin{:});
RECORDSpath = ip.Results.RECORDSpath;
writeFullCSVs = ip.Results.writeFullCSVs;
linkTablesWithFKid = ip.Results.linkTablesWithFKid;

%% Check the correct options are set for the WSDB toolbox

% % Load WFDB configuration
% [~,config]=wfdbloadlib;
% 
% % Check if the caching mechanism has been disabled to avoid downloading
% % data from PhysioNet. This can result in errors and we assume that all ECG
% % data have already been downloaded.
% if config.CACHE ~= 0
%     configPath = which('wfdbloadlib');
%     error('MAINextraction:chkWFDBconfig','The CACHE variable in %s must be set to 0. Restart Matlab afterwards!',configPath);
% end

%% Process all data files found in the RECORDS file

% Before moving to the RECORDS file path, check if this function's path is
% in the Matlab path (for correctly calling the other functions from other
% directories). If not, add it.
funPath = fileparts(which('MAINextraction'));
if ~contains(path,funPath)
    addpath(funPath);
end

% Move to the RECORDS file path given as input (or remain in the current
% directory otherwise)
origPath = cd(RECORDSpath);

% Look for the RECORDS file in the current directory
dir_info = dir(fullfile(pwd, '**', 'RECORDS'));

% Check whether the RECORDS file is present in the current directory.
if ~isempty(dir_info)
    folderPath = dir_info.folder;
    % Leggi i percorsi dei file da RECORDS
    fid = fopen([folderPath, '/RECORDS'], 'r');
    file_list = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);

    % Estrai il nome del dataset
    pathParts = split(pwd, {'/','\'});
    dataset_Name = pathParts{end};

    % Cell string array contenente i percorsi dei file da processare
    record_list = file_list{1};

    % Recupera l'estensione dall'ANNOTATORS file, se presente
    [extension, ~, ext_bool] = EXTextraction();

    % FOR DEBUG: To extract only a specific number of samples per subject for
    % smpTable, rrdTable, and annTable, replace [] (marker for 'all') with
    % the desired number.
    toEndRR = [];  %number of RR intervals for rrdTable and annTable
    toEndSmp = []; %number of ECG samples to be extracted for smpTable

    %% Initialization of output tables

    % Tables to be preserved in memory (mostly will be returned as empty if
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
        outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
        if ~isfolder(outputPath), mkdir(outputPath); end
    end
    firstCSVwrite = true;

    % Flag for possible failed RECORDS output
    firstNotFoundRecord = true;

    %% Itera attraverso i percorsi dei file e applica le tue funzioni
    for i = 1:length(record_list)
        % Ottieni il percorso completo del file
        record_path = fullfile(folderPath, record_list{i});
        % Riporta il nome del record
        [~, recordName, ~] = fileparts(record_path);
        % Riporta informazioni sul folder che contiene i record
        folder_info = dir([fileparts(record_path),'/*']);

        % Estrazione della data di creazione del record
        val = [recordName,'.hea'];
        fld = {folder_info.name};
        pos = find(strcmp(fld, val), 1);
        dat = [folder_info(pos).date, '.000'];
        dat_str = string(datetime(translateDate(dat), 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));

        % Verifica se il file esiste prima di applicare le funzioni
        regex_pattern = ['^', recordName, '\.'];
        found = any(~cellfun(@isempty, regexp({folder_info.name}, regex_pattern)));

        if found
            %% Esegui le funzioni sul file

            % Se e' la prima volta che viene eseguito questo ciclo, bisogna
            % creare i file CSV delle tabelle in output a cui poi andranno aggiunte le
            % righe nelle successive iterazioni
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
              'toEnd', toEndSmp);
            if writeFullCSVs
                writetable(smpTable, strcat(outputPath,'/samp_',dataset_Name,'.csv'), 'Delimiter',',',...
                           'WriteVariableNames',wvarNames,'WriteMode',wCSVMode,'QuoteStrings','all');
            else
                smpTableFull = [smpTableFull; smpTable]; %#ok<AGROW>
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
                'ext_bool', ext_bool, 'ext', extension, 'toEnd', toEndRR);
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
            disp(['Il file non esiste: ' recordName]);

            % Aggiungiamo il record al TXT con la lista di quelli non processati
            if firstNotFoundRecord, wTXTMode = 'w'; else, wTXTMode = 'a'; end
            fid_failedRecords = fopen( strcat(outputPath,'/failedRecords_',dataset_Name,'.txt'), wTXTMode );
            fprintf(fid_failedRecords,'%s\n',recordName);
            fclose(fid_failedRecords);

            % Cambiamo il flag per effettuare append in eventuali
            % successive iterazioni
            firstNotFoundRecord = false;
        end
    end

else
    disp("Nessun file RECORDS trovato. Impossibile procedere!");
end

% Move back to the original directory (if changed at the beginning) before exiting
cd(origPath);

end