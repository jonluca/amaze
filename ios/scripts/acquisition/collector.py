#!/usr/bin/env python3
"""Read-only Apple aggregate reporting. Python 3.10+, asc CLI, no SDK credentials."""

from __future__ import annotations

import argparse
import csv
import fcntl
import gzip
import hashlib
import html
import io
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

APP_ID = "6809253424"
REQUEST_ID = "3d6744a6-8d0e-408c-b0b3-1ecd6ec075eb"
REPORTS = {
    "discovery": {"prefix": "r14", "name": "App Store Discovery and Engagement Standard", "days": 3},
    "downloads": {"prefix": "r3", "name": "App Downloads Standard", "days": 2},
    "sessions": {"prefix": "r8", "name": "App Sessions Standard", "days": 5},
    "opt_in": {"prefix": "r189", "name": "App Opt In", "days": 3},
}
NUMERIC_FIELDS = {"Counts", "Unique Counts", "Sessions", "Total Session Duration",
                  "Unique Devices", "Downloading Users", "Users Opting-In"}
CAVEATS = [
    "Missing or suppressed metrics are null, never inferred zero. Published rows do not establish complete population totals.",
    "Latest processingDate replaces the ENTIRE Date partition within one report and granularity. Snapshot and Detailed reports are excluded.",
    "Unique Counts, Unique Devices and opt-in user counts are not added across breakdowns or dates. No user-level join is possible.",
    "First-time downloads are Apple-ID-based Get/Buy actions, not proof of installation or active players. Updates/restores/redownloads are separate.",
    "Product page in download attribution is not a page-view count. Search may include ads; Standard reports do not identify campaign or referring app.",
    "Sessions represent opted-in users and require at least five users for the report. Absence does not prove zero usage or permanent suppression.",
    "Completeness windows: discovery/opt-in 3 days, downloads 2, sessions 5; corrections can arrive later. Fresh dates remain provisional.",
    "Date timezone is not asserted. Release-day aggregates may mix periods. Apple, GA4 web and Firebase app populations must remain separate.",
    "No conversion or retention rate is computed from unmatched dates, sources, user populations, or event versus unique counts.",
]


def stamp():
    return datetime.now(timezone.utc).isoformat()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temp.replace(path)


def load_json(path):
    return json.loads(path.read_text())


def parse_rows(data, app_id):
    reader = csv.DictReader(io.StringIO(data.decode("utf-8-sig")), delimiter="\t")
    if not reader.fieldnames or "Date" not in reader.fieldnames or "App Apple Identifier" not in reader.fieldnames:
        raise ValueError("Unexpected report header; no canonical data published")
    rows = []
    for row in reader:
        if None in row or any(value is None for value in row.values()):
            raise ValueError("Malformed TSV row")
        if row["App Apple Identifier"] != app_id:
            raise ValueError("Report contains a different app")
        date.fromisoformat(row["Date"])
        for field in NUMERIC_FIELDS & row.keys():
            row[field] = int(row[field]) if row[field] != "" else None
        rows.append(row)
    return rows


def validate_fields(key, rows):
    required = {"discovery": {"Event", "Page Type", "Counts", "Unique Counts"},
                "downloads": {"Download Type", "Counts"},
                "sessions": {"Sessions", "Total Session Duration", "Unique Devices"},
                "opt_in": {"Downloading Users", "Users Opting-In"}}[key]
    if any(not required <= row.keys() for row in rows):
        raise ValueError(f"Unexpected {key} report fields")


def canonicalize(instances):
    """Whole-date replacement, across ALL segments of an instance. Never row-dedup."""
    partitions = {}
    for instance in sorted(instances, key=lambda x: (x["processing_date"], x["instance_id"])):
        if instance["request_type"] != "ONGOING" or instance["granularity"] != "DAILY":
            continue
        batches = {}
        for row in instance["rows"]:
            batches.setdefault(row["Date"], []).append(row)
        for day, rows in batches.items():
            key = (instance["report_key"], instance["granularity"], day)
            previous = partitions.get(key)
            if previous and previous["processing_date"] == instance["processing_date"]:
                # IDs cannot break an undocumented same-processing-date tie safely.
                if sorted(map(lambda r: json.dumps(r, sort_keys=True), previous["rows"])) != sorted(map(lambda r: json.dumps(r, sort_keys=True), rows)):
                    raise ValueError(f"Conflicting same-processing-date batches for {key}")
                continue
            partitions[key] = {"report_key": instance["report_key"], "date": day,
                               "granularity": instance["granularity"],
                               "processing_date": instance["processing_date"],
                               "instance_id": instance["instance_id"], "rows": rows,
                               "provisional": (date.fromisoformat(instance["processing_date"]) - date.fromisoformat(day)).days < REPORTS[instance["report_key"]]["days"]}
    return [partitions[key] for key in sorted(partitions)]


