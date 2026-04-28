package access_test

import data.access

test_allow_admin if {
	access.allow with input as {"role": "admin"}
}

test_deny_user if {
	not access.allow with input as {"role": "user"}
}

test_deny_empty if {
	not access.allow with input as {}
}
