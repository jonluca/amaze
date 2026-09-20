import argparse
import gzip
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import collector as c


def impression(day, count=1, territory="US", unique=1):
    return {"Date": day, "App Apple Identifier": c.APP_ID, "Event": "Impression",
            "Page Type": "No page", "Source Type": "App Store search", "Territory": territory,
            "Counts": count, "Unique Counts": unique}


def instance(identifier, processing, rows, key="discovery", request="ONGOING", granularity="DAILY"):
    return {"instance_id": identifier, "processing_date": processing, "report_key": key,
            "request_type": request, "granularity": granularity, "rows": rows}


class CorrectionTests(unittest.TestCase):
    def test_metric_fingerprint_ignores_processing_order_and_cosmetic_name(self):
        old = [impression("2026-09-17", 2), impression("2026-09-17", 1, "VN")]
        fresh = [{**r, "App Name": "New title"} for r in reversed(old)]
        a = c.canonicalize([instance("old", "2026-09-18", old)])
        b = c.canonicalize([instance("new", "2026-09-19", fresh)])
        self.assertEqual(c.metric_fingerprint(a), c.metric_fingerprint(b))

    def test_expired_api_instances_do_not_erase_local_history(self):
        old = {"report_key": "discovery", "instances": [instance("old", "2026-09-18", [impression("2026-09-15")])]}
        fresh = {"report_key": "discovery", "instances": [instance("new", "2026-09-20", [impression("2026-09-19", 2)])]}
        merged = c.retain_history([old], [fresh])[0]
        self.assertEqual(merged["historical_instances_retained"], 1)
        self.assertEqual(c.summarize(c.canonicalize(merged["instances"]))["observed_metrics"]["impression_events"], 3)

    def test_newer_date_partition_replaces_missing_old_breakdown(self):
        old = instance("old", "2026-09-18", [impression("2026-09-15"), impression("2026-09-17", 4), impression("2026-09-17", 3, "VN")])
        new = instance("new", "2026-09-19", [impression("2026-09-17", 2)])
        result = c.canonicalize([new, old])
        self.assertEqual([(p["date"], len(p["rows"])) for p in result], [("2026-09-15", 1), ("2026-09-17", 1)])
        self.assertEqual(c.summarize(result)["observed_metrics"]["impression_events"], 3)

    def test_snapshot_and_weekly_overlap_are_excluded(self):
        row = impression("2026-09-17")
        result = c.canonicalize([instance("a", "2026-09-18", [row]),
            instance("snapshot", "2026-09-19", [impression("2026-09-17", 99)], request="ONE_TIME_SNAPSHOT"),
            instance("weekly", "2026-09-20", [impression("2026-09-17", 99)], granularity="WEEKLY")])
        self.assertEqual(c.summarize(result)["observed_metrics"]["impression_events"], 1)

    def test_identical_rows_in_one_complete_batch_are_not_arbitrarily_deduplicated(self):
        result = c.canonicalize([instance("multi-segment", "2026-09-18", [impression("2026-09-17"), impression("2026-09-17")])])
        self.assertEqual(c.summarize(result)["observed_metrics"]["impression_events"], 2)

    def test_conflicting_same_processing_date_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            c.canonicalize([instance("a", "2026-09-18", [impression("2026-09-17", 1)]),
                            instance("b", "2026-09-18", [impression("2026-09-17", 2)])])

    def test_report_types_have_independent_date_partitions(self):
        download = {"Date": "2026-09-17", "Download Type": "First-time download", "Counts": 1}
        result = c.canonicalize([instance("a", "2026-09-18", [impression("2026-09-17", 7)]),
                            instance("b", "2026-09-19", [download], key="downloads")])
        summary = c.summarize(result)["observed_metrics"]
        self.assertEqual(summary["impression_events"], 7)
        self.assertEqual(summary["first_time_downloads"], 1)
        self.assertIsNone(summary["conversion_rate"])


