extends Control
## 决定性复现：走【场景真实 _do_save 路径】(经 GameManager.do_save -> SaveManager.save_to_slot)
## 而非直接调 SaveManager，排除"真实存档按钮"与"直接落盘"的差异。
## 流程：实例化 scene2(REASONING) → 真实开墙 → 连线设计 → 调用 s2._do_save(0)（真实存档）
##      → 清空 → SaveManager.load_slot → 再次实例化 scene2 → 断言推理墙设计恢复。

var _failures: Array = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[OK]   " + msg)
	else:
		printerr("[FAIL] " + msg)
		_failures.append(msg)

func _ready() -> void:
	await get_tree().process_frame
	if SaveManager == null or ClueSystem == null or GameManager == null:
		printerr("FATAL: autoload 未就绪"); get_tree().quit(2); return

	var clue_ids := ["c201", "c202", "c203", "c204", "c205", "c206"]
	# 以非游客身份，使场景 _do_save 不被 is_guest 拦截
	GameManager.is_guest = false
	ClueSystem.case_wall_state = {}
	GameManager.current_scene_id = "scene2"
	GameManager.current_case_id = "case1"
	GameManager.scene_state = {"scene_id":"scene2", "phase":3, "clue_ids":clue_ids, "slot":0}

	# 1) 实例化 scene2（REASONING 自动开墙）
	var s2 = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var wall = s2.get("_wall_instance")
	_assert(wall != null, "1) REASONING 自动打开推理墙")
	if wall == null:
		printerr("RESULT: FAIL"); get_tree().quit(1); return

	# 2) 真实设计：连 c201 -> H2-01
	wall._relations.append({"from":"c201","to":"H2-01","kind":"support","color_key":"green","dashed":false})
	wall._gv_relations_changed(wall._relations)
	await get_tree().process_frame
	_assert(ClueSystem.case_wall_state.get("relations", []).size() == 1, "2) 设计实时写入 case_wall_state")

	# 3) 真实存档路径（场景 _do_save -> GameManager.do_save -> SaveManager）
	await s2._do_save(0)
	await get_tree().process_frame
	print("[SAVED] case_wall_state.relations =", ClueSystem.case_wall_state.get("relations", []).size())

	# 4) 清空
	ClueSystem.case_wall_state = {}
	GameManager.scene_state = {}

	# 5) 读档
	var ok := await SaveManager.load_slot(0)
	_assert(ok == true, "3) load_slot 成功")
	_assert(ClueSystem.case_wall_state.get("relations", []).size() == 1, "4) 读档后 case_wall_state.relations 还原(=%d)" % ClueSystem.case_wall_state.get("relations", []).size())

	# 6) 再次实例化 → 读档重开墙
	var s2b = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2b)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var wallb = s2b.get("_wall_instance")
	_assert(wallb != null, "5) 读档后再次自动打开推理墙")
	if wallb != null:
		_assert(wallb._relations.size() == 1, "6) 重开墙后 _relations 保留设计(=%d)" % wallb._relations.size())

	if _failures.is_empty():
		print("RESULT: PASS 真实 _do_save 路径下，场景二推理链设计→存档→读档→推理 完整保留")
		get_tree().quit(0)
	else:
		printerr("RESULT: FAIL 共 %d 项失败" % _failures.size())
		get_tree().quit(1)
