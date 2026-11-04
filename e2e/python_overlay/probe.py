"""Check the overlaid executable, Python stdlib, and component marker."""
import hashlib
import json
import pathlib
import sys

assert hashlib.sha256(b"overlay").hexdigest() == "b4b33d2441645d4dd0a0694b5989a0a14a5cc22fe9865e6b7b7eae966e0de36c"
marker = pathlib.Path(sys.argv[2]).read_text()
assert "version=" in marker and "platform=" in marker, marker
pathlib.Path(sys.argv[1]).write_text(json.dumps({"python": sys.version, "marker": marker}))
