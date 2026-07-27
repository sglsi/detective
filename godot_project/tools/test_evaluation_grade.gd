extends SceneTree
## P3.1.y 评价体系完善回归单测：
##   1) 综合等级（GDD §2.6.5）：名侦探 / 合格侦探 / 继续推理
##   2) 简单模式观察 3 星门槛降至 0.8（GDD §2.6.2：关键线索≥80%即可）
##   3) 与竞技倍率合成星级（P3.1.x）互不冲突
## 哨兵：P1_RESULT: PASS
## 运行：godot --headless --script res://tools/test_evaluation_grade.gd --path <godot_project>

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
	var s = load("res://autoload/star_rating_system.gd").new()

	# ── 1. 综合等级 ──
	# 名侦探：满星 9，三维均 3 星
	s.observation_score = s.max_observation
	s.reasoning_score = s.max_reasoning
	s.insight_score = s.max_insight
	var g = s.get_evaluation_grade()
	if g.get("grade", "") != "master_detective":
		ok = false; msg = "满星应名侦探，实得 %s" % g.get("grade", "")

	# 名侦探：7 星且 2 维满星（obs3+rea3+ins1）→ 仍名侦探
	s.insight_score = 1
	g = s.get_evaluation_grade()
	if g.get("grade", "") != "master_detective":
		ok = false; msg = "7星且2维满星应名侦探，实得 %s" % g.get("grade", "")

	# 合格侦探：7 星但仅 1 维满星（obs3+rea2+ins2）→ 合格侦探
	s.reasoning_score = int(float(s.max_reasoning) * 0.64)   # 8/14≈0.57→2星
	s.insight_score = int(float(s.max_insight) * 0.43)       # 3/7≈0.43→2星
	g = s.get_evaluation_grade()
	if g.get("grade", "") != "qualified_detective":
		ok = false; msg = "7星仅1维满星应合格侦探，实得 %s" % g.get("grade", "")

	# 合格侦探：5 星（obs3+rea2+ins0）
	s.observation_score = s.max_observation
	s.reasoning_score = int(float(s.max_reasoning) * 0.64)
	s.insight_score = 0
	g = s.get_evaluation_grade()
	if g.get("grade", "") != "qualified_detective":
		ok = false; msg = "5星应合格侦探，实得 %s" % g.get("grade", "")

	# 继续推理：3 星（obs3+rea0+ins0）
	s.observation_score = s.max_observation
	s.reasoning_score = 0
	s.insight_score = 0
	g = s.get_evaluation_grade()
	if g.get("grade", "") != "keep_investigating":
		ok = false; msg = "3星应继续推理，实得 %s" % g.get("grade", "")

	# ── 2. 简单模式观察 3 星门槛降至 0.8 ──
	if DifficultyManager != null:
		s.observation_score = int(float(s.max_observation) * 0.85)  # 97/115≈0.843
		s.reasoning_score = 0
		s.insight_score = 0
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
		var easy_obs = s.get_stars(s.RatingDimension.OBSERVATION)
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
		var normal_obs = s.get_stars(s.RatingDimension.OBSERVATION)
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
		if easy_obs != 3 or normal_obs != 2:
			ok = false; msg = "EASY观察0.85应3星/NORMAL应2星，实得 EASY=%d NORMAL=%d" % [easy_obs, normal_obs]

	# ── 3. 难度不影响原始三星总数（倍率仅作用于 get_adjusted_total_stars，已由 test_difficulty_enhanced 覆盖）──
	s.observation_score = s.max_observation
	s.reasoning_score = s.max_reasoning
	s.insight_score = s.max_insight
	if DifficultyManager != null:
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
		if s.get_total_stars() != 9:
			ok = false; msg = "原始总星(HARD下)应恒为9，实得 %d" % s.get_total_stars()
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	# 原始三星总数不受难度影响
	if s.get_total_stars() != 9:
		ok = false; msg = "原始总星应恒为9，实得 %d" % s.get_total_stars()

	if ok:
		print("P1_RESULT: PASS — 评价体系完善（综合等级/简单观察门槛）通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
