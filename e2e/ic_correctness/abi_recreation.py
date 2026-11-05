#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Require a complete ABI jar after an incremental one-file body edit."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import zipfile


def entries(path):
    with zipfile.ZipFile(path) as archive:
        return {name: archive.read(name) for name in archive.namelist()
                if name.endswith('.class') or name.endswith('.kotlin_module')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--elide', required=True, type=Path)
    args = parser.parse_args()
    elide = str(args.elide.resolve())
    with tempfile.TemporaryDirectory(prefix='elide-ic-abi-') as directory:
        work = Path(directory)
        (work / 'A.kt').write_text('package probe\nclass A { fun value() = 1 }\n')
        (work / 'B.kt').write_text('package probe\nclass B { fun value() = 2 }\n')

        def compile_to(incremental):
            mode = ['--incremental', '--incremental-cache-dir', 'cache'] if incremental else ['--abi-only']
            output = ['--emit-abi', 'combined.jar', '-d', 'classes'] if incremental else ['-d', 'reference.jar']
            subprocess.run([elide, '--safe-close', 'kotlinc', *mode, '--', *output,
                            '-module-name', 'probe', '-jvm-target', '21', 'A.kt', 'B.kt'],
                           cwd=work, check=True, timeout=60)

        compile_to(True)
        compile_to(False)
        assert entries(work / 'combined.jar') == entries(work / 'reference.jar'), 'Initial ABI mismatch'
        (work / 'A.kt').write_text('package probe\nclass A { fun value() = 3 }\n')
        # Retain both IC state and complete classes; only the declared ABI output is recreated.
        (work / 'combined.jar').unlink()
        compile_to(True)
        compile_to(False)
        assert (work / 'classes/probe/B.class').exists(), 'Unchanged runtime class disappeared'
        actual, expected = entries(work / 'combined.jar'), entries(work / 'reference.jar')
        if actual != expected:
            missing = sorted(expected.keys() - actual.keys())
            raise AssertionError(f'Incremental ABI differs from complete header; missing: {missing}')
        print('Incremental combined ABI matches complete header')


if __name__ == '__main__':
    main()
