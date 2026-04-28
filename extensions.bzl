"""Bzlmod extension. One `version` tag class — fetches the OPA binary
for each supported platform.

Same shape as rules_kind: per-platform repos named `opa_<plat>` each
contain just the binary (`opa`) and a tiny BUILD that exposes it as a
filegroup. The toolchain at //toolchain:opa selects the right one based
on the resolved exec/target platform.
"""

load("//private:repositories.bzl", "opa_binary_repo")
load("//private:versions.bzl", "PLATFORMS")

_version_tag = tag_class(attrs = {
    "version": attr.string(mandatory = True),
})

def _impl(mctx):
    # Only honor `version` tags from the root module. Without this guard,
    # both rules_opa (when consumed as a dep) and the consumer would each
    # emit `@opa_<plat>` repos and Bazel would collide them. The library's
    # own MODULE.bazel still needs `opa.version(...)` so its in-tree tests
    # can build, but that only fires when rules_opa itself is the root.
    for mod in mctx.modules:
        if not mod.is_root:
            continue
        for tag in mod.tags.version:
            for plat in PLATFORMS.keys():
                opa_binary_repo(
                    name     = "opa_" + plat,
                    version  = tag.version,
                    platform = plat,
                )

opa = module_extension(
    implementation = _impl,
    tag_classes = {"version": _version_tag},
)
