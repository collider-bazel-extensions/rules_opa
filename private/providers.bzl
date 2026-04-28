"""Providers exported by rules_opa."""

OpaInfo = provider(
    doc = "The resolved OPA install: pinned version + path to the " +
          "downloaded, sha256-verified `opa` executable.",
    fields = {
        "version": "OPA version string, e.g. '1.15.2'.",
        "opa_bin": "File: the platform-specific OPA executable.",
    },
)
