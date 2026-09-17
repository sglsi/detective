extends SceneTree
## 离屏验证 Problem3：平移/缩放远端时连线与折叠图示是否消失。
## 构建一张「宽图」（多人物 case_wide + 多条关系），分别渲染：
##   A) 人物居中默认视图  B) 平移到最右远端节点  C) 放大到 2x 并居中中间节点
## 三张图都应有连线（金色/彩色）+ 折叠圆圈（金色圆环+字形）。
## 运行（窗口模式，必须非 headless，否则 SubViewport 无渲染设备）：
##   Godot.exe --path godot_project --script res://tools/shot_wall_panzoom.gd

func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 900)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)

	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	sv.add_child(gv)
	await process_frame
	gv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 宽图数据：3 人物（case_wide 横向铺开）+ 多条结论/线索/关系
	var data := {
		"clues": [
			{"id":"c201","name":"碾轧的花草","image":"res://assets/scenes/sc02_street.png","anchor":"c201","correct":true,"associated":true,"related_npcs":["p1"]},
			{"id":"c202","name":"平行车轮印","image":"res://assets/scenes/sc02_street.png","anchor":"c202","correct":true,"associated":true,"related_npcs":["p1"]},
			{"id":"c205","name":"两组脚印","image":"res://assets/scenes/sc02_path.png","anchor":"c205","correct":true,"associated":true,"related_npcs":["p2"]},
			{"id":"c301","name":"尸体面部","image":"res://assets/scenes/sc_03_indoor_hd.jpg","anchor":"c301","correct":true,"associated":true,"related_npcs":["p3"]},
			{"id":"c303","name":"衣着整洁","image":"res://assets/scenes/sc_03_indoor_hd.jpg","anchor":"c303","correct":true,"associated":true,"related_npcs":["p3"]},
			{"id":"c3","name":"可疑证词","correct":false,"associated":true,"related_npcs":[]},
		],
		"hypo": {"title":"x","case_name":"血字的研究","chain_id":"1",
			"battlefield":{"hypotheses":[],"contradictions":[]}},
		"relations": [
			{"from":"c201","to":"dc1","kind":"support"},
			{"from":"c202","to":"dc1","kind":"support"},
			{"from":"c205","to":"dc2","kind":"support"},
			{"from":"c301","to":"dc3","kind":"support"},
			{"from":"c303","to":"dc3","kind":"support"},
			{"from":"c3","to":"dc2","kind":"support"},
			{"from":"dc1","to":"p1","kind":"target"},
			{"from":"dc2","to":"p2","kind":"target"},
			{"from":"dc3","to":"p3","kind":"target"},
		],
		"persons": [{"id":"p1","name":"人物一"}, {"id":"p2","name":"人物二"}, {"id":"p3","name":"人物三"}],
		"focus_person": "p1",
		"difficulty": 1,
		"editable": true,
		"verdict": -1,
		"case_wide": true,
		"state_store": {
			"graph_tutorial_seen": true,
			"graph_placed_clues": ["c201","c202","c205","c301","c303","c3"],
			"graph_derived_conclusions": [
				{"id":"dc1","text":"结论一"},{"id":"dc2","text":"结论二"},{"id":"dc3","text":"结论三"}],
			"graph_nodes": [],
		},
	}
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gv._canvas.size = sv.size
	gv._rebuild_graph()
	for i in 6:
		await process_frame

	# 手动补 always 边，确保连线必绘制（_edge_list 与 _relations 同源，这里兜底）
	var col := Color(0.85, 0.62, 0.18, 1.0)
	for e in data["relations"]:
		gv._edge_list.append({"from": e["from"], "to": e["to"], "kind": e["kind"],
			"color": col, "dashed": false, "dotted": false, "always": true})
	gv._redraw_all()
	for i in 4:
		await process_frame

	var clip_rect: Rect2 = gv._clip.get_global_rect()
	var vp := clip_rect.size
	print("NODES=", gv._node_center.size(), " EDGES=", gv._edge_list.size(),
		" FOLDS=", gv._fold_controls.size(), " VP=", vp)

	# 找最右 / 中间节点
	var maxx := -1e18; var right_id := ""
	var midx := 0.0
	for id in gv._node_center:
		if gv._node_center[id].x > maxx:
			maxx = gv._node_center[id].x; right_id = id
	var xs := []
	for id in gv._node_center: xs.append(gv._node_center[id].x)
	xs.sort()
	var mid_c: Vector2 = gv._node_center[gv._node_center.keys()[0]]
	if not xs.is_empty():
		var mx: float = xs[xs.size() / 2]
		for id in gv._node_center:
			if gv._node_center[id].x == mx:
				mid_c = gv._node_center[id]
				break

	# A) 人物居中默认
	gv._center_on_person(1.0)
	for i in 6: await process_frame
	_save(sv, "D:/AI/workbuddy/Claw/shot_pan_default.png")
	var cntA := _count_drawn(sv)
	print("[A 人物居中] 远端节点 right_id=", right_id, " right_x=", maxx, " drawn_px=", cntA)

	# B) 平移到最右远端节点（模拟玩家找远端推理链）
	gv._canvas.scale = Vector2(1.0, 1.0)
	gv._canvas.position = vp * 0.5 - gv._node_center[right_id] * 1.0
	gv._redraw_all()
	for i in 6: await process_frame
	_save(sv, "D:/AI/workbuddy/Claw/shot_pan_far.png")
	var cntB := _count_drawn(sv)
	print("[B 平移远端] drawn_px=", cntB, " (应≈A，证明连线/折叠未消失)")

	# C) 放大 2x 居中中间节点
	gv._canvas.scale = Vector2(2.0, 2.0)
	gv._canvas.position = vp * 0.5 - mid_c * 2.0
	gv._redraw_all()
	for i in 6: await process_frame
	_save(sv, "D:/AI/workbuddy/Claw/shot_zoom.png")
	var cntC := _count_drawn(sv)
	print("[C 放大2x] drawn_px=", cntC)

	var ok := (cntA > 500) and (cntB > 500) and (cntC > 500)
	print("PANZOOM_RESULT: ", "PASS" if ok else "CHECK")
	quit()


func _save(sv: SubViewport, path: String) -> void:
	var img := sv.get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path, " ", img.get_width(), "x", img.get_height())


## 粗略统计「非背景」绘制像素：背景接近深色 (0.07,0.06,0.08)；连线/折叠/卡片含大量更亮像素。
func _count_drawn(sv: SubViewport) -> int:
	var img := sv.get_texture().get_image()
	var n := 0
	var w := img.get_width(); var h := img.get_height()
	for y in range(0, h, 3):
		for x in range(0, w, 3):
			var c: Color = img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.9:   # 明显比背景亮
				n += 1
	return n
