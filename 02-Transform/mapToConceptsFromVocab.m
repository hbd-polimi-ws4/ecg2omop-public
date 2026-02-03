function vOutConceptIDs = mapToConceptsFromVocab(TableName,FieldName,vSourceTerms,...
                                                 mustMatch,vocabFolderPath)
% 
% vOutConceptIDs = mapToConceptsFromVocab(TableName,FieldName,vSourceTerms,mustMatch,vocabFolderPath)
%  
% This function performs the Source To Concept Mapping (STCM) operation.
% Basically, it takes the source terms (i.e., the codes/names used to
% represent the (categorical) information extracted by MAINextraction and
% map them to concepts contained in OMOP CDM standard vocabularies or in
% custom ones. It relies on a Source To Concept table where all the
% information to perform the mappings are provided. This STCM table must be
% provided as one or more XLSX files (i.e., you can have multiple of them
% in the same folder or a single one for all tables, as you wish) to be
% formatted as expected by this function.
% Specifically, these STCM "vocabularies" must comprise:
%    1) a "TableName" column, with the exact name of the OMOP table the
%       mapped concept refers to;
%    2) a "FieldName" column, with the name of the field in which that concept
%       has to be inserted (if the same concept is allowed in multiple
%       TableName-FieldName pairs, it must be specified for each of these
%       pairs);
%    3) a "SourceTerm" column, specifying the "standardized" term (e.g., a
%       label) that we used in our Extraction routine to refer to a specific
%       concept, attribute categorical value, variable name, etc., that
%       needs to be mapped.
%       NB: The source term is a string that will be searched with EXACT
%           MATCH to ensure integrity and minimize risks of mistakes; so
%           be specific, as the match is case-sensitive.
%    4) an "OMOPconceptID" column, indicating the concept ID in the OMOP CDM
%       (or custom) vocabularies to which the specified source term will be
%       mapped;
%    5) a "Description" column where free text notes and considerations can be
%       reported; in particular, we should always include (for clarity
%       towards the other developers) the concept_name of the selected OMOP
%       concept. We can also add reasons why we decided to select a
%       specific concept. Be assured that this column (and any other
%       possibly following this one) will not be imported in Matlab, so
%       feel free to use this column and possible next ones in the file as
%       you wish.
%
% This function returns:
% 
% - vOutConceptIDs
%           a numeric vector of OMOPconceptIDs associated with each of the
%           source terms provided as an input. If mustMatch is set to true,
%           vOutConceptIDs will contain an NaN in correspondence of each
%           source term not found in the STCM (or "vocabulary") tables.
%
% Required inputs:
% - TableName
%           string referring to one of the OMOP CDM tables, to be searched
%           along the TableName column of the STCM table.
% - FieldName
%           string with the name of the specific field of the OMOP CDM
%           table in which to perform the mapping from the source term to
%           the selected OMOPconceptID. This is the string that will be
%           searched in the FieldName column of the STCM table.
% - vSourceTerms
%           vector of strings containing the source term to be searched in
%           the STCM table. One OMOPconceptID (if available) will be
%           returned in vOutConceptIDs for each source term in this vector.
%
% Optional inputs (positional, can be skipped through []):
% - mustMatch
%           if set to true, missing values in vOutConceptIDs won't
%           be accepted: in their presence, the function will throw an
%           error. Set this to true if you are mapping concepts to
%           required FieldName fields; set it to false otherwise.
%           Default: true
% - vocabFolderPath
%           path to the directory where STCM table files (.xlsx) are
%           searched. All the .xlsx files contained in this folder are
%           assumed to be STCM tables, formatted as specified above.
%           Default: a subfolder named "VocabulariesConceptMap" placed in
%                    the folder where MAINtransform is stored. If you kept
%                    the original organization of the repo, this should be:
%                       ecg2omop-public/02-Transform/VocabulariesConceptMap
%
% Contributors:
%   Pierluigi Reali, Ph.D., 2025-2026
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano
% 
% 

if ~exist('vocabFolderPath','var') || isempty(vocabFolderPath)
    vocabFolderPath = fullfile(fileparts(which('MAINtransform')),'VocabulariesConceptMap');
end
if ~exist('mustMatch','var') || isempty(mustMatch)
    mustMatch = true;
end

persistent tvocab;
persistent vocabList;