def metric_fingerprint(partitions):
    # Ignore processing metadata, row order and cosmetic app-name updates.
    normalized = []
    for partition in partitions:
        rows = [{k: v for k, v in row.items() if k != "App Name"} for row in partition["rows"]]
        normalized.append({"report_key": partition["report_key"], "date": partition["date"],
                           "rows": sorted(rows, key=lambda r: json.dumps(r, sort_keys=True))})
    return digest(json.dumps(normalized, sort_keys=True).encode())


def row_measures(key, row):
    """Explicit additive whitelist; uniqueness and opt-in users stay row scoped."""
    if key == "discovery":
        event = row["Event"].casefold()
        metric = {"impression": "impression_events", "tap": "tap_events"}.get(event, "page_view_events" if event == "page view" else "discovery_other_events")
        if event == "page view" and row["Page Type"].casefold() == "product page":
            metric = "product_page_view_events"
        return [(metric, row["Counts"], True), ("unique_counts_in_row", row["Unique Counts"], False)]
    if key == "downloads":
        kind = re.sub(r"[^a-z0-9]+", "_", row["Download Type"].casefold()).strip("_")
        return [("download_" + kind, row["Counts"], True)]
    if key == "sessions":
        return [("session_events", row["Sessions"], True),
                ("session_duration_seconds", row["Total Session Duration"], True),
                ("unique_devices_in_row", row["Unique Devices"], False)]
    return [("downloading_users_in_row", row["Downloading Users"], False),
            ("users_opting_in_in_row", row["Users Opting-In"], False)]


def observations(partitions, app_id, request_id):
    output = []
    for partition in partitions:
        key = partition["report_key"]
        for index, row in enumerate(partition["rows"]):
            for metric, value, additive in row_measures(key, row):
                output.append({
                    "app_id": app_id, "request_id": request_id, "report_key": key,
                    "event_date": row["Date"], "processing_date": partition["processing_date"],
                    "granularity": "DAILY", "instance_id": partition["instance_id"],
                    "row_index": index, "source_type": row.get("Source Type") or None,
                    "territory": row.get("Territory") or None, "device": row.get("Device") or None,
                    "app_version": row.get("App Version") or None, "page_type": row.get("Page Type") or None,
                    "event_type": row.get("Event") or row.get("Download Type") or key,
                    "metric_name": metric, "metric_value": value, "additive": additive,
                    "population": "Apple opted-in usage" if key == "sessions" else "Apple first-time downloaders" if key == "opt_in" else "Apple App Store aggregate",
                    "raw_fields_json": json.dumps(row, sort_keys=True, ensure_ascii=False),
                })
    return output


