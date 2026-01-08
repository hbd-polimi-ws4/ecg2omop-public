function Fs = FSextraction(recordName,dataset_Name)

tailPathRecord = tailPathRec(recordName, dataset_Name); %PierMOD

% Estrae i valori relativi agli intervalli RR
[ ~, Fs, ~ ] = rdsamp(tailPathRecord, [], 1);
end