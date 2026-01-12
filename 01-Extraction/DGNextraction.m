function autoDiagTable = DGNextraction(smpTable, recordName, dataset_Name, varargin)
% 
% autoDiagTable = DGNextraction(smpTable, varargin)
%  
%   This function returns some possible ECG abnormalities found in the input traces.
%   The recognition of abnormalities is performed through the artificial neural network (ANN) developed by Ribeiro et al. 2020 (https://doi.org/10.1038/s41467-020-15432-4).
%   Specifically, this script divides the input ECG signal in 10-second
%   chunks and pre-processes them according to the cited paper. Then, it
%   calls the Python routine publicly shared by the ANN developers on each
%   chunk and aggregates the results in one output table. The output is a
%   list of every abnormality (one per line) detected in the entire ECG
%   signal.
% 
% - autoDiagTable
%          table presenting one line for each ECG abnormality found by the
%          selected routine. If none is found, a table with a single
%          "NoAbnormalities" record is returned.
%
% Mandatory inputs:
% - smpTable
%           table containing ECG samples as returned by the SMPextraction
%           function
%
% Optional inputs:
% - id
%           id (primary key) that the first record of the output
%           table should present (to allow for joining the table with the
%           information extracted during previous calls of this function)
% - creaCSV
%           if this flag is true, a .csv containing the information
%           extracted during function execution will be written (useful
%           for debugging)
% - fk_id
%           id (foreign key) from a table whose records should be linked
%           with the ones in output from this function
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

%% Input arguments check
ip = inputParser;
ip.addRequired('smpTable');
ip.addRequired('recordName');
ip.addRequired('dataset_Name');
ip.addParameter('id', 1, @(x) isnumeric(x) && (isscalar(x)||isempty(x)));
ip.addParameter('creaCSV', false, @(x) islogical(x));
ip.addParameter('fk_id', [], @(x) isnumeric(x) && (isscalar(x)||isempty(x)));

% Input arguments parsing
ip.parse('smpTable','recordName','dataset_Name',varargin{:});
id = ip.Results.id;
creaCSV = ip.Results.creaCSV;
fk_id = ip.Results.fk_id;

%% Check if the signal has all 12 standard leads required by the selected diagnosis detector and a certain minimum total duration
% NB: The ECG data in smpTable are already provided with standard
%     lead names, thanks to SMPextraction
expectedLeads = {'Lead_I', 'Lead_II', 'Lead_III', ...
                 'Lead_aVF', 'Lead_aVR', 'Lead_aVL', ...
                 'Lead_V1', 'Lead_V2', 'Lead_V3', 'Lead_V4', 'Lead_V5', 'Lead_V6'};
minDuration = 8; %in seconds

% Extract the timestamps from the ECG samples table and convert them in
% seconds
vt = seconds( duration(smpTable.Timestamp,"InputFormat","hh:mm:ss.SSS") );

% Calculate the ECG duration by checking the length of non-NaNs data
% available for the lead with less NaNs
pAnyEcgChannels = contains(smpTable.Properties.VariableNames,'Lead_');
validEcgSmp = max( sum(~isnan(smpTable{:,pAnyEcgChannels}),1) );
ecgDuration = validEcgSmp*(vt(2)-vt(1));

% Check if all the leads required by the diagnosis detector are available
% and are not entirely made of NaNs
allExpectedAvailable = all( matches(expectedLeads,smpTable.Properties.VariableNames) );
pExpectEcgChannels   = matches(smpTable.Properties.VariableNames,expectedLeads);
allExpectedNoOnlyNaNs= all( any(~isnan(smpTable{:,pExpectEcgChannels}),1) );

if allExpectedAvailable && allExpectedNoOnlyNaNs && ecgDuration >= minDuration
    %% ECG preprocessing as requested by the selected diagnosis detector
    
    % Retain only columns containing the necessary ECG data channels
    smpTable = smpTable(:,pExpectEcgChannels);
    
    % Ensure the ECG channels in smpTable are sorted as expected by the ECG
    % diagnosis detector.
    % Expected: {DI, DII, DIII, AVR, AVL, AVF, V1, V2, V3, V4, V5, V6}
    smpTable = smpTable(:,{'Lead_I', 'Lead_II', 'Lead_III', ...
                           'Lead_aVR', 'Lead_aVL', 'Lead_aVF', ...
                           'Lead_V1', 'Lead_V2', 'Lead_V3', 'Lead_V4', 'Lead_V5', 'Lead_V6'});
    
    % Resample the signal (all channels) at 400Hz, as the ECG traces used for
    % training the selected ANN. If donw-sampling is required, Matlab's "resample" function already applies
    % an appropriate anti-aliasing (low-pass) filter with cut-off frequency
    % below the Nyquist frequency of the new sampling rate (i.e., <200Hz)
    FsNew = 400;
    ecg = smpTable{:,:};
    ecg_resamp = resample(ecg,vt,FsNew);
    N = size(ecg_resamp,1);
    Nch = size(ecg_resamp,2);

    % Create a 3D ECG data matrix by dividing the data in 4096-sample
    % chunks, as expected by the ECG diagnosis detector. Apply zero-padding
    % for too-short segments (as suggested by Ribeiro et al.), but discard
    % the last segment if it is shorter than minDuration.
    NperChunk = 4096;
    Nchunks = floor(N/NperChunk);
    % 1. Create the 3D matrix 
    if Nchunks > 0
        %If the ECG exam is longer than or equal to NperChunk
        ecg_chunked = reshape(ecg_resamp(1:Nchunks*NperChunk,:)',Nch,NperChunk,Nchunks);
        ecg_chunked = permute(ecg_chunked,[2,1,3]);
        %...Correct reshaping verified with
        % figure; tl = tiledlayout('flow');
        % for ch = 1:12
        %     nexttile(tl); plot(ecg_resamp(1:4096,ch)); hold on; plot(ecg_chunked(:,ch,1));
        % end
        %...
    else
        %If the ECG exam is longer than minDuration but shorter than NperChunk
        ecg_chunked = [];
    end
    % 2. Apply zero-padding to the last segment of ECG signal, if it is
    %    sufficiently long; discard it otherwise
    rem = N - Nchunks*NperChunk;
    if rem >= minDuration*FsNew
        lastChunk = [ecg_resamp(N-rem+1:end,:); zeros(NperChunk-rem,Nch)];
        ecg_chunked = cat(3,ecg_chunked,lastChunk);
        Nchunks = Nchunks +1;
    end
    
    %% ECG diagnoses extraction

    % Call the Matlab function that: 1) creates the temporary HDF5 file
    % with the data structure expected by the ECG diagnoses detector
    % (shape: ch, samplesPerChunk, chunks); 2) analyzes the ECG exam
    % chunk-by-chunk; 3) returns the diagnoses detected for each chunk
    ecg_chunked = permute(ecg_chunked,[3,1,2]);
    outS = runEcgAutoDiagPy(ecg_chunked);

    % Analyze the predicted labels returned by the diagnoses detector for
    % each chunk of processed ECG data
    foundDiag = string([]);
    for k = 1:Nchunks
        chunkDiag = strsplit(outS.y_labels(k),'_');
        foundDiag = unique([foundDiag,chunkDiag]);
    end
    if length(foundDiag)>1
        foundDiag(foundDiag=="NoAbnormalities") = [];
    end
    nfoundDiag = length(foundDiag);

