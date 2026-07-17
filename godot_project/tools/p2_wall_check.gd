extends Node

## P2 推理墙校验：真实线索五态机 + 假设五态机 + 红线推理链可视化
## 作为主场景运行：godot --headless --path . tools/p2_wall_check.tscn

var _failed: bool = false

func _fail(m: String) -> void:
	_failed = true
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _ready() -> void:
	print("=== P2 推理墙校验（五态机 + 红线可视化）===")
	var wall = get_node_or_null("ReasoningWall")
	if wall == null:
		_fail("找不到 ReasoningWall 节点")
		_finish()
		return

	# 1) 假设树已构建（核心 + 3 主 + 子假设 + 排除）
	if wall._hypotheses.size() >= 8:
		_pass("假设树已构建：%d 个节点（核心/主/子/排除）" % wall._hypotheses.size())
	else:
		_fail("假设树节点数 %d < 8" % wall._hypotheses.size())

	# 2) 调试演练：发现线索→关联正确假设→错置干扰→验证
	var r = wall.debug_exercise()
	print("  debug_exercise 返回: %s" % r)

	# 3) 主假设验证结果为 VERIFIED
	if r["primary_result"] == ReasoningWallUI.VerifyResult.VERIFIED:
		_pass("主假设验证结果 = VERIFIED（已确认）")
	else:
		_fail("主假设验证结果应为 VERIFIED，实际 %d" % r["primary_result"])

	# 4) 主假设五态机推进到 CONFIRMED
	if r["primary_state"] == ReasoningWallUI.HypothesisState.CONFIRMED:
		_pass("主假设五态机 = CONFIRMED（已确认）")
	else:
		_fail("主假设状态应为 CONFIRMED，实际 %d" % r["primary_state"])

	# 5) 红线（矛盾）可视化：干扰线索错置到正确假设应生成红虚线
	if r["red_lines"] >= 1:
		_pass("红线（矛盾）连线已生成：%d 条" % r["red_lines"])
	else:
		_fail("未生成红线（矛盾）连线")

	# 6) 支持线索生成绿实线（结构线 + 支持线合并计数）
	if r["line_count"] >= r["red_lines"] + 3:
		_pass("推理链连线总数 = %d（含结构线/支持绿实线/矛盾红线）" % r["line_count"])
	else:
		_fail("推理链连线总数 %d 过少" % r["line_count"])

	# 7) 线索四态机：支持线索被标记为 VERIFIED
	var verified_clues = 0
	for cid in r["clue_states"]:
		if r["clue_states"][cid] == ReasoningWallUI.ClueState.VERIFIED:
			verified_clues += 1
	if verified_clues >= 5:
		_pass("线索四态机：%d 条支持线索标记为 VERIFIED" % verified_clues)
	else:
		_fail("VERIFIED 线索数 %d < 5" % verified_clues)

	_finish()

func _finish() -> void:
	if _failed:
		print("\n💥 P2 推理墙校验失败")
		get_tree().quit(1)
	else:
		print("\n🎉 P2 推理墙校验通过")
		get_tree().quit(0)
