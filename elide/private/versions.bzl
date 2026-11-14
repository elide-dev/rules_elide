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
# Hashes verified 2026-06-23 against GitHub release tag 1.3.4+20260623.
# Hashes verified 2026-06-28 against GitHub release tag 1.3.6+20260628.
# Hashes verified 2026-10-18 against GitHub release tag v1.6.0.
# 1.6.1/1.6.2 release and nightly hashes from GitHub asset digests, 2026-11-04.
# 1.6.3 release hashes from GitHub asset digests, 2026-11-13.
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
    "1.3.4+20260623": {
        ("linux", "amd64"): "sha256-bpTATZwNpgUfDE35uLOSRIh07m+XVH7zlNu3jVzqkug=",
        ("linux", "arm64"): "sha256-ysQj8ZBR/gY89sicy19/3TvrJ3yYtooqwP1N8xqIqfE=",
        ("macos", "arm64"): "sha256-d9bWfO/J/Ph5QjrsQJG58sQIOiDjS2+GZveS0drZJLA=",
        ("windows", "amd64"): "sha256-HM6XeDnJ+QlWDjz9NSXVhsIwWwWtReUsLIuYpdl/eXs=",
    },
    "1.3.6+20260628": {
        ("linux", "amd64"): "sha256-ANmWaNt9sBG9GLyfN7Kt8E82Hn2a91or9PHqabusVSY=",
        ("linux", "arm64"): "sha256-I9+3rUuHMivY3zw0idfwhvqqU0o22c+PSALkyJgDcUk=",
        ("macos", "arm64"): "sha256-IPUIc9kYzc1mxpva0PX88yGA7UsWS+dneXTfhJxUxRA=",
        ("windows", "amd64"): "sha256-mKvMV80P8OFl0Qw1fTjH33qRw239sIPqJ0m18VAhlt8=",
    },
    "1.4.0+20260707": {
        ("linux", "amd64"): "sha256-kG1Dko6oW7QpIk5I1MmCYVQFTg/qcmlyFT1xqpAbv58=",
        ("linux", "arm64"): "sha256-U/gK+QL65sIAkCeiG/JaEylYHNJli0+mNJ8EXLhA8xo=",
        ("macos", "arm64"): "sha256-wJhyP+Lijt0VLyTfCYKMDOkhuUVxbDUkn3tXhn33+Yc=",
        ("windows", "amd64"): "sha256-JQiNk43a5XhS1seUHpZP7bD4XkMExwMOCQb34+sMCm0=",
    },
    "1.6.0": {
        ("linux", "amd64"): "sha256-vus2eTze9Kis/OrmBPolmfF2O9EGgEwO+fu35fe/2X4=",
        ("linux", "arm64"): "sha256-iAwLDYkqhlIeLVb/sXxLvN+dbr2eyd+fLfvNOpZCVTE=",
        ("macos", "arm64"): "sha256-cTEKx6IkaKmuuoXCh7s6UvE819POiUBE5p6ZjGkOvts=",
        ("windows", "amd64"): "sha256-YcH7aJ0G/SAUwU8jX5PmT9xvLhW8Dlzfy7vhI2a0cC8=",
    },
    "1.6.1": {
        ("linux", "amd64"): "sha256-GmC5bRnyouw+Gwmc8A50p1rjHuXX+GAhzQl/r7Yo+F0=",
        ("linux", "arm64"): "sha256-28FjUUP+bOACRHXbKeJZwt7OUNgr2gbKBitcMpRHgsk=",
        ("macos", "arm64"): "sha256-NDba6kd2GEQx0Qgitvs4WhgskWwtrH5pekyZF9pQqAY=",
        ("windows", "amd64"): "sha256-M/E21TnlG1dxMmIjxzkkn7p8uZ/lLevSWfpiluPtk0k=",
    },
    "1.6.2": {
        ("linux", "amd64"): "sha256-pxUjqiqNMZS8wP3O0X9pgJiER+7XSla/s9tVbFwQn2Q=",
        ("linux", "arm64"): "sha256-oN75/opmbBJ2TC0j4lQSmVYph+x9YKMDztXyg17QnMk=",
        ("macos", "arm64"): "sha256-02+nhbgrRix1MvL+oaNL9A0kpgfE4GLzqeNJToNUIas=",
        ("windows", "amd64"): "sha256-H6N9UxXnwSPfSe+CCvgjhlKsl7c609n6t0vZD60n53I=",
    },
    "1.6.2+20261102": {
        ("linux", "amd64"): "sha256-SjxCCwEiAkC72KAZ8snyhIsE5oIHidtvz5EQ/cnFtic=",
        ("linux", "arm64"): "sha256-PZ0Iz0MI0wzuh5yfrsaWVoTtY32QEfbFDjnp3W9fFUI=",
        ("macos", "arm64"): "sha256-GT7f9pI1qnqlSODT28QmqRfHHbJVolAlk5ty2cRb12M=",
        ("windows", "amd64"): "sha256-l4PudXm+w7Z+rW06YfWb36gIsnxPej/wFXPzm7A1THw=",
    },
    "1.6.2+20261103": {
        ("linux", "amd64"): "sha256-f4KH8UbrtZvzWtsMpNCznuHJt5hkwJ0lfVP4qL0OV5g=",
        ("linux", "arm64"): "sha256-/j9RtVcwRWYbPeYsE9awPZWIDxcwFKCyZUqHQRQC5ts=",
        ("macos", "arm64"): "sha256-GnVUGQRvtprtA+yHMPyl2hd+0nOKnXlg6GS0TAZ5YVQ=",
        ("windows", "amd64"): "sha256-QGpc+878ce0fY1FCRGl26jPF/hpwfmI7K8kQzoz+WwU=",
    },
    "1.6.3": {
        ("linux", "amd64"): "sha256-uUwQe53xBwG5IG4sKWdRr3RxJWsHQOyBqYUPAb/iH6A=",
        ("linux", "arm64"): "sha256-Oc6Y/Z1co3RhHvpqMxTU5UPeh/ifH30x/51e736lAvo=",
        ("macos", "arm64"): "sha256-jT2svgXa+3vXpuWNLwqvm0D+hGNNIpXADvbILriQffI=",
        ("windows", "amd64"): "sha256-mwroU519ot718Je2+GkLNx8PKty/oxvHds+Pae40QXQ=",
    },
    "1.6.3+20261111": {
        ("linux", "amd64"): "sha256-XpNUcMR2nVsxT/KtCvPJkSlWndNLKYC0878qzQ1F0GQ=",
        ("linux", "arm64"): "sha256-4MeVT0CJxl9G60rYl+VBSuaM6VNHGCT+lkjbc/od3uA=",
        ("macos", "arm64"): "sha256-cJuojKZXSr2YjotZHokzQzCCpMvT05X7EDSTwfO1JeU=",
        ("windows", "amd64"): "sha256-53lWiltaJWKUitnBBMJbwRmSB1bLa3WWgsbrxQQOwOE=",
    },
}

