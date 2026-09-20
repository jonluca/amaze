-- Replace PROJECT.DATASET after authorized setup. Load the current canonical
-- snapshot with WRITE_TRUNCATE; never append snapshots into this current table.
-- This is an Apple aggregate view, not a join to GA4/Firebase users.
SELECT
  app_id,
  report_key,
  population,
  event_date,
  source_type,
  territory,
  metric_name,
  -- If any published row has an unavailable measure, retain NULL.
  IF(COUNTIF(metric_value IS NULL) > 0, NULL, SUM(metric_value)) AS observed_value
FROM `PROJECT.DATASET.apple_acquisition_current`
WHERE additive IS TRUE
GROUP BY app_id, report_key, population, event_date, source_type, territory, metric_name;
