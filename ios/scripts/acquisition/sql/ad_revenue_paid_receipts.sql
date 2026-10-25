-- PREPARED GoogleSQL: offline-reviewed only; not executed in BigQuery.
-- Requires a future app release and verified exported ad_revenue_paid rows.
-- DATE parameters: start_date, end_date (inclusive; at most 31 past days).
-- Confirm a <100 MB estimate and set maximum_bytes_billed=100000000 externally.
-- Uses the actual event schema observed in events_20260920 on September 22;
-- custom parameter receipt/types still require validation after release.
-- This is SDK receipt telemetry, not GA4 Total ad revenue or AdMob earnings.
ASSERT @start_date <= @end_date AS 'Invalid date bounds';
ASSERT DATE_DIFF(@end_date, @start_date, DAY) < 31 AS 'Limit the receipt scan to 31 days';
ASSERT @end_date < CURRENT_DATE('America/Los_Angeles') AS 'Use past daily exports only';

WITH exported_days AS (
  SELECT SAFE.PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)) AS event_day
  FROM `prism-roll.analytics_554682731.INFORMATION_SCHEMA.TABLES`
  WHERE REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}$')
    AND table_name BETWEEN CONCAT('events_', FORMAT_DATE('%Y%m%d', @start_date))
      AND CONCAT('events_', FORMAT_DATE('%Y%m%d', @end_date))
), receipts AS (
  SELECT
    PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) AS event_day,
    event_date = _TABLE_SUFFIX AS date_label_matches_table,
    app_info.version AS app_version,
    -- Duplicate keys are invalid rather than resolved arbitrarily with LIMIT 1.
    (SELECT IF(COUNT(*) = 1, ANY_VALUE(COALESCE(value.double_value,
        value.float_value, CAST(value.int_value AS FLOAT64))), NULL)
      FROM UNNEST(event_params) WHERE key = 'ad_value') AS raw_ad_value,
    (SELECT IF(COUNT(*) = 1, ANY_VALUE(value.string_value), NULL)
      FROM UNNEST(event_params) WHERE key = 'ad_currency') AS raw_currency,
    (SELECT IF(COUNT(*) = 1, ANY_VALUE(value.int_value), NULL)
      FROM UNNEST(event_params) WHERE key = 'ad_value_precision') AS raw_precision,
    (SELECT IF(COUNT(*) = 1, ANY_VALUE(value.string_value), NULL)
      FROM UNNEST(event_params) WHERE key = 'ad_format') AS raw_format,
    EXISTS (SELECT 1 FROM UNNEST(event_params)
      WHERE key IN ('debug_mode', '_dbg')
        AND (value.int_value = 1 OR LOWER(value.string_value) IN ('1', 'true')))
      AS debug_marked,
    EXISTS (SELECT 1 FROM UNNEST(event_params)
      WHERE (key = 'traffic_type' AND value.string_value = 'internal')
        OR (key IN ('qa_run', 'qa_run_id') AND NULLIF(value.string_value, '') IS NOT NULL))
      AS qa_marked
  FROM `prism-roll.analytics_554682731.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', @start_date)
    AND FORMAT_DATE('%Y%m%d', @end_date)
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^[0-9]{8}$')
    AND event_name = 'ad_revenue_paid'
    AND stream_id = '15792271279'
    AND platform = 'IOS'
    AND app_info.id = 'com.jonluca.prismroll'
    AND privacy_info.analytics_storage = 'Yes'
), validated AS (
  SELECT event_day, app_version, date_label_matches_table,
    IF(raw_ad_value >= 0 AND NOT IS_NAN(raw_ad_value) AND NOT IS_INF(raw_ad_value),
      raw_ad_value, NULL) AS ad_value,
    IF(REGEXP_CONTAINS(raw_currency, r'^[A-Z]{3}$'), raw_currency, NULL) AS currency,
    IF(raw_precision BETWEEN 0 AND 3, raw_precision, NULL) AS value_precision,
    IF(raw_format IN ('rewarded', 'interstitial'), raw_format, NULL) AS ad_format,
    CASE
      WHEN debug_marked AND qa_marked THEN 'debug_and_internal_qa_marked'
      WHEN debug_marked THEN 'debug_marked'
      WHEN qa_marked THEN 'internal_qa_marked'
      ELSE 'unclassified_no_exported_qa_marker'
    END AS traffic_status
  FROM receipts
), checked AS (
  SELECT *,
    COALESCE(date_label_matches_table, FALSE)
      AND ad_value IS NOT NULL AND currency IS NOT NULL
      AND value_precision IS NOT NULL AND ad_format IS NOT NULL AS parameters_valid
  FROM validated
), grouped AS (
  SELECT event_day, app_version, currency, ad_format, value_precision, traffic_status,
    COUNT(*) AS receipt_rows,
    COUNTIF(NOT parameters_valid) AS invalid_parameter_receipt_rows,
    -- Never silently return a partial total when a receipt in the group is invalid.
    IF(COUNTIF(parameters_valid) = COUNT(*), SUM(ad_value), NULL) AS reported_ad_value_sum
  FROM checked
  GROUP BY event_day, app_version, currency, ad_format, value_precision, traffic_status
)
SELECT requested_day AS event_day,
  e.event_day IS NOT NULL AS daily_table_present,
  CASE
    WHEN e.event_day IS NULL THEN 'missing_daily_table'
    WHEN g.receipt_rows IS NULL THEN 'daily_table_has_no_matching_receipt_rows'
    ELSE 'receipt_rows_present'
  END AS coverage_status,
  IF(requested_day >= DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 3 DAY),
    'within_ordinary_late_arrival_window', 'past_ordinary_late_arrival_window') AS date_maturity,
  g.app_version, g.currency, g.ad_format, g.value_precision, g.traffic_status,
  g.receipt_rows, g.invalid_parameter_receipt_rows, g.reported_ad_value_sum
FROM UNNEST(GENERATE_DATE_ARRAY(@start_date, @end_date)) AS requested_day
LEFT JOIN exported_days e ON e.event_day = requested_day
LEFT JOIN grouped g ON g.event_day = requested_day
ORDER BY event_day, app_version, currency, ad_format, value_precision, traffic_status;
