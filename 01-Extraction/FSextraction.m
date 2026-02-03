function Fs = FSextraction(recordName,dataset_Name)
% 
% Fs = FSextraction(recordName,dataset_Name)
%  
%   Support function. Given record and dataset names, this function returns
%   the sampling rate of the processed ECG record, leveraging WFDB's function
%   rdsamp (without actually reading any data sample but only the FS
%   information).
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

tailPathRecord = tailPathRec(recordName, dataset_Name);

% Extract RR interval values
[ ~, Fs, ~ ] = rdsamp(tailPathRecord, [], 1);
end