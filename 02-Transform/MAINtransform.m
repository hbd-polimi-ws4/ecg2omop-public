function sOMOPtables = MAINtransform(varargin)
% 
% sOMOPtables = MAINtransform(varargin)
%  
%   Main function to transform the tables created by the MAINextraction
%   procedure and map the relevant information into OMOP-compliant tables.
%   It returns the requested set of standard tables that can be imported
%   into an OMOP SQL database.
% 
% - sOMOPtables
%       struct containing, in separate homonimous fields, one of the
%       standard OMOP tables obtained by transforming the previously
%       extracted data. For example, "sOMOPtable.person" contains OMOP CDM
%       "person" table, "sOMOPtable.condition_occurrence" contains OMOP CDM
%       "condition_occurrence" table, and so on.
%
% Optional inputs (Name-value parameters):
% - inputCSVPath
%           path to the directory where the CSV files to be imported (extracted by
%           MAINextraction) are. CSV files extracted from different
%           datasets, named exactly as returned by MAINextraction, must be
%           inserted in the same folder (with no subfolders).
%           Default: pwd
% - writeOMOPTableCSVs
%           if this flag is true, one .csv file for each output OMOP table
%           will be written, named as the OMOP table, itself, plus ".csv".
%           Default: true
% - outputPath
%           path to the directory where the output .csv OMOP tables should
%           be written. If it doesn't exist, it will be created.
%           Default: pwd/Transformed
% - comTableFull, smpTableFull, dgnTableFull, rrdTableFull, annTableFull, hrvTableFull
%           each output table produced by MAINextraction can be provided
%           separately as an input argument, instead of being loaded from a
%           CSV file.
%           Default: empty tables of the appropriate types, to be filled in
%                    with records loaded from CSV files.
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
ip.addParameter( 'writeOMOPTableCSVs', true, @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'outputPath', '', @(x) (isstring(x) && isscalar(x)) || (ischar(x) && isvector(x)) )
ip.addParameter( 'comTableFull', tableBuilder('notes',0), @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'smpTableFull', tableBuilder('meas',0), @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'dgnTableFull', tableBuilder('autoDiag',0), @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'rrdTableFull', tableBuilder('rrIntDur',0), @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'annTableFull', tableBuilder('annotations',0), @(x) islogical(x) && isscalar(x) );
ip.addParameter( 'hrvTableFull', tableBuilder('hrvMetrics',0), @(x) islogical(x) && isscalar(x) );

% Input arguments parsing
ip.parse(varargin{:});
inputCSVPath = ip.Results.inputCSVPath;
writeOMOPTableCSVs = ip.Results.writeOMOPTableCSVs;
outputPath = ip.Results.outputPath;
comTableFull = ip.Results.comTableFull;
smpTableFull = ip.Results.smpTableFull;
dgnTableFull = ip.Results.dgnTableFull;
rrdTableFull = ip.Results.rrdTableFull;
annTableFull = ip.Results.annTableFull;
hrvTableFull = ip.Results.hrvTableFull;

% If Full tables are provided as input arguments, we must have also a
% comTableFull among them
if isempty(comTableFull) && ...
   ( ~isempty(smpTableFull) || ~isempty(dgnTableFull) || ~isempty(rrdTableFull) || ...
     ~isempty(annTableFull) || ~isempty(hrvTableFull) )
   error('MAINtransform:chkInputs','A comTableFull must be provided as input if others are given.')
end

% Full tables can either be provided as input arguments or loaded from CSV
% files, not both
if ~matches('inputCSVPath',ip.UsingDefaults) && ~isempty(comTableFull)
    error('MAINtransform:chkInputs','A specific inputCSVPath cannot be provided together with input tables')
end

%% Initialization

% Move to the folder containing the ouputs of the Extraction process (stay
% in the current directory if no inputCSVPath input argument was provided)
origPath = cd(inputCSVPath);

%% Load Notes tables

% First, we retrieve information from all "Notes" tables (i.e., those
% starting with the "comm_" prefix), which contain basic ECG exam facts and
% have one record for every processed ECG trace.

% Import Notes tables if no comTableFull has been provided as input.
% At least one comTable (i.e., one dataset, with at least one ECG exam)
% must be provided to proceed with MAINtransform.
if isempty(comTableFull)
    [comTableFull,tIDmap] = importExtractedTables('comm_',comTableFull,true);
end


%% Load Automated Diagnosis tables

% Import Automated Diagnosis tables if no dgnTableFull has been provided as
% input
if isempty(dgnTableFull)
    dgnTableFull = importExtractedTables('dgn_',dgnTableFull,false,tIDmap);
end


%% Load HRV metrics tables

% Import HRV metrics tables if no hrvTableFull has been provided as input
if isempty(hrvTableFull)
    hrvTableFull = importExtractedTables('mhrv_',hrvTableFull,false,tIDmap);
end


%% Load ECG samples tables

