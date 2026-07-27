extends SceneTree
## P1-4 补充单测：三星评价系统（star_rating_system.gd）
## 三维独立评定，各维按占比给 0-3 星；总分=三维之和（满分 9）。
## 运行：godot --headless --script res://tools/test_star_rating.gd --path <godot_project>
## 未经 Godot 实跑验证（环境 shell 被沙箱拦截），请本地运行确认。

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var s = load("res://autoload/star_rating_system.gd").new()
	var ok := true
	var msg := ""

	# 部分加分：obs 2/满分（<30%）、rea 1/14、ins 3/7 → 各维星数 0/0/1 → 总分 1
	# P3.1：观察力改为加权评分，满分基数不再是 45；此处用极小观察分保证 0 星，断言与满分基数解耦。
	s.add_observation(2)
	s.add_reasoning(1)
	s.add_insight(3)
	if s.get_total_stars() != 1:
		ok = false
		msg = "部分加分期望总分 1，实得 %d" % s.get_total_stars()

	# 满分：三维各自置顶（用各维满分基数，不写死数字）→ 9 星
	s.observation_score = s.max_observation
	s.reasoning_score = s.max_reasoning
	s.insight_score = s.max_insight
	if s.get_total_stars() != 9:
		ok = false
		msg = "满分期望 9 星，实得 %d" % s.get_total_stars()

	# 单维星级边界：insight 7/7=1.0 → 3 星
	if s.get_stars(s.RatingDimension.INSIGHT) != 3:
		ok = false
		msg = "insight 满分应 3 星，实得 %d" % s.get_stars(s.RatingDimension.INSIGHT)

	if ok:
		print("P1_RESULT: PASS — 三星评价系统逻辑通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
