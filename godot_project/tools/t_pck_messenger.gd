extends SceneTree
func _init() -> void:
	var RC = load("res://data/reasoning_chains.gd")
	var wall = RC.build_wall_dict("CH01M")
	var hypos: Array = wall["battlefield"]["hypotheses"]
	for h in hypos:
		if h["id"] in ["M-01","M-02","M-04"]:
			print("HYPO %s: %s | why=%s" % [h["id"], h["text"], h.get("why","")])
	for cf in ["clue_tattoo","clue_beard","clue_posture","clue_manner"]:
		var c = load("res://data/clues/%s.tres" % cf)
		print("%s: %s | %s" % [cf, c.name, c.description])
	quit()
