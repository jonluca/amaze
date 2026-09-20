-- GoogleSQL TEMPLATE: not executed against live data; export dataset is pending.
-- Required DATE query parameters: cohort_start, cohort_end, complete_through.
-- complete_through must be a verified complete daily export date, allowing GA4's
-- three-day late-arrival window. Calendar dates use exported event_date.
DECLARE ios_stream STRING DEFAULT '15792271279';
ASSERT @cohort_start <= @cohort_end AS 'Invalid cohort bounds';
ASSERT DATE_ADD(@cohort_end, INTERVAL 2 DAY) <= @complete_through
  AS 'Allow the full 24-hour window and calendar-day boundary before finalizing';

WITH exported_days AS (
  SELECT PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)) AS day
  FROM `prism-roll.analytics_554682731.INFORMATION_SCHEMA.TABLES`
  WHERE REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}$')
), events AS (
  SELECT stream_id, user_pseudo_id, event_name, event_timestamp,
    PARSE_DATE('%Y%m%d', event_date) AS event_day,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_mode' LIMIT 1) AS game_mode,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'play_context' LIMIT 1) AS play_context,
    (SELECT COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64))
       FROM UNNEST(event_params) WHERE key = 'level' LIMIT 1) AS level,
    (SELECT COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64))
       FROM UNNEST(event_params) WHERE key = 'success' LIMIT 1) AS success
  FROM `prism-roll.analytics_554682731.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', @cohort_start)
    AND FORMAT_DATE('%Y%m%d', DATE_ADD(@cohort_end, INTERVAL 2 DAY))
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^[0-9]{8}$')
    AND stream_id = ios_stream AND platform = 'IOS'
    AND app_info.id = 'com.jonluca.prismroll'
    AND user_pseudo_id IS NOT NULL
    AND COALESCE(privacy_info.analytics_storage, 'Unset') != 'No'
    AND NOT EXISTS (SELECT 1 FROM UNNEST(event_params)
      WHERE key IN ('debug_mode', '_dbg')
      AND (value.int_value = 1 OR LOWER(value.string_value) IN ('1', 'true')))
    AND event_name IN ('first_open', 'level_start', 'level_end')
), first_observed_open AS (
  SELECT stream_id, user_pseudo_id,
    ARRAY_AGG(STRUCT(event_timestamp, event_day) ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS first_open
  FROM events WHERE event_name = 'first_open'
  GROUP BY stream_id, user_pseudo_id
), cohorts AS (
  SELECT *, first_open.event_day AS cohort_day,
    first_open.event_timestamp AS t0,
    first_open.event_timestamp + 86400000000 AS window_end
  FROM first_observed_open
  WHERE first_open.event_day BETWEEN @cohort_start AND @cohort_end
), fresh_move AS (
  SELECT c.stream_id, c.user_pseudo_id, c.cohort_day, c.t0, c.window_end,
    MIN(e.event_timestamp) AS t_move
  FROM cohorts c LEFT JOIN events e
    ON e.stream_id = c.stream_id AND e.user_pseudo_id = c.user_pseudo_id
    AND e.event_timestamp > c.t0 AND e.event_timestamp <= c.window_end
    AND e.event_name = 'level_start' AND e.game_mode = 'endless'
    AND e.play_context = 'solo' AND e.level = 1
  GROUP BY 1,2,3,4,5
), completed_one AS (
  SELECT c.*, MIN(e.event_timestamp) AS t_level1
  FROM fresh_move c LEFT JOIN events e
    ON e.stream_id = c.stream_id AND e.user_pseudo_id = c.user_pseudo_id
    AND e.event_timestamp > c.t_move AND e.event_timestamp <= c.window_end
    AND e.event_name = 'level_end' AND e.success = 1
    AND e.game_mode = 'endless' AND e.play_context = 'solo' AND e.level = 1
  GROUP BY c.stream_id, c.user_pseudo_id, c.cohort_day, c.t0, c.window_end, c.t_move
), completed_three AS (
  SELECT c.*, MIN(e.event_timestamp) AS t_level3
  FROM completed_one c LEFT JOIN events e
    ON e.stream_id = c.stream_id AND e.user_pseudo_id = c.user_pseudo_id
    AND e.event_timestamp > c.t_level1 AND e.event_timestamp <= c.window_end
    AND e.event_name = 'level_end' AND e.success = 1
    AND e.game_mode = 'endless' AND e.play_context = 'solo' AND e.level = 3
  GROUP BY c.stream_id, c.user_pseudo_id, c.cohort_day, c.t0, c.window_end, c.t_move, c.t_level1
), completed_five AS (
  SELECT c.*, MIN(e.event_timestamp) AS t_level5
  FROM completed_three c LEFT JOIN events e
    ON e.stream_id = c.stream_id AND e.user_pseudo_id = c.user_pseudo_id
    AND e.event_timestamp > c.t_level3 AND e.event_timestamp <= c.window_end
    AND e.event_name = 'level_end' AND e.success = 1
    AND e.game_mode = 'endless' AND e.play_context = 'solo' AND e.level = 5
  GROUP BY c.stream_id, c.user_pseudo_id, c.cohort_day, c.t0, c.window_end, c.t_move, c.t_level1, c.t_level3
), counts AS (
  SELECT cohort_day, COUNT(*) AS observed_first_open_installations,
    COUNTIF(t_move IS NOT NULL) AS first_move_installations,
    COUNTIF(t_level1 IS NOT NULL) AS activated_installations,
    COUNTIF(t_level3 IS NOT NULL) AS level3_installations,
    COUNTIF(t_level5 IS NOT NULL) AS level5_installations
  FROM completed_five GROUP BY cohort_day
), coverage AS (
  SELECT cohort_label AS cohort_day, COUNTIF(e.day IS NOT NULL) = 3 AS export_days_present
  FROM UNNEST(GENERATE_DATE_ARRAY(@cohort_start, @cohort_end)) cohort_label
  CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(cohort_label, DATE_ADD(cohort_label, INTERVAL 2 DAY))) required_day
  LEFT JOIN exported_days e ON e.day = required_day
  GROUP BY cohort_label
)
SELECT c.cohort_day, v.export_days_present,
  c.observed_first_open_installations,
  IF(v.export_days_present, c.first_move_installations, NULL) AS first_move_installations,
  IF(v.export_days_present, c.activated_installations, NULL) AS activated_installations_24h,
  IF(v.export_days_present, c.level3_installations, NULL) AS level3_installations_24h,
  IF(v.export_days_present, c.level5_installations, NULL) AS level5_installations_24h,
  IF(v.export_days_present, SAFE_DIVIDE(c.activated_installations, c.observed_first_open_installations), NULL) AS activation_rate_24h
FROM counts c JOIN coverage v USING (cohort_day)
ORDER BY cohort_day;
