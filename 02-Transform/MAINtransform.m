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


%% Load ECG samples tables

% Import ECG samples tables if no smpTableFull has been provided as input
if isempty(smpTableFull)
    smpTableFull = importExtractedTables('samp_',smpTableFull,false,tIDmap);
end


%% Assemble OMOP CDM person table
% CONSTRAINTS: At least one record of Person is required for each patient.
% Multiple ECG exams (i.e., rows of comTableFull) can belong to the same
% record of Person.

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
[~,iUnique,person2exam] = unique(comTableFull.Patient,'stable');
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
% which we will need to populate the procedure_occurrence table and for
% other operations
comTableFull.person_id_FK = person2exam;

% Add the table to the output struct
sOMOPtables.person = person;

%%%%% PERSON TABLE COMPLETED AND CHECKED! I SHOULD MOVE THIS TO A SEPARATE FUNCTION, ONE
%%%%% FOR EACH OMOP TABLE TO MAKE THINGS LESS MESSY.
%%%%% BUT LET'S FOCUS ON CHECKING THE OTHER TABLES BEFORE IMPROVING THE
%%%%% SCRIPT'S STRUCTURE!


%% Assemble OMOP CDM observation_period table

% CONSTRAINTS: At least one record of observation_period is required for
% each record of person. Multiple ECG exams (i.e., rows of comTableFull)
% can belong to the same record of observation_period. With our datasets,
% based on the advice reported in the source below, it seems reasonable to
% define only one observation period for each patient, including the time
% span between the first and last ECG exam of the same patient.
% Source: The "ETL Conventions" section of the following page:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#observation_period

% Define the required attributes based on OMOP CDM v5.4 specifications
reqAttrs = {'observation_period_id','int64'
            'person_id','int64'
            'observation_period_start_date','string'
            'observation_period_end_date','string'
            'period_type_concept_id','int64'};
% Define optional attributes we find useful for our data (there are no
% optional attributes for the observation_period table)
optAttrs = {};
% Combine required and optional attributes (the table will be initialized when the number of rows we need is known)
allAttrs = [reqAttrs; optAttrs];

%--------------------------------------------------------------------------
% observation_period.person_id
% Since we are assuming one record of observation_period for each record of
% person, let's initialize a table with the same number of rows of the
% "person" one
nrec = height(person);
observation_period = table('Size',[nrec length(allAttrs)],'VariableTypes',allAttrs(:,2),...
                           'VariableNames',allAttrs(:,1));
observation_period.person_id = person.person_id;

%--------------------------------------------------------------------------
% observation_period.observation_period_id
observation_period.observation_period_id = (1:height(observation_period))';

