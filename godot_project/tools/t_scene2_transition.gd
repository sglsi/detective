extends SceneTree
## 回归：街道线索(c201-204)收完 → 应切第三张(sc02_path)回收集 c205-206。
## 打印转场各个阶段的实际 stage 与 scene_bg 纹理路径，确认问题2是否复现。

func _initialize() -> void:
	await process_frame
	await process_frame
	var wd = create_timer(40.0)
	wd.timeout.connect(_wd)
	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	var APIManager = root.get_node_or_null("/root/APIManager")
	var DifficultyManager = root.get_node_or_null("/root/DifficultyManager")
	if not (ClueSystem and GameManager and APIManager and DifficultyManager):
		print("T2T_FAIL autoloads missing"); quit(); return
	APIManager.is_online = false
	GameManager.is_guest = false
	DifficultyManager.current_difficulty = DifficultyManager.Difficulty.EASY

	var packed2 = load("res://scenes/scene2.tscn")
	if not packed2: print("T2T_FAIL tscn"); quit(); return
	var s2 = packed2.instantiate()
	root.add_child(s2)
	await process_frame
	await process_frame

	# 推进 arrival 对话进入 OBSERVE
	await _adv(dialogue_controller(s2), 12)
	await _wait(0.5)
	print("T2T phase=%d OBSERVE=%d" % [s2._phase, s2.Phase.OBSERVE])
	var bg := _bg_path(s2)
	print("T2T bg(entry)=%s" % bg)
	print("T2T stage=%s street_active=%s path_active=%s" % [
		s2._stage, _active(s2._street_obs), _active(s2._path_obs)])

	# 真实记录街道线索 c201-204（走 all_recorded → 转场）
	for h in s2.STREET_HOTSPOTS:
		s2._street_obs._record(h["id"], str(h.get("desc", "")))
		await _wait(0.2)
	print("T2T after street: stage=%s" % s2._stage)
	# 等待转场(await 5s)完成
	await _wait(6.5)
	print("T2T after transition: stage=%s bg=%s street_active=%s path_active=%s" % [
		s2._stage, _bg_path(s2), _active(s2._street_obs), _active(s2._path_obs)])
	print("T2T done")
	quit()

func dialogue_controller(s2: Node) -> Node:
	return s2._dm if s2.get("_dm") != null else null

func _adv(dm: Node, n: int) -> void:
	for i in n:
		if dm == null or not is_instance_valid(dm) or not dm.is_active():
			break
		if dm.get("_is_active") == null and dm.has_method("get_current_trigger") and dm.get_current_trigger() != "choice":
			dm.advance()
		elif dm.has_method("advance"):
			var t = dm.call("get_current_trigger") if dm.has_method("get_current_trigger") else "x"
			if t != "choice": dm.advance()
		await _wait(0.3)
		await process_frame

func _bg_path(s2: Node) -> String:
	var ui = s2.get("_ui")
	if not ui: return "no_ui"
	var w = ui.get_world_layer() if ui.has_method("get_world_layer") else null
	if not w: return "no_world"
	var bg = w.find_child("scene_bg", true, false)
	if bg == null or bg.texture == null: return "no_bg"
	return str(bg.texture.resource_path)

func _active(o) -> bool:
	return o != null and o.is_active()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _wd() -> void:
	print("T2T_WATCHDOG"); quit()