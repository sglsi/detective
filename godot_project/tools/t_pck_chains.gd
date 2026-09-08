extends SceneTree
func _init():
	_run.call_deferred()
func _run() -> void:
	var rc = load("res://data/reasoning_chains.gd")
	print("PCK_CHAINS_KEYS=", rc.CHAINS.keys())
	var m = rc.CHAINS["CH01M"]["wall"]
	print("PCK_M_TITLE=", m["title"])
	var mids: Array = []
	for h in m["battlefield"]["hypotheses"]: mids.append(h["id"])
	print("PCK_M_HYPOS=", mids)
	for c in m["battlefield"]["conclusions"]: print("PCK_M_CONCL=", c["id"], " ", c["text"])
	quit(0)
