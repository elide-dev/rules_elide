# Hermetic C with Elide's bundled LLVM toolchain

Linux Elide distributions ship a complete LLVM C toolchain under
`lib/llvm/toolchain`: a clang 23 driver, lld, compiler-rt, libunwind, libc++,
clang resource headers, and glibc and musl sysroots. `elide_cc_binary` compiles
and links C executables with it, so Bazel builds need no host compiler, headers,
or system libraries.

```starlark
load("@rules_elide//elide:defs.bzl", "elide_cc_binary")

elide_cc_binary(
    name = "hello",
    srcs = ["main.c", "util/greet.c"],
    hdrs = ["util/greet.h"],
    copts = ["-O2", "-Wall"],
    defines = ["GREETING=\"elide\""],
    linkopts = ["-lm"],
)
```

See the [API reference](cc.md) and the runnable
[fixture](../e2e/cc/README.md).

## Design

The rule calls the distribution's target-prefixed driver,
`lib/llvm/toolchain/bin/<triple>-unknown-linux-gnu-clang`, directly. It does not
use `elide cc`. In Elide 1.6.3, `elide cc -- ...` accepts only one freestanding
C17 source with `-c`, `-S -emit-llvm`, or `--run`. It rejects other options
such as `-O2` and has no system headers or linking.

The clang driver automatically loads the sibling `<triple>.cfg`. That file sets
the sysroot, `-fuse-ld=lld`, `-rtlib=compiler-rt`, and `-unwindlib=libunwind`
relative to the config file. The rule also passes `-no-canonical-prefixes` so
that clang finds these files through the action's declared inputs, not through
the resolved path of the external repository.

Each `.c` file gets one `ElideCcCompile` action, and one `ElideCcLink` action
produces the executable. Both actions run with an empty environment. Their tool
inputs are `ElideToolchainInfo.cc_tool_files` and nothing else. For downloaded
toolchains that is the `elide_cc_files` filegroup, which contains:

| Files | Purpose |
| --- | --- |
| `bin/<triple>-clang`, `bin/<triple>.cfg` | Driver and its target configuration |
| `bin/ld.lld` | Linker |
| `lib/clang/**` | Resource headers (`stddef.h`, ...) and compiler-rt builtins |
| `lib/<triple>/**` | libunwind (and the C++ runtimes, unused for C) |
| `sysroot/<triple>/**` | glibc headers, crt objects, and libraries |

This set is about 420 MB for linux-amd64 1.6.3. The full `lib/llvm` tree is
1.8 GB. JVM, jextract, and Python actions do not depend on any of it, and C
actions do not depend on the `elide` launcher.

The release archive ships the clang and lld alias copies (`clang`,
`<triple>-clang`, `ld.lld`, ...) without an exec bit. The download rule restores
it, as it already does for `bin/` wrappers. It uses `chmod` from PATH, `/bin`,
or `/usr/bin`, and it fails if this step fails.

A full rules_cc `cc_toolchain` was deliberately not added. `elide_cc_binary`
covers hermetic C executables with a small, explicit input contract. Wiring the
same files into `cc_toolchain_config` features would be a follow-up.

## Hermeticity evidence

`./tools/verify_integrations.sh cc` builds the fixture with only `bazel` on
PATH, so cc, gcc, clang, ld, and chmod are absent. It uses
`--experimental_use_hermetic_linux_sandbox`, which exposes only declared inputs.
The only extra mounts are the host loader and libc directories that the bundled
clang binary itself dynamically links against. The verifier then checks three
things. The actions run the bundled driver with an empty environment. The
binary was linked by LLD from clang objects. The binary runs and returns the
expected output and exit codes with an empty PATH.

As a negative control, removing the sysroot from `elide_cc_files` makes the
hermetic build fail with `'math.h' file not found`. That shows that host
`/usr/include` is not reachable. An strace of the driver found no host header,
library, or linker accesses. It reads only its own runtime dependencies,
`/etc/os-release`, and `TMPDIR`.

## Limitations

- Linux only. The output targets the toolchain's own platform. There is no
  cross-compilation, and the musl sysroot is shipped but not selected.
- C only. There is no C++, no libraries or `deps`, and no `CcInfo`
  interoperability with rules_cc.
- Headers are included by workspace-relative path (`-iquote` on the execroot
  and bin directory). Headers from external repositories are not supported.
- glibc outputs link dynamically against the target's `libc.so.6`. The
  bundled sysroot is old enough (crt objects from GCC 4.8.5) to be broadly
  compatible.
- The bundled clang binary itself is dynamically linked against the execution
  host's glibc, as is every other tool in the distribution.
- `elide.use(local_path = ...)` never edits the local distribution. If its
  LLVM aliases lack an exec bit, fix them there.
- macOS and Windows distributions provide no `elide_cc_compiler`, and the rule
  fails analysis with a clear error.
