function [notesTable, comments] = COMextraction(recordName, dataset_Name, varargin)
% 
% [notesTable, comments] = COMextraction(recordName, dataset_Name, varargin)
%  
%   Estrae informazioni varie a partire dal file .hea e ritorna:
% 
% - notesTable
%           table con tutte le informazioni estratte da un record
% - comments (Opzionale)
%           elenco di tutti i commenti estratti dal fiel .hea di un record
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
% - date        
%           data di creazione del record estratto
% 
% Scritto da Alessandro Carotenuto, 2024

%% Check argomenti
ip = inputParser;
ip.addRequired('recordName');
ip.addRequired('dataset_Name');
ip.addParameter('id', 1, @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('creaCSV', false, @(x) islogical(x));
ip.addParameter('date', [], @(x) ischar(x) || isstring(x) || isempty(x));

% Parsing argomenti
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
recordDate = ip.Results.date;

%% Estrai i commenti a partire dall'header file
[ header_info ] = mhrv.wfdb.wfdb_header(recordName);
comments = header_info.comments;

% Variabili da salvare
% Fine del record
if ~isempty(recordDate)
    len = header_info.total_seconds;
    d = datetime(recordDate, 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
    endRecord = string(d + seconds(len));
end
% Età del paziente
age = '';
% Genere del paziente
sex = '';
% Diagnosi
diagnosis = '';
% Identificativo paziente
patient = '';
% Altre annotazioni
otherNotes = '';
% Estrazione del record_Name
record_Name = tailPathRec(recordName, dataset_Name);

%% Loop attraverso le linee
for i = 1:numel(comments)
    line = comments{i};

    % Regex per l'età del paziente
    ageMatch = regexpi(line, '(?:<)?(?:\<age\>)(?:>)?(?::)?\s*(\d+)', 'tokens');

    % Regex per il genere del paziente
    sexMatch = regexpi(line, '(?:<)?(?:\<sex\>)(?:>)?(?::)?\s*(\S+)', 'tokens');

    % Regex per la diagnosi
    diagnosisPattern = '(?:<)?(?:\<diagnoses\>|\<diagnose\>|\<diagnosis report\>|\<diagnosis\>)(?:>)?(?::)?\s*(.*)';
    diagnosisMatch = regexpi(line, diagnosisPattern, 'tokens');

    % Regex per l'identificativo del paziente
    patientMatch = regexpi(line, '(?:<)?(?:\<patient\>|\<subject_id\>|\<subject id\>|\<subject-id\>|\<id\>|\<subject\>)(?:>)?(?::)?\s*(.+)', 'tokens');
    % Se non è indicato nel file .hea cercare nel path
    if isempty(patientMatch)
        patientMatch = regexpi(recordName, '(?:patient|subject_id|subject id|subject-id|id|subject)\s*([^\\]+)', 'tokens');
    end

    % Regex per altre annotazioni
    lastCommentMatch = regexpi(line, '([^#]*)$', 'tokens', 'once');

    % Estrai l'età
    if ~isempty(ageMatch), age = single(str2double(ageMatch{1}{1})); end
    % Estrai il sesso
    if ~isempty(sexMatch), sex = sexMatch{1}{1}; end
    % Estrai la diagnosi
    if ~isempty(diagnosisMatch), diagnosis = strtrim(diagnosisMatch); end
    % Estrai il numero del paziente
    if ~isempty(patientMatch), patient = patientMatch{1}{1}; end
    % Estrai gli ultimi commenti
    if isempty(ageMatch) && isempty(sexMatch) && isempty(diagnosisMatch) && isempty(patientMatch)
        otherNotes = strcat(otherNotes," ", strtrim(lastCommentMatch{1}));
    end
end

comments = comments';

% Inizializza table per accogliere i valori
notesTable = tableBuilder('notes', 1);

%% Carica i dati nelle colonne della notesTable
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

%% Valuta se creare il file .csv
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/comm_',record_Name,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(notesTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Messaggio Finale
fprintf('%i) Estrazione GeneralComments da %s completata!\n', id, record_Name);
end