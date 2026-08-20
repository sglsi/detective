extends SceneTree
## 端到端自测：场景三「集齐 9 线索 → 推理墙 → 验证 → 过渡对话 → scene 切换」全链路
## 真实实例化 scene3，驱动对话推进、自动记录 9 线索、触发 all_recorded、
## 等待 _enter_reasoning 计时器打开推理墙、模拟验证回调、确认进入 TRANSITION。
## 看门狗兜底，任何挂死都会强制刷日志退出。

func _initialize() -> void:
	await process_frame
	await process_frame
	var wd = create_timer(40.0)
	wd.timeout.connect(_watchdog_quit)

	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	var SaveSystem = root.get_node_or_null("/root/SaveSystem")
	if not (ClueSystem and GameManager and SaveSystem):
		print("P11_FAIL autoloads missing"); quit(); return

	var packed = load("res://scenes/scene3.tscn")
	if not packed:
		print("P11_FAIL scene3.tscn load failed"); quit(); return
	var s3 = packed.instantiate()
	root.add_child(s3)
	await process_frame
	await process_frame

	var ok = true
	var log := []

	# ---- 模拟玩家：听完 arrival + detective 对话，进入 OBSERVE ----
	s3._phase = s3.Phase.OBSERVE
	# 把观察器标记为 active（模拟 _on_detective_end 里的 .show()）
	s3._obs.show()

	# ---- 走真实玩家路径记录全部 9 条线索：_on_record 会发 clue_recorded 信号
	#      → DetectiveScene._on_clue_recorded 填 _clues + ClueSystem；
	#      第 9 条自动触发 all_recorded → _on_observe_complete（真实卡死路径全覆盖）----
	for h in s3.HOTSPOTS:
		s3._obs._on_record(h["id"], str(h.get("desc", "")))
		await process_frame

	var rec = s3._obs.get_recorded()
	var cs = ClueSystem.get_collected("indoor").size()
	var local_n = s3._clues.size()
	log.append("记录数=%d ClueSystem(indoor)=%d 场景内=%d (期望 9/9/9)" % [rec, cs, local_n])
	if rec != 9 or cs != 9 or local_n != 9:
		ok = false
		print("P11_FAIL 线索登记不足：recorded=%d clueSystem=%d local=%d" % [rec, cs, local_n])

	# all_recorded 已在第 9 条时自动发射 → _on_indoor_all_done（2.5s）→ _enter_reasoning（2.5s）→ _open_wall
	await _wait(6.5)
	await process_frame
	await process_frame

	var wall = s3.find_child("ReasoningWall", true, false)
	var phase_after = s3._phase
	log.append("进入推理后 phase=%d 墙存在=%s" % [phase_after, str(wall != null)])
	if phase_after != s3.Phase.REASONING:
		ok = false
		print("P11_FAIL 未进入 REASONING，当前 phase=", phase_after)
	if wall == null:
		ok = false
		print("P11_FAIL 推理墙未创建（_open_wall 可能运行时报错）")
		# 打印场景树子节点，辅助定位
		_print_children(s3, 0)
	else:
		# ---- 模拟「关联全部线索 + 提交验证」----
		var n_clues = wall._clues.size()
		log.append("推理墙线索数=%d" % n_clues)
		if n_clues != 9:
			ok = false
			print("P11_FAIL 推理墙线索数异常：", n_clues)
		# 直接调用验证回调（_on_verify_pressed 内部 2.5s 后回调，这里绕过点击直接验证回调语义）
		# 等价逻辑：关联>=3 -> VERIFIED -> on_verify(3) -> _wall_auto 成立 -> _enter_transition
		var verdict = wall.get_verdict()
		log.append("初始 verdict（未关联）=%d (期望 1=INSUFFICIENT) 反驳计数器=%d" % [verdict, wall._contradicting])
		# 模拟玩家关联所有线索
		for c in wall._clues:
			if not c.get("associated", false):
				wall._on_card_clicked(c["id"])
		var v2 = wall.get_verdict()
		log.append("关联全部后 verdict=%d (期望 3=VERIFIED) 关联数=%d" % [v2, wall._associated])
		if v2 != 3:
			ok = false
			print("P11_FAIL 全关联后 verdict 非 VERIFIED：", v2)

		# 触发验证流程（与点击「提交验证」等价）：内部 await 2.5s 后回调 on_verify
		wall._on_verify_pressed()
		await _wait(3.0)
		await process_frame
		await process_frame

	var phase_trans = s3._phase
	var wall_gone = (s3.find_child("ReasoningWall", true, false) == null)
	log.append("验证后 phase=%d 墙已释放=%s" % [phase_trans, str(wall_gone)])
	if phase_trans != s3.Phase.TRANSITION:
		ok = false
		print("P11_FAIL 验证后未进入 TRANSITION，当前 phase=", phase_trans)
	if not wall_gone:
		ok = false
		print("P11_FAIL 验证后推理墙未释放（可能 _enter_transition 未执行）")
	else:
		# 检查过渡对话是否激活（SceneFramework 对话框），并自动推进 3 句
		var dm = s3._dm
		var dm_active = (dm != null and dm.is_active())
		log.append("过渡对话激活=%s" % str(dm_active))
		if not dm_active:
			ok = false
			print("P11_FAIL 过渡对话未激活")
		else:
			for i in 5:
				if dm.is_active() and dm.get_current_trigger() != "choice":
					dm.advance()
				await process_frame
				await process_frame
			log.append("过渡对话已推进，最终 dm.is_active=%s" % str(dm.is_active()))

	# 汇总
	for l in log:
		print("[P11]", l)

	if ok:
		print("P11_E2E_OK 场景三全链路通过（9线索→推理墙→验证→过渡对话）")
	else:
		print("P11_E2E_FAIL 场景三全链路存在阻断点")
	quit()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _print_children(node: Node, depth: int) -> void:
	var pad = ""
	for i in depth: pad += "  "
	print(pad + node.name + " [" + node.get_class() + "]")
	for c in node.get_children():
		_print_children(c, depth + 1)

func _watchdog_quit() -> void:
	print("P11_WATCHDOG 超时强制退出（测试协程疑似挂死）")
	quit()
