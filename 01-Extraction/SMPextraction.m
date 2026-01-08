function measTable = SMPextraction(recordName, dataset_Name, varargin)
% 
% measTable = SMPextraction(recordName, dataset_Name, varargin)
%  
%   Estrai i samples da un record ECG e ritorna:
% 
% - measTable
%           table con i samples estratti in base alla derivazione e al
%           timestamp
%
% Parametri richiesti:
% - recordName
%           nome del record analizzato
% - dataset_Name
%           nome del dataset di cui fa parte il record analizzato
%
% Parametri opzionali:
% - id
%           id di partenza per iniziare a riportare nelle righe le
%           informazioni estratte
% - creaCSV
%           flag per specificare se creare o meno il file .csv contenente
%           le informazioni estratte
% - toEnd        
%           numero di samples a cui l'estrazione si deve fermare
% - fk_id
%           id per associare una tabella principale di riferimento
%
% Scritto da Alessandro Carotenuto, 2024

%% Check argomenti
ip = inputParser;
ip.addRequired('recordName');
ip.addRequired('dataset_Name');
ip.addParameter('id', 1, @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('creaCSV', false, @(x) islogical(x));
ip.addParameter('toEnd', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Parsing argomenti
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
toEnd = ip.Results.toEnd;
fk_id = ip.Results.fk_id;

% Estrazione del record_Name
record_Name = tailPathRec(recordName, dataset_Name);

% Leggi i dati del segnale dal file ECG utilizzando
% la funzione WFDB PhysioNet version rdsamp
[ sig, ~, tms ] = rdsamp(record_Name, [], toEnd);

% Recupera solo le colonne accettabili secondo la convenzione
[N_samples, leads_name, leads_numb] = LEADextraction(record_Name);

%% Creazione della measTable
% Valuta quanti campioni salvare
if N_samples >= trace(toEnd)
    n_rows = (~isempty(toEnd))*(trace(toEnd)) + (isempty(toEnd))*N_samples;
else
    fprintf(['Il numero di campioni estraibili dal record %s è %d,' ...
        ' inferiore a %d, numero di campioni richiesto\n'], record_Name, N_samples, toEnd);
    n_rows = N_samples;
end

% Inizializza table per accogliere i valori controllando se è richiesta
% una tabella con o senza foreign key
if isempty(fk_id)
    measTable = tableBuilder('meas_no_fk', n_rows);
    measTable.RecordName = repmat(record_Name, n_rows,1);
    measTable.DatasetName = repmat(dataset_Name, n_rows,1);
else
    measTable = tableBuilder('meas', n_rows);
    measTable.FK_ID = repmat(fk_id, n_rows,1);
end

% Carica i dati dell'id e del timestamp nella measTable
measTable.ID = (id:id+n_rows-1)';
measTable.Timestamp = TMSextraction(tms, n_rows);

%% Carica i valori estratti nella measTable per ogni lead
for col = 1:length(leads_numb)
    if (~ismissing(leads_name(col)) && ~isempty(leads_name(col)) && ~strcmp(leads_name(col), ""))
        measTable.(leads_name(col)) = sig(:, col);
    end
end

%% Valuta se creare il file .csv
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", dataset_Name);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    % Crea il nome del file .csv che raccoglierà i dati
    outputFileName = strcat(outputPath,'/samp_', record_Name,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(measTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Messaggio Finale
fprintf('%i) Estrazione Samples da %s completata!\n', fk_id, record_Name);
end