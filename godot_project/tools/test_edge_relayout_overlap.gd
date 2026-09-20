extends Control

## 复现「调整（新建/删除）文本框之间关系后，文本框互相覆盖」。
## 用**真实渲染视图矩形**(Control.position + size) 做 AABB 相交检测——最贴近用户所见。
## 运行：godot --headless --path godot_project res://scenes/test_edge_relayout_overlap.tscn

var _fail := 0

func _ready() -> void:
	_run()

func _chk(cond: bool, name: String) -> void:
	if cond:
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)


## 真实视图 AABB 重叠列表
func _overlaps(gv) -> Array:
	var res := []
	var ids := []
	for id in gv._node_views.keys():
		var v = gv._node_views[id]
		if v == null or not is_instance_valid(v):
			continue
		ids.append(str(id))
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a = gv._node_views[ids[i]]
			var b = gv._node_views[ids[j]]
			var ra := Rect2(a.position, a.size)
			var rb := Rect2(b.position, b.size)
			if ra.intersects(rb):
				var ov := ra.intersection(rb)
				res.append("%s ✕ %s  (重叠 %.0f×%.0f)" % [ids[i], ids[j], ov.size.x, ov.size.y])
	return res


func _report(tag: String, gv) -> void:
	var ov := _overlaps(gv)
	print("  [%s] 节点=%d 重叠=%d" % [tag, gv._node_views.size(), ov.size()])
	for s in ov:
		print("      " + s)


func _mk_data() -> Dictionary:
	var clues := [
		{"id": "c1", "name": "手臂上有锚的文身", "desc": "锚形文身", "correct": true, "associated": true,
			"related_npcs": ["NPC_M"], "relation_tags": ["H1"], "attribute_tags": ["身体特征"]},
		{"id": "c2", "name": "军人式络腮胡", "desc": "络腮胡", "correct": true, "associated": true,
			"related_npcs": ["NPC_M"], "relation_tags": ["H2"], "attribute_tags": ["身体特征"]},
		{"id": "c3", "name": "站姿笔挺", "desc": "站姿", "correct": true, "associated": true,
			"related_npcs": ["NPC_M"], "relation_tags": ["H3"], "attribute_tags": ["举止"]},
		{"id": "c4", "name": "发号施令的神气", "desc": "神气", "correct": true, "associated": true,
			"related_npcs": ["NPC_M"], "relation_tags": ["H4"], "attribute_tags": ["举止"]},
	]
	var hypo := {
		"title": "海军陆战队员", "case_name": "测试", "chain_id": "1",
		"battlefield": {
			"hypotheses": [
				{"id": "H1", "text": "在海军中当过兵", "kind": "true", "correct": true,
					"dir": "affirm", "subject": ["信使"], "object": ["海军", "当兵"],
					"gate_clue_ids": ["c1"]},
				{"id": "H2", "text": "当过军士", "kind": "true", "correct": true,
					"dir": "affirm", "subject": ["信使"], "object": ["军士"],
					"gate_clue_ids": ["c2"]},
				{"id": "H3", "text": "受过军事训练", "kind": "true", "correct": true,
					"dir": "affirm", "subject": ["信使"], "object": ["训练"],
					"gate_clue_ids": ["c3"]},
				{"id": "H4", "text": "习惯发号施令", "kind": "true", "correct": true,
					"dir": "affirm", "subject": ["信使"], "object": ["命令"],
					"gate_clue_ids": ["c4"]},
			],
			"conclusions": [
				{"id": "CL1", "text": "此人曾在海军服役", "kind": "true", "dir": "affirm",
					"subject": ["信使"], "object": ["海军"], "gate_hypo_ids": ["H1"]},
			]
		}
	}
	var persons := [{"id": "NPC_M", "name": "信使"}]
	return {"clues": clues, "hypo": hypo, "persons": persons,
		"focus_person": "NPC_M", "difficulty": 1, "editable": true,
		"show_toolbar": true, "state_store": {}, "on_tag": Callable(),
		"on_add_edge": Callable(), "on_remove_relation": Callable(), "on_close": Callable()}


