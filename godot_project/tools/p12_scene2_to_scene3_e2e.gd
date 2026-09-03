extends SceneTree
## 端到端自测（真实玩家路径）：scene2 全流程 → change_scene 切 scene3 → scene3 全流程
## 完整复刻用户操作：scene2 六线索(真实 _record)→推理墙→全关联→提交验证→过渡对话
## →_go_to_next_scene(真实场景切换)→scene3 抵达/警长对话(真实 advance)→13 线索→推理墙。
## 带着 scene2 遗留状态（ClueSystem garden 线索、GameManager 存档态、登录态）进 scene3，
## 用于暴露「单场景测试测不出」的跨场景污染 / 卡死。

func _initialize() -> void:
	await process_frame
	await process_frame
	var wd = create_timer(90.0)
	wd.timeout.connect(_watchdog_quit)

	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	var APIManager = root.get_node_or_null("/root/APIManager")
	if not (ClueSystem and GameManager and APIManager):
		print("P12_FAIL autoloads missing"); quit(); return
	# 模拟登录用户（用户实际是登录态），但网络离线走本地存档路径
	APIManager.is_online = false
	GameManager.is_guest = false

	var ok = true
	var log := []

	# ================= SCENE 2 =================
	var packed2 = load("res://scenes/scene2.tscn")
	if not packed2: print("P12_FAIL scene2.tscn load failed"); quit(); return
	var s2 = packed2.instantiate()
	root.add_child(s2)
	await process_frame
	await process_frame

	# 真实推进 arrival 对话（模拟点击）
	await _advance_dialogue(s2, 12)
	log.append("scene2 arrival 后 phase=%d" % s2._phase)
	# 若对话推进未到位，直接走 detective 结束回调兜底
	if s2._phase < s2.Phase.OBSERVE:
		# 继续推进第二段对话
		await _advance_dialogue(s2, 12)
	log.append("scene2 对话后 phase=%d (期望 %d=OBSERVE)" % [s2._phase, s2.Phase.OBSERVE])
	if s2._phase != s2.Phase.OBSERVE:
		ok = false; print("P12_FAIL scene2 未进入 OBSERVE, phase=", s2._phase)

	# 真实收集花园线索（场景二双观察器：STREET(c201-204)→PATH(c205-206)）
	for h in s2.STREET_HOTSPOTS:
		s2._street_obs._record(h["id"], str(h.get("desc", "")))
		await process_frame
	for h in s2.PATH_HOTSPOTS:
		s2._path_obs._record(h["id"], str(h.get("desc", "")))
		await process_frame
	log.append("scene2 线索 local=%d cs=%d" % [s2._clues.size(), ClueSystem.get_collected("garden").size()])

	# all_recorded → 2.5s → _enter_reasoning（提示"思考"）→ 玩家点 think 开墙
	await _wait(6.5)
	# 真实玩家路径：点「思考」开墙（think 绑定 _open_wall）
	s2._open_wall()
	await process_frame
	await process_frame
	var wall2 = s2.find_child("ReasoningWall", true, false)
	log.append("scene2 phase=%d 墙=%s" % [s2._phase, str(wall2 != null)])
	if wall2 == null:
		ok = false; print("P12_FAIL scene2 推理墙未打开")
	else:
		for c in wall2._clues:
			if not c.get("associated", false): wall2._clue_ctl._toggle_association(c["id"])
		# 新框架 verdict 取决于真实边；按真相表建 scene2 正确边（跨场景持久化到 case_wall_state）
		_build_correct_edges(wall2, ["scene2"])
		wall2._verify_ctl._on_verify_pressed()
		await process_frame
		await process_frame
		wall2._verify_ctl._on_verify_confirm(wall2.get_verdict())
		await process_frame
		await process_frame
		# 场景二验证先播「四档回应」对话，其结束回调才 _advance_now 进过渡——推完对话再断言
		await _advance_dialogue(s2, 10)

	log.append("scene2 验证后 phase=%d (期望 %d=TRANSITION)" % [s2._phase, s2.Phase.TRANSITION])
	if s2._phase != s2.Phase.TRANSITION:
		ok = false; print("P12_FAIL scene2 验证后未进入 TRANSITION")

	# 推进过渡对话直到 dialogue_ended → _go_to_next_scene → _show_scene_rating（侦破过程评价面板）
	await _advance_dialogue(s2, 30)
	# 过渡对话结束后弹出「侦破过程」评价面板；真实玩家须点「继续推进」才会触发场景切换
	await process_frame
	await process_frame
	var rating_cont = _find_button_by_text(s2, "继续推进")
	if rating_cont != null:
		log.append("scene2 评价面板出现，真实点击「继续推进」")
		rating_cont.pressed.emit()
	else:
		log.append("⚠ scene2 评价面板未出现（场景切换将不会发生）")
	# change_scene 是延迟执行的（评分类 + 存档 await + 黑屏淡入淡出），等足时间
	await _wait(3.5)
	await process_frame
	await process_frame

	var cur = current_scene
	var cur_name = cur.name if cur else "<null>"
	log.append("场景切换后 current_scene=%s" % cur_name)
	if cur == null or not cur.scene_file_path.ends_with("scene3.tscn"):
		ok = false
		print("P12_FAIL 未切换到 scene3，current=", cur_name,
			" path=", cur.scene_file_path if cur else "")
		for l in log: print("[P12]", l)
		print("P12_E2E_FAIL")
		quit(); return

	# ================= SCENE 3（带 scene2 遗留状态）=================
	var s3 = cur
	await process_frame
	log.append("scene3 初始 phase=%d (0=ARRIVAL)" % s3._phase)

	# 真实推进 arrival + 警长对话
	await _advance_dialogue(s3, 30)
	if s3._phase < s3.Phase.OBSERVE:
		await _advance_dialogue(s3, 30)
	log.append("scene3 对话后 phase=%d (期望 %d=OBSERVE)" % [s3._phase, s3.Phase.OBSERVE])
	if s3._phase != s3.Phase.OBSERVE:
		ok = false; print("P12_FAIL scene3 未进入 OBSERVE, phase=", s3._phase)

	# 真实收集 9 条室内线索
	for h in s3.HOTSPOTS:
		s3._obs._record(h["id"], str(h.get("desc", "")))
		await process_frame
	var cs_indoor = ClueSystem.get_collected("indoor").size()
	log.append("scene3 线索 local=%d cs=%d rec=%d (期望 13)" % [s3._clues.size(), cs_indoor, s3._obs.get_recorded()])
	if cs_indoor != 13:
		ok = false; print("P12_FAIL scene3 线索登记异常 cs=", cs_indoor)

	await _wait(6.5)
	# 真实玩家路径：点「思考」开墙
	s3._open_wall()
	await process_frame
	await process_frame
	var wall3 = s3.find_child("ReasoningWall", true, false)
	log.append("scene3 phase=%d 墙=%s" % [s3._phase, str(wall3 != null)])
	if s3._phase != s3.Phase.REASONING or wall3 == null:
		ok = false; print("P12_FAIL scene3 收集完毕后未进入推理墙（用户卡死点）phase=", s3._phase, " 墙=", wall3 != null)
	else:
		var n3 = wall3._clues.size()
		log.append("scene3 推理墙线索数=%d (期望 21 = 8 garden[含干扰c208] + 13 indoor 全案池；>13 证明跨场景线索已并入)" % n3)
		if n3 != 21: ok = false; print("P12_FAIL 推理墙线索数=", n3)
		for c in wall3._clues:
			if not c.get("associated", false): wall3._clue_ctl._toggle_association(c["id"])
		# 新框架 verdict 取决于真实边；scene2 边已随 case_wall_state 带入，这里补 scene3 正确边
		_build_correct_edges(wall3, ["scene3"])
		log.append("scene3 正确建边后 verdict=%d (期望 3)" % wall3.get_verdict())
		wall3._verify_ctl._on_verify_pressed()
		await process_frame
		await process_frame
		wall3._verify_ctl._on_verify_confirm(wall3.get_verdict())
		await process_frame
		await process_frame

	log.append("scene3 验证后 phase=%d (期望 %d=TRANSITION)" % [s3._phase, s3.Phase.TRANSITION])
	if s3._phase != s3.Phase.TRANSITION:
		ok = false; print("P12_FAIL scene3 验证后未进入 TRANSITION")

	for l in log: print("[P12]", l)
	if ok:
		print("P12_E2E_OK 真实路径 scene2→scene3 全链路通过")
	else:
		print("P12_E2E_FAIL 真实路径存在阻断点")
	quit()

