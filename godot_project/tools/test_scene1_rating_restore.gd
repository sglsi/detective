extends SceneTree
## 验证：场景一评分（各推理墙得出的实例星级）在「存档→读档」后不丢失。
## 复现生产路径：_save_and_continue → SaveSystem.request_save("scene1", COMPLETE, {stars...})
##            → SaveManager 落盘 → 读档 SaveManager.load_slot → Scene1._restore_saved_state → _show_rating

func _initialize() -> void:
	await create_timer(0.3).timeout
	var ok := true

	var scene_script = load("res://scripts/scene/scene1.gd")
	if scene_script == null:
		print("LOAD FAIL: scene1.gd")
		print("RATING_RESTORE: FAIL")
		quit()
		return

	# —— 第一遍：构造通关评分并保存（slot=0 显式，避免跨槽位污染）——
	var inst1 = scene_script.new()
	if inst1 == null:
		print("NEW FAIL: scene1 #1")
		print("RATING_RESTORE: FAIL")
		quit()
		return
	inst1._stars_observe = 3
	inst1._stars_reason = 2
	inst1._stars_insight = 3
	inst1._watson_v = 3
	inst1._messenger_v = 2
	var ss_node = root.get_node_or_null("SaveSystem")
	var sm_node = root.get_node_or_null("SaveManager")
	if ss_node == null or sm_node == null:
		print("AUTOLOAD MISSING: SaveSystem=", ss_node != null, " SaveManager=", sm_node != null)
		print("RATING_RESTORE: FAIL")
		quit()
		return
	await ss_node.request_save("scene1", inst1.Phase.COMPLETE, {
		"clue_ids": ["wrist","shoulder","face","pose","tattoo","beard","posture","manner","sleeve","limp"],
		"stars_observe": inst1._stars_observe,
		"stars_reason": inst1._stars_reason,
		"stars_insight": inst1._stars_insight,
		"watson_v": inst1._watson_v,
		"messenger_v": inst1._messenger_v,
	}, 0)

	# —— 第二遍：从磁盘读档，新实例恢复 ——
	await sm_node.load_slot(0)
	var gm_node = root.get_node_or_null("GameManager")
	if gm_node != null:
		print("DBG GM.scene_state scene_id=", gm_node.scene_state.get("scene_id", "<?>"), " size=", gm_node.scene_state.size())
	var ss_direct = ss_node.take_save_state("scene1", false)
	print("DBG take_save_state direct size=", ss_direct.size(), " scene_id=", ss_direct.get("scene_id", "<?>"))
	var inst2 = scene_script.new()
	if inst2 == null:
		print("NEW FAIL: scene1 #2")
		print("RATING_RESTORE: FAIL")
		quit()
		return
	var restored: bool = inst2._restore_saved_state()
	if not restored:
		print("RESTORE returned false (scene_id mismatch?)")
		ok = false
	else:
		if inst2._stars_observe != 3:
			print("stars_observe mismatch: got ", inst2._stars_observe, " want 3"); ok = false
		if inst2._stars_reason != 2:
			print("stars_reason mismatch: got ", inst2._stars_reason, " want 2"); ok = false
		if inst2._stars_insight != 3:
			print("stars_insight mismatch: got ", inst2._stars_insight, " want 3"); ok = false
		if inst2._watson_v != 3:
			print("watson_v mismatch: got ", inst2._watson_v, " want 3"); ok = false
		if inst2._messenger_v != 2:
			print("messenger_v mismatch: got ", inst2._messenger_v, " want 2"); ok = false

	# 反例校验：未持久化时默认值应为 1（证明修复前有损）
	var inst3 = scene_script.new()
	if inst3._stars_observe != 1 or inst3._stars_reason != 1 or inst3._stars_insight != 1:
		print("default star value changed unexpectedly"); ok = false

	print("RATING_RESTORE: ", "PASS" if ok else "FAIL")
	quit()
