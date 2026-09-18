extends SceneTree
## 离屏验证 深U根治（思傅 2026-09-17 截图：场景二推理墙深U再现）。
## 构建场景二同构数据（K + CL2-1/2/3/4/5/6 + H2-01..06 + c201..c206），
## 玩家把 H2-01/02/03 同时支持 CL2-4（拖到 K 下）与浅层结论 CL2-1/2/3（未拖到 K 下）→
## DAG 单父化后 CL2-1/2/3 成孤儿根独占根带，连边 H2-0x→CL2-x 成跨树悬空长边 = 深U。
## 修复（孤儿根吸收）后深U消除。
## 运行（窗口模式，必须非 headless）：
##   Godot.exe --path godot_project --script res://tools/shot_deepu_fix.gd
## 输出 D:/AI/workbuddy/Claw/shot_deepu_after.png 与深U指标（运行两次：stash 修复=before，pop=after）。

func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 1000)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)

	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	sv.add_child(gv)
	await process_frame
	gv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var data := {
		"clues": [
			{"id":"c201","name":"碾轧的花草","image":"res://assets/scenes/sc02_street.png","anchor":"c201","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c202","name":"平行车轮印","image":"res://assets/scenes/sc02_street.png","anchor":"c202","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c203","name":"泥泞脚印","image":"res://assets/scenes/sc02_street.png","anchor":"c203","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c204","name":"车辙方向","image":"res://assets/scenes/sc02_street.png","anchor":"c204","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c205","name":"两组脚印","image":"res://assets/scenes/sc02_path.png","anchor":"c205","correct":true,"associated":true,"related_npcs":["K"]},
			{"id":"c206","name":"门廊血迹","image":"res://assets/scenes/sc02_path.png","anchor":"c206","correct":true,"associated":true,"related_npcs":["K"]},
		],
		"hypo": {"title":"x","case_name":"血字的研究","chain_id":"1",
			"battlefield":{"hypotheses":[],"contradictions":[]}},
		"persons": [{"id":"K","name":"KILLER"}],
		"focus_person": "K",
		"difficulty": 1,
		"editable": true,
		"verdict": -1,
		"case_wide": true,
		" relations_passthrough": true,
		"relations": [
			# 线索 → 假设（玩家连线）
			{"from":"c201","to":"H2-01","kind":"support"},
			{"from":"c202","to":"H2-01","kind":"support"},
			{"from":"c203","to":"H2-02","kind":"support"},
			{"from":"c204","to":"H2-03","kind":"support"},
			{"from":"c205","to":"H2-04","kind":"support"},
			{"from":"c205","to":"H2-06","kind":"support"},
			{"from":"c206","to":"H2-04","kind":"support"},
			{"from":"c206","to":"H2-05","kind":"support"},
			# 假设 → 浅层结论 + 三线合一结论（DAG 共享节点 → 单父化后浅层结论成孤儿根）
			{"from":"H2-01","to":"conclusion_CL2-1","kind":"support"},
			{"from":"H2-01","to":"conclusion_CL2-4","kind":"support"},
			{"from":"H2-02","to":"conclusion_CL2-2","kind":"support"},
			{"from":"H2-02","to":"conclusion_CL2-4","kind":"support"},
			{"from":"H2-03","to":"conclusion_CL2-3","kind":"support"},
			{"from":"H2-03","to":"conclusion_CL2-4","kind":"support"},
			{"from":"H2-04","to":"conclusion_CL2-5","kind":"support"},
			{"from":"H2-05","to":"conclusion_CL2-6","kind":"support"},
			{"from":"H2-06","to":"conclusion_CL2-6","kind":"support"},
			# CL2-4/CL2-6 被拖到人物 K 上（target 边）；CL2-1/2/3/5 未拖 → 孤儿根
			{"from":"conclusion_CL2-4","to":"K","kind":"target"},
			{"from":"conclusion_CL2-6","to":"K","kind":"target"},
		],
		"state_store": {
			"graph_tutorial_seen": true,
			"graph_placed_clues": ["c201","c202","c203","c204","c205","c206"],
			"graph_derived_conclusions": [
				{"id":"CL2-1","text":"结论一"},{"id":"CL2-2","text":"结论二"},
				{"id":"CL2-3","text":"结论三"},{"id":"CL2-4","text":"三线合一"},
				{"id":"CL2-5","text":"结论五"},{"id":"CL2-6","text":"结论六"},
			],
			"graph_nodes": [
				{"id":"H2-01","kind":"hypo","label":"H2-01","sub":"推断"},
				{"id":"H2-02","kind":"hypo","label":"H2-02","sub":"推断"},
				{"id":"H2-03","kind":"hypo","label":"H2-03","sub":"推断"},
				{"id":"H2-04","kind":"hypo","label":"H2-04","sub":"推断"},
				{"id":"H2-05","kind":"hypo","label":"H2-05","sub":"推断"},
				{"id":"H2-06","kind":"hypo","label":"H2-06","sub":"推断"},
			],
		},
	}
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gv._canvas.size = sv.size
	gv._rebuild_graph()
	for i in 8:
		await process_frame

	# 手动补 always 边，确保连线必绘制
	var col := Color(0.85, 0.62, 0.18, 1.0)
	for e in data["relations"]:
		gv._edge_list.append({"from": e["from"], "to": e["to"], "kind": e["kind"],
			"color": col, "dashed": false, "dotted": false, "always": true})
	gv._redraw_all()
	for i in 6:
		await process_frame

	# 深U 指标：所有关系连线的最大垂直跨度
	var dy := 0.0
	for r in data["relations"]:
		var f: String = str(r["from"]); var t: String = str(r["to"])
		if gv._node_center.has(f) and gv._node_center.has(t):
			dy = maxf(dy, absf(gv._node_center[f].y - gv._node_center[t].y))
	print("NODES=", gv._node_center.size(), " EDGES=", gv._edge_list.size(), " DEEP_U_DY=", dy)

	# 默认人物居中视图（符合 思傅 需求：进墙定格人物）
	gv._center_on_person(1.0)
	for i in 6: await process_frame
	_save(sv, "D:/AI/workbuddy/Claw/shot_deepu_after.png")
	var cnt := _count_drawn(sv)
	print("[AFTER 修复] 深U最大垂直跨度=", dy, " drawn_px=", cnt)

	quit()


func _save(sv: SubViewport, path: String) -> void:
	var img := sv.get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path, " ", img.get_width(), "x", img.get_height())


func _count_drawn(sv: SubViewport) -> int:
	var img := sv.get_texture().get_image()
	var n := 0
	var w := img.get_width(); var h := img.get_height()
	for y in range(0, h, 3):
		for x in range(0, w, 3):
			var c: Color = img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.9:
				n += 1
	return n
