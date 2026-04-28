#!/usr/bin/env bash
# tools/update_versions.sh — refresh OPA_VERSIONS in private/versions.bzl.
#
# Usage:
#     bash tools/update_versions.sh <version>            # add or update entry
#     bash tools/update_versions.sh <version> --update   # also auto-edit
#                                                        # private/versions.bzl
#
# OPA publishes per-platform binaries with companion `.sha256` files at
# https://github.com/open-policy-agent/opa/releases/download/v<ver>/opa_<plat>
# Each is a single executable — no tarball wrapper.
set -euo pipefail

VERSION="${1:?usage: tools/update_versions.sh <version> [--update]}"
UPDATE=0
[[ "${2:-}" == "--update" ]] && UPDATE=1

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSIONS_BZL="$REPO_ROOT/private/versions.bzl"
BASE="https://github.com/open-policy-agent/opa/releases/download/v${VERSION}"

declare -A SHA
for plat in linux_amd64 darwin_amd64 darwin_arm64; do
    asset="opa_${plat}"
    sha=$(curl -fsSL "$BASE/${asset}.sha256" | awk '{print $1}')
    SHA[$plat]="$sha"
    echo "[update_versions] $asset: $sha"
done

if (( UPDATE )); then
    echo
    echo "[update_versions] updating $VERSIONS_BZL"
    python3 - "$VERSIONS_BZL" "$VERSION" "$BASE" \
        "${SHA[linux_amd64]}" "${SHA[darwin_amd64]}" "${SHA[darwin_arm64]}" <<'PY'
import re, sys
path, version, base, l, da, dr = sys.argv[1:7]
src = open(path).read()
m = re.search(r"(OPA_VERSIONS\s*=\s*\{)([\s\S]*?)(\n\})", src)
if not m:
    sys.exit("could not locate OPA_VERSIONS dict in versions.bzl")
head, body, tail = m.group(1), m.group(2), m.group(3)
entry = (
    f'\n    "{version}": {{\n'
    f'        "linux_amd64": {{\n'
    f'            "url":    "{base}/opa_linux_amd64",\n'
    f'            "sha256": "{l}",\n'
    f'        }},\n'
    f'        "darwin_amd64": {{\n'
    f'            "url":    "{base}/opa_darwin_amd64",\n'
    f'            "sha256": "{da}",\n'
    f'        }},\n'
    f'        "darwin_arm64": {{\n'
    f'            "url":    "{base}/opa_darwin_arm64",\n'
    f'            "sha256": "{dr}",\n'
    f'        }},\n'
    f'    }},'
)
existing = re.search(rf'\n    "{re.escape(version)}":[\s\S]*?\n    \}},', body)
new_body = (body[:existing.start()] + entry + body[existing.end():]) if existing else (body.rstrip(",\n ") + "," + entry)
new_src = src[:m.start()] + head + new_body + tail + src[m.end():]
open(path, "w").write(new_src)
print(f"  wrote OPA_VERSIONS['{version}']")
PY
    echo
    echo "Next: bump MODULE.bazel's \`opa.version(version = \"$VERSION\")\` if you"
    echo "      want this to be the default, then run \`bazel test //tests:...\`."
else
    echo
    echo "Next steps (re-run with --update to do this automatically):"
    echo "  1. Add or update in private/versions.bzl::OPA_VERSIONS[\"$VERSION\"]"
    echo "     with the SHAs printed above."
    echo "  2. Bump MODULE.bazel's \`opa.version(version = \"$VERSION\")\`."
fi
