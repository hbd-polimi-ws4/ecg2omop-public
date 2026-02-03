function outFlag = isAbsolutePath(inputPath)
% 
% outFlag = isAbsolutePath(inputPath)
%  
%   Simple function that checks whether the input path is an absolute path
%   or not. It only works with Linux, Mac, and Windows systems correctly
%   detected by Matlab.
% 
% - outFlag
%       If true, the path given as an input is absolute; otherwise, it is
%       relative.
%
% Required inputs:
% - inputPath
%       Single path to be checked (char array or string).
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano
% 
% 

if ispc
    % If a Windows path contains ':', it surely is an absolute path, as
    % in "C:\Users\...
    outFlag = contains(inputPath,':');

elseif isunix
    % If a Unix (i.e., Mac or Linux) path begins with '/', it surely is an
    % absolute path
    outFlag = startsWith(inputPath,'/');
else
    error('isRelativePath:unrecognizedOS','This function only works with Linux, Mac, or Windows systems.');
end


end