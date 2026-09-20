-- GoogleSQL TEMPLATE: exact calendar-day return, NOT rolling/on-or-after retention.
-- Required DATE parameters: cohort_start, cohort_end, complete_through.
-- Set complete_through after allowing late arrivals (up to three days).
DECLARE ios_stream STRING DEFAULT '15792271279';
ASSERT @cohort_start <= @cohort_end AND @cohort_end <= @complete_through AS 'Invalid date bounds';

WITH exported_days AS (
  SELECT PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)) AS day
  FROM `prism-roll.analytics_554682731.INFORMATION_SCHEMA.TABLES`
  WHERE REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}$')
), events AS (
  SELECT stream_id, user_pseudo_id, event_name, event_timestamp,
    PARSE_DATE('%Y%m%d', event_date) AS event_day
  FROM `prism-roll.analytics_554682731.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', @cohort_start)
    AND FORMAT_DATE('%Y%m%d', LEAST(DATE_ADD(@cohort_end, INTERVAL 7 DAY), @complete_through))
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^[0-9]{8}$')
    AND stream_id = ios_stream AND platform = 'IOS'
    AND app_info.id = 'com.jonluca.prismroll' AND user_pseudo_id IS NOT NULL
    AND COALESCE(privacy_info.analytics_storage, 'Unset') != 'No'
    AND NOT EXISTS (SELECT 1 FROM UNNEST(event_params)
      WHERE key IN ('debug_mode', '_dbg')
      AND (value.int_value = 1 OR LOWER(value.string_value) IN ('1', 'true')))
    AND event_name IN ('first_open', 'session_start', 'user_engagement', 'level_start', 'level_resumed')
), first_open AS (
  SELECT stream_id, user_pseudo_id,
    ARRAY_AGG(STRUCT(event_timestamp, event_day) ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS first_open
  FROM events WHERE event_name = 'first_open'
  GROUP BY stream_id, user_pseudo_id
), cohort AS (
  SELECT stream_id, user_pseudo_id, first_open.event_day AS cohort_day
  FROM first_open WHERE first_open.event_day BETWEEN @cohort_start AND @cohort_end
), return_days AS (
  SELECT DISTINCT stream_id, user_pseudo_id, event_day
  FROM events WHERE event_name IN ('session_start', 'user_engagement', 'level_start', 'level_resumed')
), members AS (
  SELECT c.stream_id, c.user_pseudo_id, c.cohort_day,
    COUNTIF(r.event_day = DATE_ADD(c.cohort_day, INTERVAL 1 DAY)) > 0 AS returned_d1,
    COUNTIF(r.event_day = DATE_ADD(c.cohort_day, INTERVAL 7 DAY)) > 0 AS returned_d7
  FROM cohort c LEFT JOIN return_days r
    ON r.stream_id = c.stream_id AND r.user_pseudo_id = c.user_pseudo_id
    AND r.event_day IN (DATE_ADD(c.cohort_day, INTERVAL 1 DAY), DATE_ADD(c.cohort_day, INTERVAL 7 DAY))
  GROUP BY c.stream_id, c.user_pseudo_id, c.cohort_day
), counts AS (
  SELECT cohort_day, COUNT(*) AS cohort_installations,
    COUNTIF(returned_d1) AS d1_returns, COUNTIF(returned_d7) AS d7_returns
  FROM members GROUP BY cohort_day
), availability AS (
  SELECT c.*,
    DATE_ADD(c.cohort_day, INTERVAL 1 DAY) <= @complete_through AND d1.day IS NOT NULL AS d1_mature,
    DATE_ADD(c.cohort_day, INTERVAL 7 DAY) <= @complete_through AND d7.day IS NOT NULL AS d7_mature
  FROM counts c
  LEFT JOIN exported_days d1 ON d1.day = DATE_ADD(c.cohort_day, INTERVAL 1 DAY)
  LEFT JOIN exported_days d7 ON d7.day = DATE_ADD(c.cohort_day, INTERVAL 7 DAY)
)
SELECT cohort_day, cohort_installations, d1_mature, d7_mature,
  IF(d1_mature, cohort_installations, NULL) AS d1_eligible_installations,
  IF(d7_mature, cohort_installations, NULL) AS d7_eligible_installations,
  IF(d1_mature, d1_returns, NULL) AS d1_returned_installations,
  IF(d7_mature, d7_returns, NULL) AS d7_returned_installations,
  IF(d1_mature, SAFE_DIVIDE(d1_returns, cohort_installations), NULL) AS exact_d1_retention,
  IF(d7_mature, SAFE_DIVIDE(d7_returns, cohort_installations), NULL) AS exact_d7_retention
FROM availability ORDER BY cohort_day;
