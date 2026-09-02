extends SceneTree
## 驱动 scene2 完整流程，定位「提交验证后不推进」的真实断点
## godot --headless --script res://tools/test_scene2_flow.gd --path <godot_project>

func _initialize() -> void:
	await create_timer(0.1).timeout
	var s = load("res://scenes/scene2.tscn").instantiate()
	root.add_child(s)
	await create_timer(0.05).timeout   # 等 _ready 完成

	# 模拟已收集 6 条线索（让推理墙能打开）
	for i in range(6):
		s._clues.append({"id": "S2-%d" % i, "name": "线索%d" % i, "desc": "d", "correct": true})

	# 模拟真实流程：观察阶段会激活观察器（_obs.show），完成后才进入推理。
	# 之前场景二/三/七/八漏调 _obs.hide() → _obs.is_active() 恒 true → _advance_blocked 永久拦截过渡对话。
	s._obs.show()
	print("DBG obs_active(BEFORE all_done)=%s" % s._obs.is_active())
	s._on_all_done([])   # 走基类公共路径：修复后应 _obs.hide()
	await create_timer(3.0).timeout   # 等 _on_observe_complete 的 2.5s 延时 + _enter_reasoning
	print("DBG obs_active(AFTER all_done)=%s  phase=%s  _wall_auto=%s" % [s._obs.is_active(), s._phase, s._wall_auto])

	s._open_wall()
	await create_timer(0.05).timeout
	var wall = s._wall_instance
	if wall == null:
		print("DBG FLOW_FAIL: wall 未创建")
		quit(); return

	for c in wall._clues:
		wall._clue_ctl._toggle_association(c["id"])
	print("DBG associated=%s verdict=%s _on_verify valid=%s" % [wall._associated, wall.get_verdict(), wall._on_verify.is_valid()])

	var ph_before: int = s._phase
	var phase_str_before: String = s.phase_name() if s.has_method("phase_name") else str(ph_before)
	wall._on_verify_confirm(wall.get_verdict())

	# 等一帧让 queue_free 与 dialogue 启动
	await create_timer(0.3).timeout
	var dm_active := false
	if s._dm != null and is_instance_valid(s._dm):
		dm_active = s._dm.is_active()
	print("DBG phase_before=%s phase_after=%s dm_active=%s wall_valid=%s _wall_auto=%s" % [
		phase_str_before, s._phase, dm_active,
		(s._wall_instance != null and is_instance_valid(s._wall_instance)), s._wall_auto])

	if s._phase == ph_before and not dm_active:
		print("FLOW_RESULT: STUCK — _enter_transition 未推进（phase 未变、dialogue 未激活）")
	elif dm_active and s._phase != ph_before:
		print("FLOW_RESULT: OK — _enter_transition 已触发，dialogue 进行中 (phase=%s)" % s._phase)
	else:
		print("FLOW_RESULT: PARTIAL — phase=%s dm_active=%s" % [s._phase, dm_active])

	# 诊断：对话是否能被推进（_advance_blocked 是否仍拦截）
	var blk: bool = s._advance_blocked(false)
	var obs_active: bool = false
	if s._obs and s._obs.has_method("is_active"): obs_active = s._obs.is_active()
	var tb_overlay: bool = false
	if s._toolbar and s._toolbar.has_method("_is_overlay_active"): tb_overlay = s._toolbar._is_overlay_active()
	var modal_valid: bool = (s._modal_panel != null and is_instance_valid(s._modal_panel))
	print("DBG _advance_blocked=%s  obs_active=%s  toolbar_overlay=%s  modal_valid=%s" % [blk, obs_active, tb_overlay, modal_valid])
	quit()
