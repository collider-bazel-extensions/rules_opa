# rules_opa — design decisions

Hermetic [Open Policy Agent](https://www.openpolicyagent.org/) CLI for
Bazel: `opa_test` (Rego unit tests via `opa test`) and `opa_fmt_check`
(`opa fmt -d` as a test). Pure CLI — no cluster, no network at test time.

This rule set is the smallest path to "Rego policies are testable in
Bazel CI." It is a different family from the in-cluster operator rules
(`rules_certmanager`, `rules_cilium`, `rules_argocd`, …) — closer in
spirit to `rules_python`'s `py_test` than to those.

## Decided

| # | Decision | Choice | Source |
|---|---|---|---|
| 1 | Bzlmod / WORKSPACE | **Bzlmod-only at v0.1.** | Sibling-family precedent |
| 2 | Module extension shape | One tag class: `version` (download). No `system` mode in v0.1 (host opa is fine to add later if asked). | rules_kind |
| 3 | Toolchain type | `OPA_TOOLCHAIN_TYPE = Label("//toolchain:opa")`. `ToolchainInfo(opa = …)` carries the binary path. Per-platform `toolchain` declarations select the right binary based on the resolved exec platform. | rules_kind binary pattern |
| 4 | Binary provisioning | Per-platform `opa_<plat>` repos download the stand-alone OPA executable from the upstream GitHub release at the sha256 pinned in `private/versions.bzl`. **No tarball wrapper** — OPA publishes binaries directly as release assets. | rules_kind |
| 5 | Public surface | `opa_test`, `opa_fmt_check` + `OpaInfo` provider. Both are `test = True` rules — i.e., `bazel test //path:my_test` runs them. | OPA-specific |
| 6 | Rego file partitioning | `opa_test.srcs` accepts both policy files and `*_test.rego` files; `opa test` itself partitions by filename, so the rule does not. | OPA tooling-native |
| 7 | Default `opa test` flags | `--explain=fails -v`. Verbose listing per `test_*` rule on success; full trace on failure. Costs ~0 on green tests, invaluable on red. Consumers can append more via `opa_test_args`. | Pragmatic |
| 8 | Format check shape | `opa_fmt_check` runs `opa fmt -d <files>` and treats non-empty stdout as a test failure. Mirrors `gofmt -d` as a CI gate. | gofmt convention |
| 9 | Hermeticity | The OPA binary is the only external input; pinned by sha256. No host opa, no network at test time. Tests run in the Bazel sandbox. | Sibling-family policy |
| 10 | Platform matrix v1 | linux_amd64, darwin_amd64, darwin_arm64. Linux validated in CI; macOS arm64/amd64 unvalidated but the toolchain selection is symmetric. | Sibling family |
| 11 | MODULE deps | `bazel_skylib`, `platforms`. **No `rules_python`** (we don't need it; the launchers are pure bash). `rules_shell` is dev-only for the smoke. | Smallest viable |
| 12 | Naming | snake_case rules, `MixedCaseInfo` providers (`OpaInfo`), `UPPER_SNAKE` constants. | All siblings |
| 13 | Update workflow | `tools/update_versions.sh <version>` curls per-platform `.sha256` companions and rewrites `private/versions.bzl`. | rules_certmanager pattern |
| 14 | Default test tags | None — `opa_test` and `opa_fmt_check` are sandboxed and need no special tagging. | OPA-specific |
| 15 | Version selection (v0.1.1) | One OPA version per build: the root module's `opa.version()`, else rules_opa's own (its MODULE.bazel), else `DEFAULT_VERSION` (`private/versions.bzl`); each `opa_<plat>` repo is created once. Through v0.1.0 only the root's tags were honoured, but rules_opa's own MODULE.bazel imports the repos and registers the toolchain for every consumer, so a root without `opa.version()` failed (`does not generate repository "opa_linux_amd64"`), and a root repeating the tag crashed the extension. Two different versions in one module, or an unsupported one, fail naming `opa.version`. CI's `consumer` job (`.github/consumer/check.sh`) checks this from the commit's `git archive`. The `version` on each `opa_toolchain` in `toolchain/BUILD.bazel` is still literal; it must follow the selected version once a second one is pinned. | Same fix as rules_atlas#12 |

## Notes

- OPA's **standalone** mode is the use case here. Bundle servers, the OPA HTTP API, and the partial-evaluation REPL are out of scope; consumers who want those run the binary themselves.
- The `_static` build of OPA exists for some platforms but not all. We pin the **dynamic** build everywhere for symmetry — it's the asset advertised in the release notes.
- `opa eval` is intentionally **not** wrapped in v0.1. It's useful for one-off scripted checks, but the Bazel-shaped equivalent is "pin a fixture, write `test_<...>` rules in `*_test.rego`, and use `opa_test`." Add `opa_eval` only if a real consumer asks.

## v0.1.0 status (planning)

| Area | State |
|---|---|
| MODULE.bazel (Bzlmod-only) | planned |
| Module extension (`version` only) | planned |
| Pinned OPA 1.15.2 per-platform sha256 | planned |
| `opa_test`, `opa_fmt_check` rules | planned |
| Per-platform toolchain declarations | planned |
| Analysis tests | planned |
| End-to-end exercise via `tests/example/` | planned |
| End-to-end `bazel test` runtime | planned (validated under CI; macOS pending) |

## Deferred (not v0.1.0)

- **`opa_eval`** — single-expression evaluator with `expected = …` assertion. Add when a consumer asks.
- **`opa_check`** — `opa check --strict` as a test (catches issues `opa test` misses, e.g. unused imports).
- **`opa_build`** — produce a tar/gzip bundle (`*.tar.gz`) suitable for serving from an OPA bundle endpoint.
- **`system` extension mode** — `opa.system()` to honor host-installed `opa` for users who already manage it themselves.
- **Hermetic Rego LSP / `regal` (linter).** Separate concern; could be `rules_regal` later.
