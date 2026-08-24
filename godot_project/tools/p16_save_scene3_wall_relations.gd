extends SceneTree
## 端到端（真实读档路径）：scene2 全流程建推理关系 → 存档
## → 模拟「重开会话读档」（新 ClueSystem 从磁盘 load case_wall_state）
## → 进 scene3 打开推理墙 → 断言 scene2 建立的关系（graph_relations）跨场景经存档恢复。
## 覆盖用户痛点：场景二收集的线索与推理关系「读档」后必须出现在场景三推理墙。

func _initialize() -> void:
	await create_timer(0.3).timeout
	var wd = create_timer(120.0); wd.timeout.connect(_watchdog_quit)
	var ok := true
	var log := []

	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	var APIManager = root.get_node_or_null("/root/APIManager")
	var SaveManager = root.get_node_or_null("/root/SaveManager")
	var SaveSystem = root.get_node_or_null("/root/SaveSystem")
	if not (ClueSystem and GameManager and APIManager and SaveManager and SaveSystem):
		print("P16_FAIL autoloads missing"); quit(); return
	APIManager.is_online = false
	GameManager.is_guest = false

	# ============ 阶段一：scene2 全流程并在推理墙建立真实关系 ============
	var packed2 = load("res://scenes/scene2.tscn")
	if not packed2: print("P16_FAIL scene2 load"); quit(); return
	var s2 = packed2.instantiate()
	root.add_child(s2)
	await process_frame; await process_frame

	await _advance_dialogue(s2, 24)
	if s2._phase < s2.Phase.OBSERVE:
		await _advance_dialogue(s2, 24)
	log.append("scene2 phase=%d(期望%d=OBSERVE)" % [s2._phase, s2.Phase.OBSERVE])
	if s2._phase != s2.Phase.OBSERVE: ok=false; print("P16_FAIL scene2 未到 OBSERVE")

	for h in s2.HOTSPOTS:
		s2._obs._record(h["id"], str(h.get("desc", "")))
		await process_frame
	await _wait(6.5)
	s2._open_wall()
	await process_frame; await process_frame
	var wall2 = s2.find_child("ReasoningWall", true, false)
	if wall2 == null:
		ok=false; print("P16_FAIL scene2 墙未开")
	else:
		# 直接往共享态注入一条图谱连线边（等价玩家已把线索拖入画布并连线），
		# 验证「读档→场景三墙」能把这条跨场景推理关系完整带回。
		var rels := [{"from": wall2._clues[0]["id"], "to": "conclusion", "kind": "support", "color": "green", "dashed": false}]
		wall2._state_store["graph_relations"] = rels
		var rels_s2: int = wall2._state_store.get("graph_relations", []).size()
		log.append("scene2 墙 graph_relations 条数=%d (注入建边后)" % rels_s2)
		wall2._on_verify_pressed()
		await process_frame; await process_frame
		wall2._on_verify_confirm(wall2.get_verdict())
		await process_frame; await process_frame

	# scene2 完结 → 真实存档（模拟玩家点「继续推进」）
	var rating_cont2 = _find_button_by_text(s2, "继续推进")
	if rating_cont2 != null:
		rating_cont2.pressed.emit()
	await _wait(2.5)
	log.append("scene2 后 ClueSystem.case_wall_state 共享态 size=%d" % ClueSystem.case_wall_state.size())

	# 记录 scene2 结束阶段值供存档用，随后移除场景实例（干净复位）
	var phase2: int = s2._phase
	s2.queue_free()
	await process_frame; await process_frame

	# ============ 阶段二：模拟「读档」——从磁盘恢复 case_wall_state 到全新共享态 ============
	## 通过真实门面 API：request_save 落盘 → load_game 从磁盘恢复 case_wall_state。
	var rels_before: int = ClueSystem.case_wall_state.get("graph_relations", []).size()
	log.append("存档前 case_wall_state.graph_relations=%d" % rels_before)
	if rels_before < 1:
		ok=false; print("P16_FAIL scene2 建立的关系未进入共享态")

	## 落盘 scene2 完整状态（含共享 case_wall_state）
	await SaveSystem.request_save("scene2", phase2, {
		"clue_ids": ClueSystem.get_collected_ids("garden"),
	}, 2)

	## 模拟重开会话：把内存共享态清掉，再经真实 load_game 从磁盘恢复
	var rels_in_mem_before: int = ClueSystem.case_wall_state.get("graph_relations", []).size()
	ClueSystem.case_wall_state = {}
	log.append("清零内存共享态后 graph_relations=%d（仅剩磁盘）" % ClueSystem.case_wall_state.get("graph_relations", []).size())
	var load_ok: bool = await SaveSystem.load_game(2)
	if not load_ok:
		ok=false; print("P16_FAIL load_game 失败")
	var rels_loaded: int = ClueSystem.case_wall_state.get("graph_relations", []).size()
	log.append("读档后 case_wall_state.graph_relations=%d (期望==%d，即磁盘完整还原 scene2 关系)" % [rels_loaded, rels_in_mem_before])
	if rels_loaded != rels_in_mem_before:
		ok=false; print("P16_FAIL 读档后关系数与磁盘不一致")

	# ============ 阶段三：进 scene3 打开推理墙，断言跨场景关系可见 ============
	## load_game 后 ClueSystem.scene_state 指向 scene2；直接实例 scene3 并置 REASONING 阶段开墙，
	## 验证「读档恢复的共享 case_wall_state」能被场景墙完整取用。
	var packed3 = load("res://scenes/scene3.tscn")
	if not packed3: print("P16_FAIL scene3 load"); quit(); return
	var s3 = packed3.instantiate()
	root.add_child(s3)
	await process_frame; await process_frame
	s3._phase = s3.Phase.REASONING
	s3._open_wall()
	await process_frame; await process_frame
	var wall3 = s3.find_child("ReasoningWall", true, false)
	if wall3 == null:
		ok=false; print("P16_FAIL scene3 墙未开")
	else:
		# 墙内 state_store 应指向共享 case_wall_state / 或其等价拷贝，关系数应等于读档恢复值
		var rels3: int = wall3._state_store.get("graph_relations", []).size()
		log.append("scene3 墙 graph_relations=%d (期望=%d)" % [rels3, rels_loaded])
		if rels3 != rels_loaded:
			ok=false; print("P16_FAIL scene3 墙关系数 != 读档恢复值")

	for l in log: print("[P16]", l)
	if ok:
		print("P16_E2E_OK 读档后 scene3 墙恢复 scene2 关系")
	else:
		print("P16_E2E_FAIL 读档跨场景关系丢失")
	quit()

func _advance_dialogue(scene: Node, max_clicks: int) -> void:
	for i in max_clicks:
		var dm = scene._dm
		if dm == null or not is_instance_valid(dm) or not dm.is_active():
			break
		if dm.get_current_trigger() != "choice":
			dm.advance()
		await _wait(0.3)
		await process_frame

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _find_button_by_text(node: Node, txt: String) -> Button:
	if node is Button and node.text == txt:
		return node
	for c in node.get_children():
		var r = _find_button_by_text(c, txt)
		if r != null:
			return r
	return null

func _watchdog_quit() -> void:
	print("P16_WATCHDOG 超时强制退出")
	quit()