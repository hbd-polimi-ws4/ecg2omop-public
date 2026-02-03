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
%           Default: empty tables of the appropriate type, to be filled in
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


%% Assemble OMOP CDM person table
% CONSTRAINTS: At least one record of Person is required for each patient.
% Multiple ECG exams (i.e., rows of comTableFull) can belong to the same
% record of Person.

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
person = tableBuilderOMOP('person',nrec); %Initialize the "person" table based on the number of unique patients

%--------------------------------------------------------------------------
% person.person_source_value
person.person_source_value = comTableFullUnique.Patient;

%--------------------------------------------------------------------------
% person.person_id (temporary, to create internal consistency among OMOP
% tables generated during the Transform phase; definitive primary keys will
% be generated during the Load phase, based on the records already
% available in the database)
person.person_id = int64(1:nrec)';

%--------------------------------------------------------------------------
% person.year_of_birth
% As we have patient age in our datasets the year_of_birth must be
% inferred from this information and the date of the recording
vdtRecDates = datetime(comTableFullUnique.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
person.year_of_birth = int64( year(vdtRecDates) - comTableFullUnique.Age );
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
% standard "escape" value to use in case it is missing, which is honestly
% weird, we decided to use the OMOPconceptID for "More than one ethnicity"
% in our case, as we don't have this information in our datasets. To
% clearly preserve the original meaning, we also store "unknown" as the
% source value for this property.
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
comTableFull.person_id_FK = int64(person2exam);

% Add the table to the output struct
sOMOPtables.person = person;

%%%%% PERSON TABLE COMPLETED AND CHECKED! I SHOULD MOVE THIS TO A SEPARATE FUNCTION, ONE
%%%%% FOR EACH OMOP TABLE TO MAKE THINGS LESS MESSY.


%% Assemble OMOP CDM observation_period table

% CONSTRAINTS: At least one record of observation_period is required for
% each record of person. Multiple ECG exams (i.e., rows of comTableFull)
% can belong to the same record of observation_period. With our datasets,
% based on the advice reported in the source below, it seems reasonable to
% define only one observation period for each patient, including the time
% span between the first and last ECG exam of the same patient.
% Source: The "ETL Conventions" section of the following page:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#observation_period

%--------------------------------------------------------------------------
% observation_period.person_id
% Since we are assuming one record of observation_period for each record of
% person, let's initialize a table with the same number of rows of the
% "person" one
nrec = height(person);
observation_period = tableBuilderOMOP('observation_period',nrec);
observation_period.person_id = person.person_id;

%--------------------------------------------------------------------------
% observation_period.observation_period_id
observation_period.observation_period_id = int64(1:height(observation_period))';

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

%--------------------------------------------------------------------------
% visit_occurrence.visit_start_date
% visit_occurrence.visit_occurrence_id
% Define the number of visit records we need, based on the number of unique
% dates we can find for the beginning of each patient's ECG exams.
vdtStart = datetime(comTableFull.RecordDate,'InputFormat','uuuu-MM-dd HH:mm:ss.SSS');
vdtStart = dateshift(vdtStart,'start','day'); %To ignore time when applying the unique function 
cVisitDatesPerPerson = splitapply(@(x) {unique(x,'stable')},vdtStart,comTableFull.person_id_FK);
cVisitDatesPerPerson = cellfun(@(c) char(c,'uuuu-MM-dd'),cVisitDatesPerPerson,...
                               'UniformOutput',false);
vVisitDates = string( cell2mat(cVisitDatesPerPerson) );
nrec = length(vVisitDates);
visit_occurrence = tableBuilderOMOP('visit_occurrence',nrec);
visit_occurrence.visit_start_date = vVisitDates;
visit_occurrence.visit_occurrence_id = int64(1:nrec)';

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
% For the moment, we use the procedure_source_value field to capture the
% path of the ECG record related to a specific exam. We are aware that the limited length of
% the char array expected by this field (VARCHAR(50)) may prevent from
% saving the entire file path, if this is too long, especially if we
% plan to use absolute paths. However, this massively depends on the
% specific storage type we are going to use: for object-based
% storage (the storage type we are going to use in the HBD's data lake), 50
% chars would be more than enough to store billions of S3 objects
% (https://aws.amazon.com/what-is/object-storage/), as they are often
% encoded through Globally Unique Identifiers, which typically are 128-bit
% integers represented as 32 hexadecimal digits (i.e., a sequence of char,
% like f81d4fae-7dec-11d0-a765-00a0c91e6bf6) to identify data objects
% instead of traditional file paths
% (https://www.geeksforgeeks.org/cloud-computing/object-storage-vs-block-storage-in-cloud/).
% Nevertheless, if longer char sequences are needed for any reasons, an
% OMOP table of type "note" can be added in which text of arbitrary length
% can be stored. Records of this table can be directly linked to
% procedure_occurrence records through the note_event_field_concept_id and
% note_event_id fields, we also adopted to relate measurement and
% observation records to procedure_occurrence entries.
% Source:
%    https://ohdsi.github.io/CommonDataModel/cdm54.html#procedure_occurrence

%--------------------------------------------------------------------------
% procedure_occurrence.procedure_occurrence_id
% Initialize the table with a number of records equal to the number of
% available ECG recordings
nrec = height(comTableFull);
procedure_occurrence = tableBuilderOMOP('procedure_occurrence',nrec);
procedure_occurrence.procedure_occurrence_id = int64(comTableFull.ID);
% To ensure this direct link between records of comTableFull and procedure
% tables is written in stone:
comTableFull.procedure_id_FK = int64(comTableFull.ID);

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
% procedure_occurrence.procedure_source_value
procedure_occurrence.procedure_source_value = ...
       fullfile(comTableFull.DatasetName,comTableFull.RecordName);

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
condition_occurrence = tableBuilderOMOP('condition_occurrence',nrec);
condition_occurrence.person_id = conditions.person_id_FK;
condition_occurrence.visit_occurrence_id = conditions.visit_id_FK;
condition_occurrence.condition_start_date = conditions.RecordDate;
condition_occurrence.condition_source_value = conditions.Diagnosis;
condition_occurrence.condition_occurrence_id = int64(1:nrec)';
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
% belonging to the Measurement domain MUST go into the Measurement table,
% while values in the Observation table can belong to any domain, except
% for Condition, Procedure, Drug, Measurement, or Device. In both cases,
% the concept used in the <tablename>_concept_id field MUST be standard, as
% applies to all the other tables. In case of categorical response values,
% accepted concepts of the responses for the Measurement table are those
% included in the Meas Value domain. Apart from these differences, the
% other attributes available for both tables are very similar in definition
% and content. These tables have one record for each measure acquired
% during an ECG recording or related property.
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

tMeas = sortrows(tMeas,'procedure_id_FK'); %Just to help review the table...

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
% Define units of measurement for each measure. These will be mapped to a
% standard concept in the measurement.measurement_concept_id field later,
% if the relevant Source Term is defined in the vocabularies
measUnitRelation = ["Duration","s"
                     "FS","Hz"
                     "AVNN","ms"
                     "SDNN","ms"
                     "RMSSD","ms"
                     "HF_NORM_FFT","percent"
                     "HF_POWER_FFT","ms2"
                     "LF_NORM_FFT","percent"
                     "LF_POWER_FFT","ms2"
                     "LF_TO_HF_FFT","ratio"
                     "VLF_NORM_FFT","percent"
                     "VLF_POWER_FFT","ms2"
                     "SD1","ms"
                     "SD2","ms"
                     "alpha1","a.u."
                     "alpha2","a.u."
                     "SampEn","a.u."];
tMeas.measUnit = replace(tMeas.measType,measUnitRelation(:,1),measUnitRelation(:,2));


%#######################################################################
%--------------------------------------------------------------------------
% When looking for suitable concepts for the measures we want to store,
% some were found in the OMOP interconnected vocabularies, while
% others not.
% Create the custom vocabulary to store the additional concepts we need
vocabulary = tableBuilderOMOP('vocabulary', 1);
vocabulary.vocabulary_id = "ecg2omop-measures";
vocabulary.vocabulary_name = "Additional ECG HRV measures";
vocabulary.vocabulary_reference = "https://github.com/hbd-polimi-ws4/ecg2omop-public";
vocabulary.vocabulary_concept_id = int64(0); %Suggested value on OHDSI documentation
vocabulary.vocabulary_version = "2026-01-15"; %

% Create the custom concepts in the concept table
nCustomConc = 13;
concept = tableBuilderOMOP('concept', nCustomConc);
concept.concept_id = int64(2000000001:2000000001+nCustomConc-1)';
concept.concept_name = ["Root Mean Squared Successive Differences (RMSSD)"; ...
        "HRV Power High Frequency (HF)"; "HRV Power High Frequency (HF) normalized"; ...
        "HRV Power Low Frequency (LF)"; "HRV Power Low Frequency (LF) normalized"; ...
        "Ratio of HRV Low and High Frequency powers"; ...
        "HRV Power Very Low Frequency (VLF)"; "HRV Power Very Low Frequency (VLF) normalized"; ...
        "Poincaré plot SD1"; "Poincaré plot SD2"; "Detrended Fluctuation Analysis (DFA) alpha1"; ...
        "Detrended Fluctuation Analysis (DFA) alpha2"; "Sample entropy"];
concept.concept_code = ["RMSSD"; "HF_POWER"; "HF_NORM"; "LF_POWER";...
                        "LF_NORM"; "LF_TO_HF"; "VLF_POWER"; "VLF_NORM";...
                        "SD1"; "SD2"; "alpha1"; "alpha2"; "SampEn"];
%In this case, all custom concepts are measurements
concept.domain_id = repmat("Measurement",nCustomConc,1);
%We want all of them to be included in the same custom vocabulary
concept.vocabulary_id = repmat(vocabulary.vocabulary_id,nCustomConc,1);
%They are all Clinical Observation (same concept class of
%"RR-interval.standard deviation")
concept.concept_class_id = repmat("Clinical Observation",nCustomConc,1);
%Suggested value for valid_start_date is today
concept.valid_start_date = repmat(string(datetime('now'),'uuuu-MM-dd'),nCustomConc,1);
%Default value for valid_end_date
concept.valid_end_date = repmat("2099-12-31",nCustomConc,1);
%In this case, all custom concepts are STANDARD, as we didn't find
%close-enough standard concepts in OMOP vocabularies with which we could
%represent our measures. Thus, as we need the custom concepts to go in the
%measurement_concept_id, we must make them STANDARD.
concept.standard_concept = repmat("S",nCustomConc,1);

% Create relationships between: A) custom concepts and themselves, or B)
% bewteen custom concepts and other concepts from OMOP vocabularies.
%   A) When we define custom concepts as standard ("S"), we must relate
%      each concept to itself with "Maps to" and "Mapped from"
%      relationships
%   B) When we define custom concepts as non-standard ("N" or <missing>),
%      we must map each concept to the most close standard concept in OMOP
%      vocabularies with the "Maps to" relationship. In addition, we must
%      map the standard concept to the custom non-standard concept with
%      the "Mapped from" relationship.
tnonStd_to_Std = table([],... %Here go our custom non-standard concepts code
                       [],... %Here go the associated standard concepts code from OMOP vocabularies
                       'VariableNames',{'NonStd','Std'});
