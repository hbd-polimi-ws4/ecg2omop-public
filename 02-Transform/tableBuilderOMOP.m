function tableBuilt = tableBuilderOMOP(type, rows)


switch type

    case 'person'
        %% OMOP CDM person table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#person
        reqAttrs = {'person_id','int64'
                    'gender_concept_id','int64'
                    'year_of_birth','int64'
                    'race_concept_id','int64'
                    'ethnicity_concept_id','int64'};
        optAttrs = {'person_source_value','string'
                    'gender_source_value','string'
                    'race_source_value','string'
                    'ethnicity_source_value','string'};
        
    case 'observation_period'
        %% OMOP CDM observation_period table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#observation_period
        reqAttrs = {'observation_period_id','int64'
                    'person_id','int64'
                    'observation_period_start_date','string'
                    'observation_period_end_date','string'
                    'period_type_concept_id','int64'};
        optAttrs = {};
        
    case 'visit_occurrence'
        %% OMOP CDM visit_occurrence table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#visit_occurrence
        reqAttrs = {'visit_occurrence_id','int64'
                    'person_id','int64'
                    'visit_concept_id','int64'
                    'visit_start_date','string'
                    'visit_end_date','string'
                    'visit_type_concept_id','int64'};
        optAttrs = {};

    case 'procedure_occurrence'
        %% OMOP CDM procedure_occurrence table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#procedure_occurrence
        reqAttrs = {'procedure_occurrence_id','int64'
                    'person_id','int64'
                    'procedure_concept_id','int64'
                    'procedure_date','string'
                    'procedure_type_concept_id','string'};
        optAttrs = {'procedure_datetime','string'
                    'procedure_end_date','string'
                    'procedure_end_datetime','string'
                    'visit_occurrence_id','int64'};

    case 'condition_occurrence'
        %% OMOP CDM condition_occurrence table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#condition_occurrence
        reqAttrs = {'condition_occurrence_id','int64'
                    'person_id','int64'
                    'condition_concept_id','int64'
                    'condition_start_date','string'
                    'condition_type_concept_id','int64'};
        % Define optional attributes we find useful for our data
        optAttrs = {'visit_occurrence_id','int64'
                    'condition_source_value','string'};
    
    case 'measurement'
        %% OMOP CDM measurement table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#measurement
        reqAttrs = {'measurement_id','int64'
                    'person_id','int64'
                    'measurement_concept_id','int64'
                    'measurement_date','string'
                    'measurement_type_concept_id','int64'};
        % Define optional attributes we find useful for our data
        optAttrs = {'measurement_datetime','string'
                    'value_as_number','doublenan'
                    'value_as_concept_id','doublenan' %actually, int64 but we need to keep track of NaNs (NULL)
                    'unit_concept_id','doublenan' %actually, int64 but we need to keep track of NaNs (NULL)
                    'unit_source_value','string'
                    'visit_occurrence_id','int64'
                    'measurement_source_value','string'
                    'measurement_source_concept_id','doublenan' %actually, int64 but we need to keep track of NaNs (NULL)
                    'measurement_event_id','int64'
                    'meas_event_field_concept_id','int64'};

    case 'observation'
        %% OMOP CDM observation table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#observation
        reqAttrs = {'observation_id','int64'
                    'person_id','int64'
                    'observation_concept_id','int64'
                    'observation_date','string'
                    'observation_type_concept_id','int64'};
        % Define optional attributes we find useful for our data
        optAttrs = {'observation_datetime','string'
                    'value_as_number','doublenan'
                    'value_as_concept_id','doublenan' %actually, int64 but we need to keep track of NaNs (NULL)
                    'unit_concept_id','doublenan' %actually, int64 but we need to keep track of NaNs (NULL)
                    'unit_source_value','string'
                    'visit_occurrence_id','int64'
                    'observation_source_value','string'
                    'observation_source_concept_id','doublenan' %actually, int64 but we need to keep track of NaNs (NULL)
                    'observation_event_id','int64'
                    'obs_event_field_concept_id','int64'};

    case 'vocabulary'
        %% OMOP CDM vocabulary table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#vocabulary
        reqAttrs = {'vocabulary_id','string'
                    'vocabulary_name','string'
                    'vocabulary_concept_id','int64'};
        % Define optional attributes we find useful for our data
        optAttrs = {'vocabulary_reference','string'
                    'vocabulary_version','string'};

    case 'concept'
        %% OMOP CDM concept table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#concept
        reqAttrs = {'concept_id','int64'
                    'concept_name','string'
                    'concept_code','string'
                    'domain_id','string'
                    'vocabulary_id','string'
                    'concept_class_id','string'
                    'valid_start_date','string'
                    'valid_end_date','string'};
        % Define optional attributes we find useful for our data
        optAttrs = {'standard_concept','string'};


    case 'concept_relationship'
        %% OMOP CDM concept_relationship table
        % Define the required and the optional attributes of the table we
        % found useful to describe our data, based on OMOP CDM v5.4
        % specifications:
        %       https://ohdsi.github.io/CommonDataModel/cdm54.html#concept_relationship
        reqAttrs = {'concept_id_1','int64'
                    'concept_id_2','int64'
                    'relationship_id','string'
                    'valid_start_date','string'
                    'valid_end_date','string'};
        % Define optional attributes we find useful for our data
        optAttrs = {};


    
    otherwise
        error('tableBuilderOMOP:unkTableType','Unrecognized table type requested.')
end

% Combine required and optional attributes
allAttrs = [reqAttrs; optAttrs];

% Return the OMOP table with the number of records requested as an input
tableBuilt = table('Size',[rows length(allAttrs)],'VariableTypes',allAttrs(:,2),...
                   'VariableNames',allAttrs(:,1));


end
