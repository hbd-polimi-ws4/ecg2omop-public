function [sOMOPtablesRecLoaded,sOMOPtablesRecNotLoaded] = MAINload(varargin)
% 
% [sOMOPtablesRecLoaded,sOMOPtablesRecNotLoaded] = MAINload(varargin)
%  
%   Main function to load the OMOP CDM tables obtained at the end of the
%   Transform step (performed through MAINtransform) into a PostegreSQL
%   OMOP CDM database that have been already configured with the standard
%   OMOP CDM schema and standard vocabularies. This function also checks
%   whether the same records have been already uploaded to the database and
%   inserts only the "new" ones (i.e., not already present in the
%   database) for each table.
%   Please note that THESE CHECKS ARE BASIC, AT THE MOMENT. Thus, you
%   should not rely much on them and verify by yourself that the set of
%   records you wish to upload has not been inserted yet. We strongly
%   recommend using the "dryrun" option to check which records would be
%   inserted in the database and which would be skipped before actually
%   writing changes to your OMOP CDM database (see the optional inputs
%   below).
%   Possible custom vocabularies defined during MAINtransform, as
%   structured in the expected "vocabulary", "concept", and
%   "concept_relationship" tables, will be loaded by this function,
%   together with the other tables.
%
%   This function loads the tables in the requested OMOP CDM database (if
%   "dryrun" input is set to false, as it is by default) and returns two
%   output useful for further checks:
% 
% - sOMOPtablesRecLoaded
%       struct of the transformed OMOP CDM tables provided as input,
%       containing only the records (rows) of these tables that have been
%       recognized as "new" records and inserted into the database.
% - sOMOPtablesRecNotLoaded
%       as the previous one, but containing table rows that have not been
%       loaded into the database because matching others already in the DB.
%
% Optional inputs (Name-value parameters):
% - inputCSVPath
%           path to the directory where the CSV files of the OMOP CDM
%           tables to be loaded (generated through MAINextraction) are.
%           Default: pwd
% - sOMOPtables
%           struct of the OMOP CDM tables as returned by the MAINtransform
%           function. This input is meant to be used instead of
%           inputCSVPath if you prefer to provide the transformed OMOP CDM
%           tables as an input variable to the function than as .csv files.
%           Default: []
% - dryrun
%           if this flag is set to true, the function performs all the
%           operations and checks but without writing changes to the
%           database. Basically, it allows you to check which records would
%           be loaded into the OMOP CDM database without actually altering
%           its content.
%           Default: false (BE PARTICULARLY CAREFUL WITH THIS INPUT!)
% - sPGconnOpt
%           struct of options to be used for connecting Matlab with the
%           OMOP CDM DB server where you wish to load the tables provided
%           as input to this function.
%           Default: standard options used for the OMOP CDM DB set up
%                    by the forked container provided with the pipeline.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

%% Check input arguments

% All the inputs to this function are optional
ip = inputParser;
ip.addParameter( 'inputCSVPath', pwd, @(x) (isstring(x) && isscalar(x)) || (ischar(x) && isvector(x)) );
ip.addParameter( 'sOMOPtables', [], @(x) (isstruct(x) && isscalar(x)) );
ip.addParameter( 'dryrun', false, @(x) (islogical(x) && isscalar(x)) );
ip.addParameter( 'sPGconnOpt', [], @(x) (isstruct(x) && isscalar(x)) );

% Input arguments parsing
ip.parse(varargin{:});
inputCSVPath = ip.Results.inputCSVPath;
sOMOPtables = ip.Results.sOMOPtables;
dryrun = ip.Results.dryrun;
sPGconnOpt = ip.Results.sPGconnOpt;


%% Establish connection with Postegresql DB
if isempty(sPGconnOpt)
    sPGconnOpt.pgport = 5432;
    sPGconnOpt.username = 'postgres';
    sPGconnOpt.password = 'password';
    sPGconnOpt.serverAddress = 'localhost';
    sPGconnOpt.pgdbname = 'omop54';
end

conn = postgresql(sPGconnOpt.username,sPGconnOpt.password,...
                  'Server',sPGconnOpt.serverAddress,...
                  'PortNumber',sPGconnOpt.pgport,...
                  'DatabaseName',sPGconnOpt.pgdbname);


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

% All the imported OMOP tables must be mentioned in the loadOrder cell-array
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
    % NB: two missing values (such as NaNs or <missing> will never be judged
    %     as "equal" by Matlab)
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
    % "concept_class_id", "domain_id", or "relationship_id". Thus, we
    % adjust all the IDs other than these.
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