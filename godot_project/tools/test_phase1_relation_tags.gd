extends SceneTree
# 阶段1验证：relation_tags 驱动的「线索→假设」精确匹配
#  - 线索只出现在其 relation_tags 命中的假设节点证据行，不污染其它节点
#  - 未关联线索（associated=false）不作为任何假设证据
#  - 仅挂矛盾标记 id（非假设节点）的线索不出现在假设证据行
#  - 替换原退化逻辑（relation_tags 为空则全量罗列）后，匹配严格由标签决定

func _initialize() -> void:
	await create_timer(0.2).timeout
	var RW = load("res://scripts/clue/reasoning_wall.gd")
	if not RW:
		print("PHASE1_RESULT: FAIL - 无法加载 reasoning_wall.gd")
		quit(1)
		return

	var wall = RW.new()
	wall.name = "Phase1Wall"
	root.add_child(wall)

	var clues := [
		# 假设节点 H-A / H-B 的精确匹配
		{"id":"c1","name":"车轮印","desc":"双轮马车辙","correct":true,"source":"garden","associated":true,"relation_tags":["H-A"]},
		{"id":"c2","name":"两组脚印","desc":"不同鞋印","correct":true,"source":"garden","associated":true,"relation_tags":["H-A","H-B"]},
		{"id":"c3","name":"血字RACHE","desc":"复仇血字","correct":true,"source":"indoor","associated":true,"relation_tags":["H-B"]},
		# 未关联线索：即便 relation_tags 命中 H-A，也不应作为证据
		{"id":"c4","name":"未关联线索","desc":"未关联","correct":true,"source":"indoor","associated":false,"relation_tags":["H-A"]},
		# 仅挂矛盾标记（非假设节点）：不应出现在任何假设证据行
		{"id":"c5","name":"新蹄铁","desc":"一新三旧","correct":true,"source":"garden","associated":true,"relation_tags":["C-X"]},
	]
	var hypo := {
		"title": "阶段1测试假设",
		"description": "d",
		"battlefield": {
			"hypotheses": [
				{"id":"H-A","text":"乘马车来","correct":true},
				{"id":"H-B","text":"血字是德语","correct":true},
			],
			"contradictions": [],
		},
	}
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable())

	var ok := true
	var msgs := []

	var eA: Array = wall._evidence_for_hypothesis("H-A")
	var eB: Array = wall._evidence_for_hypothesis("H-B")

	# 断言1：H-A 仅含 c1（车轮印），不含 c3（血字）
	if not (eA.has("车轮印") and not eA.has("血字RACHE")):
		ok = false; msgs.append("P1_A_FAIL: H-A 证据应含[车轮印]不含[血字RACHE], got=%s" % [eA])

	# 断言2：H-B 含 c2(两组脚印) 与 c3(血字RACHE)，不含 c1(车轮印)
	if not (eB.has("两组脚印") and eB.has("血字RACHE") and not eB.has("车轮印")):
		ok = false; msgs.append("P1_B_FAIL: H-B 证据应含[两组脚印,血字RACHE]不含[车轮印], got=%s" % [eB])

	# 断言3：未关联线索 c4 不出现
	if eA.has("未关联线索") or eB.has("未关联线索"):
		ok = false; msgs.append("P1_C_FAIL: 未关联线索不应作为证据")

	# 断言4：矛盾标记线索 c5 不出现在任何假设证据行
	if eA.has("新蹄铁") or eB.has("新蹄铁"):
		ok = false; msgs.append("P1_D_FAIL: 矛盾标记线索不应出现在假设证据行")

	# 断言5（回归守卫）：collect_clue_from_catalog 的 11 参签名里 relation_tags 必须在第 11 位。
	# 若位置错配（曾踩坑：9 参时 relation_tags 落到 content_tags 槽），推理墙将看不到标签。
	var CS = Engine.get_singleton("ClueSystem")
	if CS != null:
		CS.clear_source("__phase1_guard")
		CS.collect_clue_from_catalog("g1", "守卫线索", "d", true, "__phase1_guard", -1, "", "", [], [], ["H-GUARD"])
		var stored: Array = CS.get_collected("__phase1_guard")
		var found: Dictionary = {}
		for c in stored:
			if c.get("id", "") == "g1": found = c
		if found.is_empty() or found.get("relation_tags", []) != ["H-GUARD"]:
			ok = false; msgs.append("P1_E_FAIL: relation_tags 未正确存入第11位, got=%s" % [found])
		if not found.is_empty() and found.get("content_tags", []) == ["H-GUARD"]:
			ok = false; msgs.append("P1_F_FAIL: relation_tags 错落入 content_tags（位置错配）")
		CS.clear_source("__phase1_guard")
	else:
		msgs.append("P1_WARN: 无法获取 ClueSystem 单例，跳过收集端守卫（仅校验墙体显示端）")

	if ok:
		print("PHASE1_RESULT: PASS  (标签驱动精确匹配：c1→H-A / c2→H-A,H-B / c3→H-B；未关联与矛盾标记不污染)")
	else:
		for m in msgs: print(m)
		print("PHASE1_RESULT: FAIL")
	quit(0)
