# combine nursing notes with patient info
SELECT *
FROM (
  SELECT *
  FROM `physionet-data.mimiciii_notes.noteevents`
  WHERE CATEGORY IN ("Nursing/other", "Nursing", "Physician",
                     "Rehab Services", "Social Work")
)
LEFT JOIN (
  SELECT *
  FROM `hst-953-2019.bias2020.admissions`
  WHERE (AGE_AT_WTMAX > 18) AND
        (ICU_LOS_DAYS > 1)
)
USING (HADM_ID, SUBJECT_ID)
