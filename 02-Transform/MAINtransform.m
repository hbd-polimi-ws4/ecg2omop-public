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


%% Load ECG annotations tables

% Import ECG annotations tables if no annTableFull has been provided as input
if isempty(annTableFull)
    annTableFull = importExtractedTables('anno_',annTableFull,false,tIDmap);
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
optAttrs = {'person_source_value','string'
            'gender_source_value','string'
            'race_source_value','string'
            'ethnicity_source_value','string'};
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
% person.gender_source_value
% In Physionet datasets, there is the possibility that the person's gender
% is unknown, which is extremely unlikely in real hospital datasets. To
% these observations, we assign a non-standard concept for the Gender
% domain that is defined as "Gender unknown" (see vocabularies loaded by
% mapToConceptsFromVocab). To keep track of this peculiarity and
% double-check with the assigned OMOPconceptIDs, we also save the source
% value of the gender property.
person.gender_source_value = fillmissing(comTableFullUnique.Sex,'constant',"unknown");
person.gender_concept_id = mapToConceptsFromVocab('person','gender_concept_id',person.gender_source_value);

%--------------------------------------------------------------------------
% person.ethnicity_concept_id
% person.ethnicity_source_value
% Since this is a mandatory field in the Person table and there is no
% "escape" value to use in case it is missing, which is honestly weird, we
% decided to use the OMOPconceptID for "More than one ethnicity" in our
% case, as we don't have this information in our datasets. To preserve the
% original meaning we are giving to this field clearly, we also store
% "unknown" as the source value for this property.
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#person
person.ethnicity_source_value = repmat("unknown",nrec,1);
person.ethnicity_concept_id = mapToConceptsFromVocab('person','ethnicity_concept_id',...
                                                     person.ethnicity_source_value);

%--------------------------------------------------------------------------
% person.race_concept_id
% person.race_source_value
% This is a mandatory field in the Person table, but we don't have this
% information in our datasets; we use the value recommended by the
% standard's specifications in this case, i.e. 0, as mapped in our
% vocabulary for this field's missing information. To preserve this meaning
% clearly, we also store "unknown" as the source value for this field.
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#person
person.race_source_value = repmat("unknown",nrec,1);
person.race_concept_id = mapToConceptsFromVocab('person','race_concept_id',...
                                                person.race_source_value);

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
obsPeriodType = repmat("EHRencounter",nrec,1);
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
cVisitDatesPerPerson = splitapply(@(x) {unique(x,'stable')},vdtStart,comTableFull.person_id_FK);
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
visitType = repmat("EHRencounter",nrec,1);
visit_occurrence.visit_type_concept_id = ...
      mapToConceptsFromVocab('visit_occurrence','visit_type_concept_id',visitType);

%--------------------------------------------------------------------------
% visit_occurrence.visit_concept_id
% visit_occurrence.visit_end_date
visitType2 = repmat("LabVisit",nrec,1);
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
procedure_occurrence.procedure_occurrence_id = comTableFull.ID;
% To ensure this direct link between records of comTableFull and procedure
% tables is written in stone:
comTableFull.procedure_id_FK = comTableFull.ID;

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

% Add this visit2exam (or visit2procedure) mapping in the comTableFull to
% be used later on
comTableFull.visit_id_FK = procedure_occurrence.visit_occurrence_id;

%--------------------------------------------------------------------------
% procedure_occurrence.procedure_type_concept_id
% The list of accepted concepts for this field is the same as seen for
% observation_period.period_type_concept_id.
% Here we use the same concept selected for observation_period.period_type_concept_id, 
% for consistency.
procedureType = repmat("EHRencounter",nrec,1);
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


%% Assemble OMOP CDM condition_occurrence table