# Optional Python overlays, matched to the base release; GitHub asset digests.
PYTHON_VERSIONS = {
    "1.6.0": {
        ("linux", "amd64"): "sha256-gLotWfj25gSuN2VUNXQ3skRY2UDCrJF73aUBdR91lls=",
        ("linux", "arm64"): "sha256-wNRIowaC+HNHUi5tNKLvKxEJgEvy82DTfFD8+M8C4mk=",
        ("macos", "arm64"): "sha256-fd6qoReJbl4Gvz3NzMGerAkN+eE9jok0ZazhXsk8c+M=",
        ("windows", "amd64"): "sha256-+xqLXAfKTJCDX78DkghTsW/YnVMNJOaWgp0x+0F96qk=",
    },
    "1.6.1": {
        ("linux", "amd64"): "sha256-YmIOPh42td7fdeANOarqPlZX/cT+qR0pos3Zsg7iXwE=",
        ("linux", "arm64"): "sha256-1TwZj3BPXozxvbAHyUBhRsH2duzwBOxU5E/1Ro0iR7Y=",
        ("macos", "arm64"): "sha256-fGecSbblca907ZvQZGbdel1HIWFoiEIHG/mYR9P+d3o=",
        ("windows", "amd64"): "sha256-3JhE1eG76dKt6APP7T9peXwuDRfgCZaBwaUV1L6NPaM=",
    },
    "1.6.2": {
        ("linux", "amd64"): "sha256-EVdxVQsuz+zcqOSb0uJwNz/vOVdzD+auplmEFGPCmUI=",
        ("linux", "arm64"): "sha256-2oxQeHkidDuVyvVK5LIuauA5QotnWMz+JNl/LAhS7s4=",
        ("macos", "arm64"): "sha256-rHmobVfNDoiCp5P4r+N56JxaSn4Bw85TYcb0C086qpE=",
        ("windows", "amd64"): "sha256-0VnDnF0gRk9k+1evvUdR7XxCZwbwDLMsBTbwcAmS/fU=",
    },
    "1.6.2+20261102": {
        ("linux", "amd64"): "sha256-KiPGUzh4Dba33VEUCKSsBW/C+sQ58dNbVsUMmYBYQEs=",
        ("linux", "arm64"): "sha256-Wm8dV0vSrTIR5h05eVcCpjT+Hv7FWrnOefa1yjKzHUY=",
        ("macos", "arm64"): "sha256-AC9hl/B6I7kC/60hy9LidBIE/Rhk6jqwz/cfuIcGGZ8=",
        ("windows", "amd64"): "sha256-2yGUN2NR/6UHTcKjHYufeyRv+qI2lfmC6la0NW+iEek=",
    },
    "1.6.2+20261103": {
        ("linux", "amd64"): "sha256-jxgGFOuGbGETtMhksa7fXv5kFooTgu+Oo9ccYJkWP7w=",
        ("linux", "arm64"): "sha256-TcPJK1ww0de8sjfkRCTB8IpCNofvzL7SUajpwqA1dV8=",
        ("macos", "arm64"): "sha256-OcgC4rg0spTC7jQjL1El57QXwL+EL/incoh7fpIR5ME=",
        ("windows", "amd64"): "sha256-hgxcgJCeTff+YsXLxZ3ImHxL3RhUeuK29FsfpQ2xkFY=",
    },
    "1.6.3": {
        ("linux", "amd64"): "sha256-9MqiAZFWjmZQzf/y5LZ/+gSi8MfKXWdSu8A4oyT2e60=",
        ("linux", "arm64"): "sha256-VWgvmJiHJiWswcfoBCPZoVkBzzvcZ/V/qnrSzew+4wc=",
        ("macos", "arm64"): "sha256-Oqj6mh6Ie9coVTjs529YmZzkwXc6rAznZUQ94oD6R4c=",
        ("windows", "amd64"): "sha256-Pa++D23Jq980fO9HTCkGxZXOv6A4V+6rKcu5HjtP8z0=",
    },
    "1.6.3+20261111": {
        ("linux", "amd64"): "sha256-6M4WTxoyDkHtpgFCNHGGiojIRcAw8fJvJ9P/282K3tc=",
        ("linux", "arm64"): "sha256-/j2q/Evwrp7L6G/J89oggd01vt2Zp95OEvvWuB6wI2Y=",
        ("macos", "arm64"): "sha256-tx0klzlrolqLVZmfMfNF1ievOC+NfKNuPYJDCoW119w=",
        ("windows", "amd64"): "sha256-/yqr60Q4TRhuBUtv8xXOgMpts9H/63FeI8F8CwXy0k0=",
    },
}

