extends SceneTree
## Renders every screen of the game to PNG for review and App Store assets.
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --rendering-driver opengl3 \
##     --resolution 720x1560 --fixed-fps 60 -s res://tools/screenshots.gd -- /output/dir
## The body lives in screenshots_body.gd, loaded at runtime so it can see the autoloads.

var out_dir := "/tmp/maze_keep_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var runner: RefCounted = load("res://tools/screenshots_body.gd").new()
	await runner.run(self, out_dir)
	quit()