func _run() -> void:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	gv.name = "GV"
	add_child(gv)
	gv.build(_mk_data())
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.size = Vector2(1920, 1080)
		gv._rebuild_graph()
	await get_tree().process_frame
	await get_tree().process_frame

	# 派生 3 条推断链（H4 暂不派生，留作「钉位后新增节点」用）
	gv._derive_hypo("c1", "H1"); await get_tree().process_frame
	gv._derive_hypo("c2", "H2"); await get_tree().process_frame
	gv._derive_hypo("c3", "H3"); await get_tree().process_frame
	gv._derive_conclusion("H1", "CL1"); await get_tree().process_frame
	gv._rebuild_graph(); await get_tree().process_frame
	_report("① 建图+派生后", gv)

	# 模拟玩家拖动过人物节点 → 产生钉位（saved_pos 非空）
	var pid: String = "person_NPC_M"
	if not gv._node_center.has(pid):
		for k in gv._node_center.keys():
			if str(k).begins_with("person"):
				pid = str(k); break
	if gv._node_center.has(pid):
		var p: Vector2 = gv._node_center[pid]
		gv._root_anchor_pos[pid] = p
		if not gv._manual_nodes.has(pid):
			gv._manual_nodes.append(pid)
	gv._rebuild_graph(); await get_tree().process_frame
	_report("② 钉住人物后", gv)

	print("  --- 节点 id / 中心 ---")
	for k in gv._node_center.keys():
		print("      %-16s kind=%-10s center=%s" % [str(k), str(gv._node_kind.get(k, "?")), str(gv._node_center[k])])

	# ★ 场景0：钉位后新增节点（派生新推断）
	gv._derive_hypo("c4", "H4"); await get_tree().process_frame
	_report("③ 钉位后派生新推断 H4", gv)
	var ov0 := _overlaps(gv)
	_chk(ov0.is_empty(), "钉位后新增节点不应与原节点重叠")

	# ★ 场景A：模拟「拖动 H4 落到 H2 上松开」——与真实玩家操作同路径
	var h4_id := ""
	var h2_id := ""
	var h1_id := ""
	var h3_id := ""
	for k in gv._node_kind.keys():
		var s := str(k)
		if s.ends_with("H4"): h4_id = s
		if s.ends_with("H2"): h2_id = s
		if s.ends_with("H1"): h1_id = s
		if s.ends_with("H3"): h3_id = s
	if h4_id != "" and h2_id != "":
		gv._state = gv.State.EDITABLE
		gv._drag_start = Vector2(-999, -999)   # 保证 moved=true
		# _commit_move/_drop_node_except 期待**视口全局坐标**；_node_center 是画布局部坐标 → 换算
		var drop_pt: Vector2 = gv._canvas.get_global_transform() * gv._node_center[h2_id]
		gv._drag.commit_move(h4_id, drop_pt)
		await get_tree().process_frame
		await get_tree().process_frame
		print("  relations=%d（应含 H4→H2 一条）" % gv._relations.size())
		_report("④ 拖动 H4 落到 H2 建边后", gv)
		var ovA := _overlaps(gv)
		_chk(ovA.is_empty(), "拖动建边后不应有节点重叠")

	# ★ 场景B：再拖 H4 落到 H1 上（第二次调整关系）
	if h4_id != "" and h1_id != "":
		gv._drag_start = Vector2(-999, -999)
		gv._drag.commit_move(h4_id, gv._canvas.get_global_transform() * gv._node_center[h1_id])
		await get_tree().process_frame
		await get_tree().process_frame
		_report("⑤ 再拖 H4 落到 H1 后", gv)
		var ovB := _overlaps(gv)
		_chk(ovB.is_empty(), "二次拖动建边后不应有节点重叠")

	# ★ 场景C：点选两节点建边 → 再点选删除（_handle_connect_click 路径）
	if h3_id != "" and h2_id != "":
		gv.set_connect_mode(true)
		gv._handle_connect_click(h3_id, "hypo"); await get_tree().process_frame
		gv._handle_connect_click(h2_id, "hypo"); await get_tree().process_frame
		await get_tree().process_frame
		print("  relations=%d（应 +1）" % gv._relations.size())
		_report("⑥ 点选建边后", gv)
		var ovC := _overlaps(gv)
		_chk(ovC.is_empty(), "点选建边后不应有节点重叠")
		# 再点一次同一对 → 删除
		gv._handle_connect_click(h3_id, "hypo"); await get_tree().process_frame
		gv._handle_connect_click(h2_id, "hypo"); await get_tree().process_frame
		await get_tree().process_frame
		print("  relations=%d（应 -1）" % gv._relations.size())
		_report("⑦ 点选删除连线后", gv)
		var ovD := _overlaps(gv)
		_chk(ovD.is_empty(), "点选删除连线后不应有节点重叠")
		gv.set_connect_mode(false)

	print("=== EDGE_RELAYOUT_OVERLAP: %s (fail=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)
