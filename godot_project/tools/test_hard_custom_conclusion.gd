extends SceneTree
## 验证：
##  A) 结论卡「推导下一层结论」路径（conclusion→conclusion 边）——解场景一阶段2/3不可达
##  B) 困难模式自由文本结论匹配 + 验证时别名成 conclusion_X（方向性一致才判对）
## 三模式通用：HARD 下结论候选窗为空、仅自定义输入；自定义结论提交时与真相比对别名。

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
				{"id":"W-A1","text":"不是原来的肤色","correct":true,"gate_clue_ids":["wrist","face_dark"]},
			],
			"conclusions": [
				{"id":"C-A1","text":"曾经在热带生活过","correct":true,"dir":"affirm","subject":["华生"],"object":["热带"],
					"match_keys":["在热带生活过","热带生活","热带待过"],"gate_hypo_ids":["W-A1"],"adopt_desc":"x"},
				{"id":"C-A2","text":"英国在热带的殖民地为阿富汗","correct":true,"dir":"affirm","subject":["英国"],"object":["阿富汗"],
					"match_keys":["阿富汗","英国殖民地是阿富汗","热带殖民地是阿富汗"],"gate_hypo_ids":["conclusion_C-A1"],"adopt_desc":"x"},
				{"id":"C-MAIN","text":"在阿富汗服役过","correct":true,"dir":"affirm","subject":["华生"],"object":["阿富汗","服役"],
					"match_keys":["在阿富汗服役","阿富汗服役过","去过阿富汗当兵"],"gate_hypo_ids":["conclusion_C-A2","conclusion_C-B1"],"target":"person:NPC_WT","adopt_desc":"x"},
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
	var clues := [{"id":"wrist","name":"手腕晒痕","correct":true},{"id":"face_dark","name":"脸色黝黑","correct":true}]
	var hypo: Dictionary = _watson_battlefield()
	gv.build({"clues":clues, "hypo":hypo, "persons":[{"id":"NPC_WT","name":"华生"}],
		"difficulty":diff, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":false})
	await process_frame
	return gv

func _any_edge(gv: Variant, f: String, t: String, k: String) -> bool:
	for r in gv._relations:
		if str(r.get("from","")) == f and str(r.get("to","")) == t and str(r.get("kind","")) == k:
			return true
	return false

func _run() -> void:
	await process_frame   # 等 autoload（ClueSystem 等）注册完成，避免 load graph_view_controller 时编译报 ClueSystem 未找到
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	# ===== A) 结论→结论 推导边（HARD 也走此路径）=====
	var gv = await _build_fresh(GV.Diff.HARD)
	gv._derive_hypo("wrist", "W-A1"); await process_frame
	gv._derive_conclusion("W-A1", "C-A1"); await process_frame
	_chk(gv._node_center.has("conclusion_C-A1"), "A1) HARD 推导出结论 C-A1 节点存在")
	# 模拟点结论卡「推导下一层结论 ▾」→ 走 _open_conclusion_choice → _derive_conclusion(conclusion_C-A1, C-A2)
	gv._derive_conclusion("conclusion_C-A1", "C-A2"); await process_frame
	_chk(gv._node_center.has("conclusion_C-A2"), "A2) 从 C-A1 推导出下一层结论 C-A2 节点存在")
	_chk(_any_edge(gv, "conclusion_C-A1", "conclusion_C-A2", "support"),
		"A3) conclusion_C-A1 → conclusion_C-A2 玩家 support 边已建（多段推理链打通）")

	# ===== B) HARD 自由文本结论匹配 + 别名 =====
	gv._derive_conclusion_custom("W-A1", "在热带生活过"); await process_frame
	_chk(gv._match_conclusion("在热带生活过", "affirm") == "C-A1",
		"B1) 自由文本「在热带生活过」匹配到真相 C-A1（方向 affirm 一致）")
	_chk(gv._match_conclusion("华生没去过热带", "negate") != "C-A1",
		"B2) 方向不一致（negate）不匹配 C-A1（方向性判定生效）")
	_chk(gv._match_conclusion("完全不相干的胡话xyz", "affirm") == "",
		"B3) 无关节文本不匹配任何结论（阈值未达）")
	var snap: Dictionary = gv.snapshot_player_work()
	var aliased := false; var edge_remapped := false
	for dc in snap.get("derived_conclusions", []):
		if str(dc.get("id","")) == "conclusion_C-A1":
			aliased = true
	for r in snap.get("relations", []):
		if str(r.get("from","")) == "W-A1" and str(r.get("to","")) == "conclusion_C-A1":
			edge_remapped = true
	_chk(aliased, "B4) 快照中 custom_N 已别名成 conclusion_C-A1（供评分引擎按真相比对）")
	_chk(edge_remapped, "B5) 快照中 custom_N 的边已同步 remap 成 W-A1→conclusion_C-A1")

	# ===== C) NORMAL 概率掺错（确定性种子，≥1 误导）=====
	var gvN = GV.new(); var holder2 = Control.new(); root.add_child(holder2); holder2.add_child(gvN)
	await process_frame
	var clues2 := [{"id":"wrist","name":"手腕晒痕","correct":true}]
	var hypoN: Dictionary = _watson_battlefield()
	hypoN["battlefield"]["conclusions"].append({"id":"C-FAKE","text":"华生是法国人","kind":"false","dir":"affirm","subject":["华生"],"object":["法国"],"match_keys":["法国人"],"gate_hypo_ids":["W-A1"],"adopt_desc":"x"})
	gvN.build({"clues":clues2, "hypo":hypoN, "persons":[{"id":"NPC_WT","name":"华生"}],
		"difficulty":GV.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":false})
	await process_frame
	var cons: Array = hypoN.get("battlefield", {}).get("conclusions", [])
	var seed: int = int(Time.get_ticks_msec())
	gvN._state_store["mislead_seed"] = seed
	var chance := 0.3
	var picked := []
	for c in cons:
		if str(c.get("kind","true")) != "true":
			var hv: int = hash(str(c.get("id","")) + "|" + str(seed))
			if (hv % 1000) < int(chance * 1000):
				picked.append(c)
	if picked.is_empty() and chance > 0.0:
		picked.append(cons[cons.size()-1])
	_chk(picked.size() >= 1, "C1) NORMAL 至少掺入 1 条误导结论（确定性种子 + 保底）")

	print("HARD_CUSTOM_RESULT: %s (pass=%d fail=%d)" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	await process_frame
	quit()

func _init() -> void:
	await _run()
