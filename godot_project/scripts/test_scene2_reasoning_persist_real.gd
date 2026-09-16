extends Control
## 忠实复现「场景二：线索收集 → 推理链设计(真实开墙连线) → 存档 → 读档 → 推理」
## 与上个测试的区别：不绕开墙——真实 _open_wall 打开推理墙，用墙自身的
## relations 写回回调 (_gv_relations_changed) 模拟玩家连线设计，验证墙确实把
## 设计写进 ClueSystem.case_wall_state（共享引用），再走存档/读档往返。
##
## 若本测试 FAIL，说明「设计只留在墙内存、没落进 case_wall_state」——
## 即玩家存档时抓到的是空图，读档后推理墙自然为空（需重连）。
##
## 运行：godot --headless --path . "res://scenes/test_scene2_reasoning_persist_real.tscn"

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

	# 用真实场景走「线索已集齐 → REASONING → 开墙」
	ClueSystem.case_wall_state = {}
	GameManager.current_scene_id = "scene2"
	GameManager.current_case_id = "case1"
	GameManager.scene_state = {
		"scene_id": "scene2",
		"phase": 3,            # REASONING
		"clue_ids": clue_ids,
		"slot": 0
	}

	# 1) 实例化 scene2 → 读档 → _open_wall 真实打开推理墙
	var s2 = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var wall = s2.get("_wall_instance")
	_assert(wall != null, "1) REASONING 阶段真实打开推理墙")
	if wall == null:
		printerr("RESULT: FAIL 墙未打开，无法继续"); get_tree().quit(1); return

	# 2) 真实模拟玩家「设计推理链」：把线索 c201 连到推断 H2-01（支持关系）
	#    走墙自身的 _gv_relations_changed 回调（与真实拖拽连线同源 → 触发 _persist_state 写回）
	var new_rel := {"from": "c201", "to": "H2-01", "kind": "support", "color_key": "green", "dashed": false}
	wall._relations.append(new_rel)
	wall._gv_relations_changed(wall._relations)
	await get_tree().process_frame

	# 3) 断言墙真的把设计写进了 ClueSystem.case_wall_state（共享引用）
	var live_case := ClueSystem.case_wall_state
	print("[LIVE] case_wall_state.relations =", live_case.get("relations", []).size())
	_assert(live_case.get("relations", []).size() == 1, "2) 墙设计已实时写入 ClueSystem.case_wall_state（实得 %d）" % live_case.get("relations", []).size())
	_assert(str(live_case.get("owner_scene", "")) == "scene2", "2b) owner_scene 已置为 scene2")

	# 4) 存档（真实 SaveManager 落盘）。
	# 注意：上面 _restore_saved_state 已通过 take_save_state(consume=true) 消费掉 scene_state，
	# 真实游戏里 _do_save 会重新写入 scene_state 再落盘；此处模拟该行为，避免测试假象。
	GameManager.scene_state = {
		"scene_id": "scene2",
		"phase": 3,
		"clue_ids": clue_ids,
		"slot": 0
	}
	await SaveManager.save_to_slot(0)

	# 5) 清空，模拟全新会话
	ClueSystem.case_wall_state = {}
	GameManager.scene_state = {}

	# 6) 读档
	var ok := await SaveManager.load_slot(0)
	_assert(ok == true, "3) 读档成功")
	var restored := ClueSystem.case_wall_state
	_assert(restored.get("relations", []).size() == 1, "4) 读档后 case_wall_state.relations 还原（实得 %d）" % restored.get("relations", []).size())

	# 7) 再次实例化 scene2 → 读档重开墙 → 断言设计保留
	var s2b = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2b)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var wallb = s2b.get("_wall_instance")
	_assert(wallb != null, "5) 读档后再次自动打开推理墙")
	if wallb != null:
		print("[RELOAD] 墙内 relations =", wallb._relations.size())
		_assert(wallb._relations.size() == 1, "6) 重开墙后 _relations 保留设计（实得 %d）" % wallb._relations.size())

	if _failures.is_empty():
		print("RESULT: PASS 场景二「真实开墙设计→存档→读档→推理」推理链状态完整保留")
		get_tree().quit(0)
	else:
		printerr("RESULT: FAIL 共 %d 项失败" % _failures.size())
		get_tree().quit(1)
