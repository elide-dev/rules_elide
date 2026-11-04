"""Verify built executables start and re-exec without Python on PATH."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix="elide-no-python-") as directory:
    for command in ("bash", "env", "dirname", "readlink", "grep", "cut", "sed", "tail", "awk",
                    "uname", "cat", "mkdir", "ln", "mktemp", "rm"):
        source = shutil.which(command)
        if source:
            Path(directory, command).symlink_to(source)
    environment = dict(os.environ, PATH=directory,
                       PYTHONPATH="/tmp/ambient-python",
                       VIRTUAL_ENV="/tmp/ambient-python",
                       PYTHONHOME="/tmp/ambient-python")
    result = subprocess.check_output(
        [str(Path("bazel-bin/app").absolute()), "space argument", "--flag"],
        env=environment, text=True,
    )
    assert result.strip() == "Elide Python runfiles ['space argument', '--flag']", result
    subprocess.run([str(Path("bazel-bin/runtime_test").absolute())],
                   env=environment, check=True)
print("Binary, runfiles, arguments, and subprocesses work without host Python.")
