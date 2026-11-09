extends SceneTree
## L02 无锚点链布局方向 — 正式套件
## 用例（设计文档/测试/推理墙系统测试用例清单.md）：
##   L02 | 无锚点链布局方向 | 链无人物锚点（场景二~七单链）| build 后 x | 线索最左(d0)→推断→结论最右 | P0
## 覆盖：
##   a) 真实场景二单链：persons 由线索 related_npcs 派生（非手写 []），relations 仅玩家边（无 person 边）
##      → 线索最左 → 推断 → 结论最右
##   b) 整墙无人物（persons=[]，focus 兜底 __case__）→ 同上
##   c) 一条推断支撑多条线索 → 多条线索同列(d0)、推断 d1、结论 d2（reverse 下线索当根）
##   d) 结论→结论连续推导（CL2-1→CL2-4 support）在反转模式下方向正确
##   e)（观察项，不强制修）混合墙：链A(person边→正向人物最左)、链B(无person边→反向线索最左)。
##      当前 _has_anchor 是整图判定、_reverse_mode 为全局开关 → 做不到各自独立，如实报 FAIL 并注明需按连通分量判定。
## 运行：godot --headless --path . -s res://tools/t_l02_layout_suite.gd

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("  - PASS " + msg)
	else:
		_ok = false
		print("  - FAIL " + msg)

var _gvclass = null
func _make_gv():
	if _gvclass == null:
		_gvclass = load("res://scripts/clue/graph_view_controller.gd")
	var gv = _gvclass.new()
	var holder := Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv._canvas = Control.new()
	return gv

func _has_anchor_edge(gv) -> bool:
	for r in gv._relations:
		var fk: String = gv._fold._kind_of(str(r.get("from","")))
		var tk: String = gv._fold._kind_of(str(r.get("to","")))
		if fk == "person" or fk == "event" or tk == "person" or tk == "event":
			return true
	return false

func _check_left(gv, lid: String, cid: String, tag: String) -> void:
	if not gv._node_center.has(lid) or not gv._node_center.has(cid):
		_chk(false, tag + "：节点缺失 " + lid + "/" + cid); return
	var lx: float = gv._node_center[lid].x
	var cx: float = gv._node_center[cid].x
	_chk(lx < cx, tag + "：线索x=%.0f ≤ 结论x=%.0f（线索最左→结论最右）" % [lx, cx])

