extends SceneTree
## 探针：对比华生墙/信使墙运行时结构（排查"信使缺一步推断流程"）

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	var RC = load("res://data/reasoning_chains.gd")
	for pair in [["CH01W", "watson"], ["CH01M", "messenger"]]:
		var wall = rw.new()
		wall.name = "Wall_" + pair[1]
		root.add_child(wall)
		var hypo: Dictionary = RC.build_wall_dict(pair[0])
		var bf: Dictionary = hypo.get("battlefield", {})
		print("=== %s %s ===" % [pair[0], pair[1]])
		for h in bf.get("hypotheses", []):
			print("  HYPO %s correct=%s pool=%s gate=%s" % [h.get("id"), h.get("correct"), h.get("pool", "-"), h.get("gate_clue_ids", [])])
		for c in bf.get("conclusions", []):
			print("  CONCL %s kind=%s gate=%s target=%s" % [c.get("id"), c.get("kind"), c.get("gate_hypo_ids", []), c.get("target", "-")])
		wall.setup(_mk_clues(), hypo, Callable(), Callable(), 0, Callable(), {}, Callable(), false, -1, Callable(), false, [], false, true)
		await process_frame
		await process_frame
		var gv = wall._graph_view
		if gv != null and is_instance_valid(gv):
			var ids: Array = []
			for n in gv._graph_nodes:
				ids.append(str(n.get("id")) + "/" + str(n.get("kind")))
			print("  graph_nodes(%d): %s" % [ids.size(), ", ".join(PackedStringArray(ids))])
		else:
			print("  graph_view: null")
		var gvc = wall._graph_view
		if gvc != null and "_hypo_current" in gvc:
			var cl: Array = gvc._hypo_current.get("conclusions", [])
			var cids: Array = []
			for c in cl:
				cids.append(str(c.get("id")))
			print("  concl_candidates(%d): %s" % [cids.size(), ", ".join(PackedStringArray(cids))])
		wall.queue_free()
		await process_frame
	quit()

func _mk_clues() -> Array:
	var out: Array = []
	for cid in ["tattoo", "beard", "posture", "manner", "sleeve", "limp"]:
		out.append({"id": cid, "name": cid, "description": "", "source": "messenger"})
	for cid in ["wrist", "arm", "face_dark", "face_haggard", "pose", "medical"]:
		out.append({"id": cid, "name": cid, "description": "", "source": "watson"})
	return out
