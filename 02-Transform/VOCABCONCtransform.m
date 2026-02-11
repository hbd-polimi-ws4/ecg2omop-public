function [vocabulary,concept,concept_relationship] = VOCABCONCtransform()
% 
% [vocabulary,concept,concept_relationship] = VOCABCONCtransform()
%  
%   Function that takes no inputs and returns the custom vocabulary,
%   concepts, and concept relationships required for describing measures,
%   conditions, or other entities in the CDM that are not well represented
%   by already available concepts in the standard OMOP CDM vocabularies. It
%   returns:
% 
% - vocabulary
%       table with the required standard fields of the OMOP CDM "vocabulary"
%       table to define a new custom vocabulary.
% - concept
%       table with the required standard fields of the OMOP CDM
%       "concept" table. Specifically, it contains custom concepts as
%       needed to expand the current OMOP CDM standard vocabularies, in
%       order to describe extracted ECG features or measures accurately.
% - concept_relationship
%       table with the required standard fields of the OMOP CDM
%       "concept_relationship" table to link the defined custom concepts
%       among themselves or to other concepts already available in OMOP CDM
%       vocabularies.
%
% Required inputs: none.
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano


%% Custom vocabulary definition

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


%% Custom concepts definition

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


%% Concept_relationship definition for the new custom concepts

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


end