## 真实场景二单链（人员由 related_npcs 派生，无 person 边）
func _scene2_a(gv) -> void:
	var clues := [
		{"id":"c201","name":"碾轧的花草","correct":true,"relation_tags":["H2-01"],"related_npcs":["KILLER"]},
		{"id":"c202","name":"平行车轮印","correct":true,"relation_tags":["H2-01"]},
	]
	var persons := []
	var seen := {}
	for c in clues:
		for p in c.get("related_npcs", []):
			if not seen.has(p): seen[p]=true; persons.append({"id":p,"name":p})
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"H2-01","text":"推断","correct":true,"gate_clue_ids":["c201","c202"]}],
		"conclusions":[
		{"id":"CL2-1","text":"结论","correct":true,"gate_hypo_ids":["H2-01"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":persons,"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await gv.get_tree().process_frame
	gv._derive.derive_hypo("c201","H2-01"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("H2-01","CL2-1"); await gv.get_tree().process_frame
	gv._rebuild_graph(); await gv.get_tree().process_frame
	_chk(gv._persons.size() == 1 and gv._persons[0].get("id","") == "KILLER" and gv._focus_person == "KILLER",
		"a 真实场景二：persons 由 related_npcs 派生 size=%d focus=%s（无 person 边，应 reverse）" % [gv._persons.size(), gv._focus_person])
	_chk(not _has_anchor_edge(gv), "a 无 person 端点边 → _has_anchor=false → reverse")
	_check_left(gv, "c201", "conclusion_CL2-1", "a")

## 整墙无人物单链
func _empty_b(gv) -> void:
	var clues := [{"id":"e1","name":"线索","correct":true,"relation_tags":["HE"]}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"HE","text":"推断","correct":true,"gate_clue_ids":["e1"]}],
		"conclusions":[
		{"id":"CLE","text":"结论","correct":true,"gate_hypo_ids":["HE"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await gv.get_tree().process_frame
	gv._derive.derive_hypo("e1","HE"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("HE","CLE"); await gv.get_tree().process_frame
	gv._rebuild_graph(); await gv.get_tree().process_frame
	_chk(gv._focus_person == "__case__" and not _has_anchor_edge(gv), "b 无人物：focus 兜底 __case__ 且无 person 边 → reverse")
	_check_left(gv, "e1", "conclusion_CLE", "b")

## 一条推断支撑多条线索：多线索同列(d0)、推断 d1、结论 d2
func _multi_clue_c(gv) -> void:
	var clues := []
	for i in range(3):
		clues.append({"id":"mc%d" % i,"name":"线索%d"%i,"correct":true,"relation_tags":["MH"]})
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"MH","text":"推断","correct":true,"gate_clue_ids":["mc0","mc1","mc2"]}],
		"conclusions":[
		{"id":"MCL","text":"结论","correct":true,"gate_hypo_ids":["MH"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await gv.get_tree().process_frame
	for i in range(3):
		gv._derive.derive_hypo("mc%d"%i,"MH"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("MH","MCL"); await gv.get_tree().process_frame
	gv._rebuild_graph(); await gv.get_tree().process_frame
	var xs: Array[float] = []
	var all_root: bool = gv._node_center.has("MH")
	for i in range(3):
		if gv._node_center.has("mc%d"%i):
			xs.append(gv._node_center["mc%d"%i].x)
			# reverse 下线索同为根(d0)，均位于推断左侧
			all_root = all_root and gv._node_center["mc%d"%i].x < gv._node_center["MH"].x
	_chk(all_root and xs.size() == 3, "c 三条线索同为 d0 根、均位于推断左侧：x=%s" % str(xs))
	if xs.size() == 3 and gv._node_center.has("MH") and gv._node_center.has("conclusion_MCL"):
		var hx: float = gv._node_center["MH"].x
		var clx: float = gv._node_center["conclusion_MCL"].x
		_chk(hx > xs[0] + 1.0 and clx > hx + 1.0, "c 推断d1<x=%s 结论d2<x=%s（线索d0→推断d1→结论d2）" % [hx, clx])

## 结论→结论连续推导（SC0→SC1→SC2）在反转模式下方向正确
func _serial_d(gv) -> void:
	var clues := [{"id":"s1","name":"线索","correct":true,"relation_tags":["SH"]}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"SH","text":"推断","correct":true,"gate_clue_ids":["s1"]}],
		"conclusions":[
		{"id":"SC0","text":"结论0","correct":true,"gate_hypo_ids":["SH"]},
		{"id":"SC1","text":"结论1","correct":true,"gate_hypo_ids":["SC0"]},
		{"id":"SC2","text":"结论2","correct":true,"gate_hypo_ids":["SC1"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await gv.get_tree().process_frame
	gv._derive.derive_hypo("s1","SH"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("SH","SC0"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("conclusion_SC0","SC1"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("conclusion_SC1","SC2"); await gv.get_tree().process_frame
	gv._rebuild_graph(); await gv.get_tree().process_frame
	var has_all: bool = gv._node_center.has("s1") and gv._node_center.has("conclusion_SC0") \
		and gv._node_center.has("conclusion_SC1") and gv._node_center.has("conclusion_SC2")
	_chk(has_all, "d 串行结论链齐全")
	if has_all:
		var x0: float = gv._node_center["s1"].x
		var xc0: float = gv._node_center["conclusion_SC0"].x
		var xc1: float = gv._node_center["conclusion_SC1"].x
		var xc2: float = gv._node_center["conclusion_SC2"].x
		_chk(x0 < xc0 and xc0 < xc1 and xc1 < xc2, "d 反转下串行结论深度递增（线索→SC0→SC1→SC2 ×：%.0f→%.0f→%.0f→%.0f）" % [x0,xc0,xc1,xc2])

## 观察项 e：混合墙（不强制修）
func _mixed_e(gv) -> void:
	var clues := [
		{"id":"cA1","name":"链A线索","correct":true,"relation_tags":["HA"]},
		{"id":"cB1","name":"链B线索","correct":true,"relation_tags":["HB"]},
	]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"HA","text":"推断A","correct":true,"gate_clue_ids":["cA1"]},
		{"id":"HB","text":"推断B","correct":true,"gate_clue_ids":["cB1"]}],
		"conclusions":[
		{"id":"CLA","text":"结论A","correct":true,"gate_hypo_ids":["HA"],"target":"person:PA"},
		{"id":"CLB","text":"结论B","correct":true,"gate_hypo_ids":["HB"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"PA","name":"人物A"}],"focus_person":"PA",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await gv.get_tree().process_frame
	gv._derive.derive_hypo("cA1","HA"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("HA","CLA"); await gv.get_tree().process_frame
	gv._edge._add_edge("PA","conclusion_CLA","support","green",false)
	gv._derive.derive_hypo("cB1","HB"); await gv.get_tree().process_frame
	gv._derive.derive_conclusion("HB","CLB"); await gv.get_tree().process_frame
	gv._rebuild_graph(); await gv.get_tree().process_frame
	var rev: bool = not _has_anchor_edge(gv)
	print("[L02-e] 观察项：has_person_edge=%s → 全局 reverse_mode=%s（整图开关，无法按连通分量独立）" % [_has_anchor_edge(gv), rev])
	var aok: bool = gv._node_center.has("PA") and gv._node_center.has("cA1") \
		and gv._node_center["PA"].x < gv._node_center["conclusion_CLA"].x \
		and gv._node_center["conclusion_CLA"].x < gv._node_center["cA1"].x
	# 链B期望反向：cB1(线索).x < 推断HB.x < 结论. 全局正向下 HB 可能更左
	var b_desired: bool = gv._node_center.has("cB1") and gv._node_center.has("HB") \
		and gv._node_center["cB1"].x < gv._node_center["HB"].x \
		and gv._node_center["HB"].x < gv._node_center["conclusion_CLB"].x
	print("[L02-e] 观察项：链A(person边)正向=%s；链B(无person边)『线索最左』实际=%s（全局开关→无法独立→需按连通分量判定）" % [aok, b_desired])
	print("[L02-e] 观察项 RESULT: 链A=%s 链B=%s（不强制修，记录缺口）" % ["PASS" if aok else "FAIL", "PASS" if b_desired else "FAIL"])

func _initialize() -> void:
	await process_frame

	await _scene2_a(await _make_gv())
	await _empty_b(await _make_gv())
	await _multi_clue_c(await _make_gv())
	await _serial_d(await _make_gv())
	await _mixed_e(await _make_gv())

	if _ok:
		print("L02_SUITE_RESULT: PASS")
	else:
		print("L02_SUITE_RESULT: FAIL")
	quit()