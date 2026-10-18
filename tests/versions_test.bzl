# SPDX-License-Identifier: Apache-2.0

"""Unit tests for pure helpers in elide/private/versions.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//elide/private:versions.bzl", "DEFAULT_VERSION", "ELIDE_VERSIONS", "PLATFORMS", "archive_ext", "binary_ext", "release_tag")

def _archive_ext_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "tgz", archive_ext("linux"))
    asserts.equals(env, "tgz", archive_ext("macos"))
    asserts.equals(env, "zip", archive_ext("windows"))
    return unittest.end(env)

_archive_ext_test = unittest.make(_archive_ext_test_impl)

def _binary_ext_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "", binary_ext("linux"))
    asserts.equals(env, "", binary_ext("macos"))
    asserts.equals(env, ".exe", binary_ext("windows"))  # token still mapped for future use
    return unittest.end(env)

_binary_ext_test = unittest.make(_binary_ext_test_impl)

def _platforms_complete_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, 4, len(PLATFORMS))
    asserts.true(env, ("linux", "amd64") in PLATFORMS, "linux/amd64 missing")
    asserts.true(env, ("linux", "arm64") in PLATFORMS, "linux/arm64 missing")
    asserts.true(env, ("macos", "arm64") in PLATFORMS, "macos/arm64 missing")
    asserts.true(env, ("windows", "amd64") in PLATFORMS, "windows/amd64 missing")
    return unittest.end(env)

_platforms_complete_test = unittest.make(_platforms_complete_test_impl)

def _release_tag_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "1.3.6+20260628", release_tag("1.3.6+20260628"))
    asserts.equals(env, "v1.6.0-rc.2", release_tag("1.6.0-rc.2"))
    asserts.equals(env, "v1.6.0", release_tag("1.6.0"))
    asserts.true(env, DEFAULT_VERSION in ELIDE_VERSIONS, "DEFAULT_VERSION has no integrity row")
    return unittest.end(env)

_release_tag_test = unittest.make(_release_tag_test_impl)

def versions_test_suite(name):
    """Wires unit tests for versions.bzl helpers.

    Args:
        name: test_suite target name aggregating all version-helper tests.
    """
    _archive_ext_test(name = "archive_ext_test")
    _binary_ext_test(name = "binary_ext_test")
    _platforms_complete_test(name = "platforms_complete_test")
    _release_tag_test(name = "release_tag_test")
    native.test_suite(
        name = name,
        tests = [
            ":archive_ext_test",
            ":binary_ext_test",
            ":platforms_complete_test",
            ":release_tag_test",
        ],
    )
