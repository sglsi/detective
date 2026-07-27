extends SceneTree

# P3.1 线索分级加权评分测试（--script 模式）
# 验证「把设计的线索等级在运行时落地」这一机制：
#   1. 目录（.tres）线索权重取 importance（wrist importance=10 → 权重10、等级"关键"）；
#   2. 误导项（correct==false）权重恒为 0、等级"误导"，且 inline_weight 也无法改变；
#   3. 内联线索（无 .tres）用 inline_weight 提供权重；缺省回退 2（一般）；
#   4. total_weight(source) 正确合计；按 id 去重幂等，重复收集不叠加权重。
#
# 用法（godot_project 目录下，需本机 Godot）：
#   godot --headless --script res://tools/test_clue_tier_weight.gd
# 成功哨兵：P1_RESULT: PASS

var started := false
var failures: Array = []

func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	run_test()
	return false

func run_test() -> void:
	var cs = root.get_node_or_null("/root/ClueSystem")
	if cs == null:
		print("P1_RESULT: FAIL (ClueSystem 单例缺失)")
		quit()
		return

	var SRC := "tier_test"
	cs.clear_collected()

	# —— 1. 目录线索：权重取 .tres importance（wrist=10 → 关键）——
	if cs.get_clue_definition("wrist") == null:
		failures.append("前置缺失：clue_wrist.tres 未预载，无法验证目录权重")
	else:
		cs.collect_clue_from_catalog("wrist", "内联名", "内联desc", true, SRC)
		var w = cs.get_collected(SRC)
		if w.size() != 1:
			failures.append("目录线索未登记")
		else:
			var c = w[0]
			if int(c.get("weight", -1)) != 10:
				failures.append("目录线索权重应=importance(10)，实得 %s" % c.get("weight"))
			if c.get("tier", "") != "关键":
				failures.append("importance10 等级应为'关键'，实得 %s" % c.get("tier"))

	# —— 2. 误导项：correct=false → 权重0、等级"误导"，inline_weight 无法覆盖 ——
	cs.collect_clue_from_catalog("C_TIER_MIS", "误导线索", "d", false, SRC, 10)
	var mis = _find(cs, SRC, "C_TIER_MIS")
	if mis.is_empty():
		failures.append("误导线索未登记")
	else:
		if int(mis.get("weight", -1)) != 0:
			failures.append("误导项权重应为0（不计分），实得 %s" % mis.get("weight"))
		if mis.get("tier", "") != "误导":
			failures.append("误导项等级应为'误导'，实得 %s" % mis.get("tier"))

	# —— 3. 内联线索（无目录）：inline_weight 生效 ——
	cs.collect_clue_from_catalog("C_TIER_INLINE5", "重要内联", "d", true, SRC, 5)
	var i5 = _find(cs, SRC, "C_TIER_INLINE5")
	if int(i5.get("weight", -1)) != 5 or i5.get("tier", "") != "重要":
		failures.append("内联权重5应为'重要'，实得 w=%s tier=%s" % [i5.get("weight"), i5.get("tier")])

	# —— 4. 内联缺省：不传 inline_weight → 回退2（一般）——
	cs.collect_clue_from_catalog("C_TIER_DEFAULT", "缺省内联", "d", true, SRC)
	var idf = _find(cs, SRC, "C_TIER_DEFAULT")
	if int(idf.get("weight", -1)) != 2 or idf.get("tier", "") != "一般":
		failures.append("内联缺省应回退权重2/'一般'，实得 w=%s tier=%s" % [idf.get("weight"), idf.get("tier")])

	# —— 5. total_weight 合计：10(wrist) + 0(误导) + 5 + 2 = 17 ——
	var expect_total := 17
	if cs.get_clue_definition("wrist") == null:
		expect_total = 7  # 若 wrist 缺失则只有 0+5+2
	if cs.total_weight(SRC) != expect_total:
		failures.append("total_weight 期望 %d，实得 %d" % [expect_total, cs.total_weight(SRC)])

	# —— 6. 幂等：重复收集同 id 不叠加权重、不新增条目 ——
	var before_n: int = cs.get_collected(SRC).size()
	var before_w: int = cs.total_weight(SRC)
	cs.collect_clue_from_catalog("C_TIER_INLINE5", "重要内联", "d", true, SRC, 5)
	if cs.get_collected(SRC).size() != before_n:
		failures.append("幂等失败：重复收集新增了条目")
	if cs.total_weight(SRC) != before_w:
		failures.append("幂等失败：重复收集叠加了权重")

	# —— 7. weight_of 纯函数：误导恒0；无目录用 inline；缺省2 ——
	if cs.weight_of("C_NO_SUCH", false, 10) != 0:
		failures.append("weight_of 误导项应为0")
	if cs.weight_of("C_NO_SUCH", true, 5) != 5:
		failures.append("weight_of 无目录应取 inline_weight")
	if cs.weight_of("C_NO_SUCH", true, -1) != 2:
		failures.append("weight_of 缺省应回退2")

	if failures.is_empty():
		print("P1_RESULT: PASS (线索分级加权：importance权重 + 误导0 + 内联/缺省回退 + total_weight + 幂等)")
	else:
		print("P1_RESULT: FAIL")
		for f in failures:
			print("  - " + f)
	quit()

func _find(cs, source: String, id: String) -> Dictionary:
	for c in cs.get_collected(source):
		if c.get("id", "") == id:
			return c
	return {}
