import os
import unittest


class BazelEnvTest(unittest.TestCase):
    def test_bazel_test_environment(self):
        for name in ("TEST_TMPDIR", "TEST_UNDECLARED_OUTPUTS_DIR", "XML_OUTPUT_FILE", "PATH"):
            self.assertIn(name, os.environ)
        self.assertTrue(os.path.isdir(os.environ["TEST_TMPDIR"]))
        for name in ("TEST_UNDECLARED_OUTPUTS_DIR",):
            probe = os.path.join(os.environ[name], "probe.txt")
            with open(probe, "w") as f:
                f.write("ok\n")
        self.assertTrue(os.access(os.path.dirname(os.environ["XML_OUTPUT_FILE"]), os.W_OK))


if __name__ == "__main__":
    unittest.main()
