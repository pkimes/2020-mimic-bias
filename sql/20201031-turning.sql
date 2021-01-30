SELECT * 
FROM (
  SELECT ICUSTAY_ID, HADM_ID, SUBJECT_ID, INTIME
  FROM `physionet-data.mimiciii_clinical.icustays` 
)
INNER JOIN (
  # ICU stays with recorded height, weight.
  # subset to entries with recorded weights and heights.
  SELECT ICUSTAY_ID, WEIGHT_MAX, HEIGHT_MAX
  FROM `physionet-data.mimiciii_derived.heightweight`
  WHERE WEIGHT_MAX IS NOT NULL 
    AND HEIGHT_MAX IS NOT NULL
) 
USING (ICUSTAY_ID)
