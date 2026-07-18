extends SceneTree

## P2 推理墙五态机+红线校验（--script 模式）
## godot --headless --path . --script tools/p2_wall_script_check.gd

var _wall: Control = null
var _frame: int = 0
var _failed: bool = false

func _fail(m: String) -> void:
	_failed = true
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _init() -> void:
	print("=== P2 推理墙校验（五态机 + 红线可视化）===")

	# 手动构造最小节点树
	var root_node = get_root()

	var wall = Control.new()
	wall.name = "ReasoningWall"

	var clue_panel = Control.new()
	clue_panel.name = "CluePanel"
	wall.add_child(clue_panel)

	var board_area = Control.new()
	board_area.name = "BoardArea"
	wall.add_child(board_area)

	var board_label = Label.new()
	board_label.name = "BoardLabel"
	board_label.text = "推理板"
	board_area.add_child(board_label)

	var verify_button = Button.new()
	verify_button.name = "VerifyButton"
	verify_button.text = "验证推理"
	wall.add_child(verify_button)

	var result_label = Label.new()
	result_label.name = "ResultLabel"
	wall.add_child(result_label)

	var milestone_popup = Panel.new()
	milestone_popup.name = "MilestonePopup"
	var ms_label = Label.new()
	ms_label.name = "Label"
	milestone_popup.add_child(ms_label)
	wall.add_child(milestone_popup)

	root_node.add_child(wall)

	# 加载并设置脚本
	var wall_script = load("res://scripts/clue/reasoning_wall_ui.gd")
	if wall_script == null:
		_fail("无法加载 ReasoningWallUI 脚本")
		_finish()
		return

	wall.set_script(wall_script)
	_wall = wall

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		# 此时 _ready 和 @onready 已经执行完毕
		_run_checks()
	return false

func _run_checks() -> void:
	if _wall == null:
		_fail("_wall 为 null")
		_finish()
		return

	# 1) 假设树已构建
	var hypotheses = _wall.get("_hypotheses")
	if hypotheses != null and hypotheses.size() >= 8:
		_pass("假设树已构建：%d 个节点（核心/主/子/排除）" % hypotheses.size())
	else:
		_fail("假设树节点数不足：%s" % str(hypotheses.size() if hypotheses else "null"))

	# 2) 调试演练
	var r = _wall.debug_exercise()
	print("  debug_exercise 返回:")
	for k in r:
		print("    %s = %s" % [k, r[k]])

	# 3) 主假设验证结果为 VERIFIED
	var primary_result = r.get("primary_result", -1)
	if primary_result == 0:  # VerifyResult.VERIFIED = 0
		_pass("主假设验证结果 = VERIFIED（已确认）")
	else:
		_fail("主假设验证结果应为 VERIFIED(0)，实际 %d" % primary_result)

	# 4) 主假设五态机推进到 CONFIRMED
	var primary_state = r.get("primary_state", -1)
	if primary_state == 3:  # HypothesisState.CONFIRMED = 3
		_pass("主假设五态机 = CONFIRMED（已确认）")
	else:
		_fail("主假设状态应为 CONFIRMED(3)，实际 %d" % primary_state)

	# 5) 红线（矛盾）可视化
	var red_lines = r.get("red_lines", 0)
	if red_lines >= 1:
		_pass("红线（矛盾）连线已生成：%d 条" % red_lines)
	else:
		_fail("未生成红线（矛盾）连线")

	# 6) 连线总数
	var line_count = r.get("line_count", 0)
	if line_count >= red_lines + 3:
		_pass("推理链连线总数 = %d（含结构线/支持绿实线/矛盾红线）" % line_count)
	else:
		_fail("推理链连线总数 %d 过少（期望 >= %d）" % [line_count, red_lines + 3])

	# 7) 线索四态机：支持线索标记为 VERIFIED
	var clue_states = r.get("clue_states", {})
	var verified_clues = 0
	for cid in clue_states:
		if clue_states[cid] == 2:  # WallClueState.VERIFIED = 2
			verified_clues += 1
	if verified_clues >= 5:
		_pass("线索四态机：%d 条支持线索标记为 VERIFIED" % verified_clues)
	else:
		_fail("VERIFIED 线索数 %d < 5" % verified_clues)

	_finish()

func _finish() -> void:
	if _failed:
		print("\n💥 P2 推理墙校验失败")
		quit(1)
	else:
		print("\n🎉 P2 推理墙校验通过")
		quit(0)
