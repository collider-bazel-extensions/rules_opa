"""opa_test — Bazel test rule that runs `opa test` over a set of Rego
source files (and optional data files).

Generates a small wrapper script that:
  1. Resolves the toolchain's OPA binary via runfiles.
  2. Invokes `opa test --explain=fails -v <inputs...>`.
  3. Exits with `opa test`'s exit code (non-zero if any test_* rule fails
     or if any source file fails to parse).

`opa test` discovers Rego unit tests (`test_<name>` rules in `*_test.rego`
files). The `srcs` attr is the union of policies + tests; OPA picks them
apart by filename. `data` is for non-Rego files (JSON/YAML) that policies
reference at test time.
"""

def _impl(ctx):
    tc = ctx.toolchains["//toolchain:opa"]
    opa_bin = tc.opa.opa_bin

    # Build the list of input paths the wrapper passes to `opa test`.
    inputs = ctx.files.srcs + ctx.files.data
    if not ctx.files.srcs:
        fail("opa_test {}: srcs must be non-empty".format(ctx.label))

    short_paths = [f.short_path for f in inputs]

    out = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = out,
        substitutions = {
            "{OPA_BIN}":   opa_bin.short_path,
            "{INPUTS}":    " ".join(["'" + p + "'" for p in short_paths]),
            "{EXTRA}":     " ".join(["'" + a + "'" for a in ctx.attr.opa_test_args]),
        },
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [opa_bin] + inputs)
    return [DefaultInfo(executable = out, runfiles = runfiles)]

opa_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".rego"],
            doc = "Rego source files. Both policy and `*_test.rego` files " +
                  "go here; `opa test` partitions them by filename.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Optional non-Rego data files (JSON/YAML) referenced by " +
                  "the policies under test.",
        ),
        "opa_test_args": attr.string_list(
            doc = "Extra args passed verbatim to `opa test` (e.g. " +
                  "`['--coverage']`). The default invocation already " +
                  "passes `--explain=fails -v`.",
        ),
        "_tmpl": attr.label(
            default = "//private:opa_test.sh.tmpl",
            allow_single_file = True,
        ),
    },
    toolchains = ["//toolchain:opa"],
)
