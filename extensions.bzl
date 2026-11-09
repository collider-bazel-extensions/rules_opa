"""Bzlmod extension. One `version` tag class — fetches the OPA binary
for each supported platform.

Same shape as rules_kind: per-platform repos named `opa_<plat>` each
contain just the binary (`opa`) and a tiny BUILD that exposes it as a
filegroup. The toolchain at //toolchain:opa selects the right one based
on the resolved exec/target platform.
"""

load("//private:repositories.bzl", "opa_binary_repo")
load("//private:versions.bzl", "DEFAULT_VERSION", "OPA_VERSIONS", "PLATFORMS")

_version_tag = tag_class(attrs = {
    "version": attr.string(mandatory = True),
})

def _select_version(mctx):
    """The one OPA version to fetch.

    The extension runs once for the whole build and sees every module's
    tags, but the repos it creates (`opa_<plat>`) are global, so it must
    pick a single version and create each repo once. The root module's
    `opa.version()` wins; without one, rules_opa's own (from its
    MODULE.bazel, which imports these repos and registers the toolchain
    for every consumer); without that, DEFAULT_VERSION. Other modules'
    tags are ignored.
    """
    root = []
    own = []
    for mod in mctx.modules:
        versions = [tag.version for tag in mod.tags.version]
        if mod.is_root:
            root = versions
        elif mod.name == "rules_opa":
            own = versions
    for candidates, who in [(root, "the root module"), (own, "rules_opa")]:
        distinct = sorted({v: None for v in candidates}.keys())
        if len(distinct) > 1:
            fail("rules_opa: {} sets opa.version() to more than one version ({}); set one.".format(
                who,
                ", ".join(distinct),
            ))
        if distinct:
            return distinct[0]
    return DEFAULT_VERSION

def _impl(mctx):
    version = _select_version(mctx)
    if version not in OPA_VERSIONS:
        fail("rules_opa: opa.version(version = \"{}\") is not supported. Supported: {}".format(
            version,
            ", ".join(sorted(OPA_VERSIONS.keys())),
        ))
    for plat in PLATFORMS.keys():
        opa_binary_repo(
            name     = "opa_" + plat,
            version  = version,
            platform = plat,
        )

opa = module_extension(
    implementation = _impl,
    tag_classes = {"version": _version_tag},
)
