#!/usr/bin/env bash
set -uo pipefail
f='@@RUNFILES@@'
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null ||
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null ||
  source "$0.runfiles/$f" 2>/dev/null ||
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null ||
  { echo >&2 "Cannot locate Bazel runfiles for Elide Python"; exit 1; }
set -e
runfiles_export_envvars
elide="$(rlocation '@@ELIDE@@')"
# Keep Bazel's PYTHONPATH (transitive imports); discard ambient runtime selection.
# Elide 1.6.2 honors PYTHONSAFEPATH but reports sys.flags.safe_path=False.
# rules_python then deletes the first stdlib path. Let its bootstrap remove
# the ordinary script-directory entry instead.
unset PYTHONSAFEPATH VIRTUAL_ENV PYTHONHOME PYTHONUSERBASE
# The legacy bootstrap passes declared import roots through PYTHONPATH.
# Keep only entries inside this runfiles tree, dropping ambient host packages.
_elide_pythonpath=""
IFS=: read -r -a _elide_paths <<< "${PYTHONPATH:-}"
for _elide_path in "${_elide_paths[@]}"; do
  case "$_elide_path" in
    "${RUNFILES_DIR:-/dev/null}"|"${RUNFILES_DIR:-/dev/null}"/*)
      _elide_pythonpath="${_elide_pythonpath:+$_elide_pythonpath:}$_elide_path" ;;
  esac
done
export PYTHONPATH="$_elide_pythonpath"
export PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1 ELIDE_BAZEL=1
exec "$elide" --no-env --no-properties -X "python.Executable=$0" python -s -B "$@"