concept_relationship = tableBuilderOMOP('concept_relationship',nCustomConc*2);
for k = 1:nCustomConc
    ci = (k-1)*2+1;
    cf = k*2;
    if concept.standard_concept(k) == "S"
        % Case A), i.e. custom STANDARD concept
        concept_relationship.concept_id_1(ci:cf) = repmat(concept.concept_id(k),2,1);
        concept_relationship.concept_id_2(ci:cf) = repmat(concept.concept_id(k),2,1);
        concept_relationship.relationship_id(ci:cf) = ["Maps to"; "Mapped from"];
    else
        % Case B), i.e. custom NON-STANDARD concept
        NonStd = concept.concept_id(k);
        Std = tnonStd_to_Std.Std(tnonStd_to_Std.NonStd==NonStd);
        concept_relationship.concept_id_1(ci:cf) = [NonStd; Std];
        concept_relationship.concept_id_2(ci:cf) = [Std; NonStd];
        concept_relationship.relationship_id(ci:cf) = ["Maps to"; "Mapped from"];
    end
    concept_relationship.valid_start_date(ci:cf) = repmat(concept.valid_start_date(k),2,1);
    concept_relationship.valid_end_date(ci:cf) = repmat(concept.valid_end_date(k),2,1);
end

% Store all custom concept-related tables in the output struct
sOMOPtables.vocabulary = vocabulary;
sOMOPtables.concept = concept;
sOMOPtables.concept_relationship = concept_relationship;

