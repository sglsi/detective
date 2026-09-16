extends Control
## 回归测试：场景一/二「提交验证 → 存档 → 读档」的相位恢复
## 覆盖思傅 2026-09-15 报告的存档 bug：
##   问题1（读档回到推理墙）：已验证的读档应重放结论裁定对话、流程继续，
##       而不是重开推理墙（旧行为：华生/信使读档都进墙，信使还卡住无法推进）。
##   问题2（读档跳流程）：验证后推进 1-2 步再存档，读档不应直接跳到最终评分页，
##       而应重放验证后流程（含委托信 / 警长手写信 / 过场对话）。
##
## 运行：godot --headless --path godot_project "res://scenes/test_save_restore_flow.tscn"
## 退出码 0=PASS，1=FAIL（"ObjectDB instances leaked" 属正常噪声）。

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager == null:
		printerr("FATAL: GameManager autoload 未就绪"); get_tree().quit(2); return

	await run_scene1_messenger_verified()   # 问题1b + 问题2(scene1) 已验证分支
	await run_scene1_watson_verified()      # 问题1a 华生已验证分支
	await run_scene1_messenger_unverified() # 控制组：未验证仍应重开墙（确保未改坏该路径）
	await run_scene2_transition()           # 问题2(scene2) 过场读档不跳评分页

	if _failures.is_empty():
		print("RESULT: PASS 全部场景读档相位恢复正确（无重开墙 / 无跳流程）")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("RESULT: FAIL " + f)
		get_tree().quit(1)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[OK]   " + msg)
	else:
		printerr("[FAIL] " + msg)
		_failures.append(msg)

func _dict_prop(node: Node, name: String) -> Dictionary:
	var v = node.get(name)
	if v is Dictionary: return v
	return {}

func _seed_and_load(scene_path: String, scene_state: Dictionary) -> Node:
	GameManager.scene_state = scene_state.duplicate(true)
	var s = load(scene_path).instantiate()
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return s

func _cleanup(s: Node) -> void:
	if s: s.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func run_scene1_messenger_verified() -> void:
	print("=== 场景一 信使已验证 读档（问题1b + 问题2-scene1） ===")
	var ss := {
		"scene_id": "scene1", "phase": 5,   # MESSENGER_REASONING
		"clue_ids": ["tattoo","beard","posture","manner","sleeve","limp"],
		"wall_state_watson": {},
		"wall_state_messenger": {"verified": true, "verdict": 3, "relations": [], "graph_nodes": []},
		"watson_recorded": 6, "messenger_recorded": 6
	}
	var s = await _seed_and_load("res://scenes/scene1.tscn", ss)
	_assert(s.get("_wall_instance") == null, "信使已验证读档：未重开推理墙（旧 bug 是进墙）")
	_assert(int(s.get("_phase")) == 5, "信使已验证读档：相位保持 MESSENGER_REASONING(5)")
	_assert(s.get("_dm") != null, "信使已验证读档：重放结论裁定对话（流程继续，非跳评分）")
	_assert(_dict_prop(s, "_messenger_wall_state").get("verified", false) == true, "信使已验证读档：verified 标记保留")
	await _cleanup(s)

func run_scene1_watson_verified() -> void:
	print("=== 场景一 华生已验证 读档（问题1a） ===")
	var ss := {
		"scene_id": "scene1", "phase": 3,   # WATSON_REASONING
		"clue_ids": ["wrist","arm","face_dark","face_haggard","pose","medical"],
		"wall_state_watson": {"verified": true, "verdict": 2, "relations": [], "graph_nodes": []},
		"wall_state_messenger": {},
		"watson_recorded": 6, "messenger_recorded": 0
	}
	var s = await _seed_and_load("res://scenes/scene1.tscn", ss)
	_assert(s.get("_wall_instance") == null, "华生已验证读档：未重开推理墙")
	_assert(int(s.get("_phase")) == 3, "华生已验证读档：相位保持 WATSON_REASONING(3)")
	_assert(s.get("_dm") != null, "华生已验证读档：重放结论裁定对话（流程继续）")
	_assert(_dict_prop(s, "_watson_wall_state").get("verified", false) == true, "华生已验证读档：verified 标记保留")
	await _cleanup(s)

func run_scene1_messenger_unverified() -> void:
	print("=== 场景一 信使未验证 读档（控制组：应重开墙） ===")
	var ss := {
		"scene_id": "scene1", "phase": 5,
		"clue_ids": ["tattoo","beard","posture","manner","sleeve","limp"],
		"wall_state_watson": {},
		"wall_state_messenger": {"verified": false, "verdict": -1, "relations": [], "graph_nodes": []},
		"watson_recorded": 6, "messenger_recorded": 6
	}
	var s = await _seed_and_load("res://scenes/scene1.tscn", ss)
	_assert(s.get("_wall_instance") != null, "信使未验证读档：正确重开推理墙（未验证路径未被改坏）")
	await _cleanup(s)

func run_scene2_transition() -> void:
	print("=== 场景二 过场(TRANSITION)读档（问题2-scene2） ===")
	var ss := {
		"scene_id": "scene2", "phase": 4,   # TRANSITION
		"clue_ids": []
	}
	var s = await _seed_and_load("res://scenes/scene2.tscn", ss)
	_assert(int(s.get("_phase")) == 4, "场景二过场读档：相位保持 TRANSITION(4)")
	# 新代码重放 _enter_transition() → _start_dialogue 会建立 _dm（活跃对话）；
	# 旧代码直接 _show_scene_rating() 只建评分面板、不建 _dm。故 _dm != null 即证明未跳评分页。
	_assert(s.get("_dm") != null, "场景二过场读档：重放过场对话（非直接跳评分页）")
	await _cleanup(s)
