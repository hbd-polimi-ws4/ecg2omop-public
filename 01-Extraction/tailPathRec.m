function tailPathRecord = tailPathRec(recordName, dataset_Name)
% Look for the correct path of the record
% splitting the full path using the appropriate delimiter for the current OS
parts = strsplit(recordName, {'/','\'});
% Search the dataset_Name position index
index = find(strcmp(parts, dataset_Name));
if ~isempty(index) && index < numel(parts)
    tailPathRecord = strjoin(parts(index + 1:end), '/');
else
    [~, tailPathRecord, ~] = fileparts(recordName);
end
end