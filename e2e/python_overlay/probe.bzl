"""Run Python with only the declared toolchain inputs in a Bazel sandbox."""

def _probe_impl(ctx):
    elide = ctx.toolchains["@rules_elide//elide:toolchain_type"].elide_info
    output = ctx.actions.declare_file(ctx.label.name + ".txt")
    args = ctx.actions.args()
    args.add("python")
    args.add(ctx.file.src)
    args.add(output)
    args.add(elide.binary.dirname + "/../conf/components/python")
    ctx.actions.run(
        executable = elide.binary,
        arguments = [args],
        inputs = depset([ctx.file.src], transitive = [elide.python_tool_files]),
        outputs = [output],
        mnemonic = "ElidePythonOverlayProbe",
    )
    return [DefaultInfo(files = depset([output]))]

python_overlay_probe = rule(
    implementation = _probe_impl,
    attrs = {"src": attr.label(allow_single_file = [".py"], mandatory = True)},
    toolchains = ["@rules_elide//elide:toolchain_type"],
)