# Versions whose GitHub release tag differs from the version string. Nightly tags
# (`1.3.6+20260628`) are the version itself; release candidates and releases are
# tagged with a leading `v`.
RELEASE_TAGS = {
    "1.6.0": "v1.6.0",
    "1.6.1": "v1.6.1",
    "1.6.2": "v1.6.2",
    "1.6.3": "v1.6.3",
}

def release_tag(version):
    """Returns the GitHub release tag that publishes `version`.

    Args:
        version: str. An Elide version, e.g. `1.6.0` or `1.3.6+20260628`.

    Returns:
        str. The release tag, which the `{version}` URL token expands to.
    """
    return RELEASE_TAGS.get(version, version)

# Default version used when consumers call elide.install() without a version.
# Points at the most-recently verified stable release in ELIDE_VERSIONS above.
DEFAULT_VERSION = "1.6.2"

# GitHub releases serve each tag as an immutable artifact. The {channel} token
# is accepted but unused here; it remains available for consumers who override
# this template with a channel-based URL (e.g. the elide.zip CDN).
DEFAULT_URL_TEMPLATE = (
    "https://github.com/elide-dev/elide/releases/download/{version}/elide.{os}-{cpu}.{ext}"
)

def download_url(url_template, channel, version, os, cpu):
    """Expands a release URL template for one platform.

    The built-in template points at GitHub releases, so `{version}` becomes the
    release tag there. A custom template gets the version exactly as pinned.

    Args:
        url_template: str. A custom template, or empty for the built-in one.
        channel: str. Release channel; empty means DEFAULT_CHANNEL.
        version: str. An Elide version from ELIDE_VERSIONS.
        os: str. OS token, e.g. `linux`.
        cpu: str. CPU token, e.g. `amd64`.

    Returns:
        str. The archive URL.
    """
    return (url_template or DEFAULT_URL_TEMPLATE).format(
        channel = channel or DEFAULT_CHANNEL,
        version = version if url_template else release_tag(version),
        os = os,
        cpu = cpu,
        ext = archive_ext(os),
    )