% CONSTRAINTS AND ASSUMPTIONS:
% Each ECG recording can produce zero, one, or multiple records in the
% condition_occurrence table.
% This table can only store concepts belonging to the Condition domain,
% namely patient diagnoses that have been manually assigned by clinicians
% or automatically detected from the ECG signals.
% To stress the connection of these diagnoses with a specific ECG exam
% (i.e., procedure_occurrence), we will use the optional attribute
% visit_occurrence_id, to map the condition of the patient to the visit
% (hence, implicitly, to the ECG exam) where it has been detected (either
% manually or automatically).
% Besides, to distinguish the origin of these diagnoses (i.e.,
% clinicians-made, ECG device annotation, automatic ECG diagnosis), we use
% a different condition_type_concept_id for each origin.
% Finally, we keep track of the source term, i.e. the original one
% extracted from the data, to ensure full transparency of the diagnoses
% detected on patients before their mapping into the selected
% OMOPconceptIDs.
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#condition_occurrence

% Define the required attributes based on OMOP CDM v5.4 specifications
reqAttrs = {'condition_occurrence_id','int64'
            'person_id','int64'
            'condition_concept_id','int64'
            'condition_start_date','string'
            'condition_type_concept_id','int64'};
% Define optional attributes we find useful for our data
optAttrs = {'visit_occurrence_id','int64'
            'condition_source_value','string'};
% Combine required and optional attributes (the table will be initialized
% when the number of rows we need is known)
allAttrs = [reqAttrs; optAttrs];

%--------------------------------------------------------------------------
% Extract the diagnoses manually annotated by clinicians or related to
% patient EHR and insert them in a temporary table
conditions = comTableFull(~ismissing(comTableFull.Diagnosis),{'Diagnosis','person_id_FK','visit_id_FK','RecordDate'});
conditions.RecordDate = arrayfun(@(s) strtok(s,' '), conditions.RecordDate); %Keep only the date, remove the time
cDiags = arrayfun(@(s) strip(split(s,',')),conditions.Diagnosis,'UniformOutput',false);
conditionsMan = table('Size',[0 4], 'VariableTypes',{'string','int64','int64','string'},...
                      'VariableNames',{'Diagnosis','person_id_FK','visit_id_FK','RecordDate'});
for k = 1:length(cDiags)
    nDiagsCurr = length(cDiags{k});
    vpid = repmat(conditions.person_id_FK(k),nDiagsCurr,1);
    vvid = repmat(conditions.visit_id_FK(k),nDiagsCurr,1);
    vRD  = repmat(conditions.RecordDate(k),nDiagsCurr,1);
    conditionsMan = [conditionsMan; table(cDiags{k},vpid,vvid,vRD,...
                                    'VariableNames',{'Diagnosis','person_id_FK','visit_id_FK','RecordDate'})]; %#ok<AGROW>
end
% Keep only one line for each combination Diagnosis - person_id_FK -
% visit_id_FK (multiple ECG recordings collected in the same day might
% present the same diagnoses reported by the clinician)
conditionsMan = unique(conditionsMan,'rows','stable');
% Add a condition type label to these diagnoses (to distinguish them from
% the others)
conditionsMan.Type = repmat("ManuallyReported",height(conditionsMan),1); 

%--------------------------------------------------------------------------
% Extract and summarize pathological automatic beat annotations represented
% with standard Physionet notation, obtained during the Extraction phase of
% the ETL and loaded in annTableFull.
% Retain only special annotations (i.e., exclude normal/healthy ones) from
% annTableFull
patholSourceTerms = {'Left bundle branch block beat','Right bundle branch block beat',...
                     'Bundle branch block beat (unspecified)','Atrial premature beat',...
                     'Aberrated atrial premature beat','Nodal (junctional) premature beat',...
                     'Supraventricular premature or ectopic beat (atrial or nodal)',...
                     'Premature ventricular contraction','R-on-T premature ventricular contraction',...
                     'Fusion of ventricular and normal beat','Atrial escape beat',...
                     'Nodal (junctional) escape beat','Supraventricular escape beat (atrial or nodal)',...
                     'Ventricular escape beat','Paced beat','Fusion of paced and normal beat'};
