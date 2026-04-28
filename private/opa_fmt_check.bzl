"""opa_fmt_check — Bazel test rule that fails when any of the given
Rego files would be reformatted by `opa fmt`.

Equivalent to `gofmt -d` as a test: runs `opa fmt -d <files>` (which
prints a unified diff of any reformatting); the wrapper script captures
that output and treats non-empty diff as a test failure.
"""

def _impl(ctx):
    tc = ctx.toolchains["//toolchain:opa"]
    opa_bin = tc.opa.opa_bin

    if not ctx.files.srcs:
        fail("opa_fmt_check {}: srcs must be non-empty".format(ctx.label))

    short_paths = [f.short_path for f in ctx.files.srcs]

    out = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = out,
        substitutions = {
            "{OPA_BIN}": opa_bin.short_path,
            "{INPUTS}":  " ".join(["'" + p + "'" for p in short_paths]),
        },
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [opa_bin] + ctx.files.srcs)
    return [DefaultInfo(executable = out, runfiles = runfiles)]

_opa_fmt_check_rule_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".rego"],
            doc = "Rego source files to format-check.",
        ),
        "_tmpl": attr.label(
            default = "//private:opa_fmt_check.sh.tmpl",
            allow_single_file = True,
        ),
    },
    toolchains = ["//toolchain:opa"],
)

def opa_fmt_check(name, srcs, **kwargs):
    """Wraps the underlying test rule so the public name doesn't need a
    `_test` suffix. Bazel requires test-rule *class* names to end with
    `_test`, but consumers prefer plain `opa_fmt_check(...)`."""
    _opa_fmt_check_rule_test(name = name, srcs = srcs, **kwargs)
