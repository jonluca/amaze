# Apple acquisition collector

Read-only acquisition reporting for Prism Roll. Uses the installed `asc` CLI and its existing Keychain/API authentication; Python 3.10+ standard library only. No native SDK change, Google credentials, request creation, release action, or automation is performed.

```sh
python3 ios/scripts/acquisition/collector.py
python3 -m unittest discover -s ios/scripts/acquisition -p 'test_*.py' -v
```

Default app: `6809253424`. Existing ongoing request: `3d6744a6-8d0e-408c-b0b3-1ecd6ec075eb`. The collector validates that this request is active and that the configured report IDs have their expected names. It stops rather than creating/replacing a request. Run `asc analytics requests --help`, `asc analytics reports --help`, `asc analytics instances --help`, and `asc analytics download --help` when upgrading the CLI.

Outputs live under ignored `ios/release/acquisition/`, separate from historical `growth-2026-09-16/baseline/`. Existing historical baseline/latest pointers are never written. Override with `--output /absolute/path`; use a separate output directory per app/request. `--days 7` controls the displayed window ending at the latest published Date label. It does not invent rows for missing dates. Full available history remains in exports.

The first run imports verified ongoing segment bytes from the historical baseline's `downloaded_reports` when present. `--seed-baseline` accepts a baseline JSON or its `latest.json` pointer. A missing seed is harmless. Subsequent runs download only unknown segment IDs; cached compressed/decoded bytes are hash-checked. Each run still checks current request/report/instance metadata. Locally cached old instances are retained when they age out of Apple's API. A process lock prevents overlapping collectors; a failed refresh records `failure.json` and leaves the previous successful latest pointer intact. Calls have a 45-second timeout and are not retried automatically.

## Files

- `dashboard.html`: stable local entry point to the latest successful report.
- `latest.json`: successful run pointer, canonical and metric fingerprints, check timestamp.
- `runs/<timestamp>/summary.json`, `report.md`, `dashboard.html`: combined Apple discovery/download/session/opt-in baseline and missing-data caveats.
- `partitions.json`: complete Date partitions with processing date, instance provenance, and provisional flag.
- `observations.jsonl` and `observations.csv`: normalized long-form measures, population labels, raw fields and provenance.
- `daily-source-territory.csv`: additive measures grouped by Date/source/territory for the displayed window. Blank values mean unavailable.
- `ingestion-manifest.json`, `api/*.json`: source relationships and segment hashes. Do not publish these account-level evidence files publicly.
- `cache/segments/<id>/`: immutable raw gzip bytes, decoded TSV, and SHA-256 manifest.

## Interpretation and corrections

Only Standard discovery/download/session reports and App Opt In are ingested. Snapshot, Detailed and weekly/monthly totals are excluded. All segments of an instance are read before processing. Within **report type + granularity + Date**, the greatest `processingDate` replaces the entire earlier Date partition. Older dates absent from a newer instance are retained. Identical-looking rows inside one batch are not arbitrarily deduplicated. Conflicting batches with the same processing date fail closed. Processing date changes without changed rows are separated from metric changes.

`Counts` is interpreted by Event or Download Type. First-time downloads are Apple-ID-based Get/Buy actions; updates, restores and redownloads are separate. Download attribution `Page Type=Product page` is not a page-view count. Unique Counts/Unique Devices are emitted with `additive=false` and never totaled across breakdowns. Opt-in counts and ratios remain per published row. Sessions are opted-in usage, not all users. There is no cross-platform user-level join or automatic conversion/retention calculation.

Missing metrics are null, not zero. Published Standard rows can still have privacy limitations. Completeness windows documented by Apple: discovery 3 days, downloads 2, sessions 5, opt-in 3. Sessions require at least five opted-in users for the respective report. A `provisional=false` partition has reached the documented processing-date interval, but later corrections remain possible. Report Date timezone is not inferred, and release-day aggregates cannot isolate a release timestamp.

## BigQuery / Looker handoff

`bigquery-schema.json` describes `observations.jsonl`. Load each successful canonical snapshot with **WRITE_TRUNCATE** into a dedicated current table; do not blindly append successive snapshots because each contains corrected historical partitions. For audit history, write each complete snapshot to its own run partition/table and select one run before aggregation. Keep raw cache/manifests in private storage.

Example after an authorized project/dataset is available (the collector does not run this):

```sh
bq load --replace --source_format=NEWLINE_DELIMITED_JSON PROJECT:DATASET.apple_acquisition_current /absolute/run/observations.jsonl ios/scripts/acquisition/bigquery-schema.json
```

`looker-aggregate.sql` is a template over that table. It only sums explicitly additive event measures; unique/opt-in counts stay out. Null sums must remain null in charts. Retain `report_key`, `population`, source, Date and metric labels when combining with separate GA4 web or Firebase app reporting. Put those datasets alongside Apple metrics with explicit labels; they do not have a shared user denominator. No Google account/project is embedded in these files.

Daily scheduling is intentionally external. The owner can schedule the command and use `metrics_changed` plus errors to decide notifications. A successful empty report is not an acquisition failure; it is an availability observation.

## Primary references

- [Data completeness and corrections](https://developer.apple.com/documentation/analytics-reports/data-completeness-corrections)
- [Discovery and engagement](https://developer.apple.com/documentation/analytics-reports/app-store-discovery-and-engagement)
- [Downloads](https://developer.apple.com/documentation/analytics-reports/app-download)
- [Sessions](https://developer.apple.com/documentation/analytics-reports/app-sessions)
- [Opt-in](https://developer.apple.com/documentation/analytics-reports/app-store-opt-in)
