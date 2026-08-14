extends SceneTree
## 验证：场景一读到终局阶段（COMPLETE/RATING）后，_suppress_terminal_save 被置 true，
## 从而「进入场景二」按钮不会再次自动写入 identical 存档；
## 读到非终局阶段时该标志保持 false，正常流程仍可自动存档。

func _initialize() -> void:
	await create_timer(0.3).timeout
	var ok := true

	var scene_script = load("res://scripts/scene/scene1.gd")
	if scene_script == null:
		print("LOAD FAIL: scene1.gd")
		print("TERMINAL_SAVE_SUPPRESSION: FAIL")
		quit()
		return

	var ss_node = root.get_node_or_null("SaveSystem")
	var sm_node = root.get_node_or_null("SaveManager")
	if ss_node == null or sm_node == null:
		print("AUTOLOAD MISSING: SaveSystem=", ss_node != null, " SaveManager=", sm_node != null)
		print("TERMINAL_SAVE_SUPPRESSION: FAIL")
		quit()
		return

	var sample_ids := ["wrist","shoulder","face","pose","tattoo","beard","posture","manner","sleeve","limp"]

	# —— 测试1：终局阶段（COMPLETE）读档须置抑制标志 ——
	await ss_node.request_save("scene1", scene_script.Phase.COMPLETE, {
		"clue_ids": sample_ids,
		"stars_observe": 3, "stars_reason": 2, "stars_insight": 3,
		"watson_v": 3, "messenger_v": 2,
	}, 0)
	await sm_node.load_slot(0)
	var inst1 = scene_script.new()
	if inst1 == null:
		print("NEW FAIL: scene1 #1")
		print("TERMINAL_SAVE_SUPPRESSION: FAIL")
		quit()
		return
	inst1._restore_saved_state()
	if inst1._phase != scene_script.Phase.RATING:
		print("phase mismatch after COMPLETE restore: got ", inst1._phase, " want RATING")
		ok = false
	if not inst1._suppress_terminal_save:
		print("_suppress_terminal_save should be true after COMPLETE/RATING restore")
		ok = false

	# —— 测试2：非终局阶段（OBSERVE_WATSON）读档须保持 false ——
	await ss_node.request_save("scene1", scene_script.Phase.OBSERVE_WATSON, {
		"clue_ids": ["wrist","shoulder"]
	}, 1)
	await sm_node.load_slot(1)
	var inst2 = scene_script.new()
	if inst2 == null:
		print("NEW FAIL: scene1 #2")
		print("TERMINAL_SAVE_SUPPRESSION: FAIL")
		quit()
		return
	inst2._restore_saved_state()
	if inst2._phase != scene_script.Phase.OBSERVE_WATSON:
		print("phase mismatch after OBSERVE restore: got ", inst2._phase, " want OBSERVE_WATSON")
		ok = false
	if inst2._suppress_terminal_save:
		print("_suppress_terminal_save should be false after non-terminal restore")
		ok = false

	print("TERMINAL_SAVE_SUPPRESSION: ", "PASS" if ok else "FAIL")
	quit()
