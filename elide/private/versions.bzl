"""Pinned release artifacts of the Elide runtime.

Entries are appended as upstream releases land at
https://github.com/elide-dev/WHIPLASH/releases. Each artifact is recorded with
SRI integrity (sha256-...).
"""

visibility(["//elide/...", "//tests/..."])

# Supported (os, cpu) tuples for prebuilt releases.
PLATFORMS = [
    ("linux", "amd64"),
    ("linux", "arm64"),
    ("macos", "arm64"),
    ("windows", "amd64"),
]

OS_CONSTRAINTS = {
    "linux": "@platforms//os:linux",
    "macos": "@platforms//os:macos",
    "windows": "@platforms//os:windows",
}

CPU_CONSTRAINTS = {
    "amd64": "@platforms//cpu:x86_64",
    "arm64": "@platforms//cpu:aarch64",
}

# Per-version SRI integrity table.
# Shape: ELIDE_VERSIONS[version][(os, cpu)] = "sha256-..."
ELIDE_VERSIONS = {}

DEFAULT_URL_TEMPLATE = (
    "https://github.com/elide-dev/WHIPLASH/releases/download/" +
    "v{version}/elide-{version}-{os}-{cpu}.{ext}"
)

def archive_ext(os):
    """Returns the canonical archive extension for the given OS token."""
    return "zip" if os == "windows" else "tar.gz"

def binary_ext(os):
    """Returns the canonical executable extension for the given OS token."""
    return ".exe" if os == "windows" else ""