%#######################################################################

%--------------------------------------------------------------------------
% Map the data from the combined temporary table into the standard
% measurement and observation tables.
pMeas = tMeas.measTable=="measurement";
pObs  = tMeas.measTable=="observation";
nrecMeas = sum(pMeas);
nrecObs  = sum(pObs);
measurement = tableBuilderOMOP('measurement',nrecMeas);
observation = tableBuilderOMOP('observation',nrecObs);

%-----------------------------------------------------------------------
% measurement.measurement_id
% measurement.person_id
% measurement.visit_occurrence_id
measurement.measurement_id = int64(1:nrecMeas)';
measurement.person_id = tMeas.person_id_FK(pMeas);
measurement.visit_occurrence_id = tMeas.visit_id_FK(pMeas);

%-----------------------------------------------------------------------
% measurement.meas_event_field_concept_id
% measurement.measurement_event_id
% Define the link between each measure and the procedure record (i.e., ECG
% signal) from which the measure was calculated
measConnTbl = repmat("procedure_occurrence",nrecMeas,1);
measurement.meas_event_field_concept_id = ...
       mapToConceptsFromVocab('measurement','meas_event_field_concept_id',measConnTbl);
measurement.measurement_event_id = tMeas.procedure_id_FK(pMeas);

%-----------------------------------------------------------------------
% measurement.measurement_date
% measurement.measurement_datetime
vdtStart = arrayfun(@(prid) datetime( ...
           procedure_occurrence.procedure_datetime(procedure_occurrence.procedure_occurrence_id==prid), ...
           'InputFormat','uuuu-MM-dd HH:mm:ss' ),...
           tMeas.procedure_id_FK(pMeas));
