"""Internal helpers shared by rules_elide compile rules."""

load("//elide:providers.bzl", "ElideInfo")

visibility(["//elide/...", "//tests/..."])

def collect_exported_plugins(deps):
    """Merges `exported_compiler_plugins` depsets from `deps` that carry ElideInfo.

    Args:
        deps: list[Target]. Direct dependencies; non-ElideInfo entries are ignored.

    Returns:
        depset[Target]. Union of `exported_compiler_plugins` across the inputs.
    """
    return depset(transitive = [
        d[ElideInfo].exported_compiler_plugins
        for d in deps
        if ElideInfo in d
    ])
