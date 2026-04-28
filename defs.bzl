"""Public API for rules_opa."""

load("//private:opa_fmt_check.bzl", _opa_fmt_check = "opa_fmt_check")
load("//private:opa_test.bzl", _opa_test = "opa_test")
load("//private:providers.bzl", _OpaInfo = "OpaInfo")

opa_test = _opa_test
opa_fmt_check = _opa_fmt_check

OpaInfo = _OpaInfo