pPathol = matches(annTableFull.AnnExplanation,patholSourceTerms);
conditionsAnn = annTableFull(pPathol,{'AnnExplanation','FK_ID'}); %FK_ID links to the ID of the ECG recording
% Add the foreign keys of the visit and of the person to the temporary
% table. We can remove the foreign key of the ECG recording (i.e., "FK_ID")
% at the end.
conditionsAnn.visit_id_FK = arrayfun(@(eid) comTableFull.visit_id_FK(comTableFull.ID==eid),...
                                     conditionsAnn.FK_ID);
conditionsAnn.person_id_FK = arrayfun(@(eid) comTableFull.person_id_FK(comTableFull.ID==eid),...
                                      conditionsAnn.FK_ID);
conditionsAnn.FK_ID = [];
% If at least one beat in an ECG exam reporting a specific condition is
% present, we'll add this as a condition_occurrence to the relative visit.
% Remove repetitions (i.e., muliple ECG recordings of the same patient
% collected on the same day showing the same annotations, or multiple
% beats in the same ECG recording presenting the same annotation)
conditionsAnn = unique(conditionsAnn,'rows','stable');
% Add the date associated to the visit to the temporary table
conditionsAnn.RecordDate = ...
      arrayfun(@(vid) visit_occurrence.visit_start_date(visit_occurrence.visit_occurrence_id==vid),...
               conditionsAnn.visit_id_FK);
% Add a condition type label to these diagnoses (to distinguish them from
% the others)
conditionsAnn.Type = repmat("StandardAnnotation",height(conditionsAnn),1);

%--------------------------------------------------------------------------
% Extract and summarize the automated diagnoses obtained from raw ECG
% signals during the Extraction phase of the ETL through the selected
% algorithm. These are loaded in dgnTableFull.
% Retain only pathological diagnoses from dgnTableFull
nonPatholSourceTerms = {'NoAbnormalities','ImpossibleToEvaluate'};
pPathol = ~matches(dgnTableFull.AutoECGDiagnosis,nonPatholSourceTerms);
conditionsAuto = dgnTableFull(pPathol,{'AutoECGDiagnosis','FK_ID'});
% Add the foreign keys of the visit and of the person to the temporary
% table. We can remove the foreign key of the ECG recording (i.e., "FK_ID")
% at the end.
conditionsAuto.visit_id_FK = arrayfun(@(eid) comTableFull.visit_id_FK(comTableFull.ID==eid),...
                                      conditionsAuto.FK_ID);
conditionsAuto.person_id_FK = arrayfun(@(eid) comTableFull.person_id_FK(comTableFull.ID==eid),...
                                       conditionsAuto.FK_ID);
conditionsAuto.FK_ID = [];
% Remove repetitions (i.e., muliple ECG recordings of the same patient
% collected on the same day showing the same abnormalities)
conditionsAuto = unique(conditionsAuto,'rows','stable');
% Add the date associated to the visit to the temporary table
conditionsAuto.RecordDate = ...
      arrayfun(@(vid) visit_occurrence.visit_start_date(visit_occurrence.visit_occurrence_id==vid),...
               conditionsAuto.visit_id_FK);
% Add a condition type label to these diagnoses (to distinguish them from
% the others)
conditionsAuto.Type = repmat("AutomaticallyDetected",height(conditionsAuto),1);

%--------------------------------------------------------------------------
% Combine the three temporary "conditions" table into one.
% Rename variable names differing across temporary tables so that they match
conditionsAnn = renamevars(conditionsAnn,'AnnExplanation','Diagnosis');
conditionsAuto = renamevars(conditionsAuto,'AutoECGDiagnosis','Diagnosis');
% Define a struct containing all temporary condition tables
condTables = struct('Man',conditionsMan,'Ann',conditionsAnn,'Auto',conditionsAuto);
% Combine rows of the temporary condition tables ("union" operation)
condNames = fieldnames(condTables);
conditions = condTables.(condNames{1});
for k = 2:length(condNames)
    conditions = union(conditions,condTables.(condNames{k}),'stable');
end
conditions = sortrows(conditions,'visit_id_FK'); %Just to help review the table...

