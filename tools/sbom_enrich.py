#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Enrich an SPDX JSON SBOM with the direct MODULE.bazel bazel_dep closure.

Reads an SPDX 2.3 document (produced by syft over the release tarball) plus the
repo MODULE.bazel, and adds one SPDX package per direct `bazel_dep` (name +
version) with a DEPENDS_ON relationship from the document's root package — so
the SBOM reflects the Bazel dependency graph, not only file contents.

Usage: sbom_enrich.py <spdx.json> <MODULE.bazel>   (mutates <spdx.json> in place)
"""

import json
import re
import sys

# Matches `bazel_dep(name = "X", version = "Y" ...)`; dev_dependency entries
# (which list version before the dev flag) are included.
_BAZEL_DEP = re.compile(
    r'bazel_dep\(\s*name\s*=\s*"(?P<name>[^"]+)"\s*,\s*version\s*=\s*"(?P<version>[^"]+)"'
)


def parse_bazel_deps(module_text):
    """Returns [(name, version), ...] for each direct bazel_dep with a version."""
    return [(m.group("name"), m.group("version")) for m in _BAZEL_DEP.finditer(module_text)]


def enrich(spdx, deps):
    """Adds an SPDX package + DEPENDS_ON relationship per (name, version) dep."""
    describes = spdx.get("documentDescribes") or []
    root_id = describes[0] if describes else "SPDXRef-DOCUMENT"
    packages = spdx.setdefault("packages", [])
    relationships = spdx.setdefault("relationships", [])
    existing = {p.get("SPDXID") for p in packages}
    for name, version in deps:
        spdxid = "SPDXRef-Package-bazeldep-" + re.sub(r"[^A-Za-z0-9.-]", "-", name)
        if spdxid in existing:
            continue
        existing.add(spdxid)
        packages.append({
            "SPDXID": spdxid,
            "name": name,
            "versionInfo": version,
            "downloadLocation": "NOASSERTION",
            "filesAnalyzed": False,
            "externalRefs": [{
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": "pkg:generic/bazel/%s@%s" % (name, version),
            }],
        })
        relationships.append({
            "spdxElementId": root_id,
            "relationshipType": "DEPENDS_ON",
            "relatedSpdxElement": spdxid,
        })
    return spdx


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: sbom_enrich.py <spdx.json> <MODULE.bazel>")
    spdx_path, module_path = argv[1], argv[2]
    with open(spdx_path, encoding="utf-8") as f:
        spdx = json.load(f)
    with open(module_path, encoding="utf-8") as f:
        deps = parse_bazel_deps(f.read())
    enrich(spdx, deps)
    with open(spdx_path, "w", encoding="utf-8") as f:
        json.dump(spdx, f, indent=2)
        f.write("\n")
    print("enriched %s with %d bazel_dep package(s)" % (spdx_path, len(deps)))


if __name__ == "__main__":
    main(sys.argv)
