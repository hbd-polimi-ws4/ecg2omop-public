function [person,comTableFull] = PERSONtransform(comTableFull)
% 
% [person,comTableFull] = PERSONtransform(comTableFull)
%  
%   Function that takes, as an input, the tables created by MAINextraction
%   that are needed to assemble the "person" OMOP CDM table. It maps into
%   this table the relevant information contained in the original tables
%   and returns:
% 
% - person
%       table with the standard fields of the OMOP CDM "person" table
%       required by the current pipeline implementation.
% - comTableFull
%       table with the original data contained in the input comTableFull,
%       plus the information added within this function (to be used for
%       assembling other OMOP CDM tables in the caller function).
%
% Required inputs:
% - comTableFull
%           table containing general patient and ECG exam characteristics
%           for each ECG recording
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano


%% Assemble OMOP CDM person table
% CONSTRAINTS: At least one record of Person is required for each patient.
% Multiple ECG exams (i.e., rows of comTableFull) can belong to the same
% record of Person.

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


end