extends SceneTree
## v4.0 三星评价系统单测：逐链三维离散（各 1-3⭐），聚合=链之和，满星=链数×9。
## 运行：godot --headless --script res://tools/test_star_rating.gd --path <godot_project>

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

	# 单链最低：obs1+rea1+ins1 = 3⭐
	s.submit_chain("c1", 1, 1, 1)
	if s.get_total_stars() != 3:
		ok = false; msg = "单链 1/1/1 期望总星 3，实得 %d" % s.get_total_stars()
	if s.get_chain_total("c1") != 3:
		ok = false; msg = "c1 链总星应 3，实得 %d" % s.get_chain_total("c1")
	if s.get_max_total_stars() != 9:
		ok = false; msg = "单链满星应 9，实得 %d" % s.get_max_total_stars()

	# 单链满星覆盖：obs3+rea3+ins3 = 9⭐
	s.submit_chain("c1", 3, 3, 3)
	if s.get_total_stars() != 9:
		ok = false; msg = "c1 满星期望 9，实得 %d" % s.get_total_stars()

	# 双链聚合：c1(9) + c2(2,2,2=6) → 15，满星 18
	s.submit_chain("c2", 2, 2, 2)
	if s.get_total_stars() != 15:
		ok = false; msg = "双链聚合期望 15，实得 %d" % s.get_total_stars()
	if s.get_max_total_stars() != 18:
		ok = false; msg = "双链满星应 18，实得 %d" % s.get_max_total_stars()

	# 维度聚合（c1=3/3/3, c2=2/2/2 → 观察=5）
	if s.get_stars(s.RatingDimension.OBSERVATION) != 5:
		ok = false; msg = "观察聚合应 5，实得 %d" % s.get_stars(s.RatingDimension.OBSERVATION)

	# 空 chain_id 不计入分（避免场景一·华生/信使墙相互覆盖）
	s.submit_chain("", 3, 3, 3)
	if s.get_chain_count() != 2:
		ok = false; msg = "空 chain_id 不应计入，链数应 2，实得 %d" % s.get_chain_count()

	# 越界值被夹取到 1-3
	s.submit_chain("c3", 9, 0, -1)
	var c3 = s.get_chain_stars("c3")
	if c3["observation"] != 3 or c3["reasoning"] != 1 or c3["insight"] != 1:
		ok = false; msg = "越界值未夹取：%s" % str(c3)

	if ok:
		print("P1_RESULT: PASS — v4.0 三星评价（逐链离散/聚合/满星/夹取）通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
