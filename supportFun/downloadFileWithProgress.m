function downloadFileWithProgress(outFilePath,url,overwrite)
% 
% downloadFileWithProgress(outFilePath,url,overwrite)
%  
%   Function to download a file from the internet, given its link,  showing
%   progress (percentage of downloaded size / total size) during download.
% 
% Required inputs:
% - outFilePath
%       Full path (relative or absolute) where the downloaded file should
%       be saved, comprising file name and extension (char array or string)
% - url
%       URL of the file to be downloaded (char array or string)
%
% Optional inputs (positional, can be skipped through []):
% - overwrite
%       Flag (true/false) defining whether already existing files matching
%       outFilePath should be overwritten. If set to false and a file
%       already exists, the function exits without doing anything.
%       Default: false
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano
% 
% 

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
    pause(4);
end

fprintf('\n\tDownload completed.\n');

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUPPORT FUNCTIONS
%--------------------------------------------------------------------------
% CLEANUP FUNCTION: to be executed every time downloadFileWithProgress
% terminates or is interrupted by the user (e.g., CTRL+C) to ensure the
% download is interrupted and partial files are deleted.
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