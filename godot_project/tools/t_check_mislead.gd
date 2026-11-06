extends SceneTree
const Truth = preload("res://data/case_branch_truth.gd")
func _init():
	call_deferred("_run")
func _run():
	for b in Truth.branches():
		var bid: String = str(b.get("id",""))
		var mcount: int = b.get("misleads", []).size()
		if mcount > 0 or bid == "CH01M" or bid == "CH01W":
			print(bid, "  scene=", b.get("scene",""), "  practice=", b.get("practice",false), "  misleads=", mcount, "  nodes=", b.get("nodes",[]).size(), "  edges=", b.get("edges",[]).size())
	quit(0)
