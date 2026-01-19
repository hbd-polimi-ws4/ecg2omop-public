function vOutConceptIDs = mapToConceptsFromVocab(TableName,FieldName,vSourceTerms,vocabFolderPath)

if ~exist('vocabFolderPath','var') || isempty(vocabFolderPath)
    vocabFolderPath = fullfile(fileparts(which('MAINtransform')),'VocabulariesConceptMap');
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

    % Check if there are mulitple SourceTerms associated with different
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
    % nPerTriplet = zeros(heigth(tAvlTriplets),1);
    % for r = 1:heigth(tAvlTriplets)
    %     pSingleTriplet = tAvlbTriplets.TableName==tAvlbTriplets.TableName(r) & ...
    %                      tAvlbTriplets.FieldName==tAvlbTriplets.FieldName(r) & ...
    %     nPerTriplet(r) = sum( tAvlbTriplets(tAvlbTriplets.TableName==tn,tAvlbTriplets.FieldName==fn,tAvlbTriplets.SourceName==s),tAvlbTriplets.TableName,tAvlbTriplets.FieldName,tAvlbTriplets.SourceTerm);
    % end

    % Update the characteristics of the new vocabularies in the persistent
    % variable, after checking they are fine
    vocabList = vocabListUpd;
end

% Convert SourceTerms to strings, if needed
vSourceTerms = string(vSourceTerms);

% Replace possible <missing> elements in the array of SourceTerms with a
% literal "missing" string to allow for finding a match with the homonymous
% SourceTerm in the vocabularies
vSourceTerms = fillmissing(vSourceTerms,'constant',"missing");

% Associate the correct output OMOPconceptID to each SourceCode
tvocabSubset = tvocab(tvocab.TableName==TableName & tvocab.FieldName==FieldName, :);
vOutConceptIDs = arrayfun(@(s) tvocabSubset.OMOPconceptID(tvocabSubset.SourceTerm==s),...
                          vSourceTerms,'UniformOutput',false);

% Check if any of the cell of the output array is empty, as this means that
% no associated OMOPconceptID has been found in the vocabulary for the
% searched term in vSourceTerms. If this is the case, throw an error,
% showing all SourceTerms missing a match in the vocabularies.
pUnmatched = cellfun(@isempty,vOutConceptIDs);
if any(pUnmatched)
    unmatchedSourceTerms = unique(vSourceTerms(pUnmatched));
    fprintf(['\nERROR: Vocabularies lack definitions of OMOPconceptIDs for the ' ...
             'following SourceTerms of the %s table:\n'], TableName);
    disp(unmatchedSourceTerms);
    error('mapToConceptsFromVocab:vocabularyChk',['Missing OMOPconceptsIDs in ' ...
          'the vocabulary for the above list of SourceTerms of the %s table'],TableName);
end

% If every SourceTerm was mapped to a unique OMOPconceptID, instead, return
% the associated codes as a numeric array
vOutConceptIDs = cell2mat(vOutConceptIDs);

end