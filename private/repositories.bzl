"""Per-platform binary repo. Downloads the OPA executable at the pinned
URL + sha256 for one platform.
"""

load(":versions.bzl", "OPA_VERSIONS")

_BUILD_TMPL = """\
package(default_visibility = ["//visibility:public"])

# The filegroup name MUST differ from the source file name "opa" — a bare
# `srcs = ["opa"]` would otherwise resolve to the filegroup itself and
# trigger a cycle. Same lesson rules_kind learned (see its `kind_bin` /
# `kubectl_bin`).
filegroup(
    name = "bin",
    srcs = ["opa"],
)
"""

def _impl(rctx):
    version = rctx.attr.version
    platform = rctx.attr.platform
    if version not in OPA_VERSIONS:
        fail("rules_opa: unknown version '{}'. Known: {}".format(
            version,
            sorted(OPA_VERSIONS.keys()),
        ))
    plats = OPA_VERSIONS[version]
    if platform not in plats:
        fail("rules_opa: version {} has no entry for platform '{}'. Have: {}".format(
            version, platform, sorted(plats.keys()),
        ))
    info = plats[platform]
    rctx.download(
        url        = info["url"],
        output     = "opa",
        sha256     = info["sha256"],
        executable = True,
    )
    rctx.file("WORKSPACE", "workspace(name = \"{}\")\n".format(rctx.name))
    rctx.file("BUILD.bazel", _BUILD_TMPL)

opa_binary_repo = repository_rule(
    implementation = _impl,
    attrs = {
        "version":  attr.string(mandatory = True),
        "platform": attr.string(mandatory = True),
    },
)
