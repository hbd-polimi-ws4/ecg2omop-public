function annotationTable = ANNextraction(recordName, dataset_Name, varargin)
% 
% annotationTable = ANNextraction(recordName, dataset_Name, varargin)
%  
%   Estrae le annotazioni da un record ECG e ritorna:
% 
% - annotationTable
%           table con le annotazioni estratte 
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
ip.addParameter('ext_bool', false, @(x) islogical(x));
ip.addParameter('ext', [], @(x) ischar(x) || isstring(x) || isempty(x));
ip.addParameter('toEnd', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Parsing argomenti
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
ext_bool = ip.Results.ext_bool;
ext = ip.Results.ext;
toEnd = ip.Results.toEnd;
fk_id = ip.Results.fk_id;

% Estrazione del record_Name
record_Name = tailPathRec(recordName, dataset_Name);

% Trova la sampling frequency Fs per il timestamp
header_info = mhrv.wfdb.wfdb_header(recordName);
Fs = header_info.Fs;

%% Estrazione dei dati
% Se non è presente il file ANNOTATORS usa ecgpuwave o altre funzioni
if ~ext_bool
    ext = 'zqrs';
    ecgpuwave(record_Name, ext);
    % Controlla il risultato di ecgpuwave
    s = dir([record_Name,'.',ext]);
    % Se il recordName passato ad ecgpuwave è troppo lungo l'estrazione non
    % avviene correttamente, quindi è preferibile visitare la directory del
    % record ed eseguire direttamente lì la funzione
    if height(s) == 0
        org = pwd;
        [path, rec, ~] = fileparts(recordName);
        cd(path);
        ecgpuwave(rec, ext);
        cd(org);
        % Se ecgpuwave non funziona usa le altre funzioni
        % e unisci le annotazioni
    elseif (height(s) ~= 0 && s.bytes == 0)
        gqrs(record_Name, 'N', 1, 1, 1.00, 'gqrs');
        sqrs(record_Name);
        wqrs(record_Name);
        mrgann(record_Name, 'gqrs','wqrs','yqrs');
        mrgann(record_Name, 'yqrs','qrs','zqrs');
    end
end

[ann,anntype,subtype,chan,num,aux] = rdann(record_Name,ext);

% Esegue la pulizia degli eventuali file temporanei
if ~ext_bool
    % Elimina i file con estensione .*qrs
    delete([fileparts(recordName), '/*qrs']);
    delete([fileparts(recordName), '/fort*']);
end

% Controllo che i valori siano tutti positivi
% in caso contrario verranno eliminati assieme
% agli altri valori corrispondenti
if any(ann < 0)
    ann(ann < 0) = [];
    anntype(ann < 0) = [];
    subtype(ann < 0) = [];
    chan(ann < 0) = [];
    num(ann < 0) = [];
    aux((ann < 0),:) = [];
end

%% Creazione della annotationTable
% Valuta quanti campioni salvare
l = length(ann);
if l >= trace(toEnd)
    n_rows = (~isempty(toEnd))*(trace(toEnd)) + (isempty(toEnd))*l;
else
    fprintf(['Il numero di campioni estraibili dal record %s è %d,' ...
        ' inferiore a %d, numero di campioni richiesto\n'], record_Name, l, toEnd);
    n_rows = l;
end

% Inizializza table per accogliere i valori controllando se è richiesta
% una tabella con o senza foreign key
if isempty(fk_id)
    annotationTable = tableBuilder('annotations_no_fk', n_rows);
    annotationTable.RecordName = repmat(record_Name, n_rows,1);
    annotationTable.DatasetName = repmat(dataset_Name, n_rows,1);
else
    annotationTable = tableBuilder('annotations', n_rows);
    annotationTable.FK_ID = repmat(fk_id, n_rows,1);
end

%% Carica i dati nelle colonne della annotationTable
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

%% Valuta se creare il file .csv
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/anno_',recordName,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(annotationTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Messaggio Finale
fprintf('%i) Estrazione Annotations da %s completata!\n', fk_id, record_Name);
end