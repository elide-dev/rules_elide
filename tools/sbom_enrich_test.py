# SPDX-License-Identifier: Apache-2.0
"""Tests for the SPDX SBOM bazel_dep enrichment helper."""

from sbom_enrich import enrich, parse_bazel_deps

_MODULE = """
module(name = "rules_elide")
bazel_dep(name = "platforms", version = "1.1.0")
bazel_dep(name = "rules_kotlin", version = "2.4.0")
bazel_dep(name = "stardoc", version = "0.8.1", dev_dependency = True)
local_path_override(module_name = "ignored", path = "..")
"""


def test_parse_bazel_deps_extracts_name_and_version():
    deps = parse_bazel_deps(_MODULE)
    assert ("platforms", "1.1.0") in deps
    assert ("rules_kotlin", "2.4.0") in deps
    assert ("stardoc", "0.8.1") in deps  # dev_dependency entries included
    assert all(name != "ignored" for name, _ in deps)  # non-bazel_dep ignored


def test_enrich_adds_package_and_relationship():
    spdx = {
        "documentDescribes": ["SPDXRef-Package-root"],
        "packages": [{"SPDXID": "SPDXRef-Package-root", "name": "rules_elide"}],
    }
    enrich(spdx, [("platforms", "1.1.0")])
    pkg = next(p for p in spdx["packages"] if p.get("name") == "platforms")
    assert pkg["versionInfo"] == "1.1.0"
    assert pkg["externalRefs"][0]["referenceLocator"] == "pkg:bazel/platforms@1.1.0"
    rel = spdx["relationships"][0]
    assert rel["relationshipType"] == "DEPENDS_ON"
    assert rel["spdxElementId"] == "SPDXRef-Package-root"
    assert rel["relatedSpdxElement"] == pkg["SPDXID"]


def test_enrich_is_idempotent():
    spdx = {"documentDescribes": ["SPDXRef-DOCUMENT"], "packages": [], "relationships": []}
    enrich(spdx, [("platforms", "1.1.0")])
    enrich(spdx, [("platforms", "1.1.0")])
    pkgs = [p for p in spdx["packages"] if p.get("name") == "platforms"]
    assert len(pkgs) == 1
