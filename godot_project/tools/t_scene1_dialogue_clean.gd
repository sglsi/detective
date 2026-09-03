extends SceneTree
func _init():
	_run.call_deferred()
func _run() -> void:
	for i in 5: await process_frame
	var ps: PackedScene = load("res://scenes/scene1.tscn")
	if ps == null: print("FAIL_LOAD"); quit(1); return
	var sc = ps.instantiate()
	root.add_child(sc)
	for i in 5: await process_frame
	print("SCRIPT=", sc.get_script().resource_path if sc.get_script() else "null")
	if not sc.has_method("_show_mrs_hudson_dialogue"):
		print("NO_METHOD"); quit(1); return
	var total := 0
	var total_bad := 0
	for m in ["_show_opening_dialogue", "_show_mrs_hudson_dialogue"]:
		if not sc.has_method(m): continue
		sc.call(m)
		for i in 5: await process_frame
		var mgr = sc.get("_dm")
		var res = mgr.get("dialogue_resource") if mgr else null
		var nodes = res.get("nodes") if res else null
		if nodes == null: continue
		for n in nodes:
			total += 1
			var t: String = n.text
			if t.begins_with("（") or "（愣住）" in t or "（平静地）" in t or "（惊讶得" in t or "（上下打量" in t or "（门铃响起）" in t:
				total_bad += 1
				print("BAD:", t.substr(0, 40))
	print("CHECKED=", total, " BAD=", total_bad)
	quit(0 if (total > 0 and total_bad == 0) else 1)
