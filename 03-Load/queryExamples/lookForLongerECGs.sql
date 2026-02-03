/* Select only procedures (i.e., ECG traces) with a duration equal to or longer than 30 minutes */
SELECT *
FROM procedure_occurrence
WHERE procedure_occurrence.procedure_occurrence_id IN  (
	SELECT measurement_event_id
	FROM measurement
	WHERE measurement.meas_event_field_concept_id = 1147301
	      measurement.measurement_concept_id=3004182 AND
		  measurement.value_as_number>=1800 AND
		  measurement.unit_concept_id=8555
);

/* As above, but optimized with JOIN: */
SELECT po.*,m.value_as_number,m.measurement_concept_id
FROM procedure_occurrence AS po
JOIN measurement AS m
ON po.procedure_occurrence_id = m.measurement_event_id
WHERE m.meas_event_field_concept_id = 1147301 AND /* meas_event_field = procedure_occurrence */
	  m.measurement_concept_id = 3004182 AND /* measurement = duration */
	  m.value_as_number>=1800 AND /* duration of 30 minutes (1800 seconds) or more */
	  m.unit_concept_id=8555; /* ensuring we are talking about seconds */