% If anything has changed in the list of vocabularies (e.g., number, size,
% names, modification dates of files) from the previous call of this
% function, reload all the vocabularies.
% Note: persistent variables are first declared as empty doubles ([]).
vocabListUpd = dir([vocabFolderPath,'/*.xlsx']);
if ~isequal(vocabList,vocabListUpd)
    varNT = {'TableName','string'
             'FieldName','string'
             'SourceTerm','string'
             'OMOPconceptID','int64'};
    tvocab = table('Size',[0 4],'VariableTypes',varNT(:,2),'VariableNames',varNT(:,1));

    for k = 1:length(vocabListUpd)
        vocabPath = fullfile(vocabListUpd(k).folder,vocabListUpd(k).name);
        tvocab = union(tvocab, readtable(vocabPath,'ReadVariableNames',true,'Range','A:D'),...
                       'stable');
    end

    % CHECK FOR COMMON MISTAKES IN THE LOADED VOCABULARIES:
    %----------------------------------------------
    % Remove row repetitions referring to the same combination of TableName
    % - FieldName - SourceTerm - OMOPconceptID, the user might have
    % inserted by mistake in the vocabulary. We can easily correct this
    % problem so there's no reason for issuing an error (a warning, though?)
    tvocab = unique(tvocab,'rows','stable');

    % Check if there are multiple SourceTerms associated with different
    % OMOPconceptIDs for each given pair of TableName-FieldName in the
    % vocabulary. If this happens, that's surely a mistake introduced by
    % the user in the vocabulary, as it makes the association
    % SourceConcept-OMOPconceptID ambiguous (i.e., non-unique) for a given
    % pair of TableName-FieldName. Thus, we throw an error and inform the
    % user about this issue.
    [~, ia, ic] = unique(tvocab(:,{'TableName','FieldName','SourceTerm'}), 'rows', 'stable');
    if ~isequal(ia,ic)
        % If the mapping vectors from non-unique to unique values (ia) and
        % viceversa (ic) are different (with a 'stable' sorting order), we
        % know for sure that there isn't the one-to-one match we are
        % seeking in the vocabulary!
        error('mapToConceptsFromVocab:vocabularyChk',...
              ['There are repeated TableName-FieldName-SourceTerm triplets in the loaded vocabularies.' ...
              '\nDouble-check them and try again.']);
    end

    % Update the characteristics of the new vocabularies in the persistent
    % variable, after checking they are fine
    vocabList = vocabListUpd;
end

% Convert SourceTerms to strings, if needed
vSourceTerms = string(vSourceTerms);

% Associate the correct output OMOPconceptID to each SourceCode
tvocabSubset = tvocab(tvocab.TableName==TableName & tvocab.FieldName==FieldName, :);
vOutConceptIDs = arrayfun(@(s) tvocabSubset.OMOPconceptID( strcmpi(tvocabSubset.SourceTerm,s)),...
                          vSourceTerms,'UniformOutput',false);

% Check if any of the cell of the output array is empty, meaning either that
% no associated OMOPconceptID has been found in the vocabulary for the
% searched term in vSourceTerms or that some elements of vSourceTerms were
% missing form the beginning.
pUnmatched = cellfun(@isempty,vOutConceptIDs);
if any(pUnmatched)
    if mustMatch
        % If mustMatch is set to true, throw an error, showing all
        % SourceTerms missing at least one match in the vocabularies
        unmatchedSourceTerms = unique(vSourceTerms(pUnmatched));
        fprintf(['\nERROR: Vocabularies lack definitions of OMOPconceptIDs for the ' ...
                 'following SourceTerms of the %s table:\n'], TableName);
        disp(unmatchedSourceTerms);
        error('mapToConceptsFromVocab:vocabularyChk',['Missing OMOPconceptsIDs in ' ...
              'the vocabulary for the above list of SourceTerms of the %s table'],TableName);
    else
        % If mustMatch is set to false, replace empty cells (i.e.,
        % unmatched Source Terms) with NaN and convert the other elements to
        % double before proceeding. The cell2mat below can give issues if
        % trying to combine int64 with NaN values
        vOutConceptIDs(pUnmatched) = {NaN};
        vOutConceptIDs = cellfun(@double, vOutConceptIDs,'UniformOutput',false);
    end
end

% If every SourceTerm was mapped to a unique OMOPconceptID, instead, return
% the associated codes as a numeric array
vOutConceptIDs = cell2mat(vOutConceptIDs);

end