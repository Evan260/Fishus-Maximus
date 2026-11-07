extends RefCounted
## One file of tests: every method whose name starts with test_ is run by run_tests.gd.

var failures := 0
var passed := 0


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failures += 1
		print("FAIL: " + what)
