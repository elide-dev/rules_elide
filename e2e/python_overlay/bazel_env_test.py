import os
import unittest


class BazelEnvTest(unittest.TestCase):
    def test_bazel_test_environment(self):
        for name in ("TEST_TMPDIR", "TEST_UNDECLARED_OUTPUTS_DIR", "XML_OUTPUT_FILE", "PATH"):
            self.assertIn(name, os.environ)


if __name__ == "__main__":
    unittest.main()
