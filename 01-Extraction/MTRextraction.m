function [hrvMetricsTable,varNamesSel] = MTRextraction(recordName, dataset_Name, varargin)
% 
% hrvMetricsTable = MTRextraction(recordName, dataset_Name, varargin)
%  
%   Estrae le metriche HRV da un record ECG e ritorna:
% 
% - hrvMetricsTable
%          table con le varie metriche basate sull'HRV calcolabili
% - varNamesSel
%          variabili della tabella da mantenere al salvataggio
%          delle tabelle nel main
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
% - ext
%           flag per specificare l'eventuale estensione associata ad un
%           file da cui estrarre le annotazioni
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
ip.addParameter('ext', '', @(x) ischar(x));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Parsing argomenti
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
ext = ip.Results.ext;
fk_id = ip.Results.fk_id;

% Estrazione del record_Name
record_Name = tailPathRec(recordName, dataset_Name);

%% HRV indices extraction
% Given that it's difficult to define universal thresholds for ectopic beat
% detection in patients, we deactivate all available filters through appropriate
% inputs of the mhrv.mhrv.filtrr function (see its help for details).
% As for the method for spectral estimate, we select the simplest one, which is
% also one of the most known in clinical practice: FFT.
mhrv.defaults.mhrv_set_default('filtrr.range.enable',false,'filtrr.moving_average.enable',false,'filtrr.quotient.enable',false,...
                               'hrv_freq.methods',{'fft'});
try
    hrv_metrics = mhrv.mhrv(record_Name, 'ann_ext', ext);
catch ME
    warning('MTRextraction:hrvCalc',['mhrv.mhrv function exited with an error (possibly invalid annotation file):\n %s\n',...
            ' -> Computing HRV indices with RR intervals detected from raw signals!'],ME.message);
    hrv_metrics = mhrv.mhrv(record_Name);
end

%% Creazione della hrvMetricsTable
% Inizializza table per accogliere i valori controllando se è richiesta
% una tabella con o senza foreign key
if isempty(fk_id)
    hrvMetricsTable = tableBuilder('hrvMetrics_no_fk', 1);
    hrvMetricsTable.RecordName = record_Name;
    hrvMetricsTable.DatasetName = dataset_Name;
else
    hrvMetricsTable = tableBuilder('hrvMetrics', 1);
    hrvMetricsTable.FK_ID = fk_id;
end 

%% Carica i dati nelle colonne della hrvMetricsTable
hrvMetricsTable.ID = id;
for col = 1:width(hrv_metrics)
    hrvMetricsTable(:,col+1) = hrv_metrics(:, col);
end

% Retain only table columns with metrics deemed of major clinical
% significance from the literature:
% - time-domain: RR-interval average, standard deviation, and RMSSD;
% - frequency-domain: very-low (VLF), low (LF), and high-frequency (HF)
%                     powers in absolute and normalized units; LF/HF;
% - non-linear HRV indices: SD1 and SD2 from Poincaré plots; short and
%                           long-term scaling exponents of the DFA; sample
%                           entropy.
mtrNames = {'AVNN','SDNN','RMSSD',...
            'VLF_NORM_FFT','VLF_POWER_FFT','HF_NORM_FFT','HF_POWER_FFT',...
            'LF_NORM_FFT','LF_POWER_FFT','LF_TO_HF_FFT',...
            'SD1','SD2','alpha1','alpha2','SampEn'};

% Retain all the possibly added info to the table
infoNames = {'RecordName','DatasetName','FK_ID','ID'};

% Select the columns to retain to be provided as an output
varNamesRet = [infoNames,mtrNames];
varNamesCurr = hrvMetricsTable.Properties.VariableNames;
varNamesSel = varNamesCurr( matches(varNamesCurr,varNamesRet) );
% hrvMetricsTable = hrvMetricsTable(:,varNamesSel);

%% Replace retained non-robust HRV metrics with NaNs, based on ECG duration
% This choice is based on rules defined from current literature on short-term and
% ultra-short-term HRV.

% Get ECG trace total duration (in seconds)
header_info = mhrv.wfdb.wfdb_header(recordName);
ecgDuration = header_info.total_seconds;

%   - Time-domain metrics (AVNN is considered always valid)
if ecgDuration<30
    hrvMetricsTable{:,{'SDNN'}} = NaN;
end
if ecgDuration<60
    hrvMetricsTable{:,{'RMSSD'}} = NaN;
end

%   - Frequency-domain metrics
if ecgDuration<120
    hrvMetricsTable{:,{'HF_NORM_FFT','HF_POWER_FFT','LF_NORM_FFT',...
                       'LF_POWER_FFT','LF_TO_HF_FFT'}} = NaN;
end
if ecgDuration<300
    hrvMetricsTable{:,{'VLF_NORM_FFT','VLF_POWER_FFT'}} = NaN;
end

%   - Non-linear metrics
if ecgDuration<60
    hrvMetricsTable{:,{'SD1','SD2'}} = NaN;
end
if ecgDuration<180
    hrvMetricsTable{:,{'SampEn','alpha1','alpha2'}} = NaN;
end


%% Valuta se creare il file .csv
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/mhrv_',recordName,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(hrvMetricsTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Messaggio Finale
fprintf('%i) Estrazione HRVmetrics da %s completata!\n', id, record_Name);
end