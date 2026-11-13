# Hermetic C fixture

This fixture builds `:hello` with `elide_cc_binary` using the clang, lld, and
glibc sysroot bundled in the pinned Elide 1.6.3 Linux x86-64 distribution. It
needs no host C compiler. From the repository root:

```sh
./tools/verify_integrations.sh cc
```

The script hides every host tool except `bazel` from PATH. It builds in the
hermetic Linux sandbox, which exposes only declared inputs. The script then
runs `verify_hermetic_cc.py`, which checks the action command lines and
environments, the linker provenance, and the program's output and exit codes.
Set `ELIDE_CC_HERMETIC_SANDBOX=0` to use the ordinary Linux sandbox instead.
See [docs/c.md](../../docs/c.md).
