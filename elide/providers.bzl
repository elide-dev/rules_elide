"""Public providers for rules_elide."""

ElideToolchainInfo = provider(
    doc = "Resolved Elide toolchain information.",
    fields = {
        "binary": "File. The elide binary executable.",
        "tool_files": "depset[File]. All runfiles required to invoke elide.",
        "version": "string. Semantic version of the elide binary.",
    },
)

ElideInfo = provider(
    doc = "Elide-specific metadata emitted by rules_elide build rules.",
    fields = {
        "exported_compiler_plugins": "depset[Target]. Compiler plugins propagated " +
                                     "to direct rdeps. Mirrors java_plugin's exported_plugins.",
        "manifest": "File or None. Optional elide.pkl-style project manifest.",
    },
)
