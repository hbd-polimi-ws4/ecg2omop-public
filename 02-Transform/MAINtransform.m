function [sOMOPtables, comTableFull, hrvTableFull, dgnTableFull] = MAINtransform(varargin)
% 
% [person, conditions_era, measurement, observation] = MAINtransform(varargin)
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
ip.addParameter( 'writeOMOPTableCSVs', true, @(x) islogical(x) && isscalar(x) );
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


%% Assemble OMOP CDM person table
% CONSTRAINTS: At least one record of Person is required for each patient.
% Multiple ECG exams (i.e., rows of comTableFull) can belong to the same
% record of Person.

% sOMOPtables.person, sOMOPtables.condition_era, sOMOPtables.measurement, sOMOPtables.observation

% Define the required attributes based on OMOP CDM v5.4 specifications
% Review specifications here: https://ohdsi.github.io/CommonDataModel/cdm54.html#person
reqAttrs = {'person_id','int64'
            'gender_concept_id','int64'
            'year_of_birth','int64'
            'race_concept_id','int64'
            'ethnicity_concept_id','int64'};
% Define optional attributes we find useful for our data
optAttrs = {'person_source_value','string'};
% Combine required and optional attributes (the table will be initialized when the number of rows we need is known)
allAttrs = [reqAttrs; optAttrs];


% Map the information from the tables obtained during the Extraction phase
% (Transform phase of the ETL). Read the appropriate concept IDs from file when
% needed.

% We use the patient's name in comTableFull.Patient to populate this
% attribute. When patients codes are not available in the header files of
% Physionet data (e.g., this sometimes happens for datasets where each exam
% is associated with a different patient), we have to replace the missing
% Patient information with a code to identify them.
pMiss = ismissing(comTableFull.Patient);
patient_names = strcat(comTableFull.RecordName(pMiss),'_',comTableFull.DatasetName(pMiss));
comTableFull.Patient(pMiss) = patient_names;

%--------------------------------------------------------------------------
% Once we've identified a unique name for every patient, we can extract
% unique patients from our exam table, with their biological sex (i.e.,
% sex at birth), and the other information we have about them. We can now
% fully populate the final person table to be imported in the OMOP CDM
% database.
% Furthermore, we can map each patient to their exams in the comTableFull,
% which we will need to populate the Procedure table (person2exam_FK).
[~,iUnique,person2exam_FK] = unique(comTableFull.Patient,'stable');
comTableFullUnique = comTableFull(iUnique,:);
nrec = height(comTableFullUnique);
person = table('Size',[nrec length(allAttrs)],'VariableTypes',allAttrs(:,2),...
               'VariableNames',allAttrs(:,1)); %Initialize the "person" table based on the number of unique patients

%--------------------------------------------------------------------------
% person.person_source_value
person.person_source_value = comTableFullUnique.Patient;

%--------------------------------------------------------------------------
% person.person_id (temporary, to create internal consistency among OMOP
% tables generated during the Transform phase; definitive primary keys will
% be generated during the Load phase, based on the records already
% available in the database)
person.person_id = (1:height(person))';

%--------------------------------------------------------------------------
% person.year_of_birth
% As we have patient age in our datasets the year_of_birth must be
% inferred from this information and the date of the recording
vdtRecDates = datetime(comTableFullUnique.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
person.year_of_birth = year(vdtRecDates) - comTableFullUnique.Age;
% For those subjects whose age was not provided in the dataset, we have to
% replace NaNs with a missing value marker (-1), as the year_of_birth is
% mandatory information in the person table
person.year_of_birth = fillmissing(person.year_of_birth,'constant',-1);

%--------------------------------------------------------------------------
% person.gender_concept_id
person.gender_concept_id = mapToConceptsFromVocab('person','gender_concept_id',comTableFullUnique.Sex);

%--------------------------------------------------------------------------
% person.ethnicity_concept_id (though this is a mandatory field in the
% Person table and there is no "escape" value, which is honestly weird, we
% decided to use the OMOPconceptID for "More than one ethnicity" in our
% case, since we don't have this information in our datasets).
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#person
comTableFullUnique.Ethnicity = repmat("missing",nrec,1);
person.ethnicity_concept_id = mapToConceptsFromVocab('person','ethnicity_concept_id',comTableFullUnique.Ethnicity);

%--------------------------------------------------------------------------
% person.race_concept_id (this is a mandatory field in the Person table,
% but we don't have this information in our datasets; we use the value
% recommended by the standard's specifications in this case, i.e. 0, as
% mapped in our vocabulary for this field's "missing" information).
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#person
comTableFullUnique.Race = repmat("missing",nrec,1);
person.race_concept_id = mapToConceptsFromVocab('person','race_concept_id',comTableFullUnique.Race);

% Furthermore, we can map each patient to their exams in the comTableFull,
% which we will need to populate the Procedure table.
sIDmapOMOPtables.person2exam = person2exam_FK;

% Add the table to the output struct
sOMOPtables.person = person;

return;

%%%%% PERSON TABLE COMPLETED AND CHECKED! I SHOULD MOVE THIS TO A SEPARATE FUNCTION, ONE
%%%%% FOR EACH OMOP TABLE TO MAKE THINGS LESS MESSY.
%%%%% BUT LET'S FOCUS ON CHECKING THE OTHER TABLES BEFORE IMPROVING THE
%%%%% SCRIPT'S STRUCTURE!


%% Assemble OMOP CDM ... table


%% Changes and checks for all the generated OMOP tables

cOMOPtableNames = fieldnames(sOMOPtables);

for tableName = cOMOPtableNames
    % When the attribute type is string, truncate to the 50th character (string
    % attributes in OMOP CDM v5.4 tables are specifically varchar(50))
    sOMOPtables.(tableName) = varfun(@(s) extractBefore(s,max([50,strlength(s)])+1), ...
                                     sOMOPtables.(tableName), "InputVariables",@isstring);
end


%% Move back to the original directory (if changed at the beginning) before exiting
cd(origPath);


end