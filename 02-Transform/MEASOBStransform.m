function [measurement,observation,comTableFull] = ...
             MEASOBStransform(procedure_occurrence,smpTableFull,comTableFull,hrvTableFull)
% 
% [measurement,observation,comTableFull] = ...
%            MEASOBStransform(procedure_occurrence,smpTableFull,comTableFull,hrvTableFull)
%  
%   Function that takes, as inputs, the tables created by MAINextraction as
%   well as previously transformed OMOP CDM tables that are needed to
%   assemble the "measurement" and/or "observation" OMOP CDM tables. It maps
%   into these tables the relevant information contained in the original
%   tables and returns:
% 
% - measurement
%       table with the standard fields of the OMOP CDM "measurement"
%       table required by the current pipeline implementation.
% - observation
%       table with the standard fields of the OMOP CDM "observation"
%       table required by the current pipeline implementation.
% - comTableFull
%       table with the original data contained in the input comTableFull,
%       with the information added within this function (to be used for
%       assembling other OMOP CDM tables within the caller of this
%       function). 
%
% Required inputs:
% - procedure_occurrence
%           previously obtained OMOP CDM "procedure_occurrence" table.
% - smpTableFull
%           table containing signal samples for each available standard ECG
%           lead. Timestamps are present even if the ECG recording
%           comprises only non-standard leads. Only the first few timestamps
%           (at least 2) are needed within this function to calculate the
%           sampling rate of each ECG record.
% - comTableFull
%           table containing general patient and ECG exam characteristics
%           for each ECG recording.
% - hrvTableFull
%           table containing all HRV metrics that could be estimated
%           robustly for each ECG recording, depending on its duration.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

%% Assemble OMOP CDM Measurement and Observation table

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
% No cases like this exist in the current pipeline implementation.
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

%--------------------------------------------------------------------------
% Map the data from the combined temporary table into the standard
% measurement and observation tables.
pMeas = tMeas.measTable=="measurement";
pObs  = tMeas.measTable=="observation";
nrecMeas = sum(pMeas);
nrecObs  = sum(pObs);
measurement = tableBuilderOMOP('measurement',nrecMeas);
observation = tableBuilderOMOP('observation',nrecObs);


%% Measurement table

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


%% Observation table

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

end