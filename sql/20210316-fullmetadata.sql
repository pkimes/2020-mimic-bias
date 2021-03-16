WITH 
# ICU stays with recorded height, weight.
# subset to entries with recorded weights and heights.
HW_ICUSTAYS AS (
  SELECT * 
  FROM (
    SELECT ICUSTAY_ID, HADM_ID, SUBJECT_ID, INTIME
    FROM `physionet-data.mimiciii_clinical.icustays` 
  )
  INNER JOIN (
    SELECT ICUSTAY_ID, WEIGHT_MAX, HEIGHT_MAX
    FROM `physionet-data.mimiciii_derived.heightweight`
    WHERE WEIGHT_MAX IS NOT NULL 
      AND HEIGHT_MAX IS NOT NULL
  ) 
  USING (ICUSTAY_ID)
),

# keep weight/height from only one ICU stay for each hospital admission.
# only keep weight, height, time for highest weight.
HW_HADMS AS (
  SELECT SUBJECT_ID, HADM_ID, WEIGHT_MAX,
         INTIME AS INTIME_AT_WTMAX,
         HEIGHT_MAX AS HEIGHT_AT_WTMAX
  FROM (
    SELECT SUBJECT_ID, HADM_ID, 
      ARRAY_AGG(INTIME ORDER BY WEIGHT_MAX DESC LIMIT 1) time_arr,
      ARRAY_AGG(HEIGHT_MAX ORDER BY WEIGHT_MAX DESC LIMIT 1) ht_arr,
      ARRAY_AGG(WEIGHT_MAX ORDER BY WEIGHT_MAX DESC LIMIT 1) wt_arr
    FROM HW_ICUSTAYS
    GROUP BY SUBJECT_ID, HADM_ID
  ),
  UNNEST(time_arr) INTIME,
  UNNEST(ht_arr) HEIGHT_MAX,
  UNNEST(wt_arr) WEIGHT_MAX
),

# calculate age as time from DOB to admission time in height/weight table
PT_META AS (
  SELECT SUBJECT_ID, GENDER, DOB
  FROM `physionet-data.mimiciii_clinical.patients` 
),

# subset to patients with charevents data
HADM_META AS (
  SELECT SUBJECT_ID, HADM_ID, INSURANCE, LANGUAGE, RELIGION, ETHNICITY
  FROM `physionet-data.mimiciii_clinical.admissions`
  WHERE HAS_CHARTEVENTS_DATA = 1 -- limit analysis to patient who have chartevents
),

# get length of ICU stay for admissions
ICU_META AS (
  SELECT DISTINCT  
    SUBJECT_ID, HADM_ID, SUM(LOS) AS ICU_LOS_DAYS
  FROM `physionet-data.mimiciii_clinical.icustays`
  GROUP BY SUBJECT_ID, HADM_ID
),

# get oasis scores
OASIS AS (
  SELECT DISTINCT
    HADM_ID, 
    AVG(AGE) AS AVG_OASIS_AGE, 
    AVG(oasis_PROB) AS AVG_OASIS_PROB, 
    AVG(oasis) AS AVG_OASIS, 
    MAX(mechvent) AS mechvent
  FROM `physionet-data.mimiciii_derived.oasis`
  GROUP BY HADM_ID
),

# read in substance abuse set of ICD9 codes
ICD9_SUBSET AS (
  SELECT REPLACE (ICD9_CODE, ".", "") AS ICD9_CODE, LONG_TITLE
  FROM `hst-953-2019.bias2020.icd9_substance_abuse`
),

# determine all cases of substance abuse
ABUSE_DIAGNOSES AS (
  SELECT SUBJECT_ID, HADM_ID, ICD9_CODE, LONG_TITLE
  FROM `physionet-data.mimiciii_clinical.diagnoses_icd`
  INNER JOIN ICD9_SUBSET
  USING (ICD9_CODE)
),

# aggregate abuse diagnoses by admission
HADM_SUBABUSE AS (
  SELECT
    SUBJECT_ID, HADM_ID,
    STRING_AGG(ICD9_CODE, ";") AS SUBABUSE_CODES,
    STRING_AGG(LONG_TITLE, ";") AS SUBABUSE_TITLES
  FROM ABUSE_DIAGNOSES 
  GROUP BY SUBJECT_ID, HADM_ID
),

# elixhauser score
ELIX AS (
  SELECT HADM_ID, elixhauser_SID30
  FROM `physionet-data.mimiciii_derived.elixhauser_quan_score`
),

# combine tables
ALLADMITS AS (
  SELECT *, DATETIME_DIFF(INTIME_AT_WTMAX, DOB, DAY) / 365.25 AS AGE_AT_WTMAX
  FROM HW_HADMS
  LEFT JOIN PT_META USING (SUBJECT_ID)
  LEFT JOIN HADM_META USING (SUBJECT_ID, HADM_ID)
  LEFT JOIN ICU_META USING (SUBJECT_ID, HADM_ID)
  LEFT JOIN OASIS USING (HADM_ID)
  LEFT JOIN ELIX USING (HADM_ID)
  LEFT JOIN HADM_SUBABUSE USING (SUBJECT_ID, HADM_ID)
)

SELECT * 
FROM ALLADMITS
ORDER BY SUBJECT_ID, HADM_ID
