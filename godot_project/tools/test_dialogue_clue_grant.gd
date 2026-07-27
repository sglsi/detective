extends SceneTree
# P3-0 回归测试：验证 DialogueManager 的 trigger=="clue" 分支经 ClueSystem 真正收集线索，
# 且与观察器路径共用同一漏斗（单一真相源）、幂等。
#
# 覆盖：
#   1. 进入 trigger=="clue" 节点时，grants_clues 中每条线索经 ClueSystem 真实登记；
#   2. correct 字段正确透传（含误导项 correct=false，不被 .tres 目录覆盖——因合成 id 不在目录）；
#   3. 幂等：再次进入同一 clue 节点，已收集线索数不增加（collect_clue 按 id 去重）；
#   4. 与观察器路径共用同一 ClueSystem 漏斗：观察器侧 collect_clue_from_catalog 落入同一 source，
#      且不产生重复条目（单一真相源不被破坏）。
#
# 哨兵：P1_RESULT: PASS / FAIL
# 用法（godot_project 目录下，需本机 Godot）：
#   godot --headless --script res://tools/test_dialogue_clue_grant.gd

var _ok := true
var _failures: Array = []

func _process(_delta: float) -> bool:
	_run()
	if _ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL")
		for f in _failures:
			print("  - " + f)
	quit()
	return false

func _fail(msg: String) -> void:
	_ok = false
	_failures.append(msg)
	push_error("[dialogue_clue_grant] " + msg)

func _run() -> void:
	var cs = root.get_node_or_null("/root/ClueSystem")
	if cs == null:
		_fail("ClueSystem 单例缺失（autoload 未注册？）")
		return

	# 清场，保证计数/幂等断言基线干净
	cs.clear_collected()

	var SOURCE := "dlg_clue_test"

	var dm := DialogueManager.new()
	root.add_child(dm)

	# 构造对话资源：a(auto) -> c(clue, grants 2 条) -> end
	var res := DialogueResource.new()
	res.scene_name = SOURCE
	res.scene_id = "test"
	res.phase_id = "P"

	var clue_a = {"id": "C_DLGTEST_001", "name": "线索甲", "desc": "甲之描述", "correct": true}
	var clue_b = {"id": "C_DLGTEST_002", "name": "线索乙", "desc": "乙之描述", "correct": false}  # 误导项

	var n_a := DialogueNodeResource.new()
	n_a.node_id = "a"; n_a.speaker = "sys"; n_a.text = "a"
	n_a.trigger = "auto"; n_a.next_nodes = ["c"]

	var n_c := DialogueNodeResource.new()
	n_c.node_id = "c"; n_c.speaker = "sys"; n_c.text = "c"
	n_c.trigger = "clue"; n_c.next_nodes = ["end"]
	n_c.grants_clues = [clue_a, clue_b]

	var n_end := DialogueNodeResource.new()
	n_end.node_id = "end"; n_end.speaker = "sys"; n_end.text = "end"
	n_end.trigger = "auto"; n_end.next_nodes = []

	res.nodes = [n_a, n_c, n_end]
	res.easy_start_node = "a"; res.normal_start_node = "a"; res.hard_start_node = "a"

	dm.dialogue_resource = res
	dm.set_difficulty(1)        # NORMAL
	dm.start_dialogue()

	# 起始节点应为 a
	if dm.current_node == null:
		_fail("start_dialogue 后 current_node 为 null（节点不存在或 _go_to_node 失败）")
		dm.queue_free()
		return
	if dm.current_node.node_id != "a":
		_fail("起始节点应为 a，实际=%s" % dm.current_node.node_id)
		dm.queue_free()
		return

	# 手动推进到 c（不依赖 0.15s 自动推进计时器，保证确定性）
	dm.advance()
	if dm.current_node == null or dm.current_node.node_id != "c":
		_fail("advance 后未进入 clue 节点 c（实际=%s）" % (dm.current_node.node_id if dm.current_node else "null"))
		dm.queue_free()
		return

	# 断言 1：c 节点进入时确实授予了 2 条线索
	var got = cs.get_collected(SOURCE)
	if got.size() != 2:
		_fail("clue 节点未授予预期 2 条线索，实际=%d" % got.size())
	else:
		var ids: Array = []
		for c in got:
			ids.append(c.get("id", ""))
		if not ("C_DLGTEST_001" in ids and "C_DLGTEST_002" in ids):
			_fail("授予线索 id 不符: %s" % ids)
		# 断言 2：correct 字段正确透传（含误导项 correct=false）
		for c in got:
			if c.get("id") == "C_DLGTEST_002" and c.get("correct") != false:
				_fail("误导项 correct 未透传为 false（实际=%s）" % c.get("correct"))
			if c.get("id") == "C_DLGTEST_001" and c.get("correct") != true:
				_fail("正确项 correct 未透传为 true（实际=%s）" % c.get("correct"))
		# 断言 2b：合成 id 不在目录，name/desc 应取内联文本（目录回退路径）
		for c in got:
			if c.get("id") == "C_DLGTEST_001" and c.get("name") != "线索甲":
				_fail("内联 name 未保留（目录缺失应回退内联），实际=%s" % c.get("name"))
			if c.get("id") == "C_DLGTEST_001" and c.get("desc") != "甲之描述":
				_fail("内联 desc 未保留（目录缺失应回退内联），实际=%s" % c.get("desc"))

	# 断言 3：幂等 —— 再次进入 c 节点，线索数不应增加
	var before = cs.get_collected(SOURCE).size()
	dm.advance_to("c")
	var after = cs.get_collected(SOURCE).size()
	if after != before:
		_fail("重复进入 clue 节点未幂等：%d -> %d" % [before, after])

	# 断言 4：与观察器路径共用同一漏斗 —— 同一 source 下观察器侧 collect 也落入此处，
	#          且不应产生重复 C_DLGTEST_001 / C_DLGTEST_002（单一真相源不被破坏）。
	cs.collect_clue_from_catalog("C_DLGTEST_003", "观察器线索", "obs desc", true, SOURCE)
	var merged = cs.get_collected(SOURCE)
	var merged_ids: Array = []
	for c in merged:
		merged_ids.append(c.get("id", ""))
	if not ("C_DLGTEST_003" in merged_ids):
		_fail("与观察器共用漏斗失败：观察器 collect 未落入同一 source")
	if merged_ids.count("C_DLGTEST_001") != 1 or merged_ids.count("C_DLGTEST_002") != 1:
		_fail("单一真相源被破坏：存在重复线索条目（001=%d 次, 002=%d 次）" % [
			merged_ids.count("C_DLGTEST_001"), merged_ids.count("C_DLGTEST_002")])

	dm.queue_free()