def summarize(partitions, days=7):
    data = observations(partitions, APP_ID, REQUEST_ID)
    dates = [r["event_date"] for r in data]
    end = max(dates) if dates else None
    start = (date.fromisoformat(end) - timedelta(days=days - 1)).isoformat() if end else None
    selected = [r for r in data if start <= r["event_date"] <= end] if end else []
    grouped = {}
    for row in selected:
        if not row["additive"]:
            continue
        key = (row["event_date"], row["source_type"], row["territory"], row["metric_name"])
        group = grouped.setdefault(key, {"values": [], "missing": False})
        group["missing"] |= row["metric_value"] is None
        if row["metric_value"] is not None:
            group["values"].append(row["metric_value"])
    aggregates = [{"event_date": k[0], "source_type": k[1], "territory": k[2], "metric_name": k[3],
                   "metric_value": None if v["missing"] else sum(v["values"])}
                  for k, v in sorted(grouped.items(), key=lambda x: tuple(str(v) for v in x[0]))]
    def total(metric):
        values = [r["metric_value"] for r in selected if r["metric_name"] == metric]
        return sum(values) if values and all(v is not None for v in values) else None
    opt_in_rows = []
    for partition in partitions:
        if partition["report_key"] != "opt_in" or not start <= partition["date"] <= end:
            continue
        for row in partition["rows"]:
            denominator, numerator = row["Downloading Users"], row["Users Opting-In"]
            opt_in_rows.append({"event_date": row["Date"], "downloading_users_in_row": denominator,
                "users_opting_in_in_row": numerator,
                "rate_in_row": numerator / denominator if denominator and numerator is not None and 0 <= numerator <= denominator else None})
    return {"window_start": start, "window_end": end, "window_days": days,
            "window_basis": "Latest published report Date label; missing dates are not filled with zeros; timezone not inferred",
            "observed_metrics": {"impression_events": total("impression_events"),
                "first_time_downloads": total("download_first_time_download"),
                "product_page_view_events": total("product_page_view_events"),
                "session_events": total("session_events"), "session_duration_seconds": total("session_duration_seconds"),
                "unique_users": None, "active_devices": None, "opt_in_rate": None,
                "conversion_rate": None, "retention": None},
            "by_date_source_territory": aggregates, "opt_in_rows": opt_in_rows,
            "report_availability": {key: {"published_row_count": sum(len(p["rows"]) for p in partitions if p["report_key"] == key),
                "latest_event_date": max((p["date"] for p in partitions if p["report_key"] == key), default=None),
                "completeness_days": spec["days"]} for key, spec in REPORTS.items()}}


class Asc:
    def __init__(self, evidence, executable="asc", timeout=45):
        self.evidence, self.executable, self.timeout = evidence, executable, timeout

    def call(self, arguments, name):
        try:
            result = subprocess.run([self.executable, "analytics", *arguments], capture_output=True,
                                    text=True, timeout=self.timeout, check=False)
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"{name}: ASC timed out after {self.timeout}s; not retried") from None
        # Never echo signed segment URLs or auth material to logs/errors.
        if result.returncode:
            raise RuntimeError(f"{name}: ASC exited {result.returncode}; no mutation attempted")
        try:
            value = json.loads(result.stdout)
        except ValueError:
            raise RuntimeError(f"{name}: ASC returned invalid JSON") from None
        save_json(self.evidence / (name + ".json"), value)
        return value


def segment_cache(root, segment_id, metadata=None, raw_source=None, app_id=APP_ID):
    folder = root / "cache" / "segments" / segment_id
    manifest = folder / "manifest.json"
    if manifest.exists():
        value = load_json(manifest)
        raw, decoded = folder / "report.txt.gz", folder / "report.txt"
        if digest(raw.read_bytes()) != value["raw_sha256"] or digest(decoded.read_bytes()) != value["decoded_sha256"]:
            raise ValueError(f"Cached segment {segment_id} failed hash verification")
        return value, parse_rows(decoded.read_bytes(), app_id)
    if raw_source is None:
        return None
    raw_bytes = raw_source.read_bytes()
    decoded_bytes = gzip.decompress(raw_bytes)
    rows = parse_rows(decoded_bytes, app_id)
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "report.txt.gz").write_bytes(raw_bytes)
    (folder / "report.txt").write_bytes(decoded_bytes)
    value = {**(metadata or {}), "segment_id": segment_id, "raw_sha256": digest(raw_bytes),
             "decoded_sha256": digest(decoded_bytes), "raw_bytes": len(raw_bytes),
             "decoded_bytes": len(decoded_bytes), "row_count": len(rows)}
    save_json(manifest, value)
    return value, rows


def seed_cache(root, seed, app_id):
    if not seed or not seed.exists():
        return 0
    baseline = load_json(seed)
    if "downloaded_reports" not in baseline and "data" in baseline:
        seed = seed.parent / baseline["data"]
        baseline = load_json(seed)
    if baseline.get("app_id") != app_id:
        raise ValueError("Seed baseline app does not match")
    count = 0
    for entry in baseline.get("downloaded_reports", []):
        if entry["request_type"] != "ONGOING":
            continue
        folder = Path(entry.get("evidence_directory", seed.parent))
        source = folder / entry["raw_file"]
        if not source.exists():
            continue
        if digest(source.read_bytes()) != entry["raw_sha256"]:
            raise ValueError("Historical seed hash mismatch")
        if segment_cache(root, entry["segment_id"], app_id=app_id) is None:
            segment_cache(root, entry["segment_id"], {"seed_file": str(source.resolve())}, source, app_id)
            count += 1
    return count


