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
  SELECT SUBJECT_ID, HADM_ID, INTIME, HEIGHT_MAX, WEIGHT_MAX
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
PT_AGE AS (
  SELECT *,
    DATETIME_DIFF(INTIME, DOB, DAY) / 365.25 AS AGE
  FROM (
    SELECT SUBJECT_ID, GENDER, DOB
    FROM `physionet-data.mimiciii_clinical.patients` 
  )
  INNER JOIN HW_HADMS
  USING (SUBJECT_ID)
),

# subset clinical notes to notes by nurses (RN or NP)
NURSE_NOTES AS (
  SELECT * 
  FROM `physionet-data.mimiciii_notes.noteevents`
  INNER JOIN (
    SELECT CGID, LABEL
    FROM `physionet-data.mimiciii_clinical.caregivers`
    WHERE label IN ("RN", "NP")
  )
  USING (CGID)
),

# combine nursing notes with patient info
PT_NOTES AS (
  SELECT *
  FROM NURSE_NOTES 
  INNER JOIN PT_AGE
  USING (HADM_ID, SUBJECT_ID)
)

SELECT * 
FROM PT_NOTES
ORDER BY SUBJECT_ID, HADM_ID, CGID
