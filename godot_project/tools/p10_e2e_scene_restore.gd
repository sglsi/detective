extends SceneTree
## 端到端验证：真实场景实例「存档 → 读档 → _restore_saved_state 恢复」跨非对话阶段
## 复用单个 sceneB 实例、每轮直接调用 _restore_saved_state()，避免实例累积触发 lambda 释放误报。
## 非对话阶段（2/3/4/5）的 _phase 恢复后不会被对话自动推进改动，是验证「阶段漏写」bug 的关键。

func _initialize() -> void:
	await process_frame
	await process_frame
	# 看门狗：无论如何保证进程退出，避免协程因偶发 lambda 错误挂死导致无输出
	var wd = create_timer(25.0)
	wd.timeout.connect(_watchdog_quit)

	var GameManager = root.get_node_or_null("/root/GameManager")
	var SaveManager = root.get_node_or_null("/root/SaveManager")
	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var SaveSystem = root.get_node_or_null("/root/SaveSystem")
	var APIManager = root.get_node_or_null("/root/APIManager")

	if not (GameManager and SaveManager and ClueSystem and SaveSystem and APIManager):
		print("P10_FAIL autoloads missing")
		quit(); return
	APIManager.is_online = false

	var packed = load("res://scenes/scene1.tscn")
	if not packed:
		print("P10_FAIL scene1.tscn load failed")
		quit(); return

	var sceneA = packed.instantiate()
	root.add_child(sceneA)
	await process_frame
	await process_frame

	# 复用单个 sceneB，避免反复实例化/释放触发 lambda 误报
	var sceneB = packed.instantiate()
	root.add_child(sceneB)
	await process_frame
	await process_frame

	var all_ok = true
	var targets = [2, 3, 4, 5]
	for target in targets:
		SaveSystem.new_game()
		if FileAccess.file_exists("user://save_game.json"):
			DirAccess.remove_absolute("user://save_game.json")

		for cid in ["wrist", "arm", "face", "pose"]:
			sceneA._on_collect_clue(cid, {"name": cid, "desc": "d", "correct": true}, "watson")
		for cid in ["tattoo", "beard", "posture", "manner", "sleeve", "limp"]:
			sceneA._on_collect_clue(cid, {"name": cid, "desc": "d", "correct": true}, "messenger")

		sceneA._phase = target
		GameManager.is_guest = false
		await sceneA._do_save()
		await process_frame

		APIManager.is_online = false
		var load_ok = await SaveManager.load_game()
		if not load_ok:
			print("P10_FAIL phase=", target, " load_game 失败")
			all_ok = false; break

		# 直接驱动真实恢复逻辑（与 _ready 中调用完全一致）
		var restored = sceneB._restore_saved_state()
		await process_frame
		await process_frame

		var got = sceneB._phase
		var w_rec = sceneB._watson_obs.get_recorded()
		var m_rec = sceneB._messenger_obs.get_recorded()
		var cs_w = ClueSystem.get_collected("watson").size()
		var cs_m = ClueSystem.get_collected("messenger").size()

		# 死局防御后的预期：恢复到观察阶段(2/4)但线索已集齐时，场景会自动
		# 推进到对应推理阶段(3/5)——否则 all_recorded 永不触发、场景永久卡死。
		var expected = target
		if target == 2 and w_rec >= 4: expected = 3
		if target == 4 and m_rec >= 6: expected = 5
		var phase_ok = (got == expected) and restored
		var obs_ok = (target in [2, 3]) and (w_rec == 4) or (target in [4, 5]) and (m_rec == 6)
		var clue_ok = (cs_w == 4 and cs_m == 6)
		print("[P10] 目标phase=", target, " → 实际phase=", got, " restored=", restored,
			" watson_rec=", w_rec, " messenger_rec=", m_rec,
			" clue(w/m)=", cs_w, "/", cs_m,
			" | phase_ok=", phase_ok, " obs_ok=", obs_ok, " clue_ok=", clue_ok)
		if not (phase_ok and obs_ok and clue_ok):
			all_ok = false

	if all_ok:
		print("P10_E2E_OK 全阶段存读档恢复通过（非对话阶段 _phase 与线索均正确）")
	else:
		print("P10_FAIL 存在阶段恢复错误")
	quit()

## 看门狗兜底：若测试协程因任何原因卡死，强制退出并刷出缓冲日志
func _watchdog_quit() -> void:
	print("P10_WATCHDOG 超时强制退出（测试协程疑似挂死）")
	quit()
