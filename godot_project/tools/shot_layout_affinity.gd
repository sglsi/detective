extends SceneTree
## 离屏渲染「链路亲和 + 自动平衡」布局效果（思傅 2026-09-17 三原则）：
## 4 条结论链，其中链1（血字）与链3（蹄铁）通过线索共连（同链）——
## 预期：① 整树高度超阈值自动左右分摊（不再单竖列）；② 链1/链3 同侧相邻不成深U。
## 运行（窗口模式）：Godot.exe --path godot_project --script res://tools/shot_layout_affinity.gd

func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 1000)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)

	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	sv.add_child(gv)
	await process_frame
	gv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var clues := []
	var clue_names := {"k1": "墙上的血字", "k2": "门外的泥印", "k3": "右前蹄新换蹄铁", "k4": "蹄铁边缘血迹",
		"k5": "碾轧的花草", "k6": "名片盒空了", "k7": "马车夫的鞭梢", "k8": "醉酒水手证词"}
	for cid in clue_names:
		clues.append({"id": cid, "name": str(clue_names[cid]), "correct": true, "associated": true,
			"related_npcs": ["霍普"]})
	var graph_nodes := []
	for i in range(1, 5):
		graph_nodes.append({"id": "h%d" % i, "kind": "hypo", "label": "推断%d" % i, "sub": ""})
	var dcs := []
	var rel := []
	for i in range(1, 5):
		dcs.append({"id": "dc%d" % i, "text": "结论%d：链路%d" % [i, i]})
		rel.append({"from": "conclusion_dc%d" % i, "to": "霍普", "kind": "support"})
		rel.append({"from": "h%d" % i, "to": "conclusion_dc%d" % i, "kind": "support"})
		rel.append({"from": "k%d" % (i * 2 - 1), "to": "h%d" % i, "kind": "support"})
		rel.append({"from": "k%d" % (i * 2), "to": "h%d" % i, "kind": "support"})
	# 同链：血字(k1) 与 蹄铁(k3) 相互印证 → 链1 与 链3 亲和
	rel.append({"from": "k1", "to": "h3", "kind": "support"})

	var data := {
		"clues": clues,
		"hypo": {"title": "x", "case_name": "血字的研究", "chain_id": "1",
			"battlefield": {"hypotheses": [], "contradictions": []}},
		"relations": rel,
		"persons": [{"id": "霍普", "name": "霍普"}],
		"focus_person": "霍普",
		"difficulty": 1,
		"editable": true,
		"verdict": -1,
		"case_wide": true,
		"state_store": {
			"graph_tutorial_seen": true,
			"graph_placed_clues": clue_names.keys(),
			"graph_derived_conclusions": dcs,
			"graph_nodes": graph_nodes,
		},
	}
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gv._canvas.size = Vector2(sv.size)
	gv._rebuild_graph()
	for i in 4:
		await process_frame

	# 断言 1：自动平衡生效（有结论在人物左侧）
	var left_n: int = 0
	for i in range(1, 5):
		var cid := "conclusion_dc%d" % i
		if gv._node_center.has(cid) and gv._node_center[cid].x < gv._node_center["霍普"].x:
			left_n += 1
	print("[ASSERT] 自动平衡：左侧结论数 = %d（>0 即已左右分摊） → %s" % [left_n, "PASS" if left_n > 0 else "FAIL"])

	# 断言 2：链1 与 链3 同侧相邻（同侧内垂直序相邻，中间不隔其他链）
	var side := {}
	var ymap := {}
	for i in range(1, 5):
		var cid := "conclusion_dc%d" % i
		ymap[i] = float(gv._node_center[cid].y)
		side[i] = "L" if gv._node_center[cid].x < gv._node_center["霍普"].x else "R"
	print("[ASSERT] 链1/链3 同侧：%s" % ["PASS" if side[1] == side[3] else "FAIL"])
	var same_side_ys: Array = []
	for i in range(1, 5):
		if side[i] == side[1]:
			same_side_ys.append([ymap[i], i])
	same_side_ys.sort_custom(func(a, b): return a[0] < b[0])
	var pos1: int = -1
	var pos3: int = -1
	for i in same_side_ys.size():
		if int(same_side_ys[i][1]) == 1: pos1 = i
		if int(same_side_ys[i][1]) == 3: pos3 = i
	print("[ASSERT] 同侧(%s)内垂直序：链1 第%d、链3 第%d → %s" % [side[1], pos1 + 1, pos3 + 1,
		"PASS" if absi(pos1 - pos3) == 1 else "FAIL"])

	# 取景（以 _clip 为目标窗口）
	var clip_rect: Rect2 = gv._clip.get_global_rect()
	var vp := clip_rect.size
	var target := clip_rect.position + clip_rect.size * 0.5
	var xform: Transform2D = gv._canvas.get_global_transform()
	var minp := Vector2(1e18, 1e18)
	var maxp := Vector2(-1e18, -1e18)
	for id in gv._node_views:
		var v: Control = gv._node_views[id]
		var tl: Vector2 = xform * (v.position)
		var br: Vector2 = xform * (v.position + v.size)
		minp = Vector2(minf(minp.x, tl.x), minf(minp.y, tl.y))
		maxp = Vector2(maxf(maxp.x, br.x), maxf(maxp.y, br.y))
	var bbox := maxp - minp
	var mg := 30.0
	var ns: float = clampf(minf((vp.x - mg * 2.0) / maxf(bbox.x, 1.0), (vp.y - mg * 2.0) / maxf(bbox.y, 1.0)), 0.05, 1.0)
	gv._canvas.scale = gv._canvas.scale * ns
	for it in 3:
		await process_frame
		var gl_c: Vector2 = gv._canvas.get_global_transform() * ((minp + maxp) * 0.5)
		var diff: Vector2 = target - gl_c
		if diff.length() < 1.0:
			break
		gv._canvas.position += diff
	for i in 10:
		await process_frame

	var img := sv.get_texture().get_image()
	var out := "D:/AI/workbuddy/Claw/layout_affinity.png"
	img.save_png(out)
	print("SAVED ", out, " ", img.get_width(), "x", img.get_height(), " nodes=", gv._node_views.size())
	quit()
