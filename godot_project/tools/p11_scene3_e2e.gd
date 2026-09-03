extends SceneTree
## 端到端自测：场景三「集齐 13 线索 → 推理墙 → 验证 → 过渡对话 → scene 切换」全链路
## 真实实例化 scene3，驱动对话推进、自动记录 13 线索（含 1 条 silent 自由发现）、触发 all_recorded、
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

	# ---- 走真实玩家路径记录全部 9 条线索：_record 会发 clue_recorded 信号
	#      → DetectiveScene._on_clue_recorded 填 _clues + ClueSystem；
	#      第 9 条自动触发 all_recorded → _on_observe_complete（真实卡死路径全覆盖）----
	for h in s3.HOTSPOTS:
		s3._obs._record(h["id"], str(h.get("desc", "")))
		await process_frame

	var rec = s3._obs.get_recorded()
	var cs = ClueSystem.get_collected("indoor").size()
	var local_n = s3._clues.size()
	log.append("记录数=%d ClueSystem(indoor)=%d 场景内=%d (期望 13/13/13)" % [rec, cs, local_n])
	if rec != 13 or cs != 13 or local_n != 13:
		ok = false
		print("P11_FAIL 线索登记不足：recorded=%d clueSystem=%d local=%d" % [rec, cs, local_n])

	# all_recorded 已在收满时自动发射 → _on_observe_complete（2.5s）→ _enter_reasoning（phase=REASONING，提示"思考"动作）
	await _wait(6.5)
	await process_frame
	await process_frame

	var phase_after = s3._phase
	log.append("进入推理后 phase=%d (期望 3=REASONING)" % phase_after)
	if phase_after != s3.Phase.REASONING:
		ok = false
		print("P11_FAIL 未进入 REASONING，当前 phase=", phase_after)

	# 真实玩家路径：点「思考」开墙（_enter_reasoning 仅提示 think，墙由 think 绑定 _open_wall 触发）
	s3._open_wall()
	await process_frame
	await process_frame

	var wall = s3.find_child("ReasoningWall", true, false)
	log.append("开墙后 墙存在=%s" % str(wall != null))
	if wall == null:
		ok = false
		print("P11_FAIL 推理墙未创建（_open_wall 可能运行时报错）")
		# 打印场景树子节点，辅助定位
		_print_children(s3, 0)
	else:
		# ---- 模拟「关联全部线索 + 正确建边 + 提交验证」----
		# ⚠️ 新框架（分枝计分）verdict 取决于 graph_view 快照里的「真实边(_relations)」，
		# 仅 _toggle_association（关联标记）不产生边 → 正确率 0 → INSUFFICIENT。
		# 故正确玩家须拖拽建边：这里按 case_branch_truth.gd 的 scene2+scene3 链，
		# 把真相边直接注入 wall._relations / graph_view._relations，模拟「推理链全部连对」。
		var n_clues = wall._clues.size()
		log.append("推理墙线索数=%d" % n_clues)
		if n_clues != 13:
			ok = false
			print("P11_FAIL 推理墙线索数异常：", n_clues)
		var verdict = wall.get_verdict()
		log.append("初始 verdict（未建边）=%d (期望 1=INSUFFICIENT) 反驳计数器=%d" % [verdict, wall._contradicting])
		# 关联全部线索（基础标记，喂 _associated 兜底）
		for c in wall._clues:
			if not c.get("associated", false):
				wall._clue_ctl._toggle_association(c["id"])
		# 按真相表建正确边（模拟正确玩家）
		_build_correct_edges(wall, ["scene2", "scene3"])
		var v2 = wall.get_verdict()
		log.append("正确建边后 verdict=%d (期望 3=VERIFIED) 关联数=%d 边=%d" % [v2, wall._associated, wall._graph_view._relations.size()])
		if v2 != 3:
			ok = false
			print("P11_FAIL 正确建边后 verdict 非 VERIFIED：", v2)

		# 触发验证流程：_on_verify_pressed 弹出结果窗口 → 点「确定」(_on_verify_confirm)
		# 才真正 queue_free 墙 + 触发 _on_verify 回调 → _advance_now → 过渡
		wall._verify_ctl._on_verify_pressed()
		await process_frame
		await process_frame
		wall._verify_ctl._on_verify_confirm(wall.get_verdict())
		await process_frame
		await process_frame
		await _wait(0.5)
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
		var dm_active = (dm != null and is_instance_valid(dm) and dm.is_active())
		log.append("过渡对话激活=%s" % str(dm_active))
		if not dm_active:
			ok = false
			print("P11_FAIL 过渡对话未激活")
		elif is_instance_valid(dm):
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
		print("P11_E2E_OK 场景三全链路通过（13线索→推理墙→验证→过渡对话）")
	else:
		print("P11_E2E_FAIL 场景三全链路存在阻断点")
	quit()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

## 按 case_branch_truth.gd 给指定场景的链注入「正确玩家边」：clue→hypo / hypo→conclusion。
## 结论节点在画布上形如 "conclusion_CL3-1"，真相表写裸 "CL3-1"，这里统一加前缀对齐。
## 真实玩家靠拖拽建边，这里直接写 _relations（evaluator 只读 _relations），等价于全连对。
func _build_correct_edges(wall, scenes: Array) -> void:
	var truth = load("res://data/case_branch_truth.gd")
	if truth == null:
		print("P11_WARN case_branch_truth 加载失败，跳过建边"); return
	var gv = wall._graph_view
	var seen_node := {}
	for b in truth.branches():
		if not (str(b.get("scene", "")) in scenes):
			continue
		# 节点：hypo 采纳进 _graph_nodes（evaluator 只认 kind=hypo 的玩家产出）；concl 进 _derived_conclusions
		for n in b.get("nodes", []):
			var layer: String = str(n.get("layer", ""))
			var nid: String = str(n.get("id", ""))
			if layer != "hypo" and layer != "concl":
				continue
			if seen_node.has(nid):
				continue
			seen_node[nid] = true
			if layer == "hypo":
				gv._graph_nodes.append({"id": nid, "kind": "hypo", "label": nid, "sub": "推断", "data": {"correct": true}})
			else:
				gv._derived_conclusions.append({"id": nid, "hid": "", "text": nid})
		# 边：clue→hypo / hypo→conclusion（truth 写裸 id，画布结论带 conclusion_ 前缀，norm 会归一）
		for e in b.get("edges", []):
			var f: String = str(e.get("from", ""))
			var t: String = str(e.get("to", ""))
			var kind: String = str(e.get("kind", "support"))
			var tout: String = t
			if t.begins_with("CL"):
				tout = "conclusion_" + t
			var rec := {"from": f, "to": tout, "kind": kind, "dashed": false}
			gv._relations.append(rec)
			wall._relations.append(rec)

func _print_children(node: Node, depth: int) -> void:
	var pad = ""
	for i in depth: pad += "  "
	print(pad + node.name + " [" + node.get_class() + "]")
	for c in node.get_children():
		_print_children(c, depth + 1)

func _watchdog_quit() -> void:
	print("P11_WATCHDOG 超时强制退出（测试协程疑似挂死）")
	quit()
