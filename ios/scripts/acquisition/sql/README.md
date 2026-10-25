# GA4 BigQuery analysis templates

These are **prepared GoogleSQL templates**, not live dashboard results. Daily exports use project `prism-roll`, region `US`, dataset `analytics_554682731`. The first export was verified on September 23; the October 25 table inventory contained `events_20260920`, `events_20260927` and `events_20261018`. That inventory does not establish complete date coverage or validate these full reports. Inspect actual `events_YYYYMMDD` tables before validating/executing each template. No historical backfill is assumed.

Known streams: iOS `15792271279` (`com.jonluca.prismroll`), web `15812996264` (`playprismroll.com`). The property timezone is America/Los_Angeles. Queries use exported `event_date` calendar labels instead of guessing UTC. `event_timestamp` is used only for ordered 24-hour activation. The Apple Date timezone remains independently unverified; matching date labels do not establish a common clock or audience.

## Saved GA4 views

The [Prism Roll — opted-in activation & retention exploration](https://analytics.google.com/analytics/web/?authuser=0&hl=en-US#/analysis/a90475221p554682731/edit/yr8C1U_GT0SbkN9kbcK8Rw) was saved and read back after reloading on September 20, 2026. Its two tabs are:

- **Ordered Classic progression**: closed first_open → Classic solo level 1 move → Classic solo levels 1, 3 and 5 completed. Each gameplay step filters Game mode `endless`, Play context `solo` and the appropriate Level number. The tab filters Stream ID `15792271279`. There is no overall 24-hour restriction in this UI view; the SQL below supplies that separate, stricter definition. The UI has no registered success dimension, so it relies on the app's completion-only `level_end` contract; SQL explicitly checks `success=1`.
- **D1/D7 — active session return**: first_open inclusion, session_start return, Daily granularity, Standard calculation, Active users metric, and the `Prism iOS stream` user segment (Stream exactly Prism Roll iOS). Day 1 and Day 7 are exact calendar intervals, not cumulative or rolling. The UI disables Total users for this technique. Its active-session numerator is narrower than the foreground-return SQL below; do not interchange the rates.

These are device-based, consenting-app observations, not total installations. The exploration's default last-28-day range includes early test/debug traffic unless a property filter excludes it; no acquisition or retention conclusion was drawn from its tiny current counts. The SQL explicitly excludes available debug markers. UI cohort counts without observed users or mature return days do not establish a population-wide zero. Saved configuration screenshots and readback text are in ignored `ios/release/acquisition/validation/ga4-*`.

## Activation and progression

`activation_funnel.sql` selects observable installation identities with `first_open` in a chosen cohort-date range and follows this closed, ordered funnel within **24 hours from that first_open**:

1. Firebase `first_open`.
2. First accepted move on Classic solo level 1: `level_start`, `game_mode=endless`, `play_context=solo`, `level=1`.
3. Classic solo level 1 completed: `level_end`, the same filters, `success=1`.
4. Classic solo level 3 completed after level 1.
5. Classic solo level 5 completed after level 3.

Activation is step 3 divided by the observed first_open cohort; levels 3/5 describe subsequent progression. These are installation-level milestones, not attempt-level completion rates; there is no stable shared run identifier in these events. Events must have strictly increasing timestamps, so ambiguous timestamp ties are conservatively excluded. The SQL does not count resumed level 1 as a fresh start. Supply DATE query parameters `cohort_start`, `cohort_end`, `complete_through`. The latter must allow the full window and GA4 late-arrival handling; the query requires two following calendar export days and makes step counts null if those daily tables are missing.

## Exact D1 / D7 retention

`exact_d1_d7_retention.sql` uses the same stream-scoped, first_open installation cohort. A return means at least one `session_start`, `user_engagement`, `level_start`, or `level_resumed` event on **exactly cohort Date + 1** or **exactly cohort Date + 7**. This is calendar-day return, not “within 24/168 hours,” rolling retention, or return on/after a day. Multiple return events count once per installation on that day.

Parameters are `cohort_start`, `cohort_end`, `complete_through`. A cohort is eligible for a horizon only if its exact target date is at or before the supplied complete-through date and that daily table exists. Immature/missing-data returns, denominators and rates are null. A mature published target table with no return for a known cohort member contributes a non-return; it does not mean all unobserved installs failed to return. No cohort with no observed first_open is fabricated as zero.

## Consent and cohort limits

The shipped native SDK starts usage collection only after explicit consent; web GA4 also loads after consent. Queries exclude `analytics_storage=No`, missing installation IDs, and exported `debug_mode`/`_dbg` traffic. `Unset`/null storage labels are retained under the application's explicit collection gate, and must not be relabeled as independently proven consent from the export alone. If that gate changes, revisit these filters. Ordinary Debug/XCTest/UI-test runs suppress collection; manually enabled debug traffic may still require inspection.

`first_open` is **not an App Store download**. Late consent, reinstall, data reset, identity reset, missing export history and identifier churn affect the observable cohort. `user_pseudo_id` is stream-scoped and installation/browser-based, not a durable human identity; no Game Center/email/user_id join is used. Rows without identifiers cannot enter these user-based funnels. People who declined analytics remain outside the denominator. Cohort rates must never be divided by Apple downloads or presented as all-user retention.

GA4 daily tables can be revised for late arrivals for up to three days. Verify the property's timezone and select a conservative `complete_through` after that window; a table existing is not itself proof that its contents are final. The explicit supplied cutoff plus table-presence guard is required. Current/intraday data is excluded.

## Combined dashboard data

`combined_daily_observations.sql` places Apple and GA4 rows alongside one another with `UNION ALL`; it never joins identities or manufactures a common conversion denominator. Load collector `observations.jsonl` into `prism-roll.reporting.apple_acquisition_current` with WRITE_TRUNCATE first, or edit that table reference to the authorized target. This collector does not create that dataset/table.

Web events are `page_view` and `app_store_click`. The latter measures an outbound click, not installation or launch. Approved `apple_ct` campaign tokens and `campaign_source` remain web dimensions; they do not prove which Apple download belongs to that visitor. Apple territory codes and GA4 country names are explicitly labeled separately. Event counts can be summed within their metric/population; distinct identities cannot be added across date/source/event groups. Apple unique counts are excluded from the additive union.

## Prepared paid-impression receipt diagnostic

`ad_revenue_paid_receipts.sql` is prepared for the **unreleased** custom `ad_revenue_paid` event described in [native analytics](../../../ANALYTICS.md#next-build-paid-callback-diagnostic). It has not been run in BigQuery and is **not operational** until a new app build is released, ordinary opted-in ad activity produces a receipt, and the exported parameter types are verified. The base fields match the actual `events_20260920` schema inspected on September 22, 2026; that older table cannot establish receipt of this new event. Automatic publisher `ad_impression` events are not exported to BigQuery, so this separate diagnostic does not replace GA4 Publisher ads or AdMob reports.

Supply inclusive DATE parameters `start_date` and `end_date`, spanning at most 31 past dates. The query uses only daily tables, iOS stream `15792271279`, the Prism Roll bundle, and `analytics_storage=Yes`. It returns aggregate receipt-row counts and custom `ad_value` sums by exported day, app version, currency, ad format, SDK precision and QA/debug status. It reads no installation identifiers and calculates no unique-user or acquisition totals. No QA marker means **unclassified**, not proven customer activity. Precision 0 means unknown; a reported zero is preserved and is not evidence of positive payment. Keep currencies, precision classes, QA groups and source populations separate, and never add these amounts to GA4 standard revenue, purchases, or AdMob earnings.

Missing or malformed parameters remain null. A group containing an invalid receipt has a null amount total rather than a partial sum. Missing daily tables and daily tables with no matching receipts have distinct coverage labels, with null counts/amounts rather than fabricated zero revenue. The date-maturity label uses the property's verified America/Los_Angeles timezone and Google's ordinary three-day late-arrival window; it does not certify complete coverage or rule out later corrections. Debug traffic may be excluded from exports, and people who decline analytics remain outside this diagnostic population.

Before any execution, inspect the current schema and table inventory, use the signed-in project/account already verified for this task, and validate the full query. Confirm the estimate is **below 100 MB** and set **Maximum bytes billed to `100000000`** in the editor's **Edit → Query settings → Advanced options**. Do not switch CLI identities, enable billing/streaming, or create persistent tables. Start with one known daily export date after the release; expand only when the displayed estimate remains within the cap. An offline parser check is not a BigQuery dry run or proof of provider receipt.

## Cost, retention and validation

The observed Firebase export setup UI on September 20, 2026 explicitly states a **10 GiB lifetime storage limit** for this sandbox export: reaching it stops Firebase export, and deleting or expiring data does not reset that quota. This export-specific restriction is distinct from generic BigQuery sandbox documentation describing 10 GiB active storage. The owner preserved the actual UI wording in `ios/ANALYTICS.md`; do not assume that deleting tables restores Firebase export eligibility. The sandbox also has a 1 TiB monthly query allowance, automatic 60-day table expiry, and no intraday streaming. Expiry can remove historical cohorts and return days, so export approved aggregate results to durable storage if longer retention is needed. Daily export starts prospectively; do not infer pre-export zeros.

All queries bound `_TABLE_SUFFIX` using DATE parameters to prune tables. Before execution, dry-run with the actual dataset available, set a maximum-bytes-billed limit, inspect schema/parameter types, and confirm stream IDs and timezone. No billed query or storage setup is performed by these templates. Prefer aggregate output tables for Looker; protect source pseudonymous identifiers and do not expose raw events in public dashboards.

Example after the export exists:

```sh
bq query --use_legacy_sql=false --dry_run --parameter=cohort_start:DATE:2026-09-21 --parameter=cohort_end:DATE:2026-09-21 --parameter=complete_through:DATE:2026-09-28 < ios/scripts/acquisition/sql/exact_d1_d7_retention.sql
```

Dates above illustrate parameter syntax only; they are not evidence of available or complete tables.

Primary references: [GA4 BigQuery export schema and late arrivals](https://support.google.com/analytics/answer/7029846), [BigQuery sandbox limits](https://cloud.google.com/bigquery/docs/sandbox), and the repository's [native event semantics](../../../ANALYTICS.md).
