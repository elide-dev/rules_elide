# SPDX-License-Identifier: Apache-2.0

"""Pinned release artifacts of the Elide runtime.

Elide publishes prebuilt binaries as GitHub release assets at:
  https://github.com/elide-dev/elide/releases/download/{version}/elide.{os}-{cpu}.{ext}

Each version tag (e.g. `1.2.0+20260603`) is immutable: once a GitHub release is
published its assets never change, so the SRI hashes below are stable forever.
The `{version}` token in DEFAULT_URL_TEMPLATE maps directly to the GitHub release
tag; no URL-encoding of `+` is required — GitHub's CDN accepts the literal `+`.

To upgrade: pick a tag from https://github.com/elide-dev/elide/releases, download
all four platform tarballs, compute `sha256-$(openssl dgst -sha256 -binary <file>
| openssl base64 -A)` for each, add a new entry here, and bump DEFAULT_VERSION.
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

# Default channel (kept for consumers that override DEFAULT_URL_TEMPLATE with a
# channel-based CDN URL; not used by the built-in GitHub releases template).
DEFAULT_CHANNEL = "nightly"

# Per-version SRI integrity table.
# Shape: ELIDE_VERSIONS[version][(os, cpu)] = "sha256-<base64>"
# Hashes verified 2026-06-02 against GitHub release tag 1.2.0+20260602.
# Hashes verified 2026-06-03 against GitHub release tag 1.2.0+20260603.
# Hashes verified 2026-06-13 against GitHub release tag 1.3.0+20260613.
# Hashes verified 2026-06-14 against GitHub release tag 1.3.1+20260614.
# Hashes verified 2026-06-15 against GitHub release tag 1.3.2+20260615.
# Hashes verified 2026-06-16 against GitHub release tag 1.3.3+20260619.
# Hashes verified 2026-06-22 against GitHub release tag 1.3.4+20260622.
ELIDE_VERSIONS = {
    "1.2.0+20260602": {
        ("linux", "amd64"): "sha256-yIQZwU4nM0SN19Zj2rdikdWBpj9d+fVlJK0d10p3DRA=",
        ("linux", "arm64"): "sha256-XDRm/XcEnTZ7rvGs2ExpGXEwvZnrdfG8WOzygAhZt1M=",
        ("macos", "arm64"): "sha256-qaZ7vN9GJWF5c+lZoMkmTvFuuKfZndxt5YpEkWgVpT8=",
        ("windows", "amd64"): "sha256-vaT3d/mbyEnS7Rk+z0ahj273eS9enolQ5QeQ9hW5how=",
    },
    "1.2.0+20260603": {
        ("linux", "amd64"): "sha256-MT9d986Ih7Z/SrKIMPvnY0hsG20euG2KnLAQMm9h+uk=",
        ("linux", "arm64"): "sha256-L+fDxoRB4/58OgRLS/HP2he7XNnEK8LjtfbS8Az9Xqg=",
        ("macos", "arm64"): "sha256-KqhHWtnNNIFbmbwhWiZGgQRrnlHUAep9Y0l7flYgMQc=",
        ("windows", "amd64"): "sha256-5oMvVWvJs+RMThCqulVLLAVoT0YCVICzTrb+J9u+o4k=",
    },
    "1.3.0+20260613": {
        ("linux", "amd64"): "sha256-FT946xuQORvo0WHMCnc1lTpLrVWFRXwUSV7CaW+PmRQ=",
        ("linux", "arm64"): "sha256-LpV8H6kLCWj8rG/YML3UpKnKRZ9o7Ol0peBIPxCK3cU=",
        ("macos", "arm64"): "sha256-QaGRSFamhOq7ERe8DIZFmU4zRdygbjwNO+A3WEyDCvw=",
        ("windows", "amd64"): "sha256-Hb+Bv3X4XEUb5vb5qYOjpTQJqP9OGmq+LQHIE3w2htU=",
    },
    "1.3.1+20260614": {
        ("linux", "amd64"): "sha256-Sh7mC2OG4uptqbvs6kq4S2Zg0PoA0ONHqKnrRnaJCUc=",
        ("linux", "arm64"): "sha256-wa5nWSXbLKbl0i5mZ26Mgjmnjwf5u6skABqbaNwdVhM=",
        ("macos", "arm64"): "sha256-bFg+N6K7ri0vE8oMNy5JrnLkxL1/4yOgHvvs+ATlMQ4=",
        ("windows", "amd64"): "sha256-XhKStYzKMh+MZaXmI7FiX124xW33y950skgcTn/Fh8M=",
    },
    "1.3.2+20260615": {
        ("linux", "amd64"): "sha256-0XxUyCH1A5SSXSgMCREtcHUC0GS0Wx6aSdvCopq2oIY=",
        ("linux", "arm64"): "sha256-K9uLfqaPPL/UdCktdj3QkoTGbtPVegXGgfkp7HgWuro=",
        ("macos", "arm64"): "sha256-VR0Q1qU3QfY4rmbv6ezh/LG9NhaNmU+zk+9o6DQRGN8=",
        ("windows", "amd64"): "sha256-JH2WvFNv4Ln7awDzApjwggDOyRPNaY2km5wksMPjXJU=",
    },
    "1.3.3+20260619": {
        ("linux", "amd64"): "sha256-Wrnt9B8urDNfhd8Rc8DP8xMgDtBJ+GcjOMIK0QiR8tY=",
        ("linux", "arm64"): "sha256-iubsEQ7FfckmNKcCUMJg/lFcVYyxqIIGwPLYCAZ9rIM=",
        ("macos", "arm64"): "sha256-rDCAwBgy4nihEtjjuspGgResNVeG9A+BF3b5Itlqh1c=",
        ("windows", "amd64"): "sha256-WHMPa413nJkmu9dNPofgGMFNEDr2wdBCRWomLY7es7E=",
    },
    "1.3.4+20260622": {
        ("linux", "amd64"): "sha256-3I+SteZc6Bn+cIk0CI5KT/KytXtJEJKAdxCbwba/IOw=",
        ("linux", "arm64"): "sha256-IkRgHlBw9YGQT3SNPB+OcgGB4a2dYk7zIQn4U9W2Mws=",
        ("macos", "arm64"): "sha256-Hs8fx481MzyQp7XhOAzFCJ0m7yUadLG6tNDU8UfLvdw=",
        ("windows", "amd64"): "sha256-n0zb+aCyeQcvIXqC2DbSXVlqfu2/OKCloN6HDiCQRns=",
    },
}

# Default version used when consumers call elide.install() without a version.
# Points at the most-recently verified entry in ELIDE_VERSIONS above.
DEFAULT_VERSION = "1.3.4+20260622"

# GitHub releases serve each tag as an immutable artifact. The {channel} token
# is accepted but unused here; it remains available for consumers who override
# this template with a channel-based URL (e.g. the elide.zip CDN).
DEFAULT_URL_TEMPLATE = (
    "https://github.com/elide-dev/elide/releases/download/{version}/elide.{os}-{cpu}.{ext}"
)

def archive_ext(os):
    """Returns the canonical archive extension for the given OS token."""
    return "zip" if os == "windows" else "tgz"

def binary_ext(os):
    """Returns the canonical executable extension for the given OS token."""
    return ".exe" if os == "windows" else ""
