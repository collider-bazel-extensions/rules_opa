"""opa_toolchain — exposes the platform-resolved OPA binary as a
`ToolchainInfo` so consumer rules can resolve it via `ctx.toolchains[...]`
without depending on the binary's specific path.
"""

load("//private:providers.bzl", "OpaInfo")

OPA_TOOLCHAIN_TYPE = Label("//toolchain:opa")

def _toolchain_impl(ctx):
    info = OpaInfo(
        version = ctx.attr.version,
        opa_bin = ctx.file.opa_bin,
    )
    return [
        platform_common.ToolchainInfo(opa = info),
        DefaultInfo(
            files = depset([ctx.file.opa_bin]),
            runfiles = ctx.runfiles(files = [ctx.file.opa_bin]),
        ),
    ]

opa_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "opa_bin": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The platform-specific OPA executable.",
        ),
    },
)