def _parse_semver(version):
    """Parses `X.Y.Z` (with optional `-prerelease` / `+metadata`) into a comparable tuple.

    Non-numeric or short versions sort lexically after numeric ones; this gives
    `1.10.0` > `1.9.0` while still keeping `latest` predictably greatest. A
    prerelease sorts below the release it precedes (`1.6.0-rc.2` < `1.6.0`).
    """
    if version == "latest":
        return (999999999, 0, 0, 1, "")
    base = version.split("+", 1)[0]
    core = base.split("-", 1)[0]
    stable = 0 if "-" in base else 1
    parts = core.split(".")
    nums = []
    for p in parts:
        if p.isdigit():
            nums.append(int(p))
        else:
            return (-1, 0, 0, 0, version)
    if len(nums) < 3:
        nums = nums + [0] * (3 - len(nums))
    return (nums[0], nums[1], nums[2], stable, version)

def select_version(versions):
    """Returns the highest of `versions`, ranking releases above their prereleases."""
    return sorted(versions, key = _parse_semver)[-1]

def archive_ext(os):
    """Returns the canonical archive extension for the given OS token."""
    return "zip" if os == "windows" else "tgz"

def binary_ext(os):
    """Returns the canonical executable extension for the given OS token."""
    return ".exe" if os == "windows" else ""

def python_download_url(url_template, channel, version, os, cpu):
    """Expands a version-matched Python overlay URL.

    Args:
        url_template: Optional custom overlay URL template.
        channel: Release channel for a custom template.
        version: Base Elide version.
        os: Platform OS token.
        cpu: Platform CPU token.

    Returns:
        The overlay archive URL, using the same tag mapping as base archives.
    """
    if url_template:
        return download_url(url_template, channel, version, os, cpu)
    return download_url("", channel, version, os, cpu).replace("/elide.", "/elide.python.")