%--------------------------------------------------------------------------
% observation_period.observation_period_start_date
% observation_period.observation_period_end_date
% For each patient, find the minimum beginning (start_date) and the
% maximum end (end_date) of their ECG recordings.
vdtStart = datetime(comTableFull.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
vdtEnd   = datetime(comTableFull.RecordEnd,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
vdtMinStart = splitapply(@min,vdtStart,comTableFull.person_id_FK);
vdtMaxEnd   = splitapply(@max,vdtEnd,comTableFull.person_id_FK);
% Convert back to string to store the found dates in the observation_period
% table. Keep only the "date" part, as we don't need "time" in this field.
observation_period.observation_period_start_date = string(vdtMinStart,'uuuu-MM-dd');
observation_period.observation_period_end_date = string(vdtMaxEnd,'uuuu-MM-dd');

%--------------------------------------------------------------------------
% observation_period.period_type_concept_id
% Look for adequate period_type_concept_ids here:
%   https://athena.ohdsi.org/search-terms/terms?domain=Type+Concept&standardConcept=Standard&page=1&pageSize=15&query=
% and more info here:
%   https://github.com/OHDSI/Vocabulary-v5.0/wiki/Vocab.-TYPE_CONCEPT#instructions
% Suitable definitions in our case:
%  - EHR encounter record (32827): A patient encounter is an interaction between a
%    patient and healthcare provider(s) for the purpose of providing
%    healthcare service(s) or assessing the health status of a patient.
%  - EHR physical examination (32836): Record of findings obtained during the
%    physical examination of a patient.
% "EHR encounter record" sounds more appropriate in our case, since it is
% less specific, hence more flexible when we don't know the exact reason
% that led to the ECG exam, as for most Physionet datasets.
obsPeriodType = repmat("missing",nrec,1);
observation_period.period_type_concept_id = ...
       mapToConceptsFromVocab('observation_period','period_type_concept_id',obsPeriodType);

% Add the table to the output struct
sOMOPtables.observation_period = observation_period;


%% Assemble OMOP CDM visit_occurrence table

% CONSTRAINTS AND ASSUMPTIONS:
% Visit records of the same person should never overlap.
% Multiple ECG exams (i.e., rows of comTableFull) can belong to the same
% record of visit_occurrence.
% Among the accepted types of visit (visit_concept_id), the most suited
% ones for visits focused on ECG examinations are "Outpatient Visit" or
% "Laboratory Visit", both accepting durations within one day. Between
% these, "Laboratory Visit" seems more appropriate as its description
% explicitly states "Patient visiting dedicated institution... for the
% purpose of a Measurement", and the Extraction phase of our ETL
% produced indeed some entries for the Measurement table.
% Since the visit_start_date and visit_end_date must match in our case and
% ECG examinations should never last longer than 24 hours for Holter's
% recordings, it sounds reasonable to assume the start date of an exam as
% the start date of a visit. Multiple ECG exams of the same patient with
% the same start date will be linked to the same visit.
% Source: The "ETL Conventions" section of the following page:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#visit_occurrence

% Define the required attributes based on OMOP CDM v5.4 specifications
reqAttrs = {'visit_occurrence_id','int64'
            'person_id','int64'
            'visit_concept_id','int64'
            'visit_start_date','string'
            'visit_end_date','string'
            'visit_type_concept_id','int64'};
% Define optional attributes we find useful for our data
optAttrs = {};
% Combine required and optional attributes (the table will be initialized when the number of rows we need is known)
allAttrs = [reqAttrs; optAttrs];

%--------------------------------------------------------------------------
% visit_occurrence.visit_start_date
% Define the number of visit records we need, based on the number of unique
% dates we can find for the beginning of each patient's ECG exams.
vdtStart = datetime(comTableFull.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
vdtStart = dateshift(vdtStart,'start','day'); %To ignore time when applying the unique function 
cVisitDatesPerPerson = splitapply(@(x) {unique(x)},vdtStart,comTableFull.person_id_FK);
cVisitDatesPerPerson = cellfun(@(c) char(c,'uuuu-MM-dd'),cVisitDatesPerPerson,...
                               'UniformOutput',false);
vVisitDates = string( cell2mat(cVisitDatesPerPerson) );
nrec = length(vVisitDates);
visit_occurrence = table('Size',[nrec length(allAttrs)],'VariableTypes',allAttrs(:,2),...
                         'VariableNames',allAttrs(:,1));
visit_occurrence.visit_start_date = vVisitDates;
visit_occurrence.visit_occurrence_id = (1:nrec)';

%--------------------------------------------------------------------------
% visit_occurrence.person_id
% Reconstruct the association between each visit and the involved patient
% (i.e., the person_id foreign key)
ri = 1; rf = 0;
for k = 1:length(cVisitDatesPerPerson)
    nVisitsPerPerson = size(cVisitDatesPerPerson{k},1);
    rf = rf + nVisitsPerPerson;
    visit_occurrence.person_id(ri:rf) = repmat(person.person_id(k),nVisitsPerPerson,1);
    ri = rf+1;
end

%--------------------------------------------------------------------------
% visit_occurrence.visit_type_concept_id
% The list of accepted concepts for this field is the same as seen for
% observation_period.period_type_concept_id.
% Here we use the same concept selected for observation_period.period_type_concept_id, 
% for consistency.
visitType = repmat("missing",nrec,1);
visit_occurrence.visit_type_concept_id = ...
      mapToConceptsFromVocab('visit_occurrence','visit_type_concept_id',visitType);

%--------------------------------------------------------------------------
% visit_occurrence.visit_concept_id
% visit_occurrence.visit_end_date
visitType2 = repmat("missing",nrec,1);
visit_occurrence.visit_concept_id = ...
      mapToConceptsFromVocab('visit_occurrence','visit_concept_id',visitType2);
% Given the visit type we selected, which must end within one day, this is
% the only allowed choice
visit_occurrence.visit_end_date = vVisitDates;

% Add the table to the output struct
sOMOPtables.visit_occurrence = visit_occurrence;


%% Assemble OMOP CDM procedure_occurrence table

% CONSTRAINTS AND ASSUMPTIONS:
% Each ECG recording produces a separate record of the procedure_occurrence
% table.
% Each procedure record must be linked to one visit, but multiple
% procedures can be related to the same visit.
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#procedure_occurrence

% Define the required attributes based on OMOP CDM v5.4 specifications
reqAttrs = {'procedure_occurrence_id','int64'
            'person_id','int64'
            'procedure_concept_id','int64'
            'procedure_date','string'
            'procedure_type_concept_id','string'};
% Define optional attributes we find useful for our data
optAttrs = {'procedure_datetime','string'
            'procedure_end_date','string'
            'procedure_end_datetime','string'
            'visit_occurrence_id','int64'};
% Combine required and optional attributes (the table will be initialized when the number of rows we need is known)
allAttrs = [reqAttrs; optAttrs];

%--------------------------------------------------------------------------
% procedure_occurrence.procedure_occurrence_id
% Initialize the table with a number of records equal to the number of
% available ECG recordings
nrec = height(comTableFull);
procedure_occurrence = table('Size',[nrec length(allAttrs)],'VariableTypes',allAttrs(:,2),...
                             'VariableNames',allAttrs(:,1));
procedure_occurrence.procedure_occurrence_id = (1:nrec)';

%--------------------------------------------------------------------------
% procedure_occurrence.procedure_date
% procedure_occurrence.procedure_datetime
% procedure_occurrence.procedure_end_date
% procedure_occurrence.procedure_end_datetime
% Define start and end dates and times of each ECG recording
vdtStart = datetime(comTableFull.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
vdtEnd   = datetime(comTableFull.RecordEnd,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
procedure_occurrence.procedure_date = string(vdtStart,'uuuu-MM-dd');
procedure_occurrence.procedure_datetime = string(vdtStart,'uuuu-MM-dd HH:mm:ss');
procedure_occurrence.procedure_end_date = string(vdtEnd,'uuuu-MM-dd');
procedure_occurrence.procedure_end_datetime = string(vdtEnd,'uuuu-MM-dd HH:mm:ss');

%--------------------------------------------------------------------------
% procedure_occurrence.person_id
% Link each ECG recording procedure to the patient it belongs to
procedure_occurrence.person_id = comTableFull.person_id_FK;

%--------------------------------------------------------------------------
% procedure_occurrence.visit_occurrence_id
% Link each ECG recording procedure to the visit it belongs to
procedure_occurrence.visit_occurrence_id = ...
       arrayfun(@(pid,dt) visit_occurrence.visit_occurrence_id(visit_occurrence.person_id==pid & ...
                visit_occurrence.visit_start_date==dt),...
                procedure_occurrence.person_id, procedure_occurrence.procedure_date);

%--------------------------------------------------------------------------
% procedure_occurrence.procedure_type_concept_id
% The list of accepted concepts for this field is the same as seen for
% observation_period.period_type_concept_id.
% Here we use the same concept selected for observation_period.period_type_concept_id, 
% for consistency.
procedureType = repmat("missing",nrec,1);
procedure_occurrence.procedure_type_concept_id = ...
      mapToConceptsFromVocab('procedure_occurrence','procedure_type_concept_id',procedureType);

%--------------------------------------------------------------------------
% procedure_occurrence.procedure_concept_id
% Describe the procedure type based on salient characteristics of the ECG
% recording. We rely on the following logic:
%   - Short recordings (< 30 minutes), with non-standard lead
%     positioning: "Ambulatory ECG"
%   - Short recordings (< 30 minutes), with 12 standard leads:
%     "12 Lead ECG"
%   - Long recordings (>= 30 minutes), with or without standard
%     lead positioning: "24 Hour ECG". This perfectly matches the case of
%     the St Petersburg INCART 12-lead Arrhythmia Database, where multiple
%     30-minute ECG excerpts extracted from Holter records are considered.
% Define rules
stdLeadsNames = {'Lead_I','Lead_II','Lead_III','Lead_aVF','Lead_aVR','Lead_aVL',...
                 'Lead_V1','Lead_V2','Lead_V3','Lead_V4','Lead_V5','Lead_V6'};
vAll12leads = splitapply( @(m) all(all(~isnan(m))), smpTableFull{:,stdLeadsNames}, smpTableFull.FK_ID);
vRecDur = vdtEnd - vdtStart;
vShortRecs = minutes(vRecDur)<30;
% Define SourceTerms based on the above rules. These SourceTerms will then
% be mapped to the desired OMOPconceptIDs following the relations defined
% in the imported vocabularies
procedureType2 = repmat("AmbulatoryECG",nrec,1);
procedureType2(vAll12leads & vShortRecs) = "12LeadECG";
procedureType2(~vShortRecs) = "HolterECG";
procedure_occurrence.procedure_concept_id = ...
      mapToConceptsFromVocab('procedure_occurrence','procedure_concept_id',procedureType2);

% Add the table to the output struct
sOMOPtables.procedure_occurrence = procedure_occurrence;


%% Assemble OMOP CDM measurement table



%% Assemble OMOP CDM condition_occurrence table
% Qui rientrano anche le diagnosi automatiche SE QUELLE INDIVIDUATE NEL
% NOSTRO CASO FANNO PARTE DEL DOMINIO "CONDITIONS"; ALTRIMENTI, DOVREMO
% INSERIRLE IN OBSERVATIONS ("tutto cio' che non rientra nel dominio di una
% tabella specifica deve essere inserito come observations).


%% Changes and checks for all the generated OMOP tables

return;

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