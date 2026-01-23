function vOutConceptIDs = mapToConceptsFromVocab(TableName,FieldName,vSourceTerms,mustMatch,vocabFolderPath)

% mustMatch = if it's set to true, missing values in vOutConceptIDs won't
%             be accepted: in their presence, the function will throw an
%             error. Set this to true if you are mapping concepts to
%             required fields; set it to false otherwise.

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