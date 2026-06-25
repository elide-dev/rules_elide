# Changelog

## [0.1.0](https://github.com/elide-dev/rules_elide/compare/v0.1.0...v0.1.0) (2026-06-25)


### Features

* **benchmarks:** e2e Elide-vs-baseline build benchmarks (CodSpeed) ([#23](https://github.com/elide-dev/rules_elide/issues/23)) ([87401ee](https://github.com/elide-dev/rules_elide/commit/87401eec70c2266663423399d79b74605b3db1ca))
* **kotlin-builder:** rewrite builtin-plugin -Xplugin to --plugins (with warning) ([#22](https://github.com/elide-dev/rules_elide/issues/22)) ([795195e](https://github.com/elide-dev/rules_elide/commit/795195edb432088262fac6d1e50cae9d3be7701c))
* **kotlin:** Karbine ABI compile-avoidance (opt-in) — issue [#11](https://github.com/elide-dev/rules_elide/issues/11) ([#21](https://github.com/elide-dev/rules_elide/issues/21)) ([aa84819](https://github.com/elide-dev/rules_elide/commit/aa84819e1e81bef5ece1b75c47109c02cd5e3de0))
* MODULE.bazel + bazel_dep set ([f1ac874](https://github.com/elide-dev/rules_elide/commit/f1ac874654850ac1087f46c5ca17180bd9a7ea62))
* **rbe:** BuildBuddy remote execution + e2e RBE test ([#31](https://github.com/elide-dev/rules_elide/issues/31)) ([b6c9c07](https://github.com/elide-dev/rules_elide/commit/b6c9c07e0de48039f9f057188a0ad6c9ec3002d9))
* **release:** automated release flow — BCR + SLSA L2 + Sigstore + SBOM ([#32](https://github.com/elide-dev/rules_elide/issues/32)) ([ed992ce](https://github.com/elide-dev/rules_elide/commit/ed992ce340a69b0819a9286b34d978168e84930e))
* **rules:** elide_java_library + elide_java_binary ([a14ab0e](https://github.com/elide-dev/rules_elide/commit/a14ab0e2b3f19f7e52a4b4cb6ff819fb886ecda5))
* **rules:** elide_java_test + elide_kotlin_test ([aaeb5ae](https://github.com/elide-dev/rules_elide/commit/aaeb5ae6657c1e9173ff242c4ccb89cb2c9def16))
* **rules:** elide_kotlin_library + elide_kotlin_binary ([413cc62](https://github.com/elide-dev/rules_elide/commit/413cc6277c68e78e0a30137b342eb8285dfdda26))
* **rules:** elide_native_image ([d7cc897](https://github.com/elide-dev/rules_elide/commit/d7cc897e39b031635ef2a3db78401645838eefe9))
* **rules:** ElideInfo + common helpers ([e1c5d99](https://github.com/elide-dev/rules_elide/commit/e1c5d996627e09e059cc692fff8cc24cc0e20030))
* **rules:** persistent worker support ([36e07e9](https://github.com/elide-dev/rules_elide/commit/36e07e91acd20f23cadc34bec8b282ad06116feb))
* **toolchain:** module_extension with install tag_class ([960554c](https://github.com/elide-dev/rules_elide/commit/960554c91125524bb20ffed3e9b57e3c98695400))
* **toolchain:** per-platform download + hub repo rules ([b9b6161](https://github.com/elide-dev/rules_elide/commit/b9b616128629093bd14323d29d656e877edccc99))
* **toolchain:** toolchain_type + ElideToolchainInfo ([9e96233](https://github.com/elide-dev/rules_elide/commit/9e96233f226feeb88ac4fd3c27f1c566b0d7c7f9))


### Bug Fixes

* caching and hermetic builds ([b676f86](https://github.com/elide-dev/rules_elide/commit/b676f86bd738c703d24adb087274bf899e36f22d))
* caching and stable outputs ([801cc9e](https://github.com/elide-dev/rules_elide/commit/801cc9e6ec0b811503d824fab460f3c1674233de))
* **ci:** bump codeql-action to v4.36.0 (language=actions support) ([465eef3](https://github.com/elide-dev/rules_elide/commit/465eef3286e3da7e2e3ff87db748cfcfdf5dba2a))
* **ci:** gate codeql on public visibility (Code Security required) ([8fae838](https://github.com/elide-dev/rules_elide/commit/8fae838e5112b9514bd3f1c0e3f0b3540378f3f7))
* **ci:** grant codeql actions:read for language=actions ([3334974](https://github.com/elide-dev/rules_elide/commit/3334974e89293b9653cd0362fc288c921af6c9e4))
* **ci:** require Bazel 8+ and restore docs build after dep bumps ([c633cd7](https://github.com/elide-dev/rules_elide/commit/c633cd7dd22f1d611db894e4bcd594c7ea227503))
* **ci:** unblock main pipeline ([4d1d01a](https://github.com/elide-dev/rules_elide/commit/4d1d01a42b398e076aa4b221e9000f46c84ead40))
* comprehensive audit follow-ups ([891e244](https://github.com/elide-dev/rules_elide/commit/891e244d63d2e64e5673c0cd63870d9083d6f07d))
* drop native image stripping on mac ([a9af37b](https://github.com/elide-dev/rules_elide/commit/a9af37b1ab29377de3c95fd9170d941e9e9e6f72))
* end-to-end integration + benchmarks + windows launcher ([21b5b2f](https://github.com/elide-dev/rules_elide/commit/21b5b2f10a83e3fc92647e378f57489c2cf9776d))
* java home for native image targets ([a2d3ad0](https://github.com/elide-dev/rules_elide/commit/a2d3ad00175096e965e4481a7f815eccba922f7a))
* java home for native image targets ([e586e70](https://github.com/elide-dev/rules_elide/commit/e586e70d98ba958e939940954662343c58c0582f))
* **kotlin:** mirror rules_kotlin 2.4.0 toolchain fields ([e144fa5](https://github.com/elide-dev/rules_elide/commit/e144fa5d3139841aadb3d07392c0a558cc7de200))
* native image compilation ([3ac021b](https://github.com/elide-dev/rules_elide/commit/3ac021bfa4d73e74e2037759df619d3e6cc8888a))
* native image compilation ([bd81fbd](https://github.com/elide-dev/rules_elide/commit/bd81fbd12383c15c1653dbc7fefd1dfb89a23df9))
* native image stripping on mac ([b2274b5](https://github.com/elide-dev/rules_elide/commit/b2274b5a79c4876333cc982bcd807d90beadbadd))
* pin elide distribution ([cd5c41e](https://github.com/elide-dev/rules_elide/commit/cd5c41e6ae23dcfa1bdf039b7b5ae5e58b2805de))
* pin elide to latest ([afc5349](https://github.com/elide-dev/rules_elide/commit/afc5349d3ae08c1fdbbb3b4fde86268476c86cec))
* **release:** authenticate release-please with a PAT to open the release PR ([#33](https://github.com/elide-dev/rules_elide/issues/33)) ([0972f13](https://github.com/elide-dev/rules_elide/commit/0972f13a35ca98f3c076bd9f2b9a1c4f765b6947))
* **release:** support immutable releases (draft-&gt;publish) + fix BCR source fetch ([#40](https://github.com/elide-dev/rules_elide/issues/40)) ([63325e9](https://github.com/elide-dev/rules_elide/commit/63325e969f4e5d687a31f6f979bc84bc007bf9c8))
* upgrade bazel and benchmarks ([512faf2](https://github.com/elide-dev/rules_elide/commit/512faf29801bcc62108bd37fbed1eaef6f7ee586))

## 0.1.0 (2026-06-25)


### Features

* **benchmarks:** e2e Elide-vs-baseline build benchmarks (CodSpeed) ([#23](https://github.com/elide-dev/rules_elide/issues/23)) ([87401ee](https://github.com/elide-dev/rules_elide/commit/87401eec70c2266663423399d79b74605b3db1ca))
* **kotlin-builder:** rewrite builtin-plugin -Xplugin to --plugins (with warning) ([#22](https://github.com/elide-dev/rules_elide/issues/22)) ([795195e](https://github.com/elide-dev/rules_elide/commit/795195edb432088262fac6d1e50cae9d3be7701c))
* **kotlin:** Karbine ABI compile-avoidance (opt-in) — issue [#11](https://github.com/elide-dev/rules_elide/issues/11) ([#21](https://github.com/elide-dev/rules_elide/issues/21)) ([aa84819](https://github.com/elide-dev/rules_elide/commit/aa84819e1e81bef5ece1b75c47109c02cd5e3de0))
* MODULE.bazel + bazel_dep set ([f1ac874](https://github.com/elide-dev/rules_elide/commit/f1ac874654850ac1087f46c5ca17180bd9a7ea62))
* **rbe:** BuildBuddy remote execution + e2e RBE test ([#31](https://github.com/elide-dev/rules_elide/issues/31)) ([b6c9c07](https://github.com/elide-dev/rules_elide/commit/b6c9c07e0de48039f9f057188a0ad6c9ec3002d9))
* **release:** automated release flow — BCR + SLSA L2 + Sigstore + SBOM ([#32](https://github.com/elide-dev/rules_elide/issues/32)) ([ed992ce](https://github.com/elide-dev/rules_elide/commit/ed992ce340a69b0819a9286b34d978168e84930e))
* **rules:** elide_java_library + elide_java_binary ([a14ab0e](https://github.com/elide-dev/rules_elide/commit/a14ab0e2b3f19f7e52a4b4cb6ff819fb886ecda5))
* **rules:** elide_java_test + elide_kotlin_test ([aaeb5ae](https://github.com/elide-dev/rules_elide/commit/aaeb5ae6657c1e9173ff242c4ccb89cb2c9def16))
* **rules:** elide_kotlin_library + elide_kotlin_binary ([413cc62](https://github.com/elide-dev/rules_elide/commit/413cc6277c68e78e0a30137b342eb8285dfdda26))
* **rules:** elide_native_image ([d7cc897](https://github.com/elide-dev/rules_elide/commit/d7cc897e39b031635ef2a3db78401645838eefe9))
* **rules:** ElideInfo + common helpers ([e1c5d99](https://github.com/elide-dev/rules_elide/commit/e1c5d996627e09e059cc692fff8cc24cc0e20030))
* **rules:** persistent worker support ([36e07e9](https://github.com/elide-dev/rules_elide/commit/36e07e91acd20f23cadc34bec8b282ad06116feb))
* **toolchain:** module_extension with install tag_class ([960554c](https://github.com/elide-dev/rules_elide/commit/960554c91125524bb20ffed3e9b57e3c98695400))
* **toolchain:** per-platform download + hub repo rules ([b9b6161](https://github.com/elide-dev/rules_elide/commit/b9b616128629093bd14323d29d656e877edccc99))
* **toolchain:** toolchain_type + ElideToolchainInfo ([9e96233](https://github.com/elide-dev/rules_elide/commit/9e96233f226feeb88ac4fd3c27f1c566b0d7c7f9))


### Bug Fixes

* caching and hermetic builds ([b676f86](https://github.com/elide-dev/rules_elide/commit/b676f86bd738c703d24adb087274bf899e36f22d))
* caching and stable outputs ([801cc9e](https://github.com/elide-dev/rules_elide/commit/801cc9e6ec0b811503d824fab460f3c1674233de))
* **ci:** bump codeql-action to v4.36.0 (language=actions support) ([465eef3](https://github.com/elide-dev/rules_elide/commit/465eef3286e3da7e2e3ff87db748cfcfdf5dba2a))
* **ci:** gate codeql on public visibility (Code Security required) ([8fae838](https://github.com/elide-dev/rules_elide/commit/8fae838e5112b9514bd3f1c0e3f0b3540378f3f7))
* **ci:** grant codeql actions:read for language=actions ([3334974](https://github.com/elide-dev/rules_elide/commit/3334974e89293b9653cd0362fc288c921af6c9e4))
* **ci:** require Bazel 8+ and restore docs build after dep bumps ([c633cd7](https://github.com/elide-dev/rules_elide/commit/c633cd7dd22f1d611db894e4bcd594c7ea227503))
* **ci:** unblock main pipeline ([4d1d01a](https://github.com/elide-dev/rules_elide/commit/4d1d01a42b398e076aa4b221e9000f46c84ead40))
* comprehensive audit follow-ups ([891e244](https://github.com/elide-dev/rules_elide/commit/891e244d63d2e64e5673c0cd63870d9083d6f07d))
* drop native image stripping on mac ([a9af37b](https://github.com/elide-dev/rules_elide/commit/a9af37b1ab29377de3c95fd9170d941e9e9e6f72))
* end-to-end integration + benchmarks + windows launcher ([21b5b2f](https://github.com/elide-dev/rules_elide/commit/21b5b2f10a83e3fc92647e378f57489c2cf9776d))
* java home for native image targets ([a2d3ad0](https://github.com/elide-dev/rules_elide/commit/a2d3ad00175096e965e4481a7f815eccba922f7a))
* java home for native image targets ([e586e70](https://github.com/elide-dev/rules_elide/commit/e586e70d98ba958e939940954662343c58c0582f))
* **kotlin:** mirror rules_kotlin 2.4.0 toolchain fields ([e144fa5](https://github.com/elide-dev/rules_elide/commit/e144fa5d3139841aadb3d07392c0a558cc7de200))
* native image compilation ([3ac021b](https://github.com/elide-dev/rules_elide/commit/3ac021bfa4d73e74e2037759df619d3e6cc8888a))
* native image compilation ([bd81fbd](https://github.com/elide-dev/rules_elide/commit/bd81fbd12383c15c1653dbc7fefd1dfb89a23df9))
* native image stripping on mac ([b2274b5](https://github.com/elide-dev/rules_elide/commit/b2274b5a79c4876333cc982bcd807d90beadbadd))
* pin elide distribution ([cd5c41e](https://github.com/elide-dev/rules_elide/commit/cd5c41e6ae23dcfa1bdf039b7b5ae5e58b2805de))
* pin elide to latest ([afc5349](https://github.com/elide-dev/rules_elide/commit/afc5349d3ae08c1fdbbb3b4fde86268476c86cec))
* **release:** authenticate release-please with a PAT to open the release PR ([#33](https://github.com/elide-dev/rules_elide/issues/33)) ([0972f13](https://github.com/elide-dev/rules_elide/commit/0972f13a35ca98f3c076bd9f2b9a1c4f765b6947))
* **release:** support immutable releases (draft-&gt;publish) + fix BCR source fetch ([#40](https://github.com/elide-dev/rules_elide/issues/40)) ([63325e9](https://github.com/elide-dev/rules_elide/commit/63325e969f4e5d687a31f6f979bc84bc007bf9c8))
* upgrade bazel and benchmarks ([512faf2](https://github.com/elide-dev/rules_elide/commit/512faf29801bcc62108bd37fbed1eaef6f7ee586))

## Changelog