%--------------------------------------------------------------------------
% Map the data from the combined temporary table into the standard
% condition_occurrence table.
nrec = height(conditions);
condition_occurrence = table('Size',[nrec length(allAttrs)],'VariableTypes',allAttrs(:,2),...
                             'VariableNames',allAttrs(:,1));
condition_occurrence.person_id = conditions.person_id_FK;
condition_occurrence.visit_occurrence_id = conditions.visit_id_FK;
condition_occurrence.condition_start_date = conditions.RecordDate;
condition_occurrence.condition_source_value = conditions.Diagnosis;
condition_occurrence.condition_occurrence_id = (1:nrec)';
condition_occurrence.condition_type_concept_id = ...
      mapToConceptsFromVocab('condition_occurrence','condition_type_concept_id',conditions.Type);
condition_occurrence.condition_concept_id = ...
      mapToConceptsFromVocab('condition_occurrence','condition_concept_id',conditions.Diagnosis);

% Add the table to the output struct
sOMOPtables.condition_occurrence = condition_occurrence;


%% Assemble OMOP CDM Measurement and Observation table and define related custom concepts

% The Measurement and Observation tables are both used to store
% quantitative or categorical results and facts from medical examinations.
% The main difference between them is that values associated with concepts
% belonging to the Measurement domain MUST go in the Measurement table,
% while values in the Observation table can belong to any domain, except
% for Condition, Procedure, Drug, Measurement, or Device. In both cases,
% the concept used in the <tablename>_concept_id field MUST be standard, as
% applies to all the other tables. In case of categorical response values,
% accepted concepts of the responses for the Measurement table are those
% included in the Meas Value domain. Apart from these differences, the
% other attributes available for both tables are very similar in definition
% and content. These tables have one record for each measure acquired
% during an ECG
% recording or related property.
% We decided to store the following quantitative info about each ECG:
%       - HRV metrics: only the ones that could be computed robustly for
%         each ECG record are stored; all in the Measurement table.
%       - Total duration of the recorded ECG signals; available for all
%         ECGs, will go in the Measurement table.
%       - Sampling frequency; available for all ECGs, stored in the Observation
%         table because no related concept was found in the Measurement domain.
%
% An example of Measurement fully characterized by a standard concept is
% the ECG duration:
%    - measurement_concept_id: "Recording duration by EKG" (3004182)
%    - unit_concept_id: second (8555)
%
% If we can't identify a standard concept from the Measurement domain that
% is capable of accurately describing the measure, a practice recommended
% by the specifications is to identify a close-enough standard concept (if
% we can find one) to which we will associate a well-describing
% non-standard concept. The non-standard concept can be either already
% available in one of the OMOP vocabularies, in which case we can just
% select it as a measurement_source_concept_id to make the description
% of the measure made by the more general, but still well-descriptive,
% selected standard concept more accurate. The standard concept, instead,
% should be mapped to the typical measurement_concept_id field.
% This goes by the definition of the measurement_source_concept_id field
% ("This field [...] should only be used when Standard Concepts do not
% adequately represent the source detail for the Measurement necessary for
% a given analytic use case."):
%       https://ohdsi.github.io/CommonDataModel/cdm54.html#measurement
% By doing so, we will obtain a perfectly compliant OMOP structure, as both
% the terms (i.e., the standard and the non-standard one) will be seen by
% OMOP tools and become querable, also in "OMOP-network studies". An example
% of this solution in our application: "ECG sampling rate" defined through
% the combination of:
%    - a standard concept used in the concept_id field: "Sampling - action"
%      (4117495) (already self-explanatory, even if not perfect)
%    - a perfectly matching non-standard concept, used in the
%      source_concept_id field: "Digital Sampling Rate" (37533243)
%    - unit_concept_id (to make its semantic even clearer): Hertz (9521)
% 
% If we can identify a close-enough standard concept, as previously, but
% not a fully-descriptive non-standard one, we can create the latter ourselves as a custom
% concept and link it to the identified standard one through a "Maps to"
% relationship (and corresponding "Mapped from"), allowing the ETL to
% resolve the related standard concept automatically. This step is important
% because allows custom-made concepts to be easily re-mapped to more
% appropriate new ones, should they ever become available. This is the
% preferred modality with which custom concepts should be added to the
% vocabulary, as clearly expressed in the OMOP CDM documentation:
%      https://ohdsi.github.io/CommonDataModel/customConcepts.html
% An example based on our application (can't find one at the moment...):
%    - ...
% 
% If a close-enough standard concept is not found, the only remaining
% alternative, is to create a custom standard concept, following a
% procedure similar to the previous one. However, without the possibility to map
% the custom concept to a standard one, we'll be able to use that feature
% only in "local" OMOP installations (though it will be perfectly usable
% through OMOP-compliant tools), where the custom vocabulary has been
% imported. Instead, we'll lose the possibility to use that feature in
% "OMOP community studies". To solve this issue, we can request our custom
% concept to be included into OMOP standard vocabularies, following the
% official procedure:
%    https://ohdsi.github.io/CommonDataModel/vocabRequest.html
%
% #########################################################################
% TO BE DELETED (OLD METHOD, NOT WELL-SUPPORTED BY OMOP DOCUMENTATION):
% An acceptable practice is to use the field value_as_concept_id to further
% refine the semantic description of the quantity that is measured. This
% opens to the possibility of using the measurement_concept_id field to
% indicate the "family" of measures that single measurement belongs to and,
% as further specification, the concept stated in the
% measurement_source_concept_id field.
% Define custom OMOP vocabulary and concepts needed for the HRV metrics in
% the measurement table. Official source:
%       https://ohdsi.github.io/CommonDataModel/customConcepts.html
% 
% units_concept_id: si puo' usare per aiutare a distinguere "normalized
% powers" dalle assolute (lasciando queste ultime senza niente). Popola
% sempre il campo "source" in questa tabella.
% "Very low frequency" lo aggiungerei come concetto custom, così da poter
% caratterizzare anche quella variabile; anche "RMSSD". Lascerei fuori solo
% "Total power" e "LF/HF" perché sono calcolabili dalle altre e, quindi,
% non e' necessario lasciarle salvate direttamente (non avendo trovato
% concetti adatti a descriverli e non valendo, quindi, la pena di
% codificarli con concetti custom), pur essendo ritenuti marker utili per
% l'identificazione di coorti di soggetti (Total power non tanto, in
% realtà, perché molto dipendente dalla durata dell'acquisizione; a meno
% che non si possa memorizzare anche la durata del segnale come metadato
% aggiuntivo; si puo' anche fare riferimento alla differenza tra datetime
% di fine e inizio procedura per quello).
% #########################################################################

