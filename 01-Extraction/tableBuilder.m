function tableBuilt = tableBuilder(type, rows)
% 
% tableBuilt = tableBuilder(type, rows)
%  
%   Support function to initialize the tables in which the information
%   extracted from the data during MAINextraction will be inserted. It
%   returns:
% 
% - tableBuilt
%       table of the requested type, with the expected number of columns,
%       variable name, and data types, and number of rows requested as an
%       input.
%
% Required inputs:
% - type
%           array of char or string. Type of table to be returned (see the
%           main "switch" below). By default, a table of the requested type
%           with a foreign key column (FK_ID) will be returned. By adding
%           the suffix "_no_fk" to this string, a table with no FK_ID
%           column, but with the additional columns 'RecordName' and
%           'DatasetName' will be returned instead.
% - rows
%           number of rows the tables should be initialized with. Every row
%           will contain <missing> information of the expected data type.
%           rows=0 initializes an empty table with the expected columns and
%           data types.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2024-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano


% Separate the table type from a possible "no foreign key" (_no_fk) request
[type,fkStr] = strtok(type,'_');
% Determine if the FK is not needed (i.e., when a "_no_fk" table or a
% 'notes' table are requested)
noFKreq = strcmp(fkStr,'_no_fk') | strcmp(type,'notes');

switch type
    % ECG exam and patient information table
    case 'notes'
        tableBuilt = table('Size', [rows 8], ...
            'VariableTypes', {'int64','string','string', 'string','singleNaN','string','string','string'}, ...
            'VariableNames', {'ID', 'RecordDate', 'RecordEnd', 'Patient', 'Age', 'Sex', 'Diagnosis', 'OtherNotes'});
    
    % Tables with or without FK
    case 'meas'
        tableBuilt = table('Size', [rows 14], ...
            'VariableTypes', {'int64', 'string','doubleNaN','doubleNaN','doubleNaN','doubleNaN', ...
            'doubleNaN','doubleNaN','doubleNaN','doubleNaN','doubleNaN','doubleNaN','doubleNaN','doubleNaN'}, ...
            'VariableNames', {'ID', 'Timestamp', 'Lead_I', 'Lead_II', 'Lead_III', ...
            'Lead_aVF', 'Lead_aVR', 'Lead_aVL', 'Lead_V1', 'Lead_V2', 'Lead_V3', 'Lead_V4', 'Lead_V5', 'Lead_V6'});
    case 'autoDiag'
        tableBuilt = table('Size', [rows 2], ...
            'VariableTypes', {'int64', 'string'},...
            'VariableNames', {'ID', 'AutoECGDiagnosis'});
    case 'rrIntDur'
        tableBuilt = table('Size', [rows 4], ...
            'VariableTypes', {'int64', 'string','doubleNaN','string'}, ...
            'VariableNames', {'ID', 'StartTimestamp', 'RRIntervalDuration', 'EndTimestamp'});
    case 'annotations'
        tableBuilt = table('Size', [rows 9], ...
            'VariableTypes', {'int64', 'string', 'doubleNaN', 'string', 'string', 'doubleNaN','doubleNaN', ...
            'doubleNaN', 'string'}, ...
            'VariableNames', {'ID', 'Timestamp', 'Sample', 'AnnType', 'AnnExplanation', 'SubType', 'Chan', 'Num', 'Comments'});
    case 'hrvMetrics'
        tableBuilt = table('Size', [rows 28], ...
            'VariableTypes', {'int64', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', ...
            'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', ...
            'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', ...
            'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', 'doubleNaN', ...
            'doubleNaN', 'doubleNaN'}, ...
            'VariableNames', {'ID', 'RR', 'NN', 'AVNN', 'SDNN', 'RMSSD', 'pNN50', 'SEM', ...
            'BETA_FFT', 'HF_NORM_FFT', 'HF_PEAK_FFT', 'HF_POWER_FFT', 'LF_NORM_FFT', 'LF_PEAK_FFT', ...
            'LF_POWER_FFT', 'LF_TO_HF_FFT', 'TOTAL_POWER_FFT', 'VLF_NORM_FFT', 'VLF_POWER_FFT',  ...
            'SD1', 'SD2', 'alpha1', 'alpha2', 'SampEn', 'PIP', 'IALS', 'PSS', 'PAS'});
    otherwise
        error('tableBuilder:unkTableType','Unrecognized table type requested.')
end

% Check the foreign key request
if noFKreq
    %"Notes" table or other tables without FK (insert 'RecordName' and 'DatasetName' columns after the primary key)
    tAdd = table('Size', [rows 2], 'VariableTypes', {'string','string'}, 'VariableNames', {'RecordName','DatasetName'});
    tableBuilt = [tableBuilt(:,1),tAdd,tableBuilt(:,2:end)];

else
    %Table with FK (add FK_ID column as last column of the table)
    tAdd = table('Size', [rows 1], 'VariableTypes', {'int64'}, 'VariableNames', {'FK_ID'});
    tableBuilt = [tableBuilt,tAdd];

end


end
