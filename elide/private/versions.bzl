# SPDX-License-Identifier: Apache-2.0

"""Pinned release artifacts of the Elide runtime.

Elide publishes its prebuilt binaries to the public CDN at https://elide.zip/
under channel directories (`nightly`, `preview`, `release`). Each artifact is
recorded here with SRI integrity (`sha256-...`) so Bzlmod can verify downloads
deterministically.

Note: the `latest` revision under each channel is a rolling pointer; integrity
shifts whenever upstream publishes a new build. Consumers needing strict
hermeticity should pin a concrete `version` once the `release` channel ships
stable, immutable revisions.
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

# Default channel used when consumers do not override.
DEFAULT_CHANNEL = "nightly"

# Per-version SRI integrity table.
# Shape: ELIDE_VERSIONS[version][(os, cpu)] = "sha256-<base64>"
# Hashes captured 2026-05-30 against `nightly/latest`.
ELIDE_VERSIONS = {
    "latest": {
        ("linux", "amd64"): "sha256-jxRDqurC0Gy0e3lNVzAxNsga3MlMD+m+LZRXvBYgHiA=",
        ("linux", "arm64"): "sha256-8ocQy7DnQYLVbWTL5eM5SBY1WlGIQuKyV00KW7qoPfM=",
        ("macos", "arm64"): "sha256-aQfBYn7vgORLuiDuSWItRMl/5o43lzUJciwE88ScSv0=",
        ("windows", "amd64"): "sha256-PKjWrVA+uiAL8eX+Q3WMBEx4Ih0+Ntl6DV9XmlmIsiM=",
    },
}

DEFAULT_URL_TEMPLATE = (
    "https://elide.zip/artifacts/{channel}/{version}/elide.{os}-{cpu}.{ext}"
)

def archive_ext(os):
    """Returns the canonical archive extension for the given OS token."""
    return "zip" if os == "windows" else "tgz"

def binary_ext(os):
    """Returns the canonical executable extension for the given OS token."""
    return ".exe" if os == "windows" else ""
