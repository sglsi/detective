extends SceneTree
## 验证「新玩不推进」修复：模拟用户会话中开过知识库弹窗/工具栏覆盖层等残留浮层，
## 确认验证推进剧情时 _advance_blocked 一定为 false（剧情能推进）。
## godot --headless --script res://tools/test_scene2_advance_block.gd --path <godot_project>

func _run_scenario(tag: String, s, setup_lingering: Callable) -> void:
	# 干净铺垫：收集 6 线索 + 观察完成 + 打开墙 + 关联
	for i in range(6):
		s._clues.append({"id": "S2-%d" % i, "name": "线索%d" % i, "desc": "d", "correct": true})
	s._obs.show()
	s._on_all_done([])
	await create_timer(3.0).timeout   # 等 _on_observe_complete 的 2.5s 延时
	s._open_wall()
	await create_timer(0.05).timeout
	var wall = s._wall_instance
	if wall == null:
		print("%s: FAIL wall未创建" % tag); return
	for c in wall._clues:
		wall._toggle_association(c["id"])
	# 构造「残留浮层」脏状态（模拟新玩过程中开过知识库/工具栏）
	if setup_lingering.is_valid():
		setup_lingering.call()
	# 提交验证
	wall._on_verify_confirm(wall.get_verdict())
	await create_timer(0.3).timeout
	var blk: bool = s._advance_blocked(false)
	var modal_valid: bool = (s._modal_panel != null and is_instance_valid(s._modal_panel))
	var tb_overlay: bool = false
	if s._toolbar and s._toolbar.has_method("_is_overlay_active"): tb_overlay = s._toolbar._is_overlay_active()
	var wall_valid: bool = (s._wall_instance != null and is_instance_valid(s._wall_instance))
	var obs_active: bool = false
	if s._obs and s._obs.has_method("is_active"): obs_active = s._obs.is_active()
	print("%s: _advance_blocked=%s (modal_valid=%s tb_overlay=%s wall_valid=%s obs_active=%s)" % [
		tag, blk, modal_valid, tb_overlay, wall_valid, obs_active])
	if blk:
		print("%s: RESULT BLOCKED ❌（剧情无法推进）" % tag)
	else:
		print("%s: RESULT OK ✅（剧情可推进）" % tag)
	# 清理以便下一场景
	if wall and is_instance_valid(wall): wall.queue_free()

func _initialize() -> void:
	await create_timer(0.1).timeout
	var s = load("res://scenes/scene2.tscn").instantiate()
	root.add_child(s)
	await create_timer(0.05).timeout

	# A. 干净流程
	await _run_scenario("A_clean", s, Callable())
	await create_timer(0.2).timeout

	# B. 开墙后残留知识库弹窗（模拟「新玩中开过知识库、难点到关闭」）
	await _run_scenario("B_kb_modal", s, Callable(s, "_open_knowledge_base"))
	await create_timer(0.2).timeout

	# C. 开墙后残留放大镜覆盖层（模拟工具栏关不掉、镜片卡住）
	await _run_scenario("C_mag_overlay", s, Callable(s._toolbar, "_start_magnifier"))
	await create_timer(0.2).timeout

	# 汇总判断
	print("=== ADVANCE_BLOCK_TEST_DONE ===")
	quit()
