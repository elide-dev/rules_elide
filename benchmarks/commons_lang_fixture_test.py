"""Guard benchmark mutations against source drift and accidental API changes."""
from pathlib import Path
import tempfile
import unittest

import commons_lang_fixture as commons
from incremental_matrix import fixture


class CommonsLangFixtureTest(unittest.TestCase):
    def test_source_drift_fails_instead_of_measuring_a_noop(self):
        with self.assertRaises(ValueError):
            commons.replace_once("new implementation", "old implementation", "edit")
        with self.assertRaises(ValueError):
            commons.replace_once("old old", "old", "edit")

    def test_real_sources_replace_generated_core_and_body_edit_is_isolated(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            production = {"org/apache/commons/lang3/StringUtils.java": b"public class StringUtils {\npublic static boolean isEmpty(CharSequence cs) { return cs == null || cs.length() == 0; }\n}\n"}
            original = production.copy()
            sources = commons.install(work, fixture(work, "java", "vanilla", 3, 2), production, 2)
            for path, contents in sources.items():
                path.write_text(contents)
            commons.mutate(sources, "body", 1)
            changed = [path for path, contents in sources.items() if path.read_text() != contents]
            self.assertEqual([path.name for path in changed], ["StringUtils.java"])
            self.assertIn("cs.isEmpty()", changed[0].read_text())
            self.assertEqual(production, original)
            self.assertFalse((work / "core/Core0.java").exists())
            self.assertIn('glob(["**/*.java"])', (work / "core/BUILD.bazel").read_text())
            self.assertIn("value() != 4", sources[work / "app/App.java"])
            first = changed[0].read_text()
            commons.mutate(sources, "body", 2)
            self.assertNotEqual(first, changed[0].read_text())
            self.assertEqual(first.split("// Benchmark")[0], changed[0].read_text().split("// Benchmark")[0])