% Import ECG samples tables if no smpTableFull has been provided as input
if isempty(smpTableFull)
    smpTableFull = importExtractedTables('samp_',smpTableFull,false,tIDmap);
end


%% Load ECG annotations tables

% Import ECG annotations tables if no annTableFull has been provided as input
if isempty(annTableFull)
    annTableFull = importExtractedTables('anno_',annTableFull,false,tIDmap);
end


% In the following sections, we map the information from the tables
% obtained during the Extraction phase into standard OMOP CDM tables (->
% Transform phase of the ETL). When required, we select appropriate concept
% IDs from OMOP CDM vocabularies (or custom ones) to assign unambiguous
% meaning to each feature/entity represented in the final schema.


%% Assemble OMOP CDM person table

[person,comTableFull] = PERSONtransform(comTableFull);

% Add the "person" table to the output struct
sOMOPtables.person = person;


%% Assemble OMOP CDM observation_period table

observation_period = OBSPERIODtransform(person,comTableFull);

% Add the table to the output struct
sOMOPtables.observation_period = observation_period;


%% Assemble OMOP CDM visit_occurrence table

visit_occurrence = VISITOCCURRtransform(person,comTableFull);

% Add the table to the output struct
sOMOPtables.visit_occurrence = visit_occurrence;


%% Assemble OMOP CDM procedure_occurrence table

[procedure_occurrence,comTableFull] = ...
                PROCOCCURRtransform(visit_occurrence,comTableFull,smpTableFull);

% Add the table to the output struct
sOMOPtables.procedure_occurrence = procedure_occurrence;


%% Assemble OMOP CDM condition_occurrence table

condition_occurrence = ...
                CONDOCCURRtransform(visit_occurrence,comTableFull,annTableFull,dgnTableFull);

% Add the table to the output struct
sOMOPtables.condition_occurrence = condition_occurrence;


%% Assemble OMOP CDM Measurement and Observation table (define related custom concepts, when required)

% Definition of the custom vocabulary and concepts needed to accurately
% describe the HRV metrics (or other quantitative information) of interest
[vocabulary,concept,concept_relationship] = VOCABCONCtransform();

% Store all custom concept-related tables in the output struct
sOMOPtables.vocabulary = vocabulary;
sOMOPtables.concept = concept;
sOMOPtables.concept_relationship = concept_relationship;

%--------------------------------------------------------------------------

% Populate OMOP CDM measurement and observation tables as needed
[measurement,observation] = ...
             MEASOBStransform(procedure_occurrence,smpTableFull,comTableFull,hrvTableFull);

% Store the measurement table in the output struct
sOMOPtables.measurement = measurement;

% Store the observation table in the output struct
sOMOPtables.observation = observation;


%% Changes and checks for all the generated OMOP tables

sOMOPtableNames = string(fieldnames(sOMOPtables));

for tableName = sOMOPtableNames'
    % When the attribute type is string, truncate to the 50th character (string
    % attributes in OMOP CDM v5.4 tables are specifically varchar(50))
    posVarStr = find(varfun(@isstring,sOMOPtables.(tableName),'OutputFormat','uniform'));
    for k = posVarStr
        sOMOPtables.(tableName){:,k} = arrayfun(@(s) extractBefore(s,min([50,strlength(s)])+1),...
                                                sOMOPtables.(tableName){:,k});
    end
    % When the attribute type is float (double or single), round to the 4th
    % decimal digit to ensure compatibility with the "numeric" type of
    % Postgresql (also because we don't need higher precision with the
    % measurements we've currently selected)
    posVarFloat = find(varfun(@isfloat,sOMOPtables.(tableName),'OutputFormat','uniform'));
    for k = posVarFloat
        sOMOPtables.(tableName){:,k} = round(sOMOPtables.(tableName){:,k},4);
    end
end


%% Write OMOP tables to CSV if requested

if writeOMOPTableCSVs

    % Define and create the path for output CSV tables
    if isempty(outputPath)
        % If outputPath is not provided as an input argument, the
        % output CSVs are produced in a subfolder inside the processed
        % dataset's folder
        outputPath = fullfile(pwd,'Transformed');
    else
        % If outputPath is provided as an input argument, it might
        % either be a relative (in relation to the path from where the
        % function was called) or an absolute path. In the first case,
        % it must be fixed to work correctly in this function, as we
        % "cd"ed to the directory with the extracted data.
        if ~isAbsolutePath(outputPath)
            outputPath = fullfile(origPath,outputPath);
        end
    end
    if ~isfolder(outputPath), mkdir(outputPath); end

    % Write each table to CSV, keeping its original name
    for tableName = sOMOPtableNames'
        outCSVpath = fullfile(outputPath,strcat(tableName,'.csv'));
        writetable(sOMOPtables.(tableName),outCSVpath,'Delimiter',',',...
                   'WriteVariableNames',true,'WriteMode','overwrite',...
                   'QuoteStrings','all');
    end

end

%% Move back to the original directory (if changed at the beginning) before exiting
cd(origPath);


end