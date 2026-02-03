/* Retrieving ECG records showing the same condition (same concept_id) but derived with different modalities:
   by referring to the same concept_id, a researcher can find more data related to the same condition they want
   to analyze. This query would have been more complex using the original source terms, as we should've known
   the labels used by the different modalities to select the same condition (RBBB/LBBB) */
SELECT cond.person_id, po.procedure_occurrence_id, cond.condition_concept_id, cond.condition_source_value,
       cond.condition_type_concept_id, conc.concept_name
FROM condition_occurrence AS cond
JOIN concept AS conc
ON cond.condition_type_concept_id = conc.concept_id
JOIN procedure_occurrence AS po
ON cond.visit_occurrence_id = po.visit_occurrence_id 
WHERE cond.condition_concept_id IN (316998, 314059);

/* Counting the above ECG records: look how many more procedures associated with LBBB/RBBB a researcher can
   identify, by using the same concepts codes for different modalities, thanks to our mapping!
   THIS IS THE QUERY SHOWN IN THE PAPER.*/
SELECT COUNT(po.procedure_occurrence_id), cond.condition_concept_id, cond.condition_source_value,
       cond.condition_type_concept_id, conc.concept_name
FROM condition_occurrence AS cond
JOIN concept AS conc
ON cond.condition_type_concept_id = conc.concept_id
JOIN procedure_occurrence AS po
ON cond.visit_occurrence_id = po.visit_occurrence_id 
WHERE cond.condition_concept_id IN (316998, 314059)
GROUP BY cond.condition_concept_id, cond.condition_source_value, cond.condition_type_concept_id,
         conc.concept_name
ORDER BY cond.condition_concept_id;