else
    % If the loaded ECG signal doesn't have the channels or the minimum
    % duration required by the selected ECG diagnosis detector
    nfoundDiag = 1;
    foundDiag = "ImpossibleToEvaluate";

end

%% Creation of the output table

% Table initialization with/without foreign key
record_Name = tailPathRec(recordName, dataset_Name); %This is needed right below or in the fprintf at the end
if isempty(fk_id)
    autoDiagTable = tableBuilder('autoDiag_no_fk', nfoundDiag);
    autoDiagTable.RecordName = repmat(record_Name,nfoundDiag,1);
    autoDiagTable.DatasetName = repmat(dataset_Name,nfoundDiag,1);
else
    autoDiagTable = tableBuilder('autoDiag', nfoundDiag);
    autoDiagTable.FK_ID = repmat(fk_id,nfoundDiag,1);
end

% Fill in the table with all found diagnoses (one row for each)
autoDiagTable.ID = (id:id+nfoundDiag-1)';
autoDiagTable.AutoECGDiagnosis = foundDiag';

%% Valuta se creare il file .csv
if creaCSV
    % outputPath = strcat("C:/Users/Public/Outputs/", repoName);
    outputPath = strcat(pwd,"/Outputs/", dataset_Name); %PierMOD
    if ~isfolder(outputPath), mkdir(outputPath); end
    outputFileName = strcat(outputPath,'/dgn_',recordName,'.csv');
    % Scrittura della tabella nel file CSV
    writetable(autoDiagTable, outputFileName, 'Delimiter',',','WriteVariableNames',true);
end

%% Messaggio Finale
fprintf('%i) Extraction of automatically detected ECG diagnoses from %s completed!\n', id, record_Name);

end