extends SceneTree
## P3.1.x 三难度高优先三项回归单测：
##   1) 动态概率调整（NORMAL：停滞+10% / 错误+5% / 正常-5%，上限0.95，基础0.7）
##   2) 困难隐藏提示选项（filter_choices + DialogueNodeResource.is_hint_only）
##   3) 竞技分数倍率（EASY 0.5 / NORMAL 1.0 / HARD 1.5）+ 合成星级
## 哨兵：P1_RESULT: PASS
## 运行：godot --headless --script res://tools/test_difficulty_enhanced.gd --path <godot_project>

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var ok := true
	var msg := ""
	var DifficultyManager = root.get_node_or_null("/root/DifficultyManager")
	var dm = DifficultyManager

	# ── 1. 动态概率调整（NORMAL）──
	dm.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	if abs(dm.get_current_hint_probability() - 0.7) > 0.0001:
		ok = false; msg = "NORMAL 基础概率应 0.7，实得 %f" % dm.get_current_hint_probability()
	# 1b 停滞 +10%：连续 15 次交互未发现线索后 on_progress_check → 0.8
	for i in range(DifficultyManager.STALL_INTERACTION_THRESHOLD):
		dm.record_interaction()
	dm.on_progress_check()
	if abs(dm.get_current_hint_probability() - 0.8) > 0.0001:
		ok = false; msg = "停滞后应 0.8，实得 %f" % dm.get_current_hint_probability()
	# 1c 上限 0.95：反复触发停滞调整，封顶 0.95
	for k in range(10):
		for i in range(DifficultyManager.STALL_INTERACTION_THRESHOLD):
			dm.record_interaction()
		dm.on_progress_check()
	if abs(dm.get_current_hint_probability() - 0.95) > 0.0001:
		ok = false; msg = "概率应封顶 0.95，实得 %f" % dm.get_current_hint_probability()
	# 1d 正常进展 -5%，下限 0.7：重置停滞后多次 on_progress_check 不跌破 0.7
	dm.reset_stall_counter()
	for k in range(10):
		dm.on_progress_check()
	if abs(dm.get_current_hint_probability() - 0.7) > 0.0001:
		ok = false; msg = "正常进展应回落到 0.7 下限，实得 %f" % dm.get_current_hint_probability()
	# 1e 错误推理 +5%：连续 3 次错误 → 0.75
	dm.reset_stall_counter()
	for i in range(DifficultyManager.WRONG_INFERENCE_THRESHOLD):
		dm.record_wrong_inference()
	dm.on_progress_check()
	if abs(dm.get_current_hint_probability() - 0.75) > 0.0001:
		ok = false; msg = "错误推理后应 0.75，实得 %f" % dm.get_current_hint_probability()
	dm.reset_wrong_inference()

	# ── 2. 困难隐藏提示选项（filter_choices + is_hint_only）──
	var hint_node = DialogueNodeResource.new()
	hint_node.is_hint_only = true
	var real_node = DialogueNodeResource.new()
	real_node.is_hint_only = false
	var nodes = [hint_node, real_node]
	dm.set_difficulty(DifficultyManager.Difficulty.HARD)
	var filtered_hard = dm.filter_choices(nodes)
	if filtered_hard.size() != 1 or filtered_hard[0] != real_node:
		ok = false; msg = "HARD 应仅保留非提示节点，实得 %d 个" % filtered_hard.size()
	dm.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	var filtered_normal = dm.filter_choices(nodes)
	if filtered_normal.size() != 2:
		ok = false; msg = "NORMAL 应保留全部 2 个节点，实得 %d" % filtered_normal.size()

	# ── 3. 竞技分数倍率 + 合成星级 ──
	var s = load("res://autoload/star_rating_system.gd").new()
	# 满星单链 9⭐（3,3,3）：NORMAL 倍率 1.0 → 9（精确，无取整歧义）
	s.submit_chain("c", 3, 3, 3)
	dm.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	if s.get_adjusted_total_stars() != 9:
		ok = false; msg = "NORMAL 9星×1.0 应 9，实得 %d" % s.get_adjusted_total_stars()
	# 6 星单链（2,2,2）：避开 0.5 取整歧义
	s.submit_chain("c", 2, 2, 2)
	dm.set_difficulty(DifficultyManager.Difficulty.EASY)
	if s.get_adjusted_total_stars() != 3:
		ok = false; msg = "EASY 6星×0.5 应 3，实得 %d" % s.get_adjusted_total_stars()
	dm.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	if s.get_adjusted_total_stars() != 6:
		ok = false; msg = "NORMAL 6星×1.0 应 6，实得 %d" % s.get_adjusted_total_stars()
	dm.set_difficulty(DifficultyManager.Difficulty.HARD)
	if s.get_adjusted_total_stars() != 9:
		ok = false; msg = "HARD 6星×1.5 应 9，实得 %d" % s.get_adjusted_total_stars()
	# competitive_score 在 evaluate_badges 后写入（HARD=9）
	s.evaluate_badges()
	if s.competitive_score != 9:
		ok = false; msg = "competitive_score 应随 HARD=9，实得 %d" % s.competitive_score

	if ok:
		print("P1_RESULT: PASS — 三难度高优先三项（动态概率/隐藏提示/分数倍率）通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
