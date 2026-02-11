function visit_occurrence = VISITOCCURRtransform(person,comTableFull)
% 
% visit_occurrence = VISITOCCURRtransform(person,comTableFull)
%  
%   Function that takes, as inputs, the tables created by MAINextraction as
%   well as previously transformed OMOP CDM tables that are needed to
%   assemble the "visit_occurrence" OMOP CDM table. It maps into this
%   table the relevant information contained in the original tables and
%   returns:
% 
% - visit_occurrence
%       table with the standard fields of the OMOP CDM "visit_occurrence"
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


end