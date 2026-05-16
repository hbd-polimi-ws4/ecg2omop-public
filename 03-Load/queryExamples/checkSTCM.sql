/* Review the association between condition source values and selected OMOP mapping concepts */

SELECT DISTINCT conc.concept_id, conc.concept_name, cond.condition_source_value
FROM condition_occurrence AS cond
JOIN concept AS conc ON cond.condition_concept_id = conc.concept_id
ORDER BY conc.concept_name;

/* Double-check the association between HRV features/ECG metadata source values and selected OMOP mapping concepts */
-- From the Measurement table (HRV features + ECG duration)
SELECT DISTINCT conc.concept_id, conc.concept_name, m.measurement_source_value
FROM measurement AS m
JOIN concept AS conc ON m.measurement_concept_id = conc.concept_id
ORDER BY conc.concept_name;

-- From the Observation table (ECG properties)
SELECT DISTINCT conc.concept_id, conc.concept_name, o.observation_source_value
FROM observation AS o
JOIN concept AS conc ON o.observation_concept_id = conc.concept_id
ORDER BY conc.concept_name;