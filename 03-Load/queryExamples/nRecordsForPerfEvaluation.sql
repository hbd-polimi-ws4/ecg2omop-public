/* For performance evaluation and number of records inserted per table of interest */

/* Procedure occurrence */
SELECT * FROM procedure_occurrence
WHERE procedure_source_value LIKE '%ptb-xl-db%';

/* Person */
SELECT DISTINCT pe.* FROM person AS pe
JOIN procedure_occurrence AS po
ON pe.person_id = po.person_id 
WHERE po.procedure_source_value LIKE '%ptb-xl-db%'
ORDER BY pe.person_id;

/* Condition occurrence */
SELECT cond.person_id, po.procedure_source_value, cond.condition_concept_id, cond.condition_source_value,
       cond.condition_type_concept_id
FROM condition_occurrence AS cond
JOIN procedure_occurrence AS po
ON cond.visit_occurrence_id = po.visit_occurrence_id 
WHERE po.procedure_source_value LIKE '%ptb-xl-db%'
ORDER BY cond.person_id;

/* Measurement */
SELECT m.person_id, po.procedure_source_value, m.value_as_number,m.measurement_source_value
FROM measurement AS m
JOIN procedure_occurrence AS po
ON po.procedure_occurrence_id = m.measurement_event_id
WHERE po.procedure_source_value LIKE '%ptb-xl-db%'
ORDER BY m.person_id;

/* Observation */
SELECT o.person_id, po.procedure_source_value, o.value_as_number,o.observation_source_value
FROM observation AS o
JOIN procedure_occurrence AS po
ON po.procedure_occurrence_id = o.observation_event_id
WHERE po.procedure_source_value LIKE '%ptb-xl-db%'
ORDER BY o.person_id;
