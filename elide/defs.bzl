"""Public API entry point for rules_elide.

Downstream users should load all symbols from this file. Internal paths under
`elide/` are not part of the stable API.
"""

load(
    ":providers.bzl",
    _ElideInfo = "ElideInfo",
    _ElideToolchainInfo = "ElideToolchainInfo",
)
load(":toolchain.bzl", _elide_toolchain = "elide_toolchain")

ElideInfo = _ElideInfo
ElideToolchainInfo = _ElideToolchainInfo
elide_toolchain = _elide_toolchain
