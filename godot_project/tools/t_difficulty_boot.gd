extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var dm = root.get_node("/root/DifficultyManager")
	print("DIFF current=%d chance=%.2f hint_lvl=%d dynamic=%s" % [dm.current_difficulty, dm.mislead_chance, dm.hotspot_hint_level, str(dm.dynamic_hint_chance)])
	var RC = load("res://data/reasoning_chains.gd")
	var wall: Dictionary = RC.build_wall_dict("CH01M")
	var ids := []
	for h in wall["battlefield"]["hypotheses"]:
		ids.append(str(h["id"]) + ("" if h.get("correct", true) else "(干扰)"))
	print("CH01M hypos: ", ", ".join(ids))
	quit()
