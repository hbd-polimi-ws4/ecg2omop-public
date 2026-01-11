function rrIntDurTable = RRextraction(recordName, dataset_Name, varargin)
% 
% rrIntDurTable = RRextraction(recordName, dataset_Name, varargin))
%  
%   Estrae la durata degli intervalli RR da un record ECG e ritorna:
% 
% - rrIntDurTable
%           table con gli intervalli di tempo tra due picchi R
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
% - ext_bool
%           flag per specificare se esiste un'estensione associata ad un
%           file da cui estrarre le annotazioni
% - ext
%           flag per specificare l'eventuale estensione associata ad un
%           file da cui estrarre le annotazioni
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

%% Se il record è provvisto del file ANNOTATORS sceglie come estrarre i dati

% This flag will be set to "false" if the extraction of R peaks from
% the annotation file works
needRpeakDetect = true;

% If an annotation file is available, try to read the R peaks from there
if ext_bool
    % Estrai i dati tramite wfdb-physionet-toolbox
    % PierMOD: L'originale presenta outputs con ordine scambiato rispetto a
    %          funzione in package WFDB. Inoltre, il terzo output non
    %          esiste nella funzione "ann2rr" originale (probabilmente,
    %          Alessandro aveva modificato la funzione al suo interno per
    %          aggiungerlo). Risolvo calcolandolo all'esterno della
    %          funzione. Tale output ("fin_tms") altro non e' che il
    %          vettore contenente gli indici dei campioni di tutti i picchi
    %          R individuati (primo e ultimo inclusi). Lo utilizza
    %          semplicemente per poi estrarne i timestamps e salvarli da
    %          qualche parte (non credo serva ad altro).
    %---Originale Alessandro Carotenuto
    % [ini_tms, RR, fin_tms] = ann2rr(record_Name,ext);
    %---Rivista (in samples)
    % [RR, ini_tms] = ann2rr(record_Name,ext);
    % fin_tms = [ini_tms; ini_tms(end)+RR(end)];
    %---Rivista (in secondi, per adattarci a output prodotto da mhrv e atteso da Alessandro in TMSextraction)
    % try
    %     [RR, ini_tms] = ann2rr(record_Name,ext);
    %     fin_tms = ini_tms + RR;
    % 
    %     % Conversion from samples to seconds
    %     Fs = FSextraction(recordName,dataset_Name);
    %     RR = RR/Fs;
    %     ini_tms = ini_tms/Fs;
    %     fin_tms = fin_tms/Fs;
    %     needRpeakDetect = false;
    % catch ME
    %     warning('RRextraction:ann2rr',['ann2rr function exited with the error (possibly invalid annotation file):\n %s\n',...
    %             'Detecting R peaks through the mhrv toolbox.'],ME.message);
    % end
    %---Rivista (in secondi, per adattarci a output prodotto da mhrv e atteso da Alessandro in TMSextraction, e sostituendo funzione ann2rr con equivalente di mhrv)
    try
        [RR, ini_tms] = mhrv.wfdb.ecgrr(recordName,'ann_ext',ext);
        needRpeakDetect = false;
    catch ME
        warning('RRextraction:ecgrr',['mhrv.wfdb.ecgrr function exited with an error (possibly invalid annotation file):\n %s\n',...
                ' -> Detecting R peaks from raw signals!'],ME.message);
    end
    %---
end

% If an annotation file is unavailable or is invalid, detect R peaks
% from the ECG
if needRpeakDetect
    % PierMOD: L'originale presentava errori in creazione vettori ini_tms,
    % fin_tms e RR. Il codice revisionato restituisce outputs del tutto
    % coerenti con quelli restituiti da sezione con ann2rr appena sopra.
    %---Original
    % % Estrai i dati tramite mhrv-physiozoo-toolbox
	% [RR, ini_tms] = mhrv.wfdb.ecgrr(recordName);
    % % Aggiungere un sample
    % fin_tms = [ini_tms(1);ini_tms(1:end)+RR(1:end)];
    % RR = [ini_tms(1);RR];
    % ini_tms = [0;ini_tms];
    %---Revised
    % Estrai i dati tramite mhrv-physiozoo-toolbox
    [RR, ini_tms] = mhrv.wfdb.ecgrr(recordName);
    %---
end
fin_tms = ini_tms + RR;

%...
% PierMOD: Controllo posizione dei picchi trovati (just for DEBUG)
% VERIFICATO: Dopo aver modificato la funzione mhrv.wfdb.wfdb_header
%             (chiamata da mhrv.wfdb.ecgrr), il codice funziona e
%             identifica i picchi corretti
%			  sia estraendoli dai file con le annotazioni, quando
%			  presenti, che ricavandoli direttamente dal segnale
%             (vedi "else" precedente). Unico dubbio e' che, nel
%			  secondo caso, l'unita' di misura degli RR e' in
%             secondi mentre nel primo in campioni... non andrebbe
%			  uniformata??
%header_info_debug = mhrv.wfdb.wfdb_header(recordName);
%ecg_channel_debug = mhrv.wfdb.get_signal_channel(recordName, 'header_info', header_info_debug);
%[qrs_dg, tm_dg, sig_dg] = mhrv.wfdb.rqrs(recordName, 'header_info', header_info_debug,...
%                                         'ecg_channel', ecg_channel_debug, ...
%                                         'from', 1, 'to', []);
%figure; plot(tm_dg,sig_dg); hold on; xline(fin_tms,'--r');
%...

% Controllo che i valori siano tutti positivi
% in caso contrario verranno eliminati assieme
% agli altri valori corrispondenti
% PierMOD: Questa valutazione veniva fatta male da Alessandro
%---Original
% if ismember(1, (ini_tms < 0))
%     fin_tms(fin_tms < 0) = [];
%     RR(RR < 0) = [];
%     ini_tms(ini_tms < 0) = [];
% end
%---Revised
posRem = unique([find(ini_tms < 0); find(fin_tms < 0); find(RR < 0)]);
if ~isempty(posRem)
    ini_tms(posRem) = [];
    RR(posRem) = [];
    fin_tms(posRem) = [];
end
%---

%% Creazione della rrIntDurTable
% Valuta quanti campioni salvare
l = length(ini_tms);
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
    rrIntDurTable = tableBuilder('rrIntDur_no_fk', n_rows);
    rrIntDurTable.RecordName = repmat(record_Name, n_rows,1);
    rrIntDurTable.DatasetName = repmat(dataset_Name, n_rows,1);
else
    rrIntDurTable = tableBuilder('rrIntDur', n_rows);
    rrIntDurTable.FK_ID = repmat(fk_id, n_rows,1);
end

%% Carica i dati nelle colonne della rrIntDurTable
% Riempio la tabella (per il momento vuota) solo se sono stati trovati
% intervalli RR da salvare.
if n_rows > 0
    rrIntDurTable.ID = (id:id+n_rows-1)';
    rrIntDurTable.StartTimestamp = TMSextraction(ini_tms(1:n_rows), n_rows);
    rrIntDurTable.RRIntervalDuration = RR(1:n_rows);
    rrIntDurTable.EndTimestamp = TMSextraction(fin_tms(1:n_rows), n_rows);
end

%% Valuta se creare il file .csv
if creaCSV
    % outputPath = strcat("C:/Users/UTENTE/Drive/Documents/MATLAB/ECGdataset/Outputs/", dataset_Name);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/rrid_',recordName,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(rrIntDurTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Messaggio Finale
fprintf('%i) Estrazione RR-Intervals da %s completata!\n', fk_id, record_Name);
end