measurement.measurement_date = string(vdtStart,'uuuu-MM-dd');
measurement.measurement_datetime = string(vdtStart,'uuuu-MM-dd HH:mm:ss');

%-----------------------------------------------------------------------
% measurement.value_as_number
% measurement.unit_concept_id
% measurement.unit_source_value
measurement.value_as_number = tMeas.NumValue(pMeas);
measurement.unit_concept_id = ...
       mapToConceptsFromVocab('measurement','unit_concept_id',tMeas.measUnit(pMeas),false);
measurement.unit_source_value = tMeas.measUnit(pMeas);


%-----------------------------------------------------------------------
% measurement.measurement_type_concept_id
% The list of accepted concepts for this field is the same as seen for
% observation_period.period_type_concept_id.
% Here we use the same concept selected for procedure.procedure_type_concept_id, 
% for consistency.
measType2 = repmat("EHRencounter",nrecMeas,1);
measurement.measurement_type_concept_id = ...
       mapToConceptsFromVocab('measurement','measurement_type_concept_id',measType2);

%-----------------------------------------------------------------------
% measurement.measurement_concept_id (standard concepts, required for EVERY record)
% measurement.measurement_source_concept_id (non-standard concepts, if any)
% measurement.measurement_source_value
measurement.measurement_concept_id = ...
       mapToConceptsFromVocab('measurement','measurement_concept_id',tMeas.measType(pMeas));
measurement.measurement_source_concept_id = ...
       mapToConceptsFromVocab('measurement','measurement_source_concept_id',tMeas.measType(pMeas),false);
measurement.measurement_source_value = tMeas.measType(pMeas);

% Store the measurement table in the output struct
sOMOPtables.measurement = measurement;


%-----------------------------------------------------------------------
% observation.observation_id
% observation.person_id
% observation.visit_occurrence_id
observation.observation_id = int64(1:nrecObs)';
observation.person_id = tMeas.person_id_FK(pObs);
observation.visit_occurrence_id = tMeas.visit_id_FK(pObs);

%-----------------------------------------------------------------------
% observation.obs_event_field_concept_id
% observation.observation_event_id
% Define the link between each measure and the procedure record (i.e., ECG
% signal) from which the measure was calculated
measConnTbl = repmat("procedure_occurrence",nrecObs,1);
observation.obs_event_field_concept_id = ...
       mapToConceptsFromVocab('observation','obs_event_field_concept_id',measConnTbl);
observation.observation_event_id = tMeas.procedure_id_FK(pObs);

%-----------------------------------------------------------------------
% observation.observation_date
% observation.observation_datetime
vdtStart = arrayfun(@(prid) datetime( ...
           procedure_occurrence.procedure_datetime(procedure_occurrence.procedure_occurrence_id==prid), ...
           'InputFormat','uuuu-MM-dd HH:mm:ss' ),...
           tMeas.procedure_id_FK(pObs));
observation.observation_date = string(vdtStart,'uuuu-MM-dd');
observation.observation_datetime = string(vdtStart,'uuuu-MM-dd HH:mm:ss');

%-----------------------------------------------------------------------
% observation.value_as_number
% observation.unit_concept_id
% observation.unit_source_value
observation.value_as_number = tMeas.NumValue(pObs);
observation.unit_concept_id = ...
       mapToConceptsFromVocab('observation','unit_concept_id',tMeas.measUnit(pObs),false);
observation.unit_source_value = tMeas.measUnit(pObs);


%-----------------------------------------------------------------------
% observation.observation_type_concept_id
% The list of accepted concepts for this field is the same as seen for
% observation_period.period_type_concept_id.
% Here we use the same concept selected for procedure.procedure_type_concept_id, 
% for consistency.
measType2 = repmat("EHRencounter",nrecObs,1);
observation.observation_type_concept_id = ...
       mapToConceptsFromVocab('observation','observation_type_concept_id',measType2);

%-----------------------------------------------------------------------
% observation.observation_concept_id (standard concepts, required for EVERY record)
% observation.observation_source_concept_id (non-standard concepts, if any)
% observation.observation_source_value
observation.observation_concept_id = ...
       mapToConceptsFromVocab('observation','observation_concept_id',tMeas.measType(pObs));
observation.observation_source_concept_id = ...
       mapToConceptsFromVocab('observation','observation_source_concept_id',tMeas.measType(pObs),false);
observation.observation_source_value = tMeas.measType(pObs);

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
    % measurement we've currently selected)
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