extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var RC = load("res://data/reasoning_chains.gd")
	var res: Array = RC.validate_all()
	print("VALIDATE_ALL: ", res)
	var CBT = load("res://data/case_branch_truth.gd")
	for b in CBT.branches():
		if str(b.get("id", "")) == "CH01M":
			var nodes: Array = b.get("nodes", [])
			var edges: Array = b.get("edges", [])
			var lay := {}
			for n in nodes:
				var L: String = str(n.get("layer", "?"))
				lay[L] = str(lay.get(L, "")) + str(n.get("id")) + " "
			print("TRUTH CH01M nodes=%d edges=%d" % [nodes.size(), edges.size()])
			for L in lay.keys():
				print("  %s: %s" % [L, lay[L]])
	quit()
