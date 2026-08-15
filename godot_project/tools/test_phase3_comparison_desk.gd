extends SceneTree
# 阶段3验证：线索对比台 + 矛盾疑点册
#  - _detect_contradiction：两条线索共享矛盾标签(C 前缀)即判定为矛盾
#  - _load_comparison 入槽（最多 2，溢出轮替）
#  - _on_compare_pressed 触发后写入 _doubt_book 并标记战场矛盾已识别
#  - 对比台 UI（_build_comparison_desk）构建不报错，_refresh_desk 刷新槽位/疑点册
#  - 疑点册跨重开持久化（persist=true 经 _state_store）

func _initialize() -> void:
	await create_timer(0.2).timeout
	var RW = load("res://scripts/clue/reasoning_wall.gd")
	if not RW:
		print("PHASE3_RESULT: FAIL - 无法加载 reasoning_wall.gd")
		quit(1)
		return

	var wall = RW.new()
	wall.name = "Phase3Wall"
	root.add_child(wall)

	# 一对共享 C-06 的矛盾线索（c309 血字指甲未修剪 ↔ c301 死者指甲干净）
	var clues := [
		{"id":"c301","name":"死者指甲干净","desc":"d","correct":true,"source":"indoor","associated":true,"relation_tags":["H3-01","C-06"]},
		{"id":"c309","name":"血字RACHE","desc":"d","correct":true,"source":"indoor","associated":true,"relation_tags":["H3-02","H3-03","H3-04","C3-03","C-06"]},
		{"id":"c312","name":"女式戒指","desc":"d","correct":true,"source":"indoor","associated":true,"relation_tags":["C3-04"]},
	]
	var hypo := {"title":"t","description":"d",
		"battlefield":{"hypotheses":[{"id":"H3-01","text":"服毒","correct":true}],
			"contradictions":[{"id":"C-06","text":"死者指甲干净 vs 血字有指甲刮痕→血字是凶手写的","correct":true}]}}
	var store: Dictionary = {}
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable(), store, Callable(), true, 3)

	var ok := true
	var msgs := []

	# 断言1：检测共享矛盾标签
	var hits: Array = wall._detect_contradiction(clues[0], clues[1])
	if not (hits.has("C-06") and hits.size() == 1):
		ok = false; msgs.append("P3_A_FAIL: 检测应命中 [C-06], got=%s" % [hits])
	# 不共享矛盾标签的两条不应判定
	var nohit: Array = wall._detect_contradiction(clues[0], clues[2])
	if not nohit.is_empty():
		ok = false; msgs.append("P3_B_FAIL: c301 与 c312 不应有矛盾, got=%s" % [nohit])

	# 断言2：入槽轮替（最多2）
	wall._load_comparison("c301")
	wall._load_comparison("c309")
	wall._load_comparison("c312")   # 溢出：c301 被轮替出，槽=[c309, c312]
	if wall._compare_slots.size() != 2:
		ok = false; msgs.append("P3_C_FAIL: 槽位应恒为2, got=%d" % wall._compare_slots.size())
	if wall._compare_slots[0].get("id","") != "c309" or wall._compare_slots[1].get("id","") != "c312":
		ok = false; msgs.append("P3_D_FAIL: 轮替后应为 [c309,c312], got=%s" % [wall._compare_slots])

	# 断言3：比对触发 → 写入疑点册 + 标记战场矛盾
	wall._compare_slots = []        # 清空（等价「清空」按钮），再装入矛盾对
	wall._load_comparison("c309")   # 血字：指甲未修剪（C-06）
	wall._load_comparison("c301")   # 死者指甲干净（C-06）
	wall._on_compare_pressed()
	if wall._doubt_book.is_empty():
		ok = false; msgs.append("P3_E_FAIL: 比对后应写入疑点册")
	else:
		var rec: Dictionary = wall._doubt_book[0]
		if rec.get("cid","") != "C-06":
			ok = false; msgs.append("P3_F_FAIL: 疑点册 cid 应为 C-06, got=%s" % rec)
	if not wall._battle_contra_states.get("C-06", false):
		ok = false; msgs.append("P3_G_FAIL: 战场矛盾 C-06 应标记已识别")

	# 断言4：无矛盾比对不报错、不入册
	wall._load_comparison("c301")
	wall._load_comparison("c312")
	var before: int = wall._doubt_book.size()
	wall._on_compare_pressed()
	if wall._doubt_book.size() != before:
		ok = false; msgs.append("P3_H_FAIL: 无矛盾比对不应新增疑点")

	# 断言5：对比台 UI 构建 + 刷新不报错
	if wall._comparison_desk == null:
		ok = false; msgs.append("P3_I_FAIL: 对比台 UI 未构建")
	wall._refresh_desk()

	# 断言6：疑点册持久化（store 应含 doubt_book）
	if not store.has("doubt_book") or (store["doubt_book"] as Array).is_empty():
		ok = false; msgs.append("P3_J_FAIL: 疑点册未持久化到 _state_store")

	if ok:
		print("PHASE3_RESULT: PASS  (对比台+疑点册：共享C标签即矛盾；入槽轮替；触发写入并标记战场；持久化OK)")
	else:
		for m in msgs: print(m)
		print("PHASE3_RESULT: FAIL")
	quit(0)