class MetricTests(unittest.TestCase):
    def test_missing_is_null_and_explicit_zero_survives(self):
        empty = c.summarize([])["observed_metrics"]
        self.assertTrue(all(v is None for v in empty.values()))
        zero = c.summarize(c.canonicalize([instance("a", "2026-09-18", [impression("2026-09-17", 0)])]))
        self.assertEqual(zero["observed_metrics"]["impression_events"], 0)
        self.assertIsNone(zero["observed_metrics"]["first_time_downloads"])

    def test_suppressed_counts_are_not_added_as_zero(self):
        parts = c.canonicalize([instance("a", "2026-09-18", [impression("2026-09-17", 2), impression("2026-09-17", None)])])
        self.assertIsNone(c.summarize(parts)["observed_metrics"]["impression_events"])

    def test_unique_counts_remain_per_row(self):
        parts = c.canonicalize([instance("a", "2026-09-18", [impression("2026-09-17", 2, unique=1), impression("2026-09-17", 2, "VN", 1)])])
        unique = [r for r in c.observations(parts, c.APP_ID, c.REQUEST_ID) if r["metric_name"] == "unique_counts_in_row"]
        self.assertEqual([r["metric_value"] for r in unique], [1, 1])
        self.assertTrue(all(not r["additive"] for r in unique))
        self.assertIsNone(c.summarize(parts)["observed_metrics"]["unique_users"])

    def test_updates_are_not_acquisition_and_page_attribution_is_not_page_views(self):
        row = {"Date": "2026-09-18", "Download Type": "Auto-update", "Page Type": "Product page", "Counts": 20}
        summary = c.summarize(c.canonicalize([instance("a", "2026-09-19", [row], key="downloads")]))
        self.assertIsNone(summary["observed_metrics"]["first_time_downloads"])
        self.assertIsNone(summary["observed_metrics"]["product_page_view_events"])
        self.assertEqual(summary["by_date_source_territory"][0]["metric_value"], 20)

    def test_sessions_and_opt_in_users_have_separate_populations(self):
        rows = [instance("s", "2026-09-20", [{"Date": "2026-09-18", "Sessions": 8, "Total Session Duration": 90, "Unique Devices": 5}], key="sessions"),
                instance("o", "2026-09-20", [{"Date": "2026-09-18", "Downloading Users": 10, "Users Opting-In": 5}], key="opt_in")]
        all_summary = c.summarize(c.canonicalize(rows))
        summary = all_summary["observed_metrics"]
        self.assertEqual(summary["session_events"], 8)
        self.assertIsNone(summary["active_devices"])
        self.assertIsNone(summary["retention"])
        self.assertEqual(all_summary["opt_in_rows"][0]["rate_in_row"], 0.5)
        self.assertIsNone(summary["opt_in_rate"])

    def test_wrong_app_and_malformed_data_rejected(self):
        with self.assertRaises(ValueError):
            c.parse_rows(b"Date\tApp Apple Identifier\n2026-09-18\twrong\n", c.APP_ID)
        with self.assertRaises(ValueError):
            c.parse_rows(b"Date\tApp Apple Identifier\n2026-09-18\n", c.APP_ID)


class FakeAsc:
    downloads = 0
    broken = False

    def __init__(self, evidence, *args):
        self.evidence = evidence

    def call(self, args, name):
        if self.broken:
            raise RuntimeError("API unavailable")
        if args[0] == "requests":
            return {"data": [{"id": c.REQUEST_ID, "attributes": {"accessType": "ONGOING", "stoppedDueToInactivity": False}}]}
        if args[:2] == ["reports", "view"]:
            key = next(k for k, spec in c.REPORTS.items() if args[3].startswith(spec["prefix"] + "-"))
            return {"data": {"attributes": {"name": c.REPORTS[key]["name"]}}}
        if args[:2] == ["reports", "links"]:
            return {"data": [{"id": "instance-a"}] if args[3].startswith("r14-") else []}
        if args[:2] == ["instances", "view"]:
            return {"data": {"attributes": {"granularity": "DAILY", "processingDate": "2026-09-19"}}}
        if args[:2] == ["instances", "links"]:
            return {"data": [{"id": "segment-a"}, {"id": "segment-b"}]}
        if args[0] == "download":
            path = Path(args[args.index("--output") + 1])
            path.parent.mkdir(parents=True, exist_ok=True)
            data = "Date\tApp Apple Identifier\tEvent\tPage Type\tCounts\tUnique Counts\n2026-09-18\t6809253424\tImpression\tNo page\t1\t1\n"
            path.write_bytes(gzip.compress(data.encode()))
            type(self).downloads += 1
            return {"filePath": str(path)}
        raise AssertionError(args)


class CollectionTests(unittest.TestCase):
    def setUp(self):
        FakeAsc.downloads = 0
        FakeAsc.broken = False

    def test_cached_segments_reused_and_failed_refresh_retains_last_good(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(c, "Asc", FakeAsc):
            root = Path(temp)
            args = argparse.Namespace(output=root, seed_baseline=None, asc="asc", timeout=45,
                                      app=c.APP_ID, request_id=c.REQUEST_ID, days=7)
            first = c.run(args)
            self.assertEqual(first["new_segments_downloaded"], 2)
            self.assertEqual(first["observed_metrics"]["impression_events"], 2)
            second = c.run(args)
            self.assertEqual(second["new_segments_downloaded"], 0)
            self.assertEqual(FakeAsc.downloads, 2)
            self.assertFalse(second["data_changed"])
            latest = (root / "latest.json").read_bytes()
            FakeAsc.broken = True
            with self.assertRaises(RuntimeError):
                c.run(args)
            self.assertEqual((root / "latest.json").read_bytes(), latest)

    def test_corrupt_cache_detected_without_trusting_existing_rows(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); source = root / "raw.gz"
            source.write_bytes(gzip.compress(b"Date\tApp Apple Identifier\n2026-09-18\t6809253424\n"))
            c.segment_cache(root, "segment", {}, source)
            (root / "cache/segments/segment/report.txt").write_text("tampered")
            with self.assertRaisesRegex(ValueError, "hash verification"):
                c.segment_cache(root, "segment")


if __name__ == "__main__":
    unittest.main()