% Define the required attributes based on OMOP CDM v5.4 specifications
reqAttrs = {'measurement_id','int64'
            'person_id','int64'
            'measurement_concept_id','int64'
            'measurement_date','string'
            'measurement_type_concept_id','int64'};
% Define optional attributes we find useful for our data
optAttrs = {'measurement_datetime','string'
            'value_as_number','double'
            'value_as_concept_id','int64'
            'unit_concept_id','int64'
            'visit_occurrence_id','int64'
            'measurement_source_concept_id','int64'
            'measurement_event_id','int64'
            'meas_event_field_concept_id','int64'};
% Combine required and optional attributes (the table will be initialized
% when the number of rows we need is known)
allAttrs = [reqAttrs; optAttrs];

%--------------------------------------------------------------------------
% Derive missing measures from the extracted ECG information
% Derive ECG sampling rate of each recording
vts = datetime(smpTableFull.Timestamp,'InputFormat','HH:mm:ss.SSS');
comTableFull.FS = splitapply(@(vt) 1/(seconds(vt(2)-vt(1))), vts,smpTableFull.FK_ID);
% Derive ECG duration of each recording
vdtStart = datetime(comTableFull.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
vdtEnd   = datetime(comTableFull.RecordEnd,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
comTableFull.Duration = seconds(vdtEnd-vdtStart);
% Assemble a temporary table with all the information required for populating
% the final Measurement or Observation tables
indexVarName = 'measType'; % We keep this name the same across all temporary measures tables
numVarName = 'NumValue';   % ""  ""
tMeas = stack(comTableFull,{'Duration','FS'},...
              'ConstantVariables',{'procedure_id_FK','visit_id_FK','person_id_FK'}, ...
              'NewDataVariableName',numVarName,'IndexVariableName',indexVarName);
% Convert the "Index" variable provided by the "stack" function to string
tMeas.measType = string(tMeas.measType);

%--------------------------------------------------------------------------
% Transform the HRV metrics table to get one row for each index and prepare
% them for insertion into the measurement table
hrvTableFull_noID = hrvTableFull(:,2:end);
hrvTableFullStacked = stack(hrvTableFull_noID,1:width(hrvTableFull_noID)-1,...
                            'ConstantVariables','FK_ID',...
                            'NewDataVariableName',numVarName,'IndexVariableName',indexVarName);
% Convert the "Index" variable provided by the "stack" function to string
hrvTableFullStacked.measType = string(hrvTableFullStacked.measType);
% Remove missing HRV metrics (i.e., those that were not calculated during
% the Extraction phase because of too short ECG signals)
hrvTableFullStacked(isnan(hrvTableFullStacked.NumValue),:) = [];
% Define the foreign keys to reconstruct the associations we need in the
% Measurement table.
% The below definition of procedure_id_FK is because each record of
% comTableFull is one exam, i.e. one record of the procedure table, and
% FK_ID of hrvTableFull links to the primary key of comTableFull.
hrvTableFullStacked.person_id_FK = arrayfun(@(eid) comTableFull.person_id_FK(comTableFull.ID==eid),...
                                            hrvTableFullStacked.FK_ID);
hrvTableFullStacked.visit_id_FK = arrayfun(@(eid) comTableFull.person_id_FK(comTableFull.ID==eid),...
                                           hrvTableFullStacked.FK_ID);
hrvTableFullStacked = renamevars(hrvTableFullStacked,'FK_ID','procedure_id_FK');
% Append the HRV measures to the temporary Measurement/Observation data table
tMeas = union(tMeas,hrvTableFullStacked,'stable');

%--------------------------------------------------------------------------
% Define the specific table type (Measurement or Observation) based on the
% domain of the suitable concepts identified for each measure. We need a
% cell for each value of unique(tMeas.measType).
measVarTableRelation = ["Duration","measurement"
                        "FS","observation"
                        "AVNN","measurement"
                        "SDNN","measurement"
                        "RMSSD","measurement"
                        "HF_NORM_FFT","measurement"
                        "HF_POWER_FFT","measurement"
                        "LF_NORM_FFT","measurement"
                        "LF_POWER_FFT","measurement"
                        "LF_TO_HF_FFT","measurement"
                        "VLF_NORM_FFT","measurement"
                        "VLF_POWER_FFT","measurement"
                        "SD1","measurement"
                        "SD2","measurement"
                        "alpha1","measurement"
                        "alpha2","measurement"
                        "SampEn","measurement"];
tMeas.measTable = replace(tMeas.measType,measVarTableRelation(:,1),measVarTableRelation(:,2));

%--------------------------------------------------------------------------
% When looking for suitable concepts for the measures we want to store,
% some were found in the OMOP interconnected vocabularies, while
% others not. Here we create the custom vocabulary and all the custom
% concepts we need for storing this information




%--------------------------------------------------------------------------
% Map the data from the combined temporary table into the standard
% measurement and observation tables.
nrec = height(tMeas);
measurement = table('Size',[nrec length(allAttrs)],'VariableTypes',allAttrs(:,2),...
                             'VariableNames',allAttrs(:,1));



%% Assemble OMOP CDM observation table
% In the observation table can be inserted every ECG-related information
% represented by concepts that don't belong to the domains of the other
% tables created so far.



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