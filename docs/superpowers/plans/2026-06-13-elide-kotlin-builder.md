# Elide KotlinBuilder Shim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an in-repo, `rules_kotlin`-compatible KotlinBuilder shim that compiles plain `kt_jvm_library` targets through the Elide binary, and transparently falls back to the stock KotlinBuilder for annotation-processing (KAPT/KSP) targets — so existing `rules_kotlin` graphs can adopt Elide via a toolchain swap, with zero rule migration.

**Architecture:** `rules_kotlin` runs a single executable (the `kotlinbuilder` toolchain attribute) per compile, as a Bazel persistent worker, handing it a `--flagfile`. Our shim is that executable. It parses the flagfile, and **routes**: requests carrying `--processors`/`--processorpath` (KAPT) or a KSP compiler plugin → exec the *assigned stock KotlinBuilder* with the original flagfile verbatim (fallback); everything else → drive the handed `elide` binary (`kotlinc` + `javac` for mixed sources), produce `jar`, `abijar` (embedded `jvm-abi-gen`, Elide 1.3.x), `srcjar`, and `jdeps` (real once WHIPLASH #998 lands; permissive stub + `strict_kotlin_deps` forced off until then). The shim is written in Kotlin, compiled with rules_elide's own `elide_kotlin_binary` (dogfood), and speaks the Bazel worker protocol via **Java bindings generated from Bazel's vendored `worker_protocol.proto`** (`rules_proto` `proto_library` + `protobuf` `java_proto_library`), with **`rules_buf`** providing proto lint/breaking checks. The `.jdeps` `Deps.Dependencies` is likewise built from Bazel's vendored `deps.proto`, generated the same way.

**Tech Stack:** Kotlin (shim), Starlark (toolchain macro + tests), the Elide binary (`kotlinc`/`javac`/`jvm-abi-gen`); Bazel persistent worker protocol via generated protos (`rules_proto` + `protobuf` `java_proto_library` over Bazel's vendored `worker_protocol.proto`/`deps.proto`; `rules_buf` for proto lint — note `rules_buf` does **not** generate code, it lints/breaking-checks alongside `proto_library`); `rules_kotlin` (consumer + fallback builder); `analysistest`/`sh_test` for verification.

**Verified contract (this session):**
- Toolchain seam: `define_kt_toolchain(..., kotlinbuilder = <exe>)`; compile action runs `toolchains.kt.kotlinbuilder.files_to_run.executable`, mnemonic `KotlinCompile`, persistent worker, `--flagfile=%s` multiline.
- Flag schema written by `_run_kt_builder_action`: `--output`, `--abi_jar`, `--kotlin_output_jdeps`, `--sources`, `--source_jars`, `--direct_dependencies`, `--classpath`, `--kotlin_friend_paths`, `--deps_artifacts`, `--kotlin_passthrough_flags`, `--javacopts`, `--strict_kotlin_deps`, `--reduced_classpath_mode`, `--build_kotlin`, `--module_name`, `--processors`, `--processorpath`, `--stubs_plugin_classpath`, `--stubs_plugin_options`, `--compiler_plugin_classpath`, `--compiler_plugin_options`, ABI plugin tuning flags.
- `JvmCompilationTask` outputs the action declares: `jar`, `abijar`, `jdeps`, `srcjar`, plus KSP/KAPT jars (only on fallback paths).
- Routing trigger for fallback: KAPT = `--processors` non-empty; KSP = a `--compiler_plugin_classpath`/`--stubs_plugin_classpath` entry that is a KSP plugin. `jvm-abi-gen` is NOT a fallback trigger (we own it).

---

## File Structure

- `elide/kotlin/builder/proto/worker_protocol.proto`, `deps.proto` — vendored from Bazel `src/main/protobuf` (Apache-2.0, headers preserved).
- `elide/kotlin/builder/proto/BUILD.bazel` — `proto_library` + `java_proto_library` (generated bindings) + `buf_lint_test`.
- `elide/kotlin/builder/Worker.kt` — thin wrapper over generated `WorkRequest.parseDelimitedFrom` / `WorkResponse.writeDelimitedTo`.
- `elide/kotlin/builder/Flagfile.kt` — flagfile reader + `CompileRequest` model (parsed view of the rules_kotlin flags we consume).
- `elide/kotlin/builder/Router.kt` — pure function: `CompileRequest -> Route` (FAST | FALLBACK) with reason.
- `elide/kotlin/builder/ElideCompile.kt` — fast path: build + run the elide invocations, emit `jar`/`abijar`/`srcjar`.
- `elide/kotlin/builder/Jdeps.kt` — builds the generated `Deps.Dependencies` proto written to the `.jdeps` output.
- `elide/kotlin/builder/Fallback.kt` — exec the stock KotlinBuilder with the original flagfile, proxy exit code/output.
- `elide/kotlin/builder/Main.kt` — entrypoint: dispatch worker vs one-shot; wire the pieces; receives `--elide=<path>` and `--fallback_builder=<path>` shim config (passed before `--flagfile`).
- `elide/kotlin/builder/BUILD.bazel` — `elide_kotlin_binary` for the shim (deps on `:proto` Java bindings) + a `filegroup` for test fixtures.
- `MODULE.bazel` (root) — add `rules_proto`, `protobuf`, `rules_buf` + buf toolchain.
- `elide/kotlin/toolchain.bzl` — `register_elide_kotlin_toolchain(name, elide, fallback_toolchain, ...)` macro registering a `kt_toolchain` whose `kotlinbuilder` is our shim.
- `tests/kotlin_builder/` — unit tests (`*_test.kt` run via `elide_kotlin_test`) for Flagfile/Router/codec.
- `e2e/kotlin_builder/` — standalone workspace: `rules_kotlin` + local `rules_elide`, a plain `kt_jvm_library` (fast path) and a KAPT `kt_jvm_library` (fallback), with `sh_test`s asserting outputs.

**Shim invocation contract (how rules_kotlin calls us):** the toolchain sets the executable to a launcher that already embeds `--elide=<path> --fallback_builder=<path>` as leading args; rules_kotlin appends the worker `--flagfile=<f>` (or streams a WorkRequest whose `arguments` are `[--flagfile=<f>]`). So argv = `[shim-config..., --flagfile=<f>]`.

---

## Phase 0 — e2e test workspace (so every later phase is verifiable)

### Task 0: Standalone rules_kotlin + rules_elide workspace

**Files:**
- Create: `e2e/kotlin_builder/MODULE.bazel`
- Create: `e2e/kotlin_builder/.bazelrc`, `.bazelversion` (copy from `e2e/integration`)
- Create: `e2e/kotlin_builder/BUILD.bazel`
- Create: `e2e/kotlin_builder/sample/Greeter.kt`

- [ ] **Step 1: Create the module wiring**

`e2e/kotlin_builder/MODULE.bazel`:
```python
module(name = "rules_elide_kotlin_builder_e2e")

bazel_dep(name = "rules_elide", version = "0.0.0")
local_path_override(module_name = "rules_elide", path = "../..")

bazel_dep(name = "rules_kotlin", version = "2.3.20")
bazel_dep(name = "rules_java", version = "9.6.1")

elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(channel = "nightly")
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
```

- [ ] **Step 2: Add a plain Kotlin library + a baseline using the stock toolchain**

`e2e/kotlin_builder/BUILD.bazel`:
```python
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")

kt_jvm_library(
    name = "greeter",
    srcs = ["sample/Greeter.kt"],
)
```

`e2e/kotlin_builder/sample/Greeter.kt`:
```kotlin
package sample
object Greeter { fun hello(): String = "hi" }
```

- [ ] **Step 3: Verify the stock path builds (control)**

Run: `cd e2e/kotlin_builder && bazelisk build //:greeter`
Expected: builds with the stock rules_kotlin toolchain (KotlinBuilder). This is the control we will later swap.

- [ ] **Step 4: Commit**

```bash
git add e2e/kotlin_builder
git commit -m "test(kotlin-builder): e2e workspace with stock rules_kotlin control"
```

---

## Phase 0b — Dev-only JVM unit-test harness

### Task 0b: kotlin.test + JUnit5 via Maven (dev_dependency), with a smoke test

The shim's unit tests (Tasks 1,2,3,4,5b,5c) use `kotlin.test` run via `elide_kotlin_test`, which launches the JUnit Platform ConsoleLauncher. The main repo has no Maven setup, so add one — **dev-scoped** so it does not propagate to consumers.

**Files:**
- Modify: `MODULE.bazel` (root)
- Create: `tests/kotlin_builder/BUILD.bazel` (smoke target only for now)
- Create: `tests/kotlin_builder/SmokeTest.kt`

- [ ] **Step 1: Add dev-only Maven deps** to root `MODULE.bazel`:
```python
bazel_dep(name = "rules_jvm_external", version = "6.7", dev_dependency = True)

maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven", dev_dependency = True)
maven.install(
    name = "kt_test_deps",
    artifacts = [
        "org.jetbrains.kotlin:kotlin-test:KOTLIN_VERSION",          # match Elide's bundled Kotlin
        "org.jetbrains.kotlin:kotlin-test-junit5:KOTLIN_VERSION",
        "org.junit.jupiter:junit-jupiter:5.11.3",
        "org.junit.platform:junit-platform-console-standalone:1.11.3",
    ],
)
use_repo(maven, "kt_test_deps", dev_dependency = True)
```
Determine `KOTLIN_VERSION` to match the Kotlin the Elide toolchain compiles with (inspect the elide kotlin stdlib jar version, or `elide --version` / docs). A mismatch can cause metadata-version warnings/errors.

- [ ] **Step 2: Smoke test** `tests/kotlin_builder/SmokeTest.kt`:
```kotlin
package elide.kotlin.builder
import kotlin.test.Test
import kotlin.test.assertEquals
class SmokeTest { @Test fun harnessWorks() { assertEquals(2, 1 + 1) } }
```
`tests/kotlin_builder/BUILD.bazel`:
```python
load("@rules_elide//elide:defs.bzl", "elide_kotlin_test")

elide_kotlin_test(
    name = "smoke_test",
    srcs = ["SmokeTest.kt"],
    test_class = "elide.kotlin.builder.SmokeTest",
    # Emit bytecode the test-launcher JVM can load (it is Java 21 / class 65;
    # Elide defaults to a newer target). Adjust if the launcher JVM differs.
    kotlinc_opts = ["-jvm-target=21"],
    deps = ["@kt_test_deps//:org_jetbrains_kotlin_kotlin_test"],
    runtime_deps = [
        "@kt_test_deps//:org_jetbrains_kotlin_kotlin_test_junit5",
        "@kt_test_deps//:org_junit_jupiter_junit_jupiter",
        "@kt_test_deps//:org_junit_platform_junit_platform_console_standalone",
    ],
)
```

- [ ] **Step 3: Verify** — Run: `bazelisk test //tests/kotlin_builder:smoke_test` → PASS. If it fails with a class-file-version mismatch (e.g. "class file version 69.0 … up to 65.0"), reconcile the `-jvm-target`/launcher JVM; if unresolvable, report BLOCKED with the exact error.

- [ ] **Step 4: Commit**

```bash
git add MODULE.bazel tests/kotlin_builder
git commit -m "test(kotlin-builder): dev-only kotlin.test + JUnit5 harness with smoke test"
```

---

## Phase 1 — Flagfile parsing (pure, fully unit-testable)

### Task 1: `CompileRequest` model + flagfile reader

**Files:**
- Create: `elide/kotlin/builder/Flagfile.kt`
- Test: `tests/kotlin_builder/FlagfileTest.kt`
- Create: `tests/kotlin_builder/testdata/fast.flagfile`, `tests/kotlin_builder/testdata/kapt.flagfile`

**Flagfile format:** rules_kotlin writes multiline params — one token per line; a `--flag` line is followed by one or more value lines until the next `--flag`. Repeated flags accumulate. Example (`fast.flagfile`):
```
--output
bazel-out/k8-fastbuild/bin/greeter.jar
--abi_jar
bazel-out/k8-fastbuild/bin/greeter.abi.jar
--kotlin_output_jdeps
bazel-out/k8-fastbuild/bin/greeter.jdeps
--module_name
greeter
--sources
sample/Greeter.kt
--classpath
external/.../kotlin-stdlib.jar
--strict_kotlin_deps
off
--build_kotlin
true
```
`kapt.flagfile` is the same plus:
```
--processors
com.example.MyProcessor
--processorpath
external/.../my-processor.jar
```

- [ ] **Step 1: Write the failing test**

`tests/kotlin_builder/FlagfileTest.kt`:
```kotlin
package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FlagfileTest {
    @Test fun parsesScalarAndRepeatedFlags() {
        val req = Flagfile.parse(listOf(
            "--output", "out.jar",
            "--module_name", "greeter",
            "--sources", "A.kt", "B.kt",
            "--classpath", "a.jar", "b.jar",
            "--strict_kotlin_deps", "off",
        ))
        assertEquals("out.jar", req.output)
        assertEquals("greeter", req.moduleName)
        assertEquals(listOf("A.kt", "B.kt"), req.sources)
        assertEquals(listOf("a.jar", "b.jar"), req.classpath)
        assertEquals("off", req.strictKotlinDeps)
        assertTrue(req.processors.isEmpty())
    }

    @Test fun capturesProcessorsForKapt() {
        val req = Flagfile.parse(listOf("--processors", "com.example.P", "--processorpath", "p.jar"))
        assertEquals(listOf("com.example.P"), req.processors)
        assertEquals(listOf("p.jar"), req.processorPath)
    }
}
```

- [ ] **Step 2: Run it to verify failure**

Run: `cd tests/kotlin_builder && bazelisk test //tests/kotlin_builder:flagfile_test`
Expected: FAIL — `Flagfile` unresolved. (BUILD target added in Task 6; until then run against a temporary `elide_kotlin_test` you add in this task's BUILD.)

- [ ] **Step 3: Implement `Flagfile.kt`**

```kotlin
package elide.kotlin.builder

import java.nio.file.Files
import java.nio.file.Path

/** Parsed, typed view of the rules_kotlin KotlinBuilder flagfile fields we consume. */
data class CompileRequest(
    val output: String? = null,
    val abiJar: String? = null,
    val jdeps: String? = null,
    val srcjar: String? = null,
    val moduleName: String? = null,
    val sources: List<String> = emptyList(),
    val sourceJars: List<String> = emptyList(),
    val classpath: List<String> = emptyList(),
    val directDependencies: List<String> = emptyList(),
    val friendPaths: List<String> = emptyList(),
    val passthroughFlags: List<String> = emptyList(),
    val javacOpts: List<String> = emptyList(),
    val strictKotlinDeps: String = "off",
    val processors: List<String> = emptyList(),
    val processorPath: List<String> = emptyList(),
    val compilerPluginClasspath: List<String> = emptyList(),
    val stubsPluginClasspath: List<String> = emptyList(),
    val raw: Map<String, List<String>> = emptyMap(),
)

object Flagfile {
    /** Reads `--flagfile=<path>` content (one token per line) into tokens. */
    fun readTokens(flagfilePath: Path): List<String> =
        Files.readAllLines(flagfilePath).filter { it.isNotEmpty() }

    fun parse(tokens: List<String>): CompileRequest {
        val map = LinkedHashMap<String, MutableList<String>>()
        var cur: MutableList<String>? = null
        for (t in tokens) {
            if (t.startsWith("--")) {
                cur = map.getOrPut(t) { mutableListOf() }
            } else {
                cur?.add(t)
            }
        }
        fun first(k: String) = map[k]?.firstOrNull()
        fun list(k: String) = map[k]?.toList() ?: emptyList()
        return CompileRequest(
            output = first("--output"),
            abiJar = first("--abi_jar"),
            jdeps = first("--kotlin_output_jdeps"),
            srcjar = first("--kotlin_output_srcjar"),
            moduleName = first("--module_name"),
            sources = list("--sources"),
            sourceJars = list("--source_jars"),
            classpath = list("--classpath"),
            directDependencies = list("--direct_dependencies"),
            friendPaths = list("--kotlin_friend_paths"),
            passthroughFlags = list("--kotlin_passthrough_flags"),
            javacOpts = list("--javacopts"),
            strictKotlinDeps = first("--strict_kotlin_deps") ?: "off",
            processors = list("--processors"),
            processorPath = list("--processorpath"),
            compilerPluginClasspath = list("--compiler_plugin_classpath"),
            stubsPluginClasspath = list("--stubs_plugin_classpath"),
            raw = map.mapValues { it.value.toList() },
        )
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `bazelisk test //tests/kotlin_builder:flagfile_test`
Expected: PASS.

- [ ] **Step 5: Capture a REAL flagfile to validate the schema** (de-risk)

In `e2e/kotlin_builder`, build the control target with `--subcommands` / `--sandbox_debug` and recover the actual `*.jar-0.params`/flagfile rules_kotlin generated for `:greeter`. Diff its flag names against the parser's known keys; add any missing ones to `CompileRequest`. Save a copy as `tests/kotlin_builder/testdata/real_fast.flagfile` and add a parse test over it.

- [ ] **Step 6: Commit**

```bash
git add elide/kotlin/builder/Flagfile.kt tests/kotlin_builder
git commit -m "feat(kotlin-builder): parse rules_kotlin flagfile into CompileRequest"
```

---

## Phase 2 — Routing (pure)

### Task 2: `Router` — fast path vs fallback

**Files:**
- Create: `elide/kotlin/builder/Router.kt`
- Test: `tests/kotlin_builder/RouterTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals

class RouterTest {
    @Test fun plainCompileIsFast() {
        val r = Router.route(CompileRequest(sources = listOf("A.kt")))
        assertEquals(Route.FAST, r.route)
    }
    @Test fun kaptFallsBack() {
        val r = Router.route(CompileRequest(processors = listOf("com.example.P")))
        assertEquals(Route.FALLBACK, r.route)
    }
    @Test fun kspPluginFallsBack() {
        val r = Router.route(CompileRequest(
            compilerPluginClasspath = listOf("external/maven/symbol-processing-cmdline.jar")))
        assertEquals(Route.FALLBACK, r.route)
    }
    @Test fun jvmAbiGenIsNotFallback() {
        val r = Router.route(CompileRequest(
            compilerPluginClasspath = listOf("external/.../kotlin-jvm-abi-gen.jar")))
        assertEquals(Route.FAST, r.route)
    }
}
```

- [ ] **Step 2: Run to verify failure** — Run: `bazelisk test //tests/kotlin_builder:router_test` → FAIL (unresolved `Router`).

- [ ] **Step 3: Implement `Router.kt`**

```kotlin
package elide.kotlin.builder

enum class Route { FAST, FALLBACK }

data class Routing(val route: Route, val reason: String)

object Router {
    // Plugin jars that signal a path Elide does not yet handle. jvm-abi-gen is
    // explicitly excluded: Elide 1.3.x runs it itself for the abijar.
    private val KSP_MARKERS = listOf("symbol-processing", "/ksp", "ksp-")

    private fun anyKsp(jars: List<String>) =
        jars.any { j -> KSP_MARKERS.any { j.contains(it) } }

    fun route(req: CompileRequest): Routing {
        if (req.processors.isNotEmpty())
            return Routing(Route.FALLBACK, "KAPT processors present")
        if (anyKsp(req.compilerPluginClasspath) || anyKsp(req.stubsPluginClasspath))
            return Routing(Route.FALLBACK, "KSP plugin present")
        return Routing(Route.FAST, "plain Kotlin/Java compile")
    }
}
```

- [ ] **Step 4: Run to verify pass** — Run: `bazelisk test //tests/kotlin_builder:router_test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add elide/kotlin/builder/Router.kt tests/kotlin_builder/RouterTest.kt
git commit -m "feat(kotlin-builder): route KAPT/KSP requests to stock-builder fallback"
```

---

## Phase 3 — Fast path: compile via Elide

### Task 3: `ElideCompile` — produce jar/abijar/srcjar/jdeps

**Files:**
- Create: `elide/kotlin/builder/ElideCompile.kt`
- Test: `tests/kotlin_builder/ElideCompileTest.kt` (builds the command lines; does not exec)

**Design:** `ElideCompile.plan(req, elidePath)` returns a `List<List<String>>` of subprocess argv's to run in order; `run(...)` executes them. Splitting plan/run keeps it unit-testable. Command shapes mirror `elide/private/compile_common.bzl:run_kotlinc`:
- kotlinc: `elide kotlinc -- -d <jar> -classpath <cp> [-module-name <m>] [-Xfriend-paths=...] <passthrough> <srcs>`
- abijar: `elide kotlinc -- -d <abijar> -Xplugin=<jvm-abi-gen> -P plugin:...:outputDir=<abijar> ...` — exact plugin id/options to be confirmed against Elide 1.3.x in Step 5.
- srcjar: `elide jar -- --create --file <srcjar> <srcs>` (or pack via the JDK single_jar already used in the rules).
- jdeps: until WHIPLASH #998, write a minimal valid empty `Deps` (`Dependencies{ rule_label, success=true }`) and require `strict_kotlin_deps=off`.

- [ ] **Step 1: Write the failing test (command construction)**

```kotlin
package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertTrue

class ElideCompileTest {
    @Test fun kotlincCommandHasSeparatorAndOutputs() {
        val req = CompileRequest(
            output = "out.jar", moduleName = "m",
            sources = listOf("A.kt"), classpath = listOf("k.jar"))
        val cmds = ElideCompile.plan(req, elidePath = "/bin/elide")
        val kotlinc = cmds.first { it.contains("kotlinc") }
        assertTrue(kotlinc.containsAll(listOf("/bin/elide", "kotlinc", "--", "-d", "out.jar")))
        assertTrue(kotlinc.contains("-classpath"))
        assertTrue(kotlinc.contains("A.kt"))
    }
}
```

- [ ] **Step 2: Run to verify failure** → FAIL (unresolved `ElideCompile`).

- [ ] **Step 3: Implement `ElideCompile.kt`**

```kotlin
package elide.kotlin.builder

import java.io.File

object ElideCompile {
    fun plan(req: CompileRequest, elidePath: String): List<List<String>> {
        val cmds = mutableListOf<List<String>>()
        val sep = File.pathSeparator
        val kt = mutableListOf(elidePath, "kotlinc", "--", "-d", req.output ?: error("--output required"))
        if (req.classpath.isNotEmpty()) { kt += "-classpath"; kt += req.classpath.joinToString(sep) }
        req.moduleName?.let { kt += listOf("-module-name", it) }
        if (req.friendPaths.isNotEmpty()) kt += "-Xfriend-paths=" + req.friendPaths.joinToString(",")
        kt += req.passthroughFlags
        kt += req.sources
        cmds += kt
        // abijar: emitted by jvm-abi-gen (embedded in Elide 1.3.x). Confirm flags in Step 5.
        // srcjar: pack sources when requested.
        req.srcjar?.let { sj ->
            cmds += listOf(elidePath, "jar", "--", "--create", "--file", sj) + req.sources
        }
        return cmds
    }

    fun run(cmds: List<List<String>>, workDir: File): Int {
        for (c in cmds) {
            val p = ProcessBuilder(c).directory(workDir).redirectErrorStream(true).start()
            val out = p.inputStream.bufferedReader().readText()
            val code = p.waitFor()
            if (code != 0) { System.err.print(out); return code }
        }
        return 0
    }
}
```

- [ ] **Step 4: Run to verify pass** → `bazelisk test //tests/kotlin_builder:elide_compile_test` PASS.

- [ ] **Step 5: Confirm `jvm-abi-gen` + `jdeps` shapes against Elide 1.3.x** (de-risk; update `plan()`)

Empirically determine the exact `elide kotlinc` invocation that emits an ABI jar with embedded jvm-abi-gen (plugin id and `-P plugin:<id>:outputDir=` options, or a dedicated `--abi` flag if Elide exposes one). Add the abijar command to `plan()` and a test asserting it. The jdeps file is produced by `Jdeps.kt` (Task 5d) using the generated `Deps.Dependencies` proto — `ElideCompile`/`Main` calls it after a successful compile; v1 writes a valid stub (`success=true`, `rule_label` set), replaced with real used-deps once Elide surfaces them (#998).

- [ ] **Step 6: Commit**

```bash
git add elide/kotlin/builder/ElideCompile.kt tests/kotlin_builder/ElideCompileTest.kt
git commit -m "feat(kotlin-builder): fast-path compile via elide kotlinc (+abijar/srcjar/jdeps)"
```

---

## Phase 4 — Fallback exec

### Task 4: `Fallback` — delegate to stock KotlinBuilder

**Files:**
- Create: `elide/kotlin/builder/Fallback.kt`
- Test: `tests/kotlin_builder/FallbackTest.kt`

- [ ] **Step 1: Write the failing test (argv construction)**

```kotlin
package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals

class FallbackTest {
    @Test fun passesFlagfileVerbatim() {
        val argv = Fallback.command(stockBuilder = "/bin/stock", flagfile = "/tmp/f")
        assertEquals(listOf("/bin/stock", "--flagfile=/tmp/f"), argv)
    }
}
```

- [ ] **Step 2: Run to verify failure** → FAIL.

- [ ] **Step 3: Implement `Fallback.kt`**

```kotlin
package elide.kotlin.builder

import java.io.File

object Fallback {
    fun command(stockBuilder: String, flagfile: String): List<String> =
        listOf(stockBuilder, "--flagfile=$flagfile")

    /** One-shot delegation: returns (exitCode, capturedOutput). */
    fun run(stockBuilder: String, flagfile: String, workDir: File): Pair<Int, String> {
        val p = ProcessBuilder(command(stockBuilder, flagfile))
            .directory(workDir).redirectErrorStream(true).start()
        val out = p.inputStream.bufferedReader().readText()
        return p.waitFor() to out
    }
}
```

- [ ] **Step 4: Run to verify pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add elide/kotlin/builder/Fallback.kt tests/kotlin_builder/FallbackTest.kt
git commit -m "feat(kotlin-builder): fallback delegates flagfile to stock KotlinBuilder"
```

---

## Phase 5 — Worker protocol (generated protos) + entrypoint

### Task 5a: vendor Bazel protos, generate Java bindings, lint with buf

**Files:**
- Modify: `MODULE.bazel` (root)
- Create: `elide/kotlin/builder/proto/worker_protocol.proto`, `deps.proto`
- Create: `elide/kotlin/builder/proto/BUILD.bazel`

- [ ] **Step 1: Add module deps**

`MODULE.bazel` (append):
```python
bazel_dep(name = "rules_proto", version = "7.1.0")
bazel_dep(name = "protobuf", version = "29.0")  # java_proto_library + protobuf-java runtime
bazel_dep(name = "rules_buf", version = "0.5.2")

buf = use_extension("@rules_buf//buf:extensions.bzl", "buf")
buf.toolchains(version = "v1.47.2")
use_repo(buf, "rules_buf_toolchains")
```

- [ ] **Step 2: Vendor the protos**

Copy `worker_protocol.proto` and `deps.proto` from `bazelbuild/bazel` `src/main/protobuf/` at a pinned tag into `elide/kotlin/builder/proto/`. Preserve Apache-2.0 headers; note their `option java_package` / `java_outer_classname` (used by the imports below). Packages are `blaze.worker` and `blaze.dependencies`.

- [ ] **Step 3: proto_library + java_proto_library + buf lint**

`elide/kotlin/builder/proto/BUILD.bazel`:
```python
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@rules_buf//buf:defs.bzl", "buf_lint_test")

package(default_visibility = ["//elide/kotlin/builder:__subpackages__"])

proto_library(name = "worker_protocol_proto", srcs = ["worker_protocol.proto"])
proto_library(name = "deps_proto", srcs = ["deps.proto"])

java_proto_library(name = "worker_protocol_java_proto", deps = [":worker_protocol_proto"])
java_proto_library(name = "deps_java_proto", deps = [":deps_proto"])

buf_lint_test(name = "worker_protocol_lint", targets = [":worker_protocol_proto"])
```

- [ ] **Step 4: Verify codegen + lint**

Run: `bazelisk build //elide/kotlin/builder/proto:worker_protocol_java_proto //elide/kotlin/builder/proto:deps_java_proto`
Run: `bazelisk test //elide/kotlin/builder/proto:worker_protocol_lint`
Expected: bindings build; lint passes.

- [ ] **Step 5: Commit**

```bash
git add MODULE.bazel elide/kotlin/builder/proto
git commit -m "build(kotlin-builder): vendor Bazel worker/deps protos, gen Java bindings, buf lint"
```

### Task 5b: `Worker` wrapper over generated types

**Files:**
- Create: `elide/kotlin/builder/Worker.kt`
- Test: `tests/kotlin_builder/WorkerTest.kt`

The generated Java lives in package `com.google.devtools.build.lib.worker` (outer class `WorkerProtocol`) per `worker_protocol.proto` — confirm from the vendored file and adjust the import if it differs.

- [ ] **Step 1: Write the failing test (round-trip via generated types)**

```kotlin
package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals

class WorkerTest {
    @Test fun roundTripsRequestAndResponse() {
        val reqBytes = ByteArrayOutputStream()
        WorkRequest.newBuilder().addArguments("--flagfile=/tmp/f").setRequestId(5)
            .build().writeDelimitedTo(reqBytes)
        val req = Worker.readRequest(ByteArrayInputStream(reqBytes.toByteArray()))!!
        assertEquals(listOf("--flagfile=/tmp/f"), req.argumentsList)
        assertEquals(5, req.requestId)

        val respBytes = ByteArrayOutputStream()
        Worker.writeResponse(respBytes, exitCode = 3, output = "boom", requestId = 5)
        val parsed = WorkResponse.parseDelimitedFrom(ByteArrayInputStream(respBytes.toByteArray()))
        assertEquals(3, parsed.exitCode)
        assertEquals("boom", parsed.output)
        assertEquals(5, parsed.requestId)
    }
}
```

- [ ] **Step 2: Run to verify failure** → FAIL (unresolved `Worker`).

- [ ] **Step 3: Implement `Worker.kt`**

```kotlin
package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.InputStream
import java.io.OutputStream

object Worker {
    fun readRequest(s: InputStream): WorkRequest? = WorkRequest.parseDelimitedFrom(s)

    fun writeResponse(o: OutputStream, exitCode: Int, output: String, requestId: Int) {
        WorkResponse.newBuilder()
            .setExitCode(exitCode)
            .setOutput(output)
            .setRequestId(requestId)
            .build()
            .writeDelimitedTo(o)
        o.flush()
    }
}
```

- [ ] **Step 4: Run to verify pass** → `bazelisk test //tests/kotlin_builder:worker_test` PASS.

- [ ] **Step 5: Commit**

```bash
git add elide/kotlin/builder/Worker.kt tests/kotlin_builder/WorkerTest.kt
git commit -m "feat(kotlin-builder): worker codec via generated WorkerProtocol bindings"
```

### Task 5c: `Jdeps` writer (generated Deps proto)

**Files:**
- Create: `elide/kotlin/builder/Jdeps.kt`
- Test: `tests/kotlin_builder/JdepsTest.kt`

Generated Java package per `deps.proto` is `com.google.devtools.build.lib.view.proto` (outer class `Deps`) — confirm from the vendored file.

- [ ] **Step 1: Write the failing test**

```kotlin
package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class JdepsTest {
    @Test fun writesParsableStub() {
        val f = File.createTempFile("x", ".jdeps")
        Jdeps.writeStub(f.toPath().toString(), ruleLabel = "//pkg:lib")
        val d = Deps.Dependencies.parseFrom(f.readBytes())
        assertEquals("//pkg:lib", d.ruleLabel)
        assertTrue(d.success)
    }
}
```

- [ ] **Step 2: Run to verify failure** → FAIL.

- [ ] **Step 3: Implement `Jdeps.kt`**

```kotlin
package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File

object Jdeps {
    /** v1 stub: a valid Deps proto, no per-dep classification (strict deps off).
     *  Replace with real used-deps once Elide surfaces them (WHIPLASH #998). */
    fun writeStub(path: String, ruleLabel: String) {
        val deps = Deps.Dependencies.newBuilder()
            .setRuleLabel(ruleLabel)
            .setSuccess(true)
            .build()
        File(path).outputStream().use { deps.writeTo(it) }
    }
}
```

- [ ] **Step 4: Run to verify pass** → PASS.

- [ ] **Step 5: Commit**

```bash
git add elide/kotlin/builder/Jdeps.kt tests/kotlin_builder/JdepsTest.kt
git commit -m "feat(kotlin-builder): write .jdeps via generated Deps proto (v1 stub)"
```

### Task 5d: `Main` dispatch (worker vs one-shot)

**Files:**
- Create: `elide/kotlin/builder/Main.kt`

- [ ] **Step 1: Implement `Main.kt`**

```kotlin
package elide.kotlin.builder

import java.io.File
import java.nio.file.Paths

object Main {
    private class Config(val elide: String, val fallback: String)

    private fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var fallback = ""; val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--fallback_builder=") -> fallback = a.substringAfter("=")
            else -> rest += a
        }
        return Config(elide, fallback) to rest
    }

    /** Handle one unit of work. Returns (exitCode, capturedOutput). */
    fun handle(cfg: Config, rest: List<String>): Pair<Int, String> {
        val ff = rest.first { it.startsWith("--flagfile=") }.substringAfter("=")
        val req = Flagfile.parse(Flagfile.readTokens(Paths.get(ff)))
        val wd = File(".")
        if (Router.route(req).route == Route.FALLBACK) return Fallback.run(cfg.fallback, ff, wd)
        val code = ElideCompile.run(ElideCompile.plan(req, cfg.elide), wd)
        if (code == 0) req.jdeps?.let { Jdeps.writeStub(it, req.moduleName ?: "") }
        return code to ""
    }

    @JvmStatic fun main(argv: Array<String>) {
        val (cfg, rest) = splitConfig(argv.toList())
        if (rest.contains("--persistent_worker")) {
            val stdin = System.`in`; val stdout = System.out
            while (true) {
                val wr = Worker.readRequest(stdin) ?: break
                val (cfg2, r) = splitConfig(wr.argumentsList)
                val merged = Config(cfg2.elide.ifEmpty { cfg.elide }, cfg2.fallback.ifEmpty { cfg.fallback })
                val (code, out) = runCatching { handle(merged, r) }.getOrElse { 1 to (it.message ?: "error") }
                Worker.writeResponse(stdout, code, out, wr.requestId)
            }
        } else {
            val (code, out) = handle(cfg, rest)
            if (out.isNotEmpty()) System.err.print(out)
            kotlin.system.exitProcess(code)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add elide/kotlin/builder/Main.kt
git commit -m "feat(kotlin-builder): worker/one-shot dispatch wiring elide + fallback + jdeps"
```

## Phase 6 — Bazel packaging + toolchain macro

### Task 6: build the shim with elide; register a kt_toolchain

**Files:**
- Create: `elide/kotlin/builder/BUILD.bazel`
- Create: `elide/kotlin/toolchain.bzl`
- Create: `tests/kotlin_builder/BUILD.bazel`

- [ ] **Step 1: Build the shim binary (dogfood) + unit tests**

`elide/kotlin/builder/BUILD.bazel`:
```python
load("@rules_elide//elide:defs.bzl", "elide_kotlin_binary", "elide_kotlin_library")

package(default_visibility = ["//visibility:public"])

elide_kotlin_library(
    name = "lib",
    srcs = glob(["*.kt"]),
    module_name = "elide_kotlin_builder",
    deps = [
        "//elide/kotlin/builder/proto:worker_protocol_java_proto",
        "//elide/kotlin/builder/proto:deps_java_proto",
    ],
)

elide_kotlin_binary(
    name = "elide_kotlin_builder",
    main_class = "elide.kotlin.builder.Main",
    runtime_deps = [":lib"],
)
```

`tests/kotlin_builder/BUILD.bazel`:
```python
load("@rules_elide//elide:defs.bzl", "elide_kotlin_test")

[elide_kotlin_test(
    name = n.lower().removesuffix(".kt"),
    srcs = [n],
    deps = [
        "//elide/kotlin/builder:lib",
        "//elide/kotlin/builder/proto:worker_protocol_java_proto",
        "//elide/kotlin/builder/proto:deps_java_proto",
    ],
    test_class = "elide.kotlin.builder." + n.removesuffix(".kt"),
) for n in [
    "FlagfileTest.kt",
    "RouterTest.kt",
    "ElideCompileTest.kt",
    "FallbackTest.kt",
    "WorkerTest.kt",
    "JdepsTest.kt",
]]
```

- [ ] **Step 2: Implement the toolchain macro**

`elide/kotlin/toolchain.bzl`:
```python
"""Register a rules_kotlin toolchain whose KotlinBuilder is the Elide shim."""

load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")

def register_elide_kotlin_toolchain(
        name,
        elide,                # label of the elide binary (toolchain-provided)
        fallback_builder,     # label of the stock KotlinBuilder executable
        **kwargs):
    """Defines + registers a kt_toolchain that compiles via Elide.

    The shim launcher embeds `--elide=<elide> --fallback_builder=<fallback>`
    before rules_kotlin appends `--flagfile=`. KAPT/KSP requests delegate to
    `fallback_builder`; everything else compiles through Elide.
    """
    # A launcher wrapping the shim with its config args is generated here
    # (genrule writing an sh/bat that execs the shim binary with the two
    # --elide/--fallback_builder flags, then "$@"). See Step 3.
    define_kt_toolchain(
        name = name,
        kotlinbuilder = ":%s_launcher" % name,
        **kwargs
    )
    native.register_toolchains(":" + name)
```

- [ ] **Step 3: Config-injecting launcher + wrapping toolchain (CHOSEN APPROACH)**

`define_kt_toolchain` does NOT expose `kotlinbuilder` and `_kt_toolchain` is private (verified, rules_kotlin 2.3.20). Chosen path: **vendor a wrapping toolchain rule** that wraps a stock toolchain instance and swaps only `kotlinbuilder`.

- A launcher rule `_elide_kt_builder_launcher` (executable): attrs `shim`/`elide`/`fallback_builder` (all `executable=True, cfg="exec"`); emits a `.sh` that `exec`s the shim with `--elide=$(rlocation elide) --fallback_builder=$(rlocation fallback) "$@"` using the standard Bazel runfiles bash init; runfiles merge all three. (Mirror `compile_common.bzl:build_launcher`; stdout untouched — it carries the worker protocol.)
- A wrapping rule `_elide_kt_toolchain`: attr `base` (a stock toolchain impl target) + `kotlinbuilder` (our launcher). impl reads `base[platform_common.ToolchainInfo]`, copies all its fields (`dir()`+`getattr`, or explicit field list from `_kotlin_toolchain_impl` if generic copy fails), overrides `kotlinbuilder`, re-emits `platform_common.ToolchainInfo(**fields)`.
- Macro `register_elide_kotlin_toolchain(name, elide, fallback_builder, **kwargs)`: instantiate the launcher; `define_kt_toolchain(name = name + "_base", **kwargs)` to get a stock impl (do NOT register it); `_elide_kt_toolchain(name = name + "_impl", base = <stock impl target>, kotlinbuilder = ":" + name + "_launcher")`; `native.toolchain(name = name, toolchain_type = "@rules_kotlin//kotlin/internal:kt_toolchain_type", toolchain = ":" + name + "_impl")`; `native.register_toolchains(":" + name)`. (Find the exact impl target name `define_kt_toolchain` produces by reading its body.)

- [ ] **Step 4: Verify the shim builds and unit tests pass**

Run: `bazelisk test //tests/kotlin_builder/...`
Expected: all PASS (built via the elide Kotlin toolchain — dogfood).

- [ ] **Step 5: Commit**

```bash
git add elide/kotlin tests/kotlin_builder/BUILD.bazel
git commit -m "feat(kotlin-builder): elide_kotlin_binary shim + kt_toolchain macro"
```

---

## Phase 7 — End-to-end: swap the toolchain on a real kt_jvm_library

### Task 7: fast-path and fallback e2e

**Files:**
- Modify: `e2e/kotlin_builder/MODULE.bazel` (register the Elide kt toolchain ahead of the stock one)
- Modify: `e2e/kotlin_builder/BUILD.bazel` (add a KAPT target)
- Create: `e2e/kotlin_builder/verify.sh`
- Create: `e2e/kotlin_builder/sample/Anno.kt`, processor fixture

- [ ] **Step 1: Register the Elide toolchain with higher priority**

In `e2e/kotlin_builder/BUILD.bazel`, call `register_elide_kotlin_toolchain(name = "elide_kt", elide = "@elide_toolchains//:elide_bin", fallback_builder = "@rules_kotlin//src/main/kotlin:build")` and ensure it is registered before the stock toolchain so `:greeter` compiles via Elide.

- [ ] **Step 2: Verify fast path compiles via Elide**

Run: `cd e2e/kotlin_builder && bazelisk build //:greeter --toolchain_resolution_debug=kotlin`
Expected: toolchain resolves to `elide_kt`; build succeeds; `greeter.jar` + `greeter.abi.jar` produced. Inspect the action (`--subcommands`) to confirm the shim (not stock builder) ran.

- [ ] **Step 3: Verify fallback for a KAPT target**

Add a `kt_jvm_library` with a `plugins`/processor (KAPT). Build it; confirm via `--subcommands` that the shim delegated to the stock builder and the processor ran (generated sources present).

- [ ] **Step 4: Assert outputs with a test**

`e2e/kotlin_builder/verify.sh` (wired as `sh_test`): unzip `greeter.jar`, assert `sample/Greeter.class` present; assert `greeter.abi.jar` non-empty; assert the KAPT target's generated class is present.

Run: `bazelisk test //:verify`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add e2e/kotlin_builder
git commit -m "test(kotlin-builder): e2e fast-path (elide) + fallback (KAPT) on kt_jvm_library"
```

---

## Phase 8 — Docs + CI

### Task 8: document the integration and wire CI

**Files:**
- Create: `docs/kotlin_builder.md`
- Modify: `CHANGELOG.md`
- Modify: `.github/workflows/ci.yml` (add the `e2e/kotlin_builder` job)
- Modify: `README.md` (roadmap row)

- [ ] **Step 1:** Write `docs/kotlin_builder.md`: the toolchain-swap usage (`register_elide_kotlin_toolchain`), routing behavior (KAPT/KSP → stock fallback), the jdeps caveat (strict deps off until WHIPLASH #998), and the abijar source (embedded jvm-abi-gen, 1.3.x).
- [ ] **Step 2:** Add a CHANGELOG "Added" entry and flip the README roadmap row for rules_kotlin interop.
- [ ] **Step 3:** Add a CI job building/testing `e2e/kotlin_builder` (mirror the `integration` job).
- [ ] **Step 4: Commit**

```bash
git add docs/kotlin_builder.md CHANGELOG.md README.md .github/workflows/ci.yml
git commit -m "docs(kotlin-builder): document toolchain swap + CI e2e job"
```

---

## Risks & open items

- **jdeps:** the shim **always writes** the `.jdeps` `Deps` proto itself — Elide is not involved in emitting the file. v1 writes a trivial valid proto and forces `strict_kotlin_deps=off`. Accurate strict-deps needs the *used-classpath signal* from Elide (reframed WHIPLASH #998 — report used deps in any format; the shim maps it). Approximate fallback without Elide: post-analyze compiled classes vs classpath (JDK-`jdeps`-style), not preferred.
- **jvm-abi-gen invocation:** exact plugin id/options for emitting the abijar via `elide kotlinc` must be confirmed against 1.3.x (Task 3 Step 5). If Elide exposes a first-class `--abi` output, prefer it.
- **`define_kt_toolchain` override:** confirm `kotlinbuilder` is settable via the public macro; otherwise instantiate the underlying toolchain rule directly (Task 6 Step 3). This couples to rules_kotlin internals and should pin a rules_kotlin version.
- **Worker protocol:** generated from Bazel's vendored `worker_protocol.proto` (no hand-rolled codec). We use `WorkRequest`/`WorkResponse` (fields exist in the proto); singleplex only for v1 (`supports-workers`, no `supports-multiplex-workers`). Vendored protos are pinned; re-vendor on Bazel upgrades if the messages change.
- **Dependency surface:** the proto route adds `rules_proto` + `protobuf` (protoc + protobuf-java runtime) + `rules_buf` (+ buf toolchain) to the root `MODULE.bazel`. Because the shim is built from source when a consumer's toolchain references it, these propagate to consumers of the Kotlin integration. (`rules_buf` is lint/breaking only — it does **not** generate code; `java_proto_library` does.) Alternative if this is unwanted: a hand-rolled length-delimited codec (zero deps) — rejected per maintainer preference for consuming Bazel's proto sources.
- **Flag schema drift:** rules_kotlin's flagfile flags are internal; pin a version and re-validate `Flagfile` against a captured real flagfile (Task 1 Step 5) on upgrades.
