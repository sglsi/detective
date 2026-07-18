extends SceneTree

# P5-5 工程治理 — GDScript 单元测试套件（首个针对"真实游戏逻辑"的单元测试）
# 此前 CI 仅含 smoke / 集成 / 数据解析类测试；本套件首次对核心玩法状态机做断言级单元测试。
#
# 被测对象：ClueSystem 的线索五态机（clue_system.gd 中 enum ClueState）
#   UNDISCOVERED=0, DISCOVERED=1, RECORDED=2, ANALYZED=3, LINKED=4
# （注意：reasoning_wall_ui.gd 另有一套同名 ClueState {COLLECTED,VERIFIED,EXPIRED,UNDISCOVERED}，
#   属设计层状态模型不一致，已在验证报告中作为新发现记录；本测试只针对 clue_system.gd 的五态机。）
#
# 覆盖断言（共 12 项）：
#   T1 discover → DISCOVERED 且 get_discovered_count 自 0 增至 1
#   T2 重复 discover 幂等，计数保持 1
#   T3 record → RECORDED
#   T4 link（双已发现）→ LINKED，且 related_clues 双向填充
#   T5 link 单边未发现时 guard 不生效（状态保持）
#   T6 get_clue_states / restore_clue_states 往返一致（状态与计数）
#
# 用法（godot_project 目录下）：
#   godot --headless --script res://tools/p5_5_clue_state_unit_test.gd
# 成功哨兵：CLUE_STATE_UNIT_OK

# 镜像 clue_system.gd 的 ClueState 枚举整数值（避免与 ReasoningWallUI.ClueState 同名冲突）
const S_UNDISCOVERED := 0
const S_DISCOVERED   := 1
const S_RECORDED     := 2
const S_ANALYZED     := 3
const S_LINKED       := 4

var started := false
var failures: Array[String] = []


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	await run_test()
	return false


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("  ✗ " + msg)
	else:
		print("  ✓ " + msg)


func run_test() -> void:
	var cs = root.get_node_or_null("/root/ClueSystem")
	if cs == null:
		print("CLUE_STATE_UNIT_FAIL: 无法获取 ClueSystem 单例")
		quit()
		return

	# 以干净内存态起步（每个 --script 为独立进程，此处仅作防御性隔离）
	cs.discovered_clues.clear()
	cs.clue_count = 0

	# T1: discover → DISCOVERED，计数自 0 增至 1
	cs.discover_clue("clue_rache")
	check(cs.discovered_clues.has("clue_rache"), "T1 discover 后线索进入已发现集合")
	check(cs.discovered_clues["clue_rache"].state == S_DISCOVERED, "T1 状态 = DISCOVERED(1)")
	check(cs.get_discovered_count() == 1, "T1 已发现计数 = 1")

	# T2: 幂等 discover 不重复计数
	cs.discover_clue("clue_rache")
	check(cs.get_discovered_count() == 1, "T2 重复 discover 计数仍为 1（幂等）")

	# T3: record → RECORDED
	cs.record_clue("clue_rache")
	check(cs.discovered_clues["clue_rache"].state == S_RECORDED, "T3 record 后状态 = RECORDED(2)")

	# T4: link（双已发现）→ LINKED + related_clues 双向填充
	cs.discover_clue("clue_ring")
	cs.link_clues("clue_rache", "clue_ring")
	check(cs.discovered_clues["clue_rache"].state == S_LINKED, "T4 链接后 clue_rache 状态 = LINKED(4)")
	check(cs.discovered_clues["clue_ring"].state == S_LINKED, "T4 链接后 clue_ring 状态 = LINKED(4)")
	check("clue_ring" in cs.discovered_clues["clue_rache"].related_clues, "T4 related_clues 双向：rache→ring")
	check("clue_rache" in cs.discovered_clues["clue_ring"].related_clues, "T4 related_clues 双向：ring→rache")

	# T5: link 单边未发现 → guard 不生效（状态保持，不抛错）
	cs.discovered_clues.erase("clue_footprint")  # 防御：确保 footprint 未被发现
	var before_link: int = cs.discovered_clues["clue_rache"].state
	cs.link_clues("clue_rache", "clue_footprint")
	check(cs.discovered_clues["clue_rache"].state == before_link, "T5 单边未发现时 link 不生效（guard）")

	# T6: get_clue_states / restore_clue_states 往返一致
	var states: Dictionary = cs.get_clue_states()
	var snapshot_count: int = states.size()
	cs.discovered_clues.clear()
	cs.clue_count = 0
	check(not cs.discovered_clues.has("clue_rache"), "T6 清空后内存态为空")
	cs.restore_clue_states(states)
	check(cs.discovered_clues.has("clue_rache"), "T6 restore 后线索恢复")
	check(cs.discovered_clues["clue_rache"].state == S_LINKED, "T6 restore 后状态保持 LINKED(4)")
	check(cs.get_discovered_count() == snapshot_count, "T6 restore 后计数与快照一致 (%d)" % snapshot_count)

	if failures.is_empty():
		print("CLUE_STATE_UNIT_OK — 线索五态机状态转移与存档往返全部通过（%d 断言）" % 12)
	else:
		print("CLUE_STATE_UNIT_FAIL: " + str(failures))
	quit()
