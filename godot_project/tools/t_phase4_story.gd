extends SceneTree
## Phase 4 剧情挂载探针：信号层 / 四档台词 / 旁支链 / 深度 gate / 账本补存

var _fails: int = 0

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("P4_STORY PASS | ", name)
	else:
		_fails += 1
		print("P4_STORY FAIL | ", name, " | ", detail)

func _run() -> void:
	# A. 账本补存（record_branch_progress 顶层 adopted + per_branch negated 合并）
	var srs = get_root().get_node_or_null("StarRatingSystem")
	_check("A0_starRS_autoload", srs != null, "StarRatingSystem 不可用")
	if srs:
		srs.record_branch_progress("scene2", {
			"ratio": 0.82, "stars": 3, "summary": "s", "hard_fail": false,
			"per_branch": [{"name": "CH02", "ratio": 0.8, "stars": 3, "negated_misleads": ["H2-M2"]}],
			"adopted_misleads": ["H2-M1"],
		})
		var blog: Dictionary = srs.get_case_branch_log()
		var sb: Dictionary = blog.get("scene2", {})
		_check("A1_adopted_saved", (sb.get("adopted_misleads", []) as Array).has("H2-M1"))
		var neg: Array = sb.get("negated_misleads", [])
		_check("A2_negated_merged", neg.has("H2-M2"), str(neg))
	# B. 信号层
	var sc2 = load("res://scripts/scene/scene2.gd").new()
	var sig: Dictionary = sc2._reasoning_signal()
	_check("B1_sig_ratio", float(sig.get("ratio", 0.0)) > 0.8 and (sig.get("adopted_misleads", []) as Array).has("H2-M1"), str(sig))
	# C. 四档台词
	var v3: Array = sc2._verdict_talk_lines(3)
	var v0: Array = sc2._verdict_talk_lines(0)
	_check("C1_lines_nonempty", not v3.is_empty() and not v0.is_empty())
	var v0_text: String = str(v0[1][1]) if v0.size() > 1 else ""
	_check("C2_contradict_hints", v0_text.contains("排除"), v0_text)
	sc2.free()
	# D. 旁支链：_make_nodes 显式 next（b2→t0）
	var sc3 = load("res://scripts/scene/scene3.gd").new()
	var raw: Array = [
		["b0", "雷斯垂德", "台词0", "", ""],
		["b1", "福尔摩斯", "台词1", "", "自信"],
		["b2", "华生", "台词2", "t0", "疑惑"],
		["t0", "福尔摩斯", "主线0", "", ""],
		["t1", "华生", "主线1", "", ""],
	]
	var made: Array = sc3._make_nodes(raw)
	var nxt0: Array = made[0].next_nodes
	var nxt2: Array = made[2].next_nodes
	_check("D1_chain_auto", nxt0.size() == 1 and str(nxt0[0]) == "b1", str(nxt0))
	_check("D2_chain_bridge", nxt2.size() == 1 and str(nxt2[0]) == "t0", str(nxt2))
	sc3.free()
	# E. 深度 gate
	var sc4 = load("res://scripts/scene/scene4.gd").new()
	_check("E1_scene_id", str(sc4.scene_id()) == "scene4", str(sc4.scene_id()))
	srs.record_branch_progress("scene3", {"ratio": 0.82, "stars": 3, "per_branch": []})
	_check("E2_depth_good", bool(sc4._sig_depth_ok()) == true, "ratio=0.82 应达标")
	if srs:
		srs.record_branch_progress("scene3", {"ratio": 0.3, "stars": 1, "per_branch": []})
	_check("E3_depth_low", bool(sc4._sig_depth_ok()) == false, "ratio=0.3 应不达标")
	srs.case_branch_log.erase("scene3")
	_check("E4_depth_none", bool(sc4._sig_depth_ok()) == false, "无账本应不达标")
	sc4.free()
	print("P4_STORY DONE fails=", _fails)
	quit(1 if _fails > 0 else 0)

func _initialize() -> void:
	call_deferred("_run")
