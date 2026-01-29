function [sOMOPtablesRecLoaded,sOMOPtablesRecNotLoaded] = MAINload(varargin)
% 
% [recLoaded,recNotLoaded] = MAINload(varargin)
%  
%   Main function to transform the tables created by the MAINextraction
%   procedure and map the relevant information into OMOP-compliant tables.
%   It returns a set of tables that can be imported in an OMOP SQL
%   database, specifically:
% 
% - person
%       ...
% - condition_era
%       ...
%
%
% Optional inputs (Name-value parameters):
% - RECORDSpath
%           path where the "RECORDS" file of the Physionet dataset to be
%           processed can be found. Default: pwd
% - writeFullCSVs
%           if this flag is true, one .csv file for each "Full" table
%           documented above will be written record-by-record, once the
%           related ECG data have been processed. All the output tables of
%           this function, except for comTableFull, will be returned empty
%           to save memory. If this flag is set to false, the opposite will
%           happen, namely no .csv will be created, but the output tables
%           will be returned with the expected content. Default: true
% - linkTablesWithFKid
%           if this flag is true, output tables other than comTableFull
%           will be provided with an fk_id column, which presents foreign
%           keys linking each table entry to the primary key of
%           comTableFull. Each entry in comTableFull refers to a single ECG
%           exam in the RECORDS file. If this flag is set to false, foreign
%           keys will not be used and all tables will be provided with
%           explicit "RecordName" and "DatasetName" columns. Default: true
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2024-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

%% Check input arguments

% All the inputs to this function are optional
ip = inputParser;
ip.addParameter( 'inputCSVPath', pwd, @(x) (isstring(x) && isscalar(x)) || (ischar(x) && isvector(x)) );
ip.addParameter( 'sOMOPtables', [], @(x) (isstruct(x) && isscalar(x)) );
ip.addParameter( 'dryrun', false, @(x) (islogical(x) && isscalar(x)) );

% Input arguments parsing
ip.parse(varargin{:});
inputCSVPath = ip.Results.inputCSVPath;
sOMOPtables = ip.Results.sOMOPtables;
dryrun = ip.Results.dryrun;


%% Create connection with Postegresql DB
pgport = 5432;
username = 'postgres';
password = 'password';
serverAddress = 'localhost';
pgdbname = 'omop54';

conn = postgresql(username,password,'Server',serverAddress,'PortNumber',pgport,'DatabaseName',pgdbname);


%% Reading OMOP tables from files, if they are not provided as inputs

if isempty(sOMOPtables)
    OMOPtablesList = dir(fullfile(inputCSVPath,'*.csv'));
    sOMOPtables = struct();
    for k = 1:length(OMOPtablesList)
        CSVfolder = OMOPtablesList(k).folder;
        CSVname = OMOPtablesList(k).name;
        tname = erase(CSVname,'.csv');
        sOMOPtables.(tname) = readtable(fullfile(CSVfolder,CSVname),...
                              'Delimiter',',','DecimalSeparator','.',...
                              'NumHeaderLines',0,'ReadVariableNames',true,...
                              'TextType','string','DatetimeType','text',...
                              'DurationType','text');
    end
end


%% Loading the available tables into the DB with the expected order (to respect FKs)

% Define a cell array of OMOP table names in the order with which all
% tables must be loaded
loadOrder = {'vocabulary','concept','concept_relationship',...
             'person','observation_period','visit_occurrence',...
             'procedure_occurrence','condition_occurrence','measurement',...
             'observation'};

% All the loaded OMOP tables must be considered in the loadOrder cell-array
if ~all( matches(fieldnames(sOMOPtables),loadOrder) )
    error('MAINload:chkLoadOrder',['All the input OMOP tables must be loaded into DB with a specific order.' ...
          '\nCheck the definition of the loadOrder variable declared in MAINload.'])
end

loadOrder = loadOrder( matches(loadOrder,fieldnames(sOMOPtables)) );
sOMOPtables = orderfields(sOMOPtables,loadOrder);
sOMOPtableNames = string(fieldnames(sOMOPtables))';

