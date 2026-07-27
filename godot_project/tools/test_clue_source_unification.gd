extends SceneTree

# P1-3 线索数据源统一测试（--script 模式）
# 验证「统一数据源」机制：
#   1. 运行时线索优先采用 .tres 目录（clue_catalog）的权威 name/description；
#   2. 目录缺失时回退到场景内联文本，保证不开编译也能安全降级；
#   3. correct（推理墙 CONTRADICTORY 判定标志）始终取自内联，不被目录覆盖。
#
# 用法（godot_project 目录下，需本机 Godot）：
#   godot --headless --script res://tools/test_clue_source_unification.gd
# 成功哨兵：P1_RESULT: PASS

var started := false
var failures: Array = []

func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	await run_test()
	return false

func run_test() -> void:
	var cs = root.get_node_or_null("/root/ClueSystem")
	if cs == null:
		print("P1_RESULT: FAIL (ClueSystem 单例缺失)")
		quit()
		return

	# 预置条件：clue_wrist.tres 应已预载进 clue_catalog
	var def = cs.get_clue_definition("wrist")
	if def == null:
		failures.append("clue_catalog 未预载 wrist 定义（clue_wrist.tres 缺失或格式错误）")
	else:
		# 1. 目录优先：name/description 取目录权威文本，而非场景内联
		cs.clear_collected()
		cs.collect_clue_from_catalog("wrist", "内联名", "内联desc", true, "watson")
		var got = cs.get_collected("watson")
		if got.size() != 1:
			failures.append("collect_clue_from_catalog 未登记线索")
		else:
			var c = got[0]
			if c.get("name") != "华生手腕肤色分界":
				failures.append("name 未取目录权威名: 实际=%s" % c.get("name"))
			if c.get("desc") != "华生手腕肤色分界明显——长期暴露于热带阳光":
				failures.append("desc 未取目录权威文本: 实际=%s" % c.get("desc"))
			# 3. correct 必须保持内联值，不覆盖
			if c.get("correct") != true:
				failures.append("correct 被错误覆盖为 %s" % c.get("correct"))

	# 2. 目录缺失项回退内联（安全降级，行为不变）
	cs.clear_collected()
	cs.collect_clue_from_catalog("nonexistent_xyz", "内联名", "内联desc", false, "test")
	var g2 = cs.get_collected("test")
	if g2.size() != 1 or g2[0].get("name") != "内联名" or g2[0].get("desc") != "内联desc":
		failures.append("目录缺失项未回退内联文本")

	if failures.is_empty():
		print("P1_RESULT: PASS (线索数据源统一：目录优先 + 缺失回退 + correct 不覆盖)")
	else:
		print("P1_RESULT: FAIL")
		for f in failures:
			print("  - " + f)
	quit()
