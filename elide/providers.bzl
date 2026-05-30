"""Public providers for rules_elide."""

ElideToolchainInfo = provider(
    doc = "Resolved Elide toolchain information.",
    fields = {
        "binary": "File. The elide binary executable.",
        "tool_files": "depset[File]. All runfiles required to invoke elide.",
        "version": "string. Semantic version of the elide binary.",
    },
)
