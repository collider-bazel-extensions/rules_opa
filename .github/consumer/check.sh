#!/usr/bin/env bash
# Consumer checks against the commit's release archive (git archive, as
# GitHub's tag tarballs are built):
#   1. no opa.version() in the root resolves, and an opa_test runs the
#      default version
#   2. the same version set twice in the root resolves
#   3. an unsupported version fails, naming opa.version
#   4. @rules_opa//... loads
# Usage: .github/consumer/check.sh <scratch dir>
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="$1"
src="$work/rules_opa"
rm -rf "$work"; mkdir -p "$src"
git -C "$repo" archive HEAD | tar -x -C "$src"
default_version="$(sed -n 's/^DEFAULT_VERSION = "\(.*\)"$/\1/p' "$src/private/versions.bzl")"

consumer() { # <name> <extra MODULE.bazel lines>
    local c="$work/$1"
    mkdir -p "$c"
    if [[ -f "$repo/.bazelversion" ]]; then cp "$repo/.bazelversion" "$c/"; fi
    cp "$repo/tests/example/access.rego" "$repo/tests/example/access_test.rego" "$c/"
    cat > "$c/MODULE.bazel" <<MOD
module(name = "consumer")
bazel_dep(name = "rules_opa")
local_path_override(module_name = "rules_opa", path = "$src")
$2
MOD
    cat > "$c/BUILD.bazel" <<'BUILD'
load("@rules_opa//:defs.bzl", "opa_test")

opa_test(
    name = "access_test",
    srcs = ["access.rego", "access_test.rego"],
)
BUILD
    echo "$c"
}

# 1. No opa.version(): resolves; the registered toolchain's opa runs.
c="$(consumer untagged "")"
(cd "$c" && bazel mod deps >/dev/null)
(cd "$c" && bazel test //:access_test --test_output=errors)
"$(cd "$c" && bazel info output_base)/external/rules_opa++opa+opa_linux_amd64/opa" version | tee "$work/untagged.out"
grep -q "^Version: $default_version$" "$work/untagged.out" || { echo "FAIL: untagged consumer did not get opa $default_version" >&2; exit 1; }
echo "PASS: untagged root resolves, opa $default_version"

# 2. The same version twice in the root.
c="$(consumer twice "opa = use_extension(\"@rules_opa//:extensions.bzl\", \"opa\")
opa.version(version = \"$default_version\")
opa.version(version = \"$default_version\")")"
(cd "$c" && bazel mod deps >/dev/null)
echo "PASS: repeated identical opa.version resolves"

# 3. An unsupported version fails with a message naming opa.version.
c="$(consumer unsupported 'opa = use_extension("@rules_opa//:extensions.bzl", "opa")
opa.version(version = "0.0.1")')"
if (cd "$c" && bazel mod deps) > "$work/unsupported.out" 2>&1; then
    echo "FAIL: unsupported version resolved" >&2; exit 1
fi
grep -q 'opa.version(version = "0.0.1") is not supported' "$work/unsupported.out" || {
    cat "$work/unsupported.out" >&2; echo "FAIL: unsupported version: wrong error" >&2; exit 1; }
echo "PASS: unsupported version fails clearly"

# 4. //... loads.
(cd "$work/untagged" && bazel query @rules_opa//... >/dev/null)
echo "PASS: @rules_opa//... loads"
