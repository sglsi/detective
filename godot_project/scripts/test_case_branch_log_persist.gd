extends Control
## 回归测试：推理链结论明细（StarRatingSystem.case_branch_log）必须随存档持久化。
## 复现用户报的「读档后评价体系缺少推理链信息」：此前 _build_save_data / _restore_from_dict
## 只处理了 chains(star_chains)，漏掉 case_branch_log → 读档后场景八「推理链结论」段为空。
## 流程：注入 chains+case_branch_log → save_game → reset → load_game → 断言两者还原。

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_run()
	await get_tree().process_frame
	var ok := _failures.is_empty()
	print("RESULT: " + ("PASS" if ok else "FAIL") + " (" + str(_failures.size()) + " failures)")
	for f in _failures:
		printerr("[FAIL] " + f)
	get_tree().quit(0 if ok else 1)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[OK]   " + msg)
	else:
		printerr("[FAIL] " + msg)
		_failures.append(msg)

func _safe(d, k, default):
	if d == null: return default
	if d is Dictionary and d.has(k): return d[k]
	return default

func _run() -> void:
	var srs = StarRatingSystem
	srs.reset()
	# 1) 模拟游玩：两堵墙提交验证写入的数据
	srs.submit_chain("scene2", 3, 2, 3)
	srs.submit_chain("scene3", 2, 3, 1)
	srs.case_branch_log["scene2"] = {
		"ratio": 0.82, "stars": 3, "summary": "示例结论", "hard_fail": false,
		"per_branch": [{"name": "分支A", "ratio": 0.9, "stars": 3}, {"name": "分支B", "ratio": 0.7, "stars": 2}]
	}
	srs.case_branch_log["scene3"] = {
		"ratio": 0.55, "stars": 2, "summary": "示例2", "hard_fail": true,
		"per_branch": [{"name": "分支C", "ratio": 0.5, "stars": 1}]
	}
	# 给 SaveManager 必要的最小环境
	if GameManager and "current_case_id" in GameManager:
		GameManager.current_case_id = "case_blood"
		GameManager.current_scene_id = "scene3"
	if DifficultyManager and DifficultyManager.has_method("set_difficulty"):
		DifficultyManager.set_difficulty(1)

	# 2) 存档
	var save_res = await SaveManager.save_game()
	_assert(_safe(save_res, "error", true) == false, "存档写入成功")

	# 3) 清空（模拟读档前全新状态）
	srs.reset()
	_assert(not srs.chains.has("scene2"), "清空后 chains 为空（准备读档）")
	_assert(not srs.case_branch_log.has("scene2"), "清空后 case_branch_log 为空（准备读档）")

	# 4) 读档
	var loaded = await SaveManager.load_game()
	_assert(loaded == true, "读档成功")

	# 5) chains 还原
	_assert(srs.chains.has("scene2"), "chains: scene2 还原")
	_assert(int(_safe(srs.chains.get("scene2", {}), "reasoning", -1)) == 2, "chains: scene2 推理星还原=2")
	_assert(srs.chains.has("scene3"), "chains: scene3 还原")

	# 6) case_branch_log 还原（关键修复点）
	_assert(srs.case_branch_log.has("scene2"), "case_branch_log: scene2 还原（修复点）")
	_assert(srs.case_branch_log.has("scene3"), "case_branch_log: scene3 还原（修复点）")
	var cb2: Dictionary = srs.case_branch_log.get("scene2", {})
	_assert(abs(float(_safe(cb2, "ratio", -1.0)) - 0.82) < 0.001, "case_branch_log: scene2 ratio 还原=0.82")
	var pb: Array = _safe(cb2, "per_branch", [])
	_assert(pb.size() == 2, "case_branch_log: scene2 per_branch 还原=2 条")
	if pb.size() >= 2:
		_assert(str(_safe(pb[0], "name", "")) == "分支A", "case_branch_log: per_branch[0].name 还原")
		_assert(int(_safe(pb[0], "stars", -1)) == 3, "case_branch_log: per_branch[0].stars 还原=3")
		_assert(int(_safe(pb[1], "stars", -1)) == 2, "case_branch_log: per_branch[1].stars 还原=2")
	_assert(bool(_safe(srs.case_branch_log.get("scene3", {}), "hard_fail", null)) == true, "case_branch_log: scene3 hard_fail 还原=true")
