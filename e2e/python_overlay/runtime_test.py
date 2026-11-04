import os
import json
import subprocess
import sys
import unittest
from library import message

class RuntimeTest(unittest.TestCase):
    def test_runtime(self):
        self.assertEqual(sys.implementation.name, "graalpy")
        self.assertEqual(sys.version_info[:2], (3, 13))
        self.assertEqual(message(), "Elide Python runfiles")

    def test_environment(self):
        self.assertNotIn("VIRTUAL_ENV", os.environ)
        self.assertNotIn("PYTHONHOME", os.environ)
        self.assertFalse(any("ambient-python" in entry for entry in sys.path))

    def test_failure(self):
        result = subprocess.run([sys.executable, "-c", "raise SystemExit(7)"])
        self.assertEqual(result.returncode, 7)

    def test_subprocess(self):
        result = subprocess.check_output([sys.executable, "-c", "import json, sys; print(json.dumps(sys.argv[1:]))", "space argument", "--flag"], text=True)
        self.assertEqual(json.loads(result), ["space argument", "--flag"])

    def test_module(self):
        result = subprocess.run([sys.executable, "-m", "json.tool"], input='{"x":1}', text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(result.stdout), {"x": 1})

if __name__ == "__main__":
    unittest.main()
