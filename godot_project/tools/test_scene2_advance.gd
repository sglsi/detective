extends SceneTree
## 头less 复现：场景二 观察→推理→提交验证→是否推进到过渡对话
## 运行：godot --headless --script res://tools/test_scene2_advance.gd

var _passc := 0
var _failc := 0

func _chk(c: bool, n: String) -> void:
	if c:
		print("[PASS] " + n); _passc += 1
	else:
		print("[FAIL] " + n); _failc += 1

func _initialize() -> void:
	await create_timer(0.1).timeout   # 等 autoload 就绪
	var s2 = load("res://scripts/scene/scene2.gd").new()
	root.add_child(s2)
	await create_timer(0.1).timeout

	# 1) 直接进入勘察阶段（绕过抵达/警长对话的点击推进）
	s2._on_arrival_ended()
	await create_timer(0.05).timeout
	s2._on_detective_ended()
	await create_timer(0.05).timeout
	_chk(s2._phase == 2, "进入 OBSERVE 阶段(phase=2)")  # Phase.OBSERVE == 2

	# 2) 模拟收集完所有线索 → 触发 _on_all_done（与真实 all_recorded 回调一致）
	#    注意：scene2._on_observe_complete 内含 2.5s await 才进推理，需等够
	s2._on_all_done([])
	await create_timer(3.0).timeout
	_chk(s2._phase == 3, "观察完成进入 REASONING(phase=3)")  # Phase.REASONING==3

	# 3) 玩家点「思考」打开推理墙（先模拟已收集满线索，否则 _open_wall 提前返回）
	s2._clues = s2.hotspots().duplicate()
	s2._open_wall()
	await create_timer(0.05).timeout
	_chk(s2._wall_instance != null, "推理墙已打开(_wall_instance 非空)")
	_chk(s2._wall_auto == true, "_wall_auto 为 true（推理阶段打开）")

	# 4) 提交验证（模拟点「确定」→ _on_verify_confirm）
	var wall = s2._wall_instance
	wall._on_verify_confirm(3)
	await create_timer(0.05).timeout
	_chk(s2._phase == 4, "提交验证后进入 TRANSITION(phase=4)")  # Phase.TRANSITION==4
	_chk(s2._dm != null and s2._dm.is_active(), "过渡对话已激活(_dm.is_active)")

	# 5) 等到推理墙 queue_free 真正生效，检查过渡对话是否可被点击推进（不被 _advance_blocked 拦死）
	await create_timer(0.2).timeout
	_chk(s2._wall_instance == null, "推理墙已销毁(_wall_instance 已清空)")
	var blocked: bool = s2._advance_blocked(false)
	_chk(blocked == false, "_advance_blocked(false) 不拦截（过渡对话可推进）")
	var blocked_m: bool = s2._advance_blocked(true)
	_chk(blocked_m == false, "_advance_blocked(true) 不拦截（点击可推进）")

	# 6) 模拟点击推进过渡对话一次，确认能 advance
	if s2._dm and s2._dm.is_active():
		var before = s2._dm.current_node.node_id
		s2._dm.advance()
		await create_timer(0.05).timeout
		var after = s2._dm.current_node.node_id if s2._dm.current_node else "(ended)"
		_chk(before != after, "过渡对话可点击推进 (%s -> %s)" % [before, after])

	print("=== 场景二推进复现结果: PASS=%d FAIL=%d ===" % [_passc, _failc])
	if _failc > 0:
		print("SCENE2_ADVANCE_RESULT: FAIL")
	else:
		print("SCENE2_ADVANCE_RESULT: PASS")
	quit()
