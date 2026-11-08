extends SceneTree
## L01 测试套件：图谱视图布局「模式 C 星型树基本布局」
## 用例（清单模块四 L01）：单链 + 人物锚点，build 后检查节点 x 坐标：
##   人物最左(depth=0) → 结论 → 推断 → 线索最右(depth 最大)；同 depth 同列(x 差≤1px)。
## 真实链路：gv.build → _derive.derive_hypo/derive_conclusion → 结论→人物 target 边
##           → _rebuild_graph（走 _compute_layout → _pack_components → 去重叠 → clamp 全后处理）
## 断言：① 人物最左  ② 深度单调右进  ③ 同 depth 同列  ④ 双结论触发自动平衡（L08 边界记录）
func _initialize() -> void:
	await process_frame
	var t := []   # 断言结果表
	var ok := true

	# ============ 构造实际布局 ============
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [
		{"id":"wrist","name":"华生手腕肤色分界","correct":true},
		{"id":"face_dark","name":"华生脸色黝黑","correct":true},
		{"id":"pose","name":"华生军人站姿","correct":true},
		{"id":"medical","name":"身上有消毒液气味","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"W-A1","text":"华生当过兵","correct":true,"gate_clue_ids":["wrist","face_dark"]},
		{"id":"W-B1","text":"华生是名军医","correct":true,"gate_clue_ids":["pose","medical"]}],
		"conclusions":[
		{"id":"C-MAIN","text":"华生刚从阿富汗归来","correct":true,"gate_hypo_ids":["W-A1","W-B1"],"target":"person:NPC_WT"}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"NPC_WT","name":"华生"}],
		"focus_person":"NPC_WT","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive.derive_hypo("wrist","W-A1"); gv._derive.derive_hypo("face_dark","W-A1")
	gv._derive.derive_hypo("pose","W-B1"); gv._derive.derive_hypo("medical","W-B1")
	await process_frame
	gv._derive.derive_conclusion("W-A1","C-MAIN"); gv._derive.derive_conclusion("W-B1","C-MAIN")
	await process_frame
	gv._edge._add_edge("conclusion_C-MAIN","NPC_WT","target","gold",false)
	await process_frame
	gv._rebuild_graph()
	await process_frame

	# ============ 节点类别归类 ============
	var node_kind := {}
	for nd in gv._node_list():
		node_kind[nd.get("id","")] = nd.get("kind","")

	# ① 人物最左
	var person_x: float = gv._node_center.get("NPC_WT", Vector2.ZERO).x
	var person_min := true
	for id in gv._node_center.keys():
		if node_kind.get(id,"")=="person": continue
		if gv._node_center[id].x < person_x - 1.0:
			person_min = false
			t.append("FAIL ①: 人物非最左（%s x=%.1f < person %.1f）" % [id, gv._node_center[id].x, person_x])
	if person_min:
		t.append("PASS ① 人物最左 (x=%.1f)" % person_x)
	ok = ok and person_min

	# ② 深度单调右进（按类 depth 列：col_x 递增）
	var depth_col_x := {}
	for id in gv._node_center.keys():
		var d: int = depth_of_class(node_kind.get(id,""))
		if d < 0: continue
		if not depth_col_x.has(d): depth_col_x[d] = INF
		depth_col_x[d] = minf(depth_col_x[d], gv._node_center[id].x)
	var mono := true
	var sorted_d := depth_col_x.keys(); sorted_d.sort()
	var prev_x := -INF
	for d in sorted_d:
		if depth_col_x[d] <= prev_x + 1.0:
			mono = false
			t.append("FAIL ②: depth %d 列 %.1f 未右大于前 %.1f" % [d, depth_col_x[d], prev_x])
		prev_x = depth_col_x[d]
	if mono:
		var dstr := ""
		for d in sorted_d: dstr += "d%d=%.0f " % [d, depth_col_x[d]]
		t.append("PASS ② 深度单调右进: %s" % dstr)
	ok = ok and mono

	# ③ 同 depth 同列（x 差 ≤1）
	var samecol := true
	for d in sorted_d:
		var xs := []
		for id in gv._node_center.keys():
			if depth_of_class(node_kind.get(id,"")) == d:
				xs.append(gv._node_center[id].x)
		if xs.size() <= 1: continue
		var base_x: float = xs[0]
		for x in xs:
			if absf(x - base_x) > 1.0:
				samecol = false
				t.append("FAIL ③: depth %d 同列偏差 %.1f" % [d, absf(x-base_x)])
	if samecol:
		t.append("PASS ③ 同 depth 同列（x 差≤1）")
	ok = ok and samecol

	# ④ 双结论触发自动平衡（L08 边界记录：非 L01 范畴）
	var gv2 = GV.new()
	var holder2 = Control.new(); root.add_child(holder2); holder2.add_child(gv2)
	await process_frame
	gv2.build({"clues":clues,"hypo":{"battlefield":{"hypotheses":[
		{"id":"W-A1","text":"A","correct":true,"gate_clue_ids":["wrist"]},
		{"id":"W-B1","text":"B","correct":true,"gate_clue_ids":["pose"]}],
		"conclusions":[
		{"id":"C-A1","text":"甲","correct":true,"gate_hypo_ids":["W-A1"],"target":"person:NPC_WT"},
		{"id":"C-MAIN","text":"乙","correct":true,"gate_hypo_ids":["W-B1"],"target":"person:NPC_WT"}]}},
		"persons":[{"id":"NPC_WT","name":"华生"}],"focus_person":"NPC_WT",
		"difficulty":gv2.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv2._derive.derive_hypo("wrist","W-A1"); gv2._derive.derive_hypo("pose","W-B1")
	await process_frame
	gv2._derive.derive_conclusion("W-A1","C-A1"); gv2._derive.derive_conclusion("W-B1","C-MAIN")
	await process_frame
	gv2._edge._add_edge("conclusion_C-A1","NPC_WT","target","gold",false)
	gv2._edge._add_edge("conclusion_C-MAIN","NPC_WT","target","gold",false)
	await process_frame
	gv2._rebuild_graph()
	await process_frame
	if gv2._balanced_layout:
		t.append("PASS ④ 双结论自动平衡已触发（L08 范畴，非 L01）")
		ok = ok and true
	else:
		t.append("INFO ④ 双结论未触发自动平衡（若意外平衡逻辑有变，需复核 L08）")

	# L01 判定：单链场景下 main 布局未被自动平衡接管
	if not gv._balanced_layout:
		t.append("PASS 前置：单链未触发自动平衡 → 走 _logic_tree_layout")
		ok = ok and true
	else:
		t.append("FAIL 前置: 单链竟触发自动平衡")
		ok = false

	for l in t: print("  - " + l)
	var dstr2 := ""
	for d in sorted_d:
		for id in gv._node_center.keys():
			if depth_of_class(node_kind.get(id,"")) == d:
				dstr2 += "%s(x=%.0f,y=%.0f) " % [id, gv._node_center[id].x, gv._node_center[id].y]
		dstr2 += "| "
	print("  L01 实录: " + dstr2)
	print("L01_SUITE_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()


## GDScript 局部 func 提升为文件级，供 depth_of_class 引用
func depth_of_class(kind: String) -> int:
	match kind:
		"person": return 0
		"conclusion": return 1
		"hypo": return 2
		"clue": return 3
		_: return -1