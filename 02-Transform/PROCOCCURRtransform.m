function [procedure_occurrence,comTableFull] = ...
                PROCOCCURRtransform(visit_occurrence,comTableFull,smpTableFull)
% 
% [procedure_occurrence,comTableFull] = PROCOCCURRtransform(visit_occurrence,comTableFull,smpTableFull)
%  
%   Function that takes, as inputs, the tables created by MAINextraction as
%   well as previously transformed OMOP CDM tables that are needed to
%   assemble the "procedure_occurrence" OMOP CDM table. It maps into this
%   table the relevant information contained in the original tables and
%   returns:
% 
% - procedure_occurrence
%       table with the standard fields of the OMOP CDM "procedure_occurrence"
%       table required by the current pipeline implementation.
% - comTableFull
%       table with the original data contained in the input comTableFull,
%       plus the information added within this function (to be used for
%       assembling other OMOP CDM tables in the caller of this function).
%
% Required inputs:
% - visit_occurrence
%           previously obtained OMOP CDM "visit_occurrence" table.
% - comTableFull
%           table containing general patient and ECG exam characteristics
%           for each ECG recording.
% - smpTableFull
%           table containing signal samples for each available ECG lead.
%           Only the first few samples for each lead are needed within this
%           function to detect whether the 12 standard leads are used for
%           each ECG recording.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

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


end