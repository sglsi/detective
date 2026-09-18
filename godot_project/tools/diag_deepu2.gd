extends SceneTree
func _initialize() -> void:
	await process_frame
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	root.add_child(gv)
	await process_frame
	var data := {
		"clues": [
			{"id":"c201","name":"碾轧的花草","image":"res://assets/scenes/sc02_street.png","anchor":"c201","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c202","name":"平行车轮印","image":"res://assets/scenes/sc02_street.png","anchor":"c202","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c203","name":"泥泞脚印","image":"res://assets/scenes/sc02_street.png","anchor":"c203","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c204","name":"车辙方向","image":"res://assets/scenes/sc02_street.png","anchor":"c204","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c205","name":"两组脚印","image":"res://assets/scenes/sc02_path.png","anchor":"c205","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c206","name":"门廊血迹","image":"res://assets/scenes/sc02_path.png","anchor":"c206","correct":true,"associated":true,"related_npcs":["K"]},
		],
		"hypo": {"title":"x","case_name":"血字的研究","chain_id":"1","battlefield":{"hypotheses":[],"contradictions":[]}},
		"persons": [{"id":"K","name":"KILLER"}],
		"focus_person": "K", "difficulty": 1, "editable": true, "verdict": -1,
		"case_wide": true, "relations_passthrough": true,
		"relations": [
			{"from":"c201","to":"H2-01","kind":"support"},
			{"from":"c202","to":"H2-01","kind":"support"},
			{"from":"c203","to":"H2-02","kind":"support"},
			{"from":"c204","to":"H2-03","kind":"support"},
			{"from":"c205","to":"H2-04","kind":"support"},
			{"from":"c205","to":"H2-06","kind":"support"},
			{"from":"c206","to":"H2-04","kind":"support"},
			{"from":"c206","to":"H2-05","kind":"support"},
			{"from":"H2-01","to":"conclusion_CL2-1","kind":"support"},
			{"from":"H2-01","to":"conclusion_CL2-4","kind":"support"},
			{"from":"H2-02","to":"conclusion_CL2-2","kind":"support"},
			{"from":"H2-02","to":"conclusion_CL2-4","kind":"support"},
			{"from":"H2-03","to":"conclusion_CL2-3","kind":"support"},
			{"from":"H2-03","to":"conclusion_CL2-4","kind":"support"},
			{"from":"H2-04","to":"conclusion_CL2-5","kind":"support"},
			{"from":"H2-05","to":"conclusion_CL2-6","kind":"support"},
			{"from":"H2-06","to":"conclusion_CL2-6","kind":"support"},
			{"from":"conclusion_CL2-4","to":"K","kind":"target"},
			{"from":"conclusion_CL2-6","to":"K","kind":"target"},
		],
		"state_store": {
			"graph_tutorial_seen": true,
			"graph_placed_clues": ["c201","c202","c203","c204","c205","c206"],
			"graph_derived_conclusions": [
				{"id":"CL2-1","text":"结论一"},{"id":"CL2-2","text":"结论二"},
				{"id":"CL2-3","text":"结论三"},{"id":"CL2-4","text":"三线合一"},
				{"id":"CL2-5","text":"结论五"},{"id":"CL2-6","text":"结论六"}],
			"graph_nodes": [
				{"id":"H2-01","kind":"hypo","label":"H2-01","sub":"推断"},
				{"id":"H2-02","kind":"hypo","label":"H2-02","sub":"推断"},
				{"id":"H2-03","kind":"hypo","label":"H2-03","sub":"推断"},
				{"id":"H2-04","kind":"hypo","label":"H2-04","sub":"推断"},
				{"id":"H2-05","kind":"hypo","label":"H2-05","sub":"推断"},
				{"id":"H2-06","kind":"hypo","label":"H2-06","sub":"推断"}],
		},
	}
	gv.build(data)
	gv._rebuild_graph()
	for i in 6:
		await process_frame
	var nc_prod: Dictionary = gv._node_center.duplicate()
	gv._balanced_layout = true
	var nodes: Array = gv._node_list()
	var out: Dictionary = {}
	gv._layout._balanced_tree_layout(nodes, Vector2(960.0, 540.0), {}, out)
	var po: Dictionary = gv._layout._build_parent_of()
	print("PARENT_OF:", po)
	# depth via BFS on parent_of
	var depth := {}
	var q := []
	for k in po.keys():
		var p: String = po[k]
		if not po.has(p):
			depth[p] = 0
			q.append(p)
	while q.size() > 0:
		var u: String = q.pop_back()
		for c in po.keys():
			if po[c] == u and not depth.has(c):
				depth[c] = depth[u] + 1
				q.append(c)
	for k in depth.keys():
		print("  depth[%s]=%d" % [k, depth[k]])
	# 生产路径边表
	var rows := []
	for r in data["relations"]:
		var f: String = r["from"]; var t: String = r["to"]
		if nc_prod.has(f) and nc_prod.has(t):
			var dy: float = absf(nc_prod[f].y - nc_prod[t].y)
			var dx: float = absf(nc_prod[f].x - nc_prod[t].x)
			rows.append({"f":f,"t":t,"dy":dy,"dx":dx,"df":depth.get(f,-1),"dt":depth.get(t,-1)})
	rows.sort_custom(func(a,b): return a["dy"] > b["dy"])
	print("=== 生产路径 gv._node_center (用户实际所见) ===")
	for r2 in rows:
		print("EDGE %s(d%d)->%s(d%d)  dy=%.0f dx=%.0f" % [r2["f"],r2["df"],r2["t"],r2["dt"],r2["dy"],r2["dx"]])
	# 直接调用边表
	var rows2 := []
	for r in data["relations"]:
		var f: String = r["from"]; var t: String = r["to"]
		if out.has(f) and out.has(t):
			var dy: float = absf(out[f].y - out[t].y)
			rows2.append({"f":f,"t":t,"dy":dy})
	rows2.sort_custom(func(a,b): return a["dy"] > b["dy"])
	print("=== 直接 _balanced_tree_layout(out) ===")
	for r2 in rows2:
		print("EDGE %s->%s  dy=%.0f" % [r2["f"], r2["t"], r2["dy"]])
	quit()
