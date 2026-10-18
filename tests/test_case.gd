extends RefCounted
## Minimal GUT-style base class. tests/run_tests.gd runs every test_* method of
## every tests/test_*.gd file, each on a fresh instance.

var tree: SceneTree
var current_test := ""
var failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		fail("expected true. " + message)


func assert_false(condition: bool, message := "") -> void:
	if condition:
		fail("expected false. " + message)


func assert_eq(got: Variant, expected: Variant, message := "") -> void:
	if not _equal(got, expected):
		fail("expected %s, got %s. %s" % [var_to_str(expected), var_to_str(got), message])


func assert_ne(got: Variant, unexpected: Variant, message := "") -> void:
	if _equal(got, unexpected):
		fail("did not expect %s. %s" % [var_to_str(unexpected), message])


func _equal(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) != typeof(b) and not (typeof(a) in numeric and typeof(b) in numeric):
		return false
	return a == b
