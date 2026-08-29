extends SceneTree
func _initialize() -> void:
	await process_frame
	var ok := true
	for p in ["res://scripts/clue/reasoning_wall.gd", "res://scripts/scene/detective_scene.gd",
			"res://scripts/clue/graph/graph_view_dock.gd", "res://scripts/clue/graph/graph_view_edge.gd",
			"res://scripts/clue/graph_view_controller.gd", "res://scripts/clue/wall/wall_verify.gd",
			"res://data/case_reasoning_registry.gd"]:
		var s = load(p)
		if s == null:
			print("PARSE FAIL: " + p); ok = false
		else:
			print("OK: " + p)
	print("PARSE_RESULT: " + ("PASS" if ok else "FAIL"))
	quit()
