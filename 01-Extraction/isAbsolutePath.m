function outFlag = isAbsolutePath(inputPath)

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