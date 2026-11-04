# SPDX-License-Identifier: Apache-2.0

"""Public API entry point for rules_elide.

Downstream users should load all symbols from this file. Internal paths under
`elide/` are not part of the stable API.
"""

load(
    "//elide/rules:format.bzl",
    _elide_format = "elide_format",
)
load(
    "//elide/rules:java.bzl",
    _elide_java_binary = "elide_java_binary",
    _elide_java_library = "elide_java_library",
    _elide_java_test = "elide_java_test",
)
load(
    "//elide/rules:jvm_tools.bzl",
    _elide_jar = "elide_jar",
    _elide_javadoc = "elide_javadoc",
    _elide_javap = "elide_javap",
    _elide_jdeps = "elide_jdeps",
    _elide_jextract = "elide_jextract",
)
load(
    "//elide/rules:kotlin.bzl",
    _elide_kotlin_binary = "elide_kotlin_binary",
    _elide_kotlin_library = "elide_kotlin_library",
    _elide_kotlin_test = "elide_kotlin_test",
)
load(
    "//elide/rules:native_image.bzl",
    _elide_native_image = "elide_native_image",
)
load(
    "//elide/rules:processing.bzl",
    _elide_kapt = "elide_kapt",
    _elide_ksp = "elide_ksp",
)
load(
    ":providers.bzl",
    _ElideInfo = "ElideInfo",
    _ElideToolchainInfo = "ElideToolchainInfo",
)
load(":toolchain.bzl", _elide_toolchain = "elide_toolchain")

ElideInfo = _ElideInfo
ElideToolchainInfo = _ElideToolchainInfo
elide_format = _elide_format
elide_java_binary = _elide_java_binary
elide_java_library = _elide_java_library
elide_java_test = _elide_java_test
elide_kotlin_binary = _elide_kotlin_binary
elide_kotlin_library = _elide_kotlin_library
elide_kotlin_test = _elide_kotlin_test
elide_native_image = _elide_native_image
elide_toolchain = _elide_toolchain
elide_javadoc = _elide_javadoc
elide_jar = _elide_jar
elide_jdeps = _elide_jdeps
elide_javap = _elide_javap
elide_jextract = _elide_jextract
elide_kapt = _elide_kapt
elide_ksp = _elide_ksp
