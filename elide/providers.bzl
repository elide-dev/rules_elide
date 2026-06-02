# SPDX-License-Identifier: Apache-2.0

"""Public providers for rules_elide."""

ElideToolchainInfo = provider(
    doc = "Resolved Elide toolchain information.",
    fields = {
        "binary": "File. The elide binary executable.",
        "compile_tool_files": "depset[File]. Inputs for JVM compile actions (javac, kotlinc, jar). " +
                              "Excludes native-image-only subtrees (lib/svm, lib/truffle, doc).",
        "kotlin_stdlib_jars": "depset[File]. Kotlin stdlib jar(s) bundled with this Elide release.",
        "tool_files": "depset[File]. Inputs for native-image actions (includes lib/svm, include/).",
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
