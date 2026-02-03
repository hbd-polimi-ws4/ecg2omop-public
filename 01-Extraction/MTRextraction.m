function [hrvMetricsTable,varNamesSel] = MTRextraction(recordName, dataset_Name, varargin)
% 
% [hrvMetricsTable,varNamesSel] = MTRextraction(recordName, dataset_Name, varargin)
%  
%   Extracts HRV metrics from an ECG record and returns:
% 
% - hrvMetricsTable
%          table with the various computable HRV-based metrics
% - varNamesSel
%          table variables of hrvMetricsTable (i.e., HRV indices) to keep
%          when saving the tables in MAINextraction
%
% Required inputs:
% - recordName
%           name of the record being analyzed
% - dataset_Name
%           name of the dataset the analyzed record belongs to
%
% Optional inputs (Name-Value parameters):
% - id
%           starting id (primary key) used to begin reporting the
%           extracted information in the output table rows. Default: 1
% - creaCSV
%           flag specifying whether or not to create the .csv file containing
%           the extracted information (only useful for debug).
%           Default: false
% - ext
%           char array or string specifying the possible extension
%           associated with a file from which to extract annotations.
%           Default: '' -> No annotation file available for the processed
%                          record
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
ip.addParameter('ext', '', @(x) ischar(x));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Parse inputs
ip.parse('recordName', 'dataset_Name', varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
ext = ip.Results.ext;
fk_id = ip.Results.fk_id;

% Extract record_Name
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

%% Create the hrvMetricsTable
% Initialize table to hold the values, checking whether a table with or without
% a foreign key is required
if isempty(fk_id)
    hrvMetricsTable = tableBuilder('hrvMetrics_no_fk', 1);
    hrvMetricsTable.RecordName = record_Name;
    hrvMetricsTable.DatasetName = dataset_Name;
else
    hrvMetricsTable = tableBuilder('hrvMetrics', 1);
    hrvMetricsTable.FK_ID = fk_id;
end 

%% Load data into the columns of hrvMetricsTable
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


%% Create .csv file if requested
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name);
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/mhrv_',recordName,'.csv');
    % Write the table to the CSV file
    writetable(hrvMetricsTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Final message
fprintf('%i) HRVmetrics extraction from %s completed!\n', id, record_Name);
end