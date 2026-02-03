/*################################################################################################*/
/* Tachicardia/Bradicardia observations - AVNN comparison */
SELECT cond.person_id, m.measurement_event_id, cond.condition_concept_id, cond.condition_source_value,
       m.value_as_number, m.measurement_source_value
FROM condition_occurrence AS cond
JOIN measurement AS m
ON cond.visit_occurrence_id = m.visit_occurrence_id
WHERE (cond.condition_concept_id IN (4007310, 4171683)) AND
      (m.measurement_concept_id = 3006307);

/* Tachicardia/Bradicardia observations - AVNN comparison (providing average meanRR as output) */
SELECT COUNT(m.measurement_event_id), cond.condition_concept_id, conc.concept_name,
       AVG(m.value_as_number), m.measurement_source_value
FROM condition_occurrence AS cond
JOIN measurement AS m
ON cond.visit_occurrence_id = m.visit_occurrence_id
JOIN concept AS conc
ON cond.condition_concept_id = conc.concept_id
WHERE (cond.condition_concept_id IN (4007310, 4171683)) AND
      (m.measurement_concept_id = 3006307)
GROUP BY cond.condition_concept_id, conc.concept_name, m.measurement_source_value;

/* Tachicardia/Bradicardia observations - AVNN comparison (providing average meanRR as output and
   grouping by procedure type, as an alternative to the filtering out longer recordings,
   as done in subsequent queries. THIS IS THE QUERY SHOWN IN THE PAPER.) */
SELECT COUNT(po.procedure_occurrence_id), po.procedure_concept_id, conc.concept_name,
       cond.condition_concept_id, cond.condition_source_value,
       AVG(m.value_as_number), m.measurement_source_value
FROM condition_occurrence AS cond
JOIN measurement AS m
ON cond.visit_occurrence_id = m.visit_occurrence_id
JOIN procedure_occurrence AS po
ON m.measurement_event_id = po.procedure_occurrence_id
JOIN concept AS conc
ON po.procedure_concept_id = conc.concept_id
WHERE (cond.condition_concept_id IN (4007310, 4171683)) AND
      (m.measurement_concept_id = 3006307)
GROUP BY cond.condition_concept_id, po.procedure_concept_id, conc.concept_name,
         cond.condition_source_value, m.measurement_source_value
ORDER BY conc.concept_name;


/*################################################################################################*/
/* Tachicardia/Bradicardia observations - AVNN comparison (adding a filter to exclude longer acquisitions) */
SELECT cond.person_id, po.procedure_occurrence_id, po.procedure_concept_id, conc.concept_name,
       cond.condition_concept_id, cond.condition_source_value,
       m.value_as_number, m.measurement_source_value
FROM condition_occurrence AS cond
JOIN measurement AS m
ON cond.visit_occurrence_id = m.visit_occurrence_id
JOIN procedure_occurrence AS po
ON m.measurement_event_id = po.procedure_occurrence_id
JOIN concept AS conc
ON po.procedure_concept_id = conc.concept_id
WHERE (cond.condition_concept_id IN (4007310, 4171683)) AND
      (m.measurement_concept_id = 3006307) AND
	  (po.procedure_concept_id != 4098508);

/* Tachicardia/Bradicardia observations - AVNN comparison (excluding longer acquisitions and
   providing average as output) */
SELECT COUNT(po.procedure_occurrence_id), po.procedure_concept_id, conc.concept_name,
       cond.condition_concept_id, cond.condition_source_value,
       AVG(m.value_as_number), m.measurement_source_value
FROM condition_occurrence AS cond
JOIN measurement AS m
ON cond.visit_occurrence_id = m.visit_occurrence_id
JOIN procedure_occurrence AS po
ON m.measurement_event_id = po.procedure_occurrence_id
JOIN concept AS conc
ON po.procedure_concept_id = conc.concept_id
WHERE (cond.condition_concept_id IN (4007310, 4171683)) AND
      (m.measurement_concept_id = 3006307) AND
	  (po.procedure_concept_id != 4098508)
GROUP BY cond.condition_concept_id, po.procedure_concept_id, conc.concept_name,
         cond.condition_source_value, m.measurement_source_value;
