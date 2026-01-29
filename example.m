
close all;
clear;
clc;

%% Definitions

% Everything you may need to change to run this script is in this section.
% If you need to download the data, run the entire script so the support
% functions written at the end will be loaded too.
% If you have already downloaded and prepared the datasets as expected by
% the ECG ETL pipeline, you can first run this section and, then, those
% after the "Download Physionet ECG datasets" one.

% Define datasets folder (if it doesn't exist, it'll be created)
dataPath = 'Datasets3/';

% Define dataset names and related .zip download URLs (they will be
% downloaded only if a folder with the dataset name doesn't exist in
% dataPath).
% Those written here are the datasets that were used for pipeline
% development and testing.
datasets = {'lobachevsky-university-ecg-db-1.0.1','https://www.physionet.org/content/ludb/get-zip/1.0.1/'
            'st-petersburg-incart-arrhythmia-db-1.0.0','https://physionet.org/content/incartdb/get-zip/1.0.0/'
            't-wave-alternans-challenge-db-1.0.0','https://physionet.org/content/twadb/get-zip/1.0.0/'};

% Define the output folder for the CSV tables produced by the Extraction
% phase (if it doesn't exist, it'll be created). This folder will also be
% the entry point of the Transform phase.
outputExtractCSVpath = 'Outputs3/';

%% Adding all paths needed to run the ETL pipeline
setup_ecg2omop();

%% Download Physionet ECG datasets

% Create the folder that will contain all the datasets, if it doesn't exist
% yet
if ~exist(dataPath,'dir'), mkdir(dataPath); end

% Download the datasets that are not already available in dataPath and
% unzip them. Delete the downloaded .zip file at the end
for ds = 1:size(datasets,1)
    dsName = datasets{ds,1};
    dsUrl  = datasets{ds,2};
    dsPath = fullfile(dataPath,dsName);
    dsTempPath = fullfile(dataPath,['temp_',dsName]);
    if ~exist(dsPath,'dir')
        outZipPath = fullfile(dataPath,[dsName,'.zip']);
        fprintf('\nDownloading ZIP file of dataset %s from:\n\t%s\nin path:\n\t%s\nPlease wait...\n',...
                dsName,dsUrl,outZipPath);

        % If the Parallel Computing Toolbox is installed, use my function
        % to download the ZIP file; otherwise, use the standard Matlab one
        if ~isempty(which('batch'))
            downloadFileWithProgress(outZipPath,dsUrl,false);
        else
            websave(outZipPath,dsUrl);
        end
        if ~exist(dsTempPath,'dir'), mkdir(dsTempPath); end
        fprintf('\nUnzipping the downloaded ZIP file in a temporary path:\n\t%s\n',dsTempPath);
        unzip(outZipPath,dsTempPath);

        % Copy the unzipped files to their final destination structuring
        % them as required to avoid the discovered WFDB "file not found"
        % bug (i.e., RECORDS and all annotation files must be in the same
        % folder as the data files)
        allFilePaths = dir([dsTempPath,'/**']);
        % Retain only files from the list
        allFilePaths = allFilePaths([allFilePaths.isdir]==false);
        % Retain only file paths from the original struct returned by dir
        allFilePaths = strcat({allFilePaths.folder}','/',{allFilePaths.name}');
        % Remove all files starting with a "." or contained in a folder
        % starting with a "." from the list (in some Physionet datasets,
        % such as "incart", "." marks older files or, in genral, files to
        % be ignored)
        pat = regexpPattern('(/|\\)\..*');
        p = contains(allFilePaths,pat);
        allFilePaths(p) = [];
        % Copy the remaining files to the final dataset folder
        mkdir(dsPath);
        fprintf('\nCopying all files from temporary path to final dataset location:\n\t%s\n',dsPath);
        for k = 1:length(allFilePaths)
            copyfile(allFilePaths{k},dsPath);
        end

        % Edit the RECORDS file to reflect the new file organization
        RECORDSpath = fullfile(dsPath,'RECORDS');
        fprintf('\nEditing the following RECORDS file to reflect the final dataset organization:\n\t%s\n',RECORDSpath);
        opts = delimitedTextImportOptions('DataLines',1,'Delimiter',',',...
                               'VariableTypes','char','NumVariables',1);
        cRECORDS = readcell(RECORDSpath,opts);
        %Keep only filenames and possible extensions, if RECORDS contains
        %paths instead of mere ECG trace names
        for k= 1:length(cRECORDS)
            [~,fname,ext] = fileparts(cRECORDS{k});
            cRECORDS{k} = [fname,ext];
        end
        %Replace the current RECORDS file with the corrected one
        delete(RECORDSpath); %delete the original RECORDS file
        writecell(cRECORDS,[RECORDSpath,'.txt']); %writecell forces us to use a file extension
        movefile([RECORDSpath,'.txt'],RECORDSpath); %remove file extension from the updated RECORDS file
        fprintf('\nDataset %s download and preparation completed!',dsName);
        fprintf('\n---------------------------------------------\n');
    end
