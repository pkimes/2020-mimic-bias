WITH
PATIENTS as (
  SELECT DISTINCT
    SUBJECT_ID, HADM_ID, 
    GENDER, ETHNICITY, DOB, 
    WEIGHT_MAX, HEIGHT_MAX
  FROM `hst-953-2019.bias2020.notes_by_weight`
  LEFT JOIN `physionet-data.mimiciii_clinical.admissions`
  USING (SUBJECT_ID, HADM_ID)
  WHERE HAS_CHARTEVENTS_DATA = 1 -- limit analysis to patient who have chartevents
), 
ICUSTAYS as (
  SELECT DISTINCT  
    SUBJECT_ID, HADM_ID, 
    SUM(LOS) AS ICU_LOS
  FROM `physionet-data.mimiciii_clinical.icustays`
  GROUP BY SUBJECT_ID, HADM_ID
),
OASIS AS (
  SELECT DISTINCT
    HADM_ID, 
    AVG(AGE) AS AGE, 
    AVG(oasis_PROB) AS ave_oasis_prob, 
    avg(oasis) as ave_oasis, 
    MAX(mechvent) as mechvent
  FROM `physionet-data.mimiciii_derived.oasis`
  GROUP BY HADM_ID
),
COHORT AS (
  SELECT DISTINCT 
    pt.*, 
    o.AGE , 
    i.ICU_LOS , 
    e.elixhauser_SID30,
    o.ave_oasis_prob, 
    o.ave_oasis, 
    o.mechvent
  FROM PATIENTS as pt
  LEFT JOIN ICUSTAYS as i
  USING (SUBJECT_ID, HADM_ID)
  LEFT JOIN `physionet-data.mimiciii_derived.elixhauser_quan_score` e
  USING (HADM_ID) 
  LEFT JOIN  OASIS o
  USING (HADM_ID)
)

SELECT DISTINCT * 
FROM COHORT
