extends SceneTree
## 回归测试：困难模式「拖线索 → 手写推断 → 续写结论」链路
## 覆盖：
##  H0 困难模式无预设推断候选（故走手写输入窗，而非死胡同提示）
##  H1/H2 拖线索弹出的是「可输入推断」的窗口（含 LineEdit + 「下一步」）
##  H3/H4 「下一步」在画布生成推断文本框（note_hypo_N）+ 线索→推断 绿 support 边
##  H5 生成推断后自动续接「结论输入窗」
##  H6/H7 结论落库后，困难模式四维评价的 证据维 / 结论维 均 > 0
## 用法：godot --headless --script res://tools/test_hard_custom_hypo.gd

var _pass := 0
var _fail := 0


func _chk(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + msg)
	else:
		_fail += 1
		print("[FAIL] " + msg)


func _watson_battlefield() -> Dictionary:
	return {
		"title": "华生刚从阿富汗回来？", "persons": [{"id": "NPC_WT"}],
		"battlefield": {
			"hypotheses": [
				{"id": "W-A1", "text": "不是原来的肤色", "correct": true, "gate_clue_ids": ["wrist", "face_dark"]},
			],
			"conclusions": [
				{"id": "C-A1", "text": "曾经在热带生活过", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["热带"],
					"match_keys": ["在热带生活过", "热带生活", "热带待过"], "gate_hypo_ids": ["W-A1"], "adopt_desc": "x"},
				{"id": "C-MAIN", "text": "在阿富汗服役过", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["阿富汗", "服役"],
					"match_keys": ["在阿富汗服役", "阿富汗服役过", "去过阿富汗当兵"], "gate_hypo_ids": ["conclusion_C-A1"], "target": "person:NPC_WT", "adopt_desc": "x"},
			],
			"contradictions": [],
		},
		"scene_id": "scene1", "practice": true,
	}


func _build_fresh(diff) -> Variant:
	root.size = Vector2(1920, 1080)
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [{"id": "wrist", "name": "手腕晒痕", "correct": true}, {"id": "face_dark", "name": "脸色黝黑", "correct": true}]
	var hypo: Dictionary = _watson_battlefield()
	gv.build({"clues": clues, "hypo": hypo, "persons": [{"id": "NPC_WT", "name": "华生"}],
		"difficulty": diff, "editable": true, "state_store": {}, "auto_fold": false, "case_wide": false})
	await process_frame
	return gv


func _find_lineedit(n: Node) -> LineEdit:
	if n == null:
		return null
	if n is LineEdit:
		return n
	for c in n.get_children():
		var r := _find_lineedit(c)
		if r != null:
			return r
	return null


func _find_button(n: Node, text: String) -> Button:
	if n == null:
		return null
	if n is Button and str(n.text).find(text) >= 0:
		return n
	for c in n.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null


func _find_hypo_id(gv: Variant, label: String) -> String:
	for gn in gv._graph_nodes:
		if str(gn.get("kind", "")) == "hypo" and str(gn.get("label", "")) == label:
			return str(gn.get("id", ""))
	return ""


func _has_edge(gv: Variant, f: String, t: String, k: String) -> bool:
	for r in gv._relations:
		if str(r.get("from", "")) == f and str(r.get("to", "")) == t and str(r.get("kind", "")) == k:
			return true
	return false


func _run() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = await _build_fresh(GV.Diff.HARD)
	var HYPO_TEXT := "皮肤黝黑，说明长期在户外/热带暴晒"

	# H0) 困难模式无预设推断候选 → 必然走手写输入窗
	_chk(gv._dockctl._derive_candidates().is_empty(), "H0) 困难模式无预设推断候选（应走手写输入窗）")

	# H1/H2) 拖线索后弹「可输入推断」窗
	gv._dockctl._open_derive_popup("wrist")
	await process_frame
	var le := _find_lineedit(gv._link_popup)
	_chk(le != null, "H1) 拖线索弹出的是可输入推断的窗口（含 LineEdit）")
	_chk(_find_button(gv._link_popup, "下一步") != null, "H2) 窗口含「下一步」按钮")

	# H3/H4) 输入推断 + 下一步 → 生成推断文本框 + 线索→推断 绿边
	if le != null:
		le.text = HYPO_TEXT
	gv._dockctl._confirm_derive_custom("wrist", le)
	await process_frame
	await process_frame
	var hid := _find_hypo_id(gv, HYPO_TEXT)
	_chk(hid != "", "H3) 「下一步」在画布生成推断文本框（%s）" % hid)
	_chk(_has_edge(gv, "wrist", hid, "support"), "H4) 线索→推断 support 绿边已建")

	# H5) 自动续接结论输入窗
	var cle := _find_lineedit(gv._link_popup)
	_chk(cle != null, "H5) 生成推断后自动弹出结论输入窗")

	# H6/H7) 输入结论 → 计入困难模式评分
	if cle != null:
		cle.text = "他曾经在热带生活过"
	gv._dockctl._confirm_custom_conclusion(hid, cle)
	await process_frame
	var snap: Dictionary = gv.snapshot_player_work()
	print("  [debug] graph_nodes=", snap.get("graph_nodes"))
	print("  [debug] derived_conclusions=", snap.get("derived_conclusions"))
	print("  [debug] relations=", snap.get("relations"))
	var HM = load("res://scripts/clue/hard_mode_evaluator.gd")
	var res: Dictionary = HM.evaluate(snap.get("relations", []), snap.get("graph_nodes", []),
		snap.get("derived_conclusions", []), "scene1", true)
	print("  [debug] four=", res.get("four"), " ratio=", res.get("ratio"), " stars=", res.get("stars"))
	_chk(float(res.get("four", {}).get("evidence", 0.0)) > 0.0, "H6) 证据维 > 0（推断/结论已连支撑边）")
	_chk(float(res.get("four", {}).get("conclusion", 0.0)) > 0.0, "H7) 结论维 > 0（自定义结论语义命中真相）")
	# H8/H9：自定义结论的支撑边必须被别名 remap 到真相结论 id，否则证据维按 player_concl_id 反查不到该边 → 拿不到证据分
	var remapped := false
	for r in snap.get("relations", []):
		if str(r.get("from", "")) == hid and str(r.get("to", "")) == "conclusion_C-A1" and str(r.get("kind", "")) == "support":
			remapped = true
	_chk(remapped, "H8) 自定义结论的支撑边已 remap 到真相别名（conclusion_C-A1）")
	_chk(is_equal_approx(float(res.get("four", {}).get("evidence", 0.0)), 1.0), "H9) 证据维 = 1.0（推断与结论两侧均获支撑）")

	print("HARD_HYPO_RESULT: %s (pass=%d fail=%d)" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	await process_frame
	quit()


func _init() -> void:
	await _run()
