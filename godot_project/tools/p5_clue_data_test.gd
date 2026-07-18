extends SceneTree

# P5-2 线索/案件数据解析测试（--script 模式）
# 验证 ClueSystem / CaseManager 现在真正从 res://data 下的 .tres 资源
# 解析真实线索与案件数据，而非返回空/硬编码。
#
# 覆盖：
#   - load_clue 解析真实 .tres（字段、关键证据标记、关联线索）
#   - get_total_clues 动态等于 data/clues 下 .tres 数量
#   - get_case_list 扫描 data/cases 返回真实案件
#   - load_case 解析出非空 scenes / clues
#
# 用法（godot_project 目录下）：
#   godot --headless --script res://tools/p5_clue_data_test.gd
# 成功哨兵：CLUE_DATA_OK

var started := false
var failures: Array[String] = []


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	await run_test()
	return false


func _count_tres(dir_path: String) -> int:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return -1
	var n = 0
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".tres") and not f.begins_with("."):
			n += 1
		f = dir.get_next()
	dir.list_dir_end()
	return n


func run_test() -> void:
	var cs = root.get_node_or_null("/root/ClueSystem")
	var cm = root.get_node_or_null("/root/CaseManager")

	if cs == null or cm == null:
		print("CLUE_DATA_FAIL: 无法获取 ClueSystem/CaseManager 单例")
		quit()
		return

	# 1. load_clue 解析真实 .tres
	var clue = cs.load_clue("clue_rache")
	if clue == null:
		failures.append("load_clue('clue_rache') 返回 null（未解析到真实 .tres）")
	else:
		if clue.id != "clue_rache":
			failures.append("clue.id 错误: '%s'" % clue.id)
		if clue.name != "墙上的血字RACHE":
			failures.append("clue.name 错误: '%s'" % clue.name)
		if clue.category != "痕迹":
			failures.append("clue.category 错误: '%s'" % clue.category)
		if not clue.is_key_evidence:
			failures.append("clue.is_key_evidence 应为 true")
		if not ("clue_ring" in clue.related_clues and "clue_footprint" in clue.related_clues):
			failures.append("clue.related_clues 内容错误: %s" % str(clue.related_clues))
		if clue.importance != 5:
			failures.append("clue.importance 错误: %d" % clue.importance)
		print("▶ load_clue OK: name=%s category=%s key=%s related=%s"
			% [clue.name, clue.category, clue.is_key_evidence, clue.related_clues])

	# 2. get_total_clues 动态等于 data/clues 下 .tres 数量
	var total = cs.get_total_clues()
	var file_count = _count_tres("res://data/clues/")
	if file_count < 0:
		failures.append("无法打开 data/clues/ 目录")
	elif total != file_count:
		failures.append("get_total_clues()=%d 不等于 data/clues 下 .tres 数 %d" % [total, file_count])
	else:
		print("▶ get_total_clues OK: %d 条（与文件数一致）" % total)

	# 3. get_case_list 扫描真实案件
	var cases = cm.get_case_list()
	if cases.size() < 1:
		failures.append("get_case_list 返回空（未扫描到 data/cases 下的案件）")
	else:
		var found = false
		for c in cases:
			if c.get("title", "") == "血字的研究":
				found = true
		if not found:
			failures.append("get_case_list 未包含 '血字的研究': %s" % str(cases))
		else:
			print("▶ get_case_list OK: %d 个案件，含 '%s'" % [cases.size(), cases[0].get("title", "")])

	# 4. load_case 解析出非空 scenes / clues
	var case = cm.load_case("blood_study")
	if case.is_empty():
		failures.append("load_case('blood_study') 返回空（未解析到真实案件 .tres）")
	elif case.get("scenes", []).size() < 1 or case.get("clues", []).size() < 1:
		failures.append("load_case 解析出的 scenes/clues 为空: %s" % str(case))
	else:
		print("▶ load_case OK: title=%s scenes=%d clues=%d"
			% [case.get("title", ""), case.get("scenes", []).size(), case.get("clues", []).size()])

	# 汇总
	if failures.is_empty():
		print("CLUE_DATA_OK — 线索/案件数据解析接通真实 .tres 资源")
	else:
		print("CLUE_DATA_FAIL: " + str(failures))
	quit()
