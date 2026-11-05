"""Ensure real-source fixtures preserve production code and edit intended files."""
from pathlib import Path
import tempfile
import unittest

from incremental_matrix import REPO, fixture
import kotlin_builder_fixture as builder


class KotlinBuilderFixtureTest(unittest.TestCase):
    def test_real_module_and_protocols_replace_generated_core(self):
        production, metadata = builder.snapshot(REPO)
        original = production.copy()
        self.assertEqual(metadata["proto_files"], 2)
        self.assertIn("Flagfile.kt", production)
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            sources = builder.install(work, fixture(work, "kotlin", "elide_hybrid", 3, 2), production, 2)
            for path, contents in sources.items():
                path.write_text(contents)
            self.assertFalse((work / "core/Core0.kt").exists())
            self.assertIn('abi_mode="separate"', (work / "core/BUILD.bazel").read_text())
            self.assertIn('kotlinc_opts=["-jvm-target=21"]', (work / "core/BUILD.bazel").read_text())
            self.assertIn('jvm_target="21"', (work / "BUILD.bazel").read_text())
            self.assertIn("//protocol:worker_protocol_java_proto", (work / "core/BUILD.bazel").read_text())
            self.assertEqual((work / "protocol/deps.proto").read_bytes(), production["proto/deps.proto"])
            builder.mutate(sources, "multi_file_body", 1)
            changed = {path.name for path, text in sources.items() if path.read_text() != text}
            self.assertEqual(changed, {"Flagfile.kt", "Router.kt", "BuiltinPlugins.kt"})
            self.assertEqual(production, original)
            first = (work / "core/Flagfile.kt").read_text()
            builder.mutate(sources, "body", 2)
            second = (work / "core/Flagfile.kt").read_text()
            self.assertNotEqual(first, second)
            self.assertEqual(first.split("// Benchmark")[0], second.split("// Benchmark")[0])
