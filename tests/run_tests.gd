extends SceneTree
## Headless test runner. From the project folder:
##   godot --headless --import
##   godot --headless --fixed-fps 60 -s res://tests/run_tests.gd
## Any engine or script error raised while a test runs fails that test.

const TESTS_DIR := "res://tests/"


class ErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var only := OS.get_environment("TEST_FILTER")
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TESTS_DIR)).filter(
		func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	for file: String in files:
		var script: GDScript = load(TESTS_DIR + file)
		for method in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_") or (only and not test_name.contains(only)):
				continue
			catcher.errors.clear()
			var case: Variant = script.new()
			case.tree = self
			case.current_test = test_name
			await case.before_each()
			await case.call(test_name)
			await case.after_each()
			var problems: Array[String] = case.failures.duplicate()
			for error in catcher.errors:
				problems.append("engine error: " + error)
			total += 1
			if problems.is_empty():
				print("  ok    %s  %s" % [file, test_name])
			else:
				failed += 1
				print("  FAIL  %s  %s" % [file, test_name])
				for problem in problems:
					print("          " + problem)
	print("\n%d tests, %d failed" % [total, failed])
	OS.remove_logger(catcher)
	quit(1 if failed > 0 else 0)
