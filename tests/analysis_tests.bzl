"""Analysis-time tests. Verify rules instantiate cleanly and expose
DefaultInfo without needing the OPA binary at analysis time."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_opa//:defs.bzl", "opa_fmt_check", "opa_test")

def _has_executable_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(
        env,
        target[DefaultInfo].files_to_run.executable != None,
        "expected target to expose an executable",
    )
    return analysistest.end(env)

_has_executable_test = analysistest.make(_has_executable_impl)

def opa_test_test_suite(name):
    opa_test(
        name = name + "_subject",
        srcs = ["example/access.rego", "example/access_test.rego"],
        tags = ["manual"],
    )
    _has_executable_test(name = name + "_executable", target_under_test = ":" + name + "_subject")
    native.test_suite(name = name, tests = [":" + name + "_executable"])

def opa_fmt_check_test_suite(name):
    opa_fmt_check(
        name = name + "_subject",
        srcs = ["example/access.rego"],
        tags = ["manual"],
    )
    _has_executable_test(name = name + "_executable", target_under_test = ":" + name + "_subject")
    native.test_suite(name = name, tests = [":" + name + "_executable"])