end


%% Execute the Extract phase on all datasets
processedRecAll = tableBuilder('notes',0);
for ds = 1:size(datasets,1)
    dsName = datasets{ds,1};
    dsPath = fullfile(dataPath,dsName);
    [~,processedRec] = MAINextraction('RECORDSpath',dsPath,'outputPath',outputExtractCSVpath,...
                                      'toEndSmp',10);
    processedRecAll = [processedRecAll; processedRec]; %#ok<AGROW>
end


%% Execute the Transform phase on all datasets
outputTransformCSVpath = fullfile(outputExtractCSVpath,'Transformed');
sOMOPtables = MAINtransform('inputCSVPath',outputExtractCSVpath,...
                            'outputPath',outputTransformCSVpath);


%% Execute the Load phase on all datasets
outputTransformCSVpath = fullfile(outputExtractCSVpath,'Transformed');
[sOMOP_recLoaded,sOMOP_recNotLoaded] = MAINload('inputCSVPath',outputTransformCSVpath,...
                                                'dryrun',false);


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUPPORT FUNCTIONS

%--------------------------------------------------------------------------
% DOWNLOAD FILE FUNCTION (showing progress during download)
function downloadFileWithProgress(outFilePath,url,overwrite)

% Add classes we need to the current packages and classes import list (this
% affects only the function where "import" is called)
import matlab.net.http.*

% Define defaults for optional variables
if ~exist('overwrite','var') || isempty(overwrite)
    overwrite = false;
end

% Check if local file already exists
if exist(outFilePath,'file')
    if overwrite
        fprintf('\n\tFile already existing and overwrite requested: deleting original file.');
        delete(outFilePath);
    else
        fprintf('\n\tFile already existing: download cancelled.');
        return;
    end
end

% Send a request to the HTTP/HTTPS web server to get size of the file being
% downloaded
req = RequestMessage('HEAD');
resp = send(req, url);
contentLengthField = resp.getFields('Content-Length');
totFileSize = str2double(contentLengthField.Value);
totFileSizeMB = totFileSize/1024/1024;

% Initiate file download in a separate batch process (requires Parallel
% Computing Toolbox)
job = batch(@websave,0,{outFilePath,url});

% When the separate download job is created, initialize the object to
% trigger job cancellation: if this function terminates for any reason
% (e.g., the user cancels the execution through CTRL+C), we instruct Matlab
% to interrupt the download job
cleanupObj = onCleanup(@()cancelDownloadJob(job,outFilePath));

% Wait for the job to start. When it begins, regularly check file size
% until the file has been downloaded entirely
fprintf('\n\tWaiting for web server response.');
wait(job,'running');
while ~strcmp(job.State,'finished')
    f = dir(outFilePath);
    if ~isempty(f)
        currFileSizeMB = f.bytes/1024/1024;
        fprintf('\n\tDownloaded %.3f out of %.3f',currFileSizeMB,totFileSizeMB);
    end
    pause(5);
end

fprintf('\n\tDownload completed.\n');

end

%--------------------------------------------------------------------------
% CLEANUP FUNCTION (to be executed whenever downloadFileWithProgress terminates)
function cancelDownloadJob(job,outFilePath)

if ~strcmp(job.State,'finished')
    % Cancel the download job
    cancel(job);
    % Delete partially downloaded files (if any)
    if exist(outFilePath,'file')
        delete(outFilePath);
    end
    fprintf('\n\tDownload interrupted.')
end

end

%--------------------------------------------------------------------------