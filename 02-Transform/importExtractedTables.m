function [tableFull,tIDmap_out] = importExtractedTables(filePrefix,tableFull,atLeastOne,tIDmap)

% filePrefix = string with which CSV files to be imported must begin.
% tableFull = table to which data records imported from CSV files must be
%             added. Generally, this is an empty table, providing a
%             template for the imported data in terms of data
%             variables that should be included and related data types.
% atLeastOne = optional flag. If true, at least one CSV file with the
%              specified prefix must be available in the current path;
%              otherwise, an error will be thrown.
% tIDmap = optional table made of three columns: orig, DatasetNameFromFile, new.
%          If provided, this table is used to map the foreign key present in the
%          imported tables, corresponding to the original IDs (tIDmap.orig),
%          to the new ones provided in tIDmap.new, using tIDmap.DatasetNameFromFile
%          to select the tIDmap rows related to the imported dataset.

%% Check input arguments and initialize defaults for optional ones
if ~exist('atLeastOne','var') || isempty(atLeastOne)
    atLeastOne = false;
end
if ~exist('tIDmap','var') || isempty(tIDmap)
    tIDmap = [];
else
    % If tIDmap is provided as input, we expect tableFull to have a foreign key
    % variable. If not, throw an error.
    if ~matches('FK_ID',tableFull.Properties.VariableNames)
        error('importExtractedTables:chkFKID','If tIDmap is provided an FK_ID variable must be present in tableFull.')
    end
end


%% Import tables

% Identify CSV files beginning with filePrefix in the current folder
CSVList = dir(['./',filePrefix,'*.csv']);

% If atLeastOne is true, we check that at least one CSV file is available
% with the filePrefix provided as input
if atLeastOne && isempty(CSVList)
    error('importExtractedTables:chkAtLeastOne',...
          'At least one CSV file with prefix "%s" must be available in the current folder.',filePrefix);
end

% Iterate on files found
vDsNameFromFile = string([]);
for CSVname = string({CSVList.name})

    % Read data from the current CSV file and import them in a table
    tableCurr = readtable(CSVname,'Delimiter',',','DecimalSeparator','.',...
                          'NumHeaderLines',0,'ReadVariableNames',true,...
                          'TextType','string','DatetimeType','text',...
                          'DurationType','text');
    currVars = tableCurr.Properties.VariableNames;

    % If the current table has a foreign key column (FK_ID), map its
    % original foreign keys to the new IDs assigned in the reference table.
    % Use the rest of the file name after the filePrefix as an identifier
    % of the dataset name.
    dsNameFromFile = erase(CSVname,regexpPattern(['^',filePrefix]));
    if matches('FK_ID',currVars)
        % If a tIDmap input is not provided in this case or if the current
        % dataset name is not represented in tIDmap, the function will
        % throw an error (we need a tIDmap table every time we import
        % tables featuring foreign keys).
        if isempty(tIDmap)
            error('importExtractedTables:tIDmapNeeded',...
                  'The imported file %s has an FK_ID but no tIDmap was provided as input.',CSVname)
        else
            tIDmap_ds = tIDmap(tIDmap.DatasetNameFromFile==dsNameFromFile,:);
            if isempty(tIDmap_ds)
                error('importExtractedTables:tIDmapDsNameMismatch',...
                      'The imported file %s has an FK_ID but no corresponding dataset name in the input tIDmap.',CSVname);
            end
            tableCurr.FK_ID = arrayfun(@(fk) tIDmap_ds.new(tIDmap_ds.orig==fk), tableCurr.FK_ID);
        end
    end

    % Keep the dataset name derived from the imported CSV file name to
    % construct the tIDmap_out.DatasetNameFromFile variable (useful if
    % tIDmap_out is requested as an output)
    vDsNameFromFile = [vDsNameFromFile; repmat(dsNameFromFile,height(tableCurr),1)]; %#ok<AGROW>

    % Adapt the imported table to the Full table.
    % To increase flexibility of the Transform phase of the ETL,
    % imported tables can either be identical to those extracted by
    % MAINextraction or present a subset of the expected variables (see
    % the "tableBuilder" function for learning more about the expected
    % structure of the various data tables). However, data types must
    % be the same for matching variable names, and all the CSVs imported
    % in one execution of MAINtrasform must have the same structure. If
    % something is off in this sense, MATLAB will throw an error at
    % this point.
    % Finally, extra variables present in the import tables but not in
    % the expected Full table will be dropped.
    fullVars = tableFull.Properties.VariableNames;
    if isempty(tableFull)
        % We adapt the Full table only when the first CSV is imported
        pMatchedVars = matches(fullVars,currVars);
        tableFull(:,~pMatchedVars) = [];
        fullVars = fullVars(pMatchedVars);
    end
    % We reorganize the variables in the imported table to match the
    % order of those in the Full table
    newVarOrder = cellfun(@(s) find(matches(currVars,s)), fullVars);
    tableCurr = tableCurr(:,newVarOrder);

    % Add current records to the Full table.
    tableFull = [tableFull;tableCurr]; %#ok<AGROW>

end

% If requested as an output, return a tIDmap_out table that shows
% the mapping between the original IDs of each imported table and the new
% ones assigned to the fullTable returned by this function. This tIDmap_out
% table can be used for subsequent calls of this function to transform,
% accordingly, foreign keys from the other tables to be imported.
tIDmap_out = table(tableFull.ID,'VariableNames',{'orig'});
tIDmap_out.DatasetNameFromFile = vDsNameFromFile;
tIDmap_out.new = (1:height(tableFull))';

% Adjust IDs to make them unique primary keys for the Full table
tableFull.ID = tIDmap_out.new;

end