## 模拟玩家连点鼠标推进当前对话（走场景 _input 同款逻辑：dm.advance）
func _advance_dialogue(scene: Node, max_clicks: int) -> void:
	for i in max_clicks:
		var dm = scene._dm
		if dm == null or not is_instance_valid(dm) or not dm.is_active():
			break
		if dm.get_current_trigger() != "choice":
			dm.advance()
		# _go_to_node 内部有 0.15s 自动推进计时器，留足间隔
		await _wait(0.3)
		await process_frame

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

## 按 case_branch_truth.gd 给指定场景的链注入「正确玩家边」（详见 p11 同名函数注释）。
func _build_correct_edges(wall, scenes: Array) -> void:
	var truth = load("res://data/case_branch_truth.gd")
	if truth == null:
		print("P12_WARN case_branch_truth 加载失败，跳过建边"); return
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

## 递归查找子树内首个文本匹配的 Button（用于点击「侦破过程」评价面板的「继续推进」）
func _find_button_by_text(node: Node, txt: String) -> Button:
	if node is Button and node.text == txt:
		return node
	for c in node.get_children():
		var r = _find_button_by_text(c, txt)
		if r != null:
			return r
	return null

func _watchdog_quit() -> void:
	print("P12_WATCHDOG 超时强制退出（疑似挂死——这可能正是用户卡死点）")
	quit()
