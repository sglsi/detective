extends SceneTree
# 阶段0验证：案件级大墙的数据底座
#  - 全案线索池应包含跨场景线索（garden 场景二 + indoor 场景三）
#  - 每条线索含 content/attribute/relation_tags 三级标签数组
#  - 观察星按「本场景已收集条数」计，不受全案池扩大抬高
#  - _local_clue_count 正确解耦

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var root := get_root()
	var RW = load("res://scripts/clue/reasoning_wall.gd")
	var wall = RW.new()
	root.add_child(wall)

	# 模拟 ClueSystem.get_collected("")：场景二(garden) + 场景三(indoor) 跨场景线索，各带三级标签
	var garden := [
		{"id":"c201","name":"车轮印","desc":"双轮马车辙","correct":true,"source":"garden","weight":5,
		 "content_tags":["车轮印"],"attribute_tags":["直接物证"],"relation_tags":["h_murder"]},
		{"id":"c202","name":"两组脚印","desc":"不同鞋印","correct":true,"source":"garden","weight":5,
		 "content_tags":["脚印"],"attribute_tags":["直接物证"],"relation_tags":["h_murder"]},
	]
	var indoor := [
		{"id":"c301","name":"尸体","desc":"死者面部","correct":true,"source":"indoor","weight":5,
		 "content_tags":["尸体"],"attribute_tags":["直接物证"],"relation_tags":["h_murder"]},
	]
	var pool := garden + indoor   # 全案池（3 条，跨 2 场景）

	# 案件级大墙打开：传全案池 + local_count=本场景(garden)已收集=2
	var hypo := {"title":"凶手是谁", "description":"d", "expected_clues":2}
	wall.setup(pool, hypo, func(v): pass, Callable(), 1, Callable(), {}, Callable(), true, 2)

	var ok := true
	var msgs := []

	# 断言1：全案池含跨场景线索
	var sources := {}
	for c in wall._clues:
		sources[c.get("source", "")] = true
	if not (sources.has("garden") and sources.has("indoor")):
		ok = false; msgs.append("P0_A_FAIL: 全案池缺跨场景线索 sources=%s" % [sources])

	# 断言2：三级标签字段存在且为数组
	var tags_ok := true
	for c in wall._clues:
		if not (c.has("content_tags") and c["content_tags"] is Array
				and c.has("attribute_tags") and c["attribute_tags"] is Array
				and c.has("relation_tags") and c["relation_tags"] is Array):
			tags_ok = false
	if not tags_ok:
		ok = false; msgs.append("P0_B_FAIL: 线索缺三级标签字段")

	# 断言3：观察星按本场景条数(local=2==expected=2 → 3星)，不被全案池(3条)抬高
	wall._state_ctl._update_star_rating()
	var obs_star: int = wall._last_stars.get("observation", 0)
	if obs_star != 3:
		ok = false; msgs.append("P0_C_FAIL: 观察星应为3(本场景满收)，实际=%d" % obs_star)

	# 断言4：_local_clue_count 解耦正确
	if wall._local_clue_count != 2:
		ok = false; msgs.append("P0_D_FAIL: _local_clue_count 应为2，实际=%d" % wall._local_clue_count)

	# 断言5：_expected_clues 取本场景值(2)，不被全案池(3)覆盖
	if wall._expected_clues != 2:
		ok = false; msgs.append("P0_E_FAIL: _expected_clues 应为2，实际=%d" % wall._expected_clues)

	if ok:
		print("PHASE0_RESULT: PASS  (全案池含 garden+indoor / 三级标签齐全 / 观察星3 / local=2 / expected=2)")
	else:
		for m in msgs: print(m)
		print("PHASE0_RESULT: FAIL")
	quit(0)
