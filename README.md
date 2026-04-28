# rules_opa

Hermetic [Open Policy Agent](https://www.openpolicyagent.org/) CLI for
Bazel. Two rules:

- **`opa_test`** — runs `opa test` over your Rego policies + `*_test.rego`
  unit tests. Standard `bazel test` integration: green when all `test_*`
  rules pass, red otherwise.
- **`opa_fmt_check`** — runs `opa fmt -d` and fails the test when any
  file would be reformatted. Mirrors `gofmt -d` as a CI gate.

Pure CLI — no cluster, no network at test time. The OPA binary itself is
sha256-pinned and downloaded by the bzlmod extension.

**Supported platforms (v0.1):** Linux x86\_64, macOS x86\_64, macOS arm64.
Linux validated in CI; macOS pending. See [Contributing](#contributing).

**Pinned versions:** OPA 1.15.2.

---

## Contents

- [Installation](#installation) (Bzlmod-only)
- [Quickstart](#quickstart)
- [Rules](#rules)
  - [opa\_test](#opa_test)
  - [opa\_fmt\_check](#opa_fmt_check)
- [Providers](#providers)
- [Hermeticity exceptions](#hermeticity-exceptions)
- [Contributing](#contributing)

---

## Installation

```python
bazel_dep(name = "rules_opa", version = "0.1.0")

opa = use_extension("@rules_opa//:extensions.bzl", "opa")
opa.version(version = "1.15.2")

use_repo(opa,
    "opa_linux_amd64",
    "opa_darwin_amd64",
    "opa_darwin_arm64",
)

register_toolchains("@rules_opa//toolchain:all")
```

`rules_opa` is **Bzlmod-only** in v0.1. Until it lands in BCR, consume
via `archive_override` or a git pin pointing at a tag.

---

## Quickstart

Layout your Rego the way OPA itself recommends — policies and tests live
side-by-side, tests are named `*_test.rego`:

```
my/policies/
  access.rego
  access_test.rego
  BUILD.bazel
```

```python
load("@rules_opa//:defs.bzl", "opa_fmt_check", "opa_test")

opa_test(
    name = "access_test",
    srcs = [
        "access.rego",
        "access_test.rego",
    ],
)

opa_fmt_check(
    name = "fmt_check",
    srcs = glob(["*.rego"]),
)
```

Run them with `bazel test //my/policies:all`. The OPA binary is
downloaded once per platform and cached.

---

## Rules

### `opa_test`

Wraps `opa test --explain=fails -v <inputs>`.

```python
opa_test(
    name = "policy_test",
    srcs = ["policy.rego", "policy_test.rego"],
    data = ["fixtures.json"],         # optional
    opa_test_args = ["--coverage"],   # optional, appended verbatim
)
```

**Attributes:**

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Test target name. |
| `srcs` | `label_list` of `.rego` | required | Rego policy + `*_test.rego` files. `opa test` itself partitions them by filename. |
| `data` | `label_list` | `[]` | Optional non-Rego data files (JSON / YAML) referenced by the policies under test. |
| `opa_test_args` | `string_list` | `[]` | Extra args appended to `opa test` (e.g. `["--coverage"]`, `["--threshold", "80"]`). |

The wrapper passes `--explain=fails -v` by default — verbose listing per
`test_*` rule on success, full trace on failure.

### `opa_fmt_check`

Wraps `opa fmt -d <files>`. Fails the test when stdout is non-empty.

```python
opa_fmt_check(
    name = "fmt_check",
    srcs = glob(["*.rego"]),
)
```

**Attributes:**

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Test target name. |
| `srcs` | `label_list` of `.rego` | required | Files to format-check. |

Run `opa fmt -w <files>` locally to apply the suggested reformatting.

---

## Providers

### `OpaInfo`

| Field | Type | Description |
|---|---|---|
| `version` | `string` | OPA version, e.g. `"1.15.2"` |
| `opa_bin` | `File` | The platform-resolved, sha256-verified OPA executable |

Custom rules that want the binary can resolve it via the toolchain:

```python
def _impl(ctx):
    info = ctx.toolchains["@rules_opa//toolchain:opa"].opa
    # info.opa_bin is a File; info.version is a string

my_rule = rule(
    implementation = _impl,
    toolchains = ["@rules_opa//toolchain:opa"],
)
```

---

## Hermeticity exceptions

| Component | Status | Notes |
|---|---|---|
| OPA binary | Fully hermetic. URL + sha256 pinned per platform in `private/versions.bzl`. | Update via `bash tools/update_versions.sh <version> --update`. |
| Test inputs | Whatever you pass via `srcs` / `data`. | Must be Bazel-tracked files; `opa test` does not reach out to the host filesystem. |

---

## Contributing

PRs welcome. Conventions match the sibling rule sets:

- New rules need an analysis test in `tests/analysis_tests.bzl`.
- Bumping the pinned OPA version: `bash tools/update_versions.sh <new-version> --update`.
- `MODULE.bazel.lock` is intentionally not committed.

### Help wanted: macOS validation

The toolchain selection is symmetric across platforms, but no one has
run the example tests on Darwin yet. A pasted log from a green
`bazel test //tests:all` on macOS would unblock the macOS support claim.
