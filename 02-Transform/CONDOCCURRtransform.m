function condition_occurrence = ...
                CONDOCCURRtransform(visit_occurrence,comTableFull,annTableFull,dgnTableFull)
% 
% condition_occurrence = ...
%               CONDOCCURRtransform(visit_occurrence,comTableFull,annTableFull,dgnTableFull)
%  
%   Function that takes, as inputs, the tables created by MAINextraction as
%   well as previously transformed OMOP CDM tables that are needed to
%   assemble the "condition_occurrence" OMOP CDM table. It maps into this
%   table the relevant information contained in the original tables and
%   returns:
% 
% - condition_occurrence
%       table with the standard fields of the OMOP CDM "condition_occurrence"
%       table required by the current pipeline implementation.
%
% Required inputs:
% - visit_occurrence
%           previously obtained OMOP CDM "visit_occurrence" table.
% - comTableFull
%           table containing general patient and ECG exam characteristics
%           for each ECG recording.
% - annTableFull
%           table containing the standard ECG annotations provided in many
%           PhysioNet datasets, for each ECG recording.
% - dgnTableFull
%           table containing the conduction abnormalities detected from the
%           ECG signals by the selected abnormality detector (i.e., the
%           deep neural network by Ribeiro et al. 2020, in the current
%           version of the extraction procedure).
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

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


end