WITH
oralcare as (
  SELECT *
  FROM `hst-953-2019.bias2020.nursing_care_items` n
  WHERE n.type LIKE "oral care"
),
chart_records as (
  SELECT distinct
  subject_id, hadm_id, icustay_id, itemid, charttime
  FROM `physionet-data.mimiciii_clinical.chartevents`
  WHERE itemid IN (SELECT distinct itemid FROM oralcare)
)
SELECT c.*, o.label
FROM chart_records as c
LEFT JOIN oralcare as o
ON c.itemid = o.itemid
WHERE hadm_id IS NOT NULL
AND icustay_id IS NOT NULL
