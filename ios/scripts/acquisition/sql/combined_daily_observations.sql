-- GoogleSQL TEMPLATE, not executed. No user-level or denominator join.
-- Required DATE parameters: start_date, end_date.
-- Apple table must first be loaded from collector observations.jsonl using
-- WRITE_TRUNCATE. Replace the reporting dataset name if configured differently.
ASSERT @start_date <= @end_date AS 'Invalid date bounds';

WITH ga_events AS (
  SELECT stream_id, platform, user_pseudo_id, event_name,
    PARSE_DATE('%Y%m%d', event_date) AS event_day,
    geo.country AS country_name,
    COALESCE((SELECT NULLIF(value.string_value, '') FROM UNNEST(event_params)
      WHERE key = 'campaign_source' LIMIT 1), collected_traffic_source.manual_source) AS source_label,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'apple_ct' LIMIT 1) AS campaign_token
  FROM `prism-roll.analytics_554682731.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', @start_date) AND FORMAT_DATE('%Y%m%d', @end_date)
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^[0-9]{8}$')
    AND ((stream_id = '15792271279' AND platform = 'IOS' AND app_info.id = 'com.jonluca.prismroll')
      OR (stream_id = '15812996264' AND platform = 'WEB'))
    AND COALESCE(privacy_info.analytics_storage, 'Unset') != 'No'
    AND NOT EXISTS (SELECT 1 FROM UNNEST(event_params)
      WHERE key IN ('debug_mode', '_dbg')
      AND (value.int_value = 1 OR LOWER(value.string_value) IN ('1', 'true')))
    AND event_name IN ('first_open', 'session_start', 'user_engagement', 'level_start',
                      'level_end', 'page_view', 'app_store_click')
), ga_counts AS (
  SELECT stream_id, platform, event_day, country_name, source_label, campaign_token, event_name,
    COUNT(*) AS event_count,
    IF(COUNTIF(user_pseudo_id IS NOT NULL) > 0, COUNT(DISTINCT user_pseudo_id), NULL) AS observed_identities
  FROM ga_events
  GROUP BY stream_id, platform, event_day, country_name, source_label, campaign_token, event_name
), ga_long AS (
  SELECT event_day AS date_label, 'GA4' AS source_system, stream_id,
    IF(platform = 'IOS', 'Consented observable app installations', 'Consented observable web browsers') AS population,
    measure.metric_name, measure.metric_value, measure.additive_across_rows,
    source_label, country_name AS territory_label, 'GA4 country name' AS territory_definition,
    campaign_token
  FROM ga_counts CROSS JOIN UNNEST([
    STRUCT(CONCAT(event_name, '_events') AS metric_name, event_count AS metric_value, TRUE AS additive_across_rows),
    STRUCT(CONCAT(event_name, '_identities_in_group') AS metric_name, observed_identities AS metric_value, FALSE AS additive_across_rows)
  ]) measure
), apple AS (
  SELECT event_date AS date_label, 'Apple App Store' AS source_system,
    CAST(NULL AS STRING) AS stream_id, population,
    metric_name, IF(COUNTIF(metric_value IS NULL) > 0, NULL, SUM(metric_value)) AS metric_value,
    TRUE AS additive_across_rows, source_type AS source_label,
    territory AS territory_label, 'Apple storefront territory code' AS territory_definition,
    CAST(NULL AS STRING) AS campaign_token
  FROM `prism-roll.reporting.apple_acquisition_current`
  WHERE event_date BETWEEN @start_date AND @end_date AND additive IS TRUE
  GROUP BY event_date, population, metric_name, source_type, territory
)
SELECT * FROM apple
UNION ALL
SELECT * FROM ga_long;
