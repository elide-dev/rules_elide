"""Check interpretation of Bazel traces independently of benchmark timings."""
import gzip
import json
from pathlib import Path
import tempfile
import unittest

from incremental_matrix import fixture, profile_summary


class ProfileSummaryTest(unittest.TestCase):
    def summary(self, events):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.json.gz"
            with gzip.open(path, "wt") as stream:
                json.dump({"traceEvents": events}, stream)
            return profile_summary(path)

    def test_missing_counters_are_unknown(self):
        result = self.summary([])
        self.assertIsNone(result["worker_memory_mib_max_sample"])
        self.assertIsNone(result["bazel_heap_nonheap_mib_max_sample"])
        self.assertEqual(result["critical_path_span_seconds"], 0)
        self.assertEqual(result["worker_memory_mib_by_mnemonic_max_sample"], {})

    def test_path_span_includes_gaps_but_action_time_does_not(self):
        result = self.summary([
            {"cat": "critical path component", "ph": "X", "ts": 100000, "dur": 200000},
            {"cat": "critical path component", "ph": "X", "ts": 400000, "dur": 300000},
            {"cat": "action processing", "ph": "X", "ts": 0, "dur": 900000},
        ])
        self.assertEqual(result["critical_path_action_seconds"], 0.5)
        self.assertEqual(result["critical_path_span_seconds"], 0.6)

    def test_partial_bucket_is_unknown(self):
        result = self.summary([
            {"name": "Total worker memory usage", "ph": "C", "ts": 0, "args": {"workers memory": 20}},
        ])
        self.assertIsNone(result["worker_memory_mib_max_sample"])

    def test_counters_exclude_partial_tail_and_keep_max_complete_bucket(self):
        result = self.summary([
            {"name": "Total worker memory usage", "ph": "C", "ts": 0, "args": {"workers memory": 20}},
            {"name": "Total worker memory usage", "ph": "C", "ts": 1000000, "args": {"workers memory": 15}},
            {"name": "Total worker memory usage", "ph": "C", "ts": 2000000, "args": {"workers memory": 999}},
            {"name": "Memory usage (Bazel)", "ph": "C", "ts": 0, "args": {"memory": 10.5}},
            {"name": "Memory usage (Bazel)", "ph": "C", "ts": 1000000, "args": {"memory": 1}},
            {"name": "Per-mnemonic worker memory usage", "ph": "C", "ts": 0, "args": {"Javac": 8, "ElideJavac": 12}},
            {"name": "Per-mnemonic worker memory usage", "ph": "C", "ts": 1000000, "args": {"Javac": 9, "ElideJavac": 6}},
            {"name": "Per-mnemonic worker memory usage", "ph": "C", "ts": 2000000, "args": {"Javac": 1, "ElideJavac": 1}},
            {"name": "Total worker memory usage", "ph": "M", "ts": 0, "args": {"workers memory": 9999}},
        ])
        self.assertEqual(result["worker_memory_mib_max_sample"], 20)
        self.assertEqual(result["bazel_heap_nonheap_mib_max_sample"], 10.5)
        self.assertEqual(result["worker_memory_mib_by_mnemonic_max_sample"], {"Javac": 9, "ElideJavac": 12})


class BaselineTest(unittest.TestCase):
    def test_stock_abi_mode_uses_stock_kotlin_rules(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = fixture(root, "kotlin", "vanilla_abi", 3, 2)
            build = (root / "core/BUILD.bazel").read_text()
            self.assertIn("@rules_kotlin//kotlin:jvm.bzl", build)
            self.assertNotIn("@rules_elide", build)
            self.assertEqual(len(sources), 8)

    def test_native_java_explicitly_matches_stock_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root, "java", "elide_fused", 3, 2)
            self.assertIn('javac_opts=["--release", "21"]', (root / "core/BUILD.bazel").read_text())
