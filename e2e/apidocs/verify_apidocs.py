#!/usr/bin/env python3
"""Checks the elide_apidocs sites and archives built by `bazel build //...` here."""

import json
import pathlib
import sys
import tarfile

BIN = pathlib.Path(__file__).resolve().parent / "bazel-bin"
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def site(name):
    root = BIN / f"{name}_site"
    check(root.is_dir(), f"{root} is missing")
    for page in ("index.html", "api.json"):
        check((root / page).is_file(), f"{name}: {page} is missing")
    return root


def archive(name, root):
    path = BIN / f"{name}.tar.gz"
    files = sorted(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file())
    with tarfile.open(path, "r:gz") as tar:
        members = tar.getmembers()
    names = sorted(m.name for m in members if m.isfile())
    check(names == files, f"{path.name} does not hold exactly the site's files")
    check(all(m.mtime == 315532800 and m.uid == 0 and m.gid == 0 for m in members),
          f"{path.name} has unpinned entry metadata")
    return names


# A Markdown comment, {@inheritDoc} of Object.toString, theme, offline links and exclusions.
fixture = site("fixture_docs")
greeter = fixture / "fixture" / "Greeter.html"
check(greeter.is_file(), "fixture_docs: fixture/Greeter.html is missing")
if greeter.is_file():
    html = greeter.read_text(encoding="utf-8")
    check("<strong>emphasis</strong>" in html, "the /// Markdown comment was not rendered")
    check("toString()" in html, "Greeter.toString() is not documented")
    check("https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html" in html,
          "JDK types are not linked through offline_links")
check(not (fixture / "fixture" / "internal").exists(), "exclude_packages left fixture.internal in")
check("rules_elide elide_apidocs fixture" in (fixture / "index.html").read_text(encoding="utf-8"),
      "the theme footer is missing")
model = json.loads((fixture / "api.json").read_text(encoding="utf-8"))
check(model["module"].get("name") == "Fixture API", "api.json has the wrong library name")
check(model["module"].get("version") == "1.2.3", "api.json has the wrong library version")
names = archive("fixture_docs", fixture)
check(any(len(n.encode()) > 100 for n in names), "the archive has no path that needs a PAX header")

# Generated sources: documented when the source jar has them, resolved from the classpath when not.
catalogue = site("catalogue_docs") / "catalogue"
for page in ("Catalogue.html", "CatalogueIndex.html"):
    check((catalogue / page).is_file(), f"catalogue_docs: catalogue/{page} is missing")
archive("catalogue_docs", catalogue.parent)
classpath = site("catalogue_classpath_docs") / "catalogue"
check((classpath / "Catalogue.html").is_file(), "catalogue_classpath_docs: Catalogue.html is missing")
check(not (classpath / "CatalogueIndex.html").exists(),
      "catalogue_classpath_docs documented CatalogueIndex, which its source jar does not hold")
if (classpath / "Catalogue.html").is_file():
    check("CatalogueIndex" in (classpath / "Catalogue.html").read_text(encoding="utf-8"),
          "Catalogue.index() does not name its generated return type")

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print("elide_apidocs: sites, archives, Markdown, links and generated-class references verified.")