def retain_history(previous_results, results):
    """The API expires old instances; preserve locally verified historical batches."""
    previous = {result["report_key"]: result for result in previous_results}
    merged = []
    for result in results:
        old = previous.get(result["report_key"], {})
        instances = {i["instance_id"]: i for i in old.get("instances", [])}
        visible = {i["instance_id"] for i in result["instances"]}
        instances.update({i["instance_id"]: i for i in result["instances"]})
        merged.append({**result, "live_daily_instance_count": len(visible),
                       "historical_instances_retained": len(set(instances) - visible),
                       "instances": list(instances.values())})
    return merged


def collect_report(key, spec, asc, root, request_id, app_id):
    report_id = spec["prefix"] + "-" + request_id
    report = asc.call(["reports", "view", "--report-id", report_id, "--output", "json"], key + "-report")["data"]
    if report["attributes"]["name"] != spec["name"]:
        raise ValueError(f"{key}: configured report ID name changed; inspect before collecting")
    links = asc.call(["reports", "links", "--report-id", report_id, "--paginate", "--output", "json"], key + "-instances")
    instances, downloaded, skipped = [], 0, 0
    for link in links["data"]:
        instance_id = link["id"]
        instance = asc.call(["instances", "view", "--instance-id", instance_id, "--output", "json"], instance_id + "-instance")["data"]
        attributes = instance["attributes"]
        date.fromisoformat(attributes["processingDate"])
        if attributes["granularity"] != "DAILY":
            skipped += 1
            continue
        segments = asc.call(["instances", "links", "--instance-id", instance_id, "--paginate", "--output", "json"], instance_id + "-segments")["data"]
        if not segments:
            raise ValueError(f"{instance_id}: published daily instance has no segments")
        rows, manifests = [], []
        for segment in segments:
            segment_id = segment["id"]
            cached = segment_cache(root, segment_id, app_id=app_id)
            if cached is None:
                target = asc.evidence / (segment_id + ".txt.gz")
                asc.call(["download", "--request-id", request_id, "--instance-id", instance_id,
                          "--segment-id", segment_id, "--output", str(target), "--output-format", "json"], segment_id + "-download")
                cached = segment_cache(root, segment_id, {"request_id": request_id, "report_id": report_id,
                    "instance_id": instance_id, "downloaded_at_utc": stamp()}, target, app_id)
                downloaded += 1
            manifest, batch = cached
            rows.extend(batch)  # Every segment contributes; no arbitrary matching-row dedup.
            manifests.append(manifest)
        validate_fields(key, rows)
        instances.append({"report_key": key, "request_type": "ONGOING", "instance_id": instance_id,
                          "processing_date": attributes["processingDate"], "granularity": "DAILY",
                          "rows": rows, "segments": manifests})
    return {"report_key": key, "report_id": report_id, "instances": instances,
            "new_segments": downloaded, "skipped_non_daily_instances": skipped}


def write_csv(path, rows, columns):
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def render_report(summary):
    show = lambda value: "Unavailable" if value is None else str(value)
    text = f"# Prism Roll acquisition baseline\n\nChecked {summary['checked_at_utc']}. Apple aggregate data only.\n\n"
    text += f"Published Date window: {summary['window_start']} to {summary['window_end']}. Missing dates are not zeros.\n\n"
    text += "| Metric | Observed value |\n| --- | ---: |\n"
    for key, value in summary["observed_metrics"].items():
        text += f"| {key.replace('_', ' ')} | {show(value)} |\n"
    text += "\n| Date | Source | Territory | Metric | Value |\n| --- | --- | --- | --- | ---: |\n"
    for row in summary["by_date_source_territory"]:
        values = [row["event_date"], row["source_type"], row["territory"], row["metric_name"], row["metric_value"]]
        text += "| " + " | ".join(show(v).replace("|", "\\|") for v in values) + " |\n"
    if summary["opt_in_rows"]:
        text += "\n| Date | First-time users in row | Opted-in users in row | Rate in row |\n| --- | ---: | ---: | ---: |\n"
        for row in summary["opt_in_rows"]:
            text += "| " + " | ".join(show(v) for v in row.values()) + " |\n"
    text += "\n" + "\n".join("- " + caveat for caveat in CAVEATS)
    text += "\n\nFull raw-field observations, provenance, hashes and report partitions accompany this report. BigQuery exports contain aggregates only.\n"
    return text


