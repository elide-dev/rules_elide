"""Public API entry point for rules_elide.

Downstream users should load all symbols from this file. Internal paths under
`elide/` are not part of the stable API.
"""

load(
    "//elide/rules:java.bzl",
    _elide_java_binary = "elide_java_binary",
    _elide_java_library = "elide_java_library",
    _elide_java_test = "elide_java_test",
)
load(
    "//elide/rules:kotlin.bzl",
    _elide_kotlin_binary = "elide_kotlin_binary",
    _elide_kotlin_library = "elide_kotlin_library",
    _elide_kotlin_test = "elide_kotlin_test",
)
load(
    ":providers.bzl",
    _ElideInfo = "ElideInfo",
    _ElideToolchainInfo = "ElideToolchainInfo",
)
load(":toolchain.bzl", _elide_toolchain = "elide_toolchain")

ElideInfo = _ElideInfo
ElideToolchainInfo = _ElideToolchainInfo
elide_java_binary = _elide_java_binary
elide_java_library = _elide_java_library
elide_java_test = _elide_java_test
elide_kotlin_binary = _elide_kotlin_binary
elide_kotlin_library = _elide_kotlin_library
elide_kotlin_test = _elide_kotlin_test
elide_toolchain = _elide_toolchain
