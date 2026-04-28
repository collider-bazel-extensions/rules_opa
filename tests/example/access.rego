package access

# Tiny illustrative policy: allow only when the input role is "admin".
# Real-world Rego is richer; this exists so we can exercise opa_test +
# opa_fmt_check end-to-end in CI.

default allow := false

allow if {
	input.role == "admin"
}
