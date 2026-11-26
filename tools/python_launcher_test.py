"""Behavioral tests for elide/python/launcher.sh.tpl using a fake elide binary."""

import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

TEMPLATE = pathlib.Path(__file__).resolve().parent.parent / "elide/python/launcher.sh.tpl"
BASHES = sorted({os.path.realpath(b) for b in ("/bin/bash", shutil.which("bash")) if b and os.path.exists(b)})


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="launcher-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        rf = self.tmp / "runfiles"
        rf.mkdir()
        (rf / "init.bash").write_text(
            "runfiles_export_envvars() { :; }\n"
            f'rlocation() {{ echo "{rf}/fake_elide"; }}\n'
        )
        fake = rf / "fake_elide"
        # Like real Elide: without --allow-env the host environment is hidden.
        fake.write_text(
            '#!/bin/sh\n'
            'case " $* " in *" --allow-env "*) ;; *) exec env -i "$0" --allow-env "$@";; esac\n'
            'echo "ARGS=$*"\necho "PYTHONPATH=$PYTHONPATH"\n'
            'echo "TEST_TMPDIR=${TEST_TMPDIR-unset}"\necho "PYTHONSTARTUP=${PYTHONSTARTUP-unset}"\n'
        )
        fake.chmod(0o755)
        script = TEMPLATE.read_text().replace("@@RUNFILES@@", "init.bash").replace("@@ELIDE@@", "fake_elide")
        self.launcher = self.tmp / "launcher.sh"
        self.launcher.write_text(script.replace("@@LAUNCHER_PATH@@", "bin/python.sh").replace("@@ELIDE_PATH@@", "runfiles/fake_elide"))
        self.launcher.chmod(0o755)
        self.rf = rf

    def run_launcher(self, bash, **env):
        base = {"PATH": os.environ["PATH"], "RUNFILES_DIR": str(self.rf), "TEST_TMPDIR": "/tmp/t"}
        base.update(env)
        return subprocess.run([bash, str(self.launcher), "-c", "pass"], env=base, capture_output=True, text=True, check=False)

    def test_interpreter_invoked_directly_from_action_inputs(self):
        direct = self.tmp / "bin/python.sh"
        direct.parent.mkdir()
        shutil.copy2(self.launcher, direct)
        for bash in BASHES:
            with self.subTest(bash=bash):
                result = subprocess.run(
                    [bash, "bin/python.sh", "-c", "pass"], cwd=self.tmp,
                    env={"PATH": os.environ["PATH"], "PYTHONPATH": "/host/site"},
                    capture_output=True, text=True, check=True,
                )
                self.assertIn("PYTHONPATH=\n", result.stdout)

    def test_script_receives_parameter_file_and_option_arguments(self):
        for bash in BASHES:
            with self.subTest(bash=bash):
                result = subprocess.run(
                    [bash, str(self.launcher), "link.py", "@link.params", "--option"],
                    env={"PATH": os.environ["PATH"], "RUNFILES_DIR": str(self.rf)},
                    capture_output=True, text=True, check=True,
                )
                self.assertIn("python -s -B -- link.py @link.params --option", result.stdout)

    def test_empty_pythonpath_does_not_fail(self):
        for bash in BASHES:
            with self.subTest(bash=bash):
                out = self.run_launcher(bash)
                self.assertEqual(out.returncode, 0, out.stderr)
                self.assertIn("PYTHONPATH=\n", out.stdout)

    def test_pythonpath_keeps_only_runfiles_entries(self):
        for bash in BASHES:
            with self.subTest(bash=bash):
                inside = f"{self.rf}/pkg"
                out = self.run_launcher(bash, PYTHONPATH=f"/host/site:{inside}:{self.rf}:/other")
                self.assertEqual(out.returncode, 0, out.stderr)
                self.assertIn(f"PYTHONPATH={inside}:{self.rf}\n", out.stdout)

    def test_allows_bazel_test_environment(self):
        for bash in BASHES:
            with self.subTest(bash=bash):
                out = self.run_launcher(bash)
                self.assertIn("TEST_TMPDIR=/tmp/t", out.stdout)

    def test_drops_ambient_python_variables(self):
        for bash in BASHES:
            with self.subTest(bash=bash):
                out = self.run_launcher(bash, PYTHONSTARTUP="/host/startup.py")
                self.assertIn("PYTHONSTARTUP=unset", out.stdout)


if __name__ == "__main__":
    unittest.main()
