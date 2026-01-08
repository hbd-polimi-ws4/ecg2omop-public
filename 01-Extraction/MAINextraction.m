function [record_list, comTableFull, smpTableFull, rrdTableFull, annTableFull, hrvTableFull] = MAINextraction()
% 
% [record_list, comTableFull, smpTableFull, rrTableFull, annTableFull, hrvTableFull] = MAINextraction()
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
%   Pierluigi Reali, Ph.D., 2025
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

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

%% Check whether the RECORDS file is present in the current directory.
dir_info = dir(fullfile(pwd, '**', 'RECORDS'));
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
    toEndSmp = 5;%number of ECG samples to be extracted for smpTable
                  %(we need all the samples in smpTable only if we want to
                  % load also every single sample in a relational DB, which
                  % we don't need as our infrastructure is built on a data lake)

    %% Inizializza tabelle vuote
    comTableFull = tableBuilder('notes', length(record_list));
    smpTableFull = tableBuilder('meas', 0);
    rrdTableFull = tableBuilder('rrIntDur', 0);
    annTableFull = tableBuilder('annotations', 0);
    hrvTableFull = tableBuilder('hrvMetrics', length(record_list));

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
            % Estrai notes
            [comTable, ~]  = COMextraction(record_path, dataset_Name, 'id', i, 'date', dat_str);
            comTableFull(i,:) = comTable(:,:);

            % Estrai samples
            smpTable = SMPextraction(record_path, dataset_Name, 'id', 1+height(smpTableFull), 'fk_id', i, ...
              'toEnd', toEndSmp);
            smpTableFull((1+height(smpTableFull)):(height(smpTable)+height(smpTableFull)),:) = smpTable(:,:);

            % Estrai RR-intervals
            rrdTable = RRextraction(record_path, dataset_Name, 'id', 1+height(rrdTableFull), 'fk_id', i, ...
              'ext_bool', ext_bool, 'ext', extension, 'toEnd', toEndRR);
            rrdTableFull((1+height(rrdTableFull)):(height(rrdTable)+height(rrdTableFull)),:) = rrdTable(:,:);

            % Estrai annotations
            annTable = ANNextraction(record_path, dataset_Name, 'id', 1+height(annTableFull), 'fk_id', i, ...
                'ext_bool', ext_bool, 'ext', extension, 'toEnd', toEndRR);
            annTableFull((1+height(annTableFull)):(height(annTable)+height(annTableFull)),:) = annTable(:,:);
            
            % Estrai metrics
            [hrvTable, hrvTblVarToSave] = MTRextraction(record_path, dataset_Name, 'id', i, 'fk_id', i, 'ext', extension);
            hrvTableFull(i,:) = hrvTable(:,:);

            fprintf('%i) Estrazione Dati da %s completata!\n\n', i, recordName);
        else
            disp(['Il file non esiste: ' recordName]);
        end
    end

    %% Scrittura della tabella nel file CSV
    % outputPath = strcat("C:/Users/Public/Outputs/", dataset_Name);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    writetable(comTableFull, strcat(outputPath,'/comm_',dataset_Name,'.csv'), 'Delimiter',',','WriteVariableNames',true);
    writetable(smpTableFull, strcat(outputPath,'/samp_',dataset_Name,'.csv'), 'Delimiter',',','WriteVariableNames',true);
    writetable(rrdTableFull, strcat(outputPath,'/rrid_',dataset_Name,'.csv'), 'Delimiter',',','WriteVariableNames',true);
    writetable(annTableFull, strcat(outputPath,'/anno_',dataset_Name,'.csv'), 'Delimiter',',','WriteVariableNames',true);
    writetable(hrvTableFull(:,hrvTblVarToSave), strcat(outputPath,'/mhrv_',dataset_Name,'.csv'), 'Delimiter',',','WriteVariableNames',true);
else
    disp("Nessun file RECORDS trovato. Impossibile procedere!");
end
end