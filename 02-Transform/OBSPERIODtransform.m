function observation_period = OBSPERIODtransform(person,comTableFull)
% 
% observation_period = OBSPERIODtransform(person,comTableFull)
%  
%   Function that takes, as inputs, the tables created by MAINextraction as
%   well as previously transformed OMOP CDM tables that are needed to
%   assemble the "observation_period" OMOP CDM table. It maps into this
%   table the relevant information contained in the original tables and
%   returns:
% 
% - observation_period
%       table with the standard fields of the OMOP CDM "observation_period"
%       table required by the current pipeline implementation.
%
% Required inputs:
% - person
%           previously obtained OMOP CDM "person" table.
% - comTableFull
%           table containing general patient and ECG exam characteristics
%           for each ECG recording.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

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


end