% Load the tables to the database in the expected order
tIDmap = struct();
for tname = sOMOPtableNames

    % Check which table rows are not already present in the DB and should
    % be imported (this check could be further tailored to the specific
    % structure and content of each table)
    OMOPtableVarNames = string(sOMOPtables.(tname).Properties.VariableNames);

    % Exclude primary keys and specific table attributes from the check
    OMOPtableSelVarNames = ...
            OMOPtableVarNames( ~matches(OMOPtableVarNames,strcat(tname,'_id')) & ...
                               ~matches(OMOPtableVarNames,{'valid_start_date','valid_end_date'}) );
    tCSVchk = sOMOPtables.(tname)(:,OMOPtableSelVarNames);
    
    % Define the SQL query to use to read data from the DB.
    % By default, we retrieve all the available rows for the current table
    whereSQL = "WHERE true";
    if matches(tname,{'concept','concept_relationship'})
        % Since these tables are huge, look in the Postgresql DB only for rows
        % presenting the concepts that are going to be loaded, which are
        % the only ones we should check if they already exist in the DB
        if tname == "concept"
            whereSQL = strcat("WHERE concept_name IN ('",...
                              strjoin(sOMOPtables.(tname).concept_name,"','"),...
                              "')");
        else
            whereSQL = strcat("WHERE concept_id_1 IN (",...
                              strjoin(string(unique(sOMOPtables.(tname).concept_id_1)),","),...
                              ") OR concept_id_2 IN (",...
                              strjoin(string(unique(sOMOPtables.(tname).concept_id_2)),","),...
                              ")");
        end
    end
    querySQL = strcat("SELECT ",strjoin(OMOPtableSelVarNames,","),...
                      " FROM ",tname," ",...
                      whereSQL);

    % Ensure the variable types of the data read from DB (tDBchk) are
    % consistent with the imported CSV tables (tCSVchk)
    OMOPtableVarTypes = varfun(@class,tCSVchk,'OutputFormat','cell');
    opts = databaseImportOptions(conn,querySQL);
    opts = setoptions(opts,OMOPtableSelVarNames,'Type',OMOPtableVarTypes);

    % Retrieve records from the DB to be compared with those we should
    % load into the DB
    tDBchk = fetch(conn,querySQL,opts);

    % Make the comparison of the two sets of records meaningful
    % NB: two missing values (such as NaNs or <missing> can never be judged
    %     as "equal")
    tDBchk = fillmissing(tDBchk,'constant',-9999,'DataVariables',@isnumeric);
    tDBchk = fillmissing(tDBchk,'constant',"",'DataVariables',@isstring);
    tCSVchk = fillmissing(tCSVchk,'constant',-9999,'DataVariables',@isnumeric);
    tCSVchk = fillmissing(tCSVchk,'constant',"",'DataVariables',@isstring);
    % For measurement and observation tables, we replace the FK linking to the
    % procedure_occurrence table (i.e., the *_event_id field) with
    % procedure_occurrence.procedure_source_value, just for the comparison
    if matches(tname,{'measurement','observation'})
        procedure_FK_varName = OMOPtableSelVarNames( endsWith(OMOPtableSelVarNames,"_event_id") );
        tDBchk_procedure_occurrence = ...
               fetch(conn,['SELECT procedure_occurrence_id,procedure_source_value ', ...
                           'FROM procedure_occurrence']);
        tDBchk.procedure_source_value = ...
               arrayfun(@(pid) tDBchk_procedure_occurrence.procedure_source_value(...
                               tDBchk_procedure_occurrence.procedure_occurrence_id==pid),...
                        tDBchk.(procedure_FK_varName));
        tCSVchk.procedure_source_value = ...
               arrayfun(@(pid) sOMOPtables.procedure_occurrence.procedure_source_value(...
                               sOMOPtables.procedure_occurrence.procedure_occurrence_id==pid),...
                        tCSVchk.(procedure_FK_varName));
        tDBchk.(procedure_FK_varName) = [];
        tCSVchk.(procedure_FK_varName) = [];
    end

    % Detect which records (i.e., data rows) are equal and which should be
    % written to the DB instead.
    if isempty(tDBchk)
        rowWrite = true(height(tCSVchk),1);
    else
        rowWrite = ~ismember(tCSVchk,tDBchk,'rows');
    end

    % For the records to be imported, adjust all primary keys not to generate
    % conflicts with other records that are already stored in the DB.
    % The following regExp matches all table variable names ending in "_id"
    % but excluding those ending in "concept_id", "vocabulary_id",
    % "concept_class_id", "domain_id", or "relationship_id". Thus, we adjust all the IDs other
    % than these.
    regExIDs = regexpPattern('(?<!(concept|vocabulary|concept_class|domain|relationship))_id$');
    OMOPtableIDVarNames = OMOPtableVarNames( contains(OMOPtableVarNames,regExIDs) );

    for idVarName = OMOPtableIDVarNames
        if endsWith(idVarName,"_event_id")
            idVarNameLookUp = "procedure_occurrence_id";
        else
            idVarNameLookUp = idVarName;
        end
        if ~isfield(tIDmap,idVarNameLookUp)
            opts = databaseImportOptions(conn,tname);
            opts.SelectedVariableNames = idVarNameLookUp;
            t = sqlread(conn,tname,opts);
            if isempty(t)
                lastID=0;
            else
                lastID = max(t.(idVarNameLookUp));
            end
            nrec = sum(rowWrite);
            tIDmap.(idVarNameLookUp).old = sOMOPtables.(tname).(idVarName);
            tIDmap.(idVarNameLookUp).new = tIDmap.(idVarNameLookUp).old;
            tIDmap.(idVarNameLookUp).new(rowWrite) = lastID+1:lastID+nrec;
            sOMOPtables.(tname).(idVarName) = tIDmap.(idVarNameLookUp).new;
        else
            sOMOPtables.(tname).(idVarName) = ...
                  arrayfun(@(pid) tIDmap.(idVarNameLookUp).new(tIDmap.(idVarNameLookUp).old==pid),...
                           sOMOPtables.(tname).(idVarName));
        end
    end

    % For vocabulary, concept, and concept_relationship tables, current
    % implementation might be improved by deleting any custom vocabularies
    % already in the DB with the same vocabulary_id as the ones being
    % imported (and the related concepts, them too associated with that
    % specific vocabulary_id) and re-import them from scratch. This way, we
    % would also allow for updating previous versions of the same custom
    % vocabularies. An idea to start with might be the coding excerpt that
    % follows:
    % if matches(tname,{'vocabulary'})
    %     %For vocabulary, concept, and concept_relationship tables
    %     t = sqlread(conn,tname);
    %     rowDBRem = ismember(t,sOMOPtables.(tname),'rows');
    % else
    %     %For all the other tables
    %     ...
    % end
    % if any(rowDBRem)
    % 
    % end

    % Load the new records in the DB (if "dryrun" is set to false) and
    % prepare the output structs for check
    if any(rowWrite) && ~dryrun
        sqlwrite(conn,tname,sOMOPtables.(tname)(rowWrite,:));
    end
    sOMOPtablesRecLoaded.(tname) = sOMOPtables.(tname)(rowWrite,:);
    sOMOPtablesRecNotLoaded.(tname) = sOMOPtables.(tname)(~rowWrite,:);
    
end


%% Close connection to Postgresql DB

close(conn);

end