def write_dashboard(path, summary):
    esc = lambda v: html.escape("Unavailable" if v is None else str(v))
    cards = "".join(f"<article><small>{esc(k.replace('_', ' '))}</small><strong>{esc(v)}</strong></article>" for k, v in summary["observed_metrics"].items())
    rows = "".join("<tr>" + "".join(f"<td>{esc(row[k])}</td>" for k in ["event_date", "source_type", "territory", "metric_name", "metric_value"]) + "</tr>" for row in summary["by_date_source_territory"])
    notes = "".join(f"<li>{esc(note)}</li>" for note in CAVEATS)
    optin = "".join("<tr>" + "".join(f"<td>{esc(v)}</td>" for v in row.values()) + "</tr>" for row in summary["opt_in_rows"])
    optin_table = f"<h2>Opt-in by published row</h2><table><tr><th>Date</th><th>Downloaders</th><th>Opted in</th><th>Rate</th></tr>{optin}</table>" if optin else ""
    path.write_text(f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Prism Roll acquisition</title><style>
body{{font:16px/1.5 system-ui;background:#f4f6fb;color:#172037;max-width:1180px;margin:40px auto;padding:0 24px}}h1{{font-size:36px;letter-spacing:-1px}}.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px}}article{{background:white;padding:20px;border-radius:12px}}small{{display:block;color:#56657d}}strong{{display:block;font-size:28px;margin-top:6px}}table{{border-collapse:collapse;background:white;width:100%;margin:28px 0}}th,td{{text-align:left;padding:12px;border-bottom:1px solid #dde3ed}}.table{{overflow:auto}}li{{margin-bottom:9px}}header p{{color:#56657d}}a{{color:#2454bb}}</style>
<header><h1>Prism Roll acquisition</h1><p>Apple aggregate baseline · checked {esc(summary['checked_at_utc'])}</p><p>Published Date labels {esc(summary['window_start'])} – {esc(summary['window_end'])}. Partial coverage; missing ≠ zero.</p></header><section class="cards">{cards}</section><div class="table"><table><thead><tr><th>Date</th><th>Source</th><th>Territory</th><th>Metric</th><th>Value</th></tr></thead><tbody>{rows}</tbody></table></div>{optin_table}<h2>Interpretation</h2><ul>{notes}</ul><p><a href="summary.json">Summary JSON</a> · <a href="observations.csv">Observations CSV</a> · <a href="report.md">Report</a></p></html>''')


def run(args):
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    with (root / ".collector.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Another acquisition collector is already running") from None
        folder = root / "runs" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        folder.mkdir(parents=True)
        asc = Asc(folder / "api", args.asc, args.timeout)
        try:
            previous = load_json(root / "latest.json") if (root / "latest.json").exists() else {}
            if previous.get("app_id", args.app) != args.app or previous.get("request_id", args.request_id) != args.request_id:
                raise ValueError("Output directory belongs to another app/request; choose a separate directory")
            seeded = seed_cache(root, args.seed_baseline, args.app)
            request_data = asc.call(["requests", "--app", args.app, "--paginate", "--output", "json"], "requests")
            request = next((r for r in request_data["data"] if r["id"] == args.request_id), None)
            if not request or request["attributes"]["accessType"] != "ONGOING" or request["attributes"].get("stoppedDueToInactivity") is not False:
                raise ValueError("Existing ongoing request missing/stopped; no request created")
            with ThreadPoolExecutor(max_workers=4) as pool:
                futures = [pool.submit(collect_report, key, spec, asc, root, args.request_id, args.app) for key, spec in REPORTS.items()]
                results, errors = [], []
                for future in futures:
                    try:
                        results.append(future.result())
                    except Exception as error:
                        errors.append(str(error))
            if errors:
                raise RuntimeError("; ".join(errors))
            prior_manifest = root / previous["run"] / "ingestion-manifest.json" if previous else None
            results = retain_history(load_json(prior_manifest) if prior_manifest else [], results)
            instances = [instance for result in results for instance in result["instances"]]
            partitions = canonicalize(instances)
            obs = observations(partitions, args.app, args.request_id)
            summary = summarize(partitions, args.days)
            fingerprint = digest(json.dumps(partitions, sort_keys=True).encode())
            # A regenerated partition with identical rows is a provenance change only.
            metrics_fingerprint = metric_fingerprint(partitions)
            summary.update({"schema_version": 1, "checked_at_utc": stamp(), "app_id": args.app,
                "request_id": args.request_id, "status": "partial_baseline_available" if partitions else "reports_unavailable",
                "report_count": len(REPORTS), "daily_instance_count": len(instances),
                "live_daily_instance_count": sum(r["live_daily_instance_count"] for r in results),
                "new_segments_downloaded": sum(r["new_segments"] for r in results), "historical_segments_seeded": seeded,
                "canonical_row_count": sum(len(p["rows"]) for p in partitions), "errors": [],
                "canonical_sha256": fingerprint, "data_changed": previous.get("canonical_sha256") != fingerprint,
                "metrics_sha256": metrics_fingerprint, "metrics_changed": previous.get("metrics_sha256") != metrics_fingerprint,
                "caveats": CAVEATS, "mutations_performed": False})
            save_json(folder / "summary.json", summary)
            save_json(folder / "partitions.json", partitions)
            save_json(folder / "ingestion-manifest.json", results)
            columns = list(obs[0]) if obs else ["app_id", "request_id", "report_key", "event_date", "processing_date", "granularity", "instance_id", "row_index", "source_type", "territory", "device", "app_version", "page_type", "event_type", "metric_name", "metric_value", "additive", "population", "raw_fields_json"]
            write_csv(folder / "observations.csv", obs, columns)
            with (folder / "observations.jsonl").open("w") as stream:
                for row in obs:
                    stream.write(json.dumps(row, ensure_ascii=False) + "\n")
            write_csv(folder / "daily-source-territory.csv", summary["by_date_source_territory"], ["event_date", "source_type", "territory", "metric_name", "metric_value"])
            (folder / "report.md").write_text(render_report(summary))
            write_dashboard(folder / "dashboard.html", summary)
            save_json(root / "latest.json", {"app_id": args.app, "request_id": args.request_id, "checked_at_utc": summary["checked_at_utc"], "run": str(folder.relative_to(root)),
                "summary": str((folder / "summary.json").relative_to(root)), "dashboard": str((folder / "dashboard.html").relative_to(root)),
                "canonical_sha256": fingerprint, "data_changed": summary["data_changed"],
                "metrics_sha256": metrics_fingerprint, "metrics_changed": summary["metrics_changed"]})
            target = str((folder / "dashboard.html").relative_to(root))
            (root / "dashboard.html").write_text(f'<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url={target}"><title>Prism Roll acquisition</title><a href="{target}">Open latest acquisition dashboard</a>')
            return {**{key: summary[key] for key in ["checked_at_utc", "daily_instance_count", "new_segments_downloaded", "historical_segments_seeded", "canonical_row_count", "data_changed", "observed_metrics"]}, "output": str(folder)}
        except Exception as error:
            save_json(folder / "failure.json", {"checked_at_utc": stamp(), "error": str(error),
                      "previous_latest_retained": True, "mutations_performed": False})
            raise


def main():
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=repo / "ios/release/acquisition")
    parser.add_argument("--seed-baseline", type=Path, default=repo / "ios/release/growth-2026-09-16/baseline/latest.json")
    parser.add_argument("--app", default=APP_ID)
    parser.add_argument("--request-id", default=REQUEST_ID)
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--asc", default="asc")
    args = parser.parse_args()
    if not 1 <= args.days <= 366 or not 1 <= args.timeout <= 120:
        parser.error("days must be 1–366 and timeout 1–120 seconds")
    try:
        print(json.dumps(run(args), indent=2))
    except Exception as error:
        print(f"Acquisition collection failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
