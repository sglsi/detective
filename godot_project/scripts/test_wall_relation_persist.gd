extends Control
## 端到端（忠实复现真实游戏路径）：
## 开案例大墙 → 经「真实图谱视图」建关系(_edge._add_edge) → 真实退出(_on_back_pressed)
## → 真实存档(SaveManager.save_to_slot) → 读档恢复 → 重开墙，断言关系不丢失。
## 运行：godot --headless "res://scripts/test_wall_relation_persist.gd"  (需配 .tscn)
## 或：godot --headless --path . "res://scenes/test_wall_relation_persist.tscn"

var _ok := false

func _ready() -> void:
	await _run()
	get_tree().quit(0 if _ok else 1)


func _run() -> void:
	if ClueSystem == null or SaveManager == null:
		printerr("FATAL: autoload 缺失")
		return

	# 清空并准备真实 case_wall_state（案例大墙共享态）
	ClueSystem.case_wall_state = {}
	var state: Dictionary = ClueSystem.case_wall_state

	# 最小化有效线索/假设，保证 _derive_persons 不空（避免开墙崩溃）
	var clues: Array = [{"id":"clue_a","name":"线索A","correct":true,"related_npcs":["NPC_X"]}]
	var hypo := {
		"title":"测试","battlefield":{},"hypotheses":[],"conclusions":[],
		"milestones":[],"persons":[{"id":"NPC_X","name":"某人"}],
	}

	var RW = load("res://scripts/clue/reasoning_wall.gd")

	# 1) 开案例大墙 persist=true，state_store 指向 case_wall_state（与 detective_scene._open_wall 一致）
	var wall = RW.new()
	add_child(wall)
	await get_tree().process_frame
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable(), state, Callable(), true, -1, Callable(), false, [], false, false)
	await get_tree().process_frame

	# 1b) 取真实图谱视图实例
	var gv = wall._graph_view
	if gv == null or not is_instance_valid(gv):
		printerr("FATAL: 图谱视图未创建")
		return
	print("[SETUP] graph_view ok, state=", state.keys())

	# 2) 经「真实图谱视图」建立一条「线索→推断」关系（真实玩家点选两节点走的是这条路径）
	gv._edge._add_edge("clue_a", "hypo_x", "support", "green", false)
	await get_tree().process_frame

	# 3) 断言：关系已写入 case_wall_state（on_relations_changed → _gv_relations_changed → _persist_state）
	var saved_rels: Array = ClueSystem.case_wall_state.get("relations", [])
	print("[WALL→STATE] relations = ", saved_rels.size())
	if saved_rels.size() < 1:
		_ok = false
		print("RESULT: FAIL 关系未写入 case_wall_state: ", saved_rels)
		return

	# 4) 真实退出推理墙（触发 _on_back_pressed → _persist_state）
	wall._on_back_pressed()
	await get_tree().process_frame

	# 5) 真实存档（SaveManager.save_to_slot → _build_save_data 收集 case_wall_state）
	var res = await SaveManager.save_to_slot(0)
	if res.get("error", true):
		printerr("WARN: save_to_slot 返回 ", res)
	var sd: Dictionary = SaveManager.save_data
	var cw_saved: Dictionary = sd.get("case_wall_state", {})
	print("[SAVE] case_wall_state.relations = ", cw_saved.get("relations", []).size())
	if cw_saved.get("relations", []).size() < 1:
		_ok = false
		print("RESULT: FAIL 存档未包含 relations")
		return

	# 6) 重置运行时（模拟全新读档：ClueSystem 重新初始化）
	ClueSystem.case_wall_state = {}

	# 7) 读档恢复（真实路径）
	SaveManager._restore_from_dict(sd)
	print("[RESTORE] case_wall_state.relations = ", ClueSystem.case_wall_state.get("relations", []).size())
	if ClueSystem.case_wall_state.get("relations", []).size() < 1:
		_ok = false
		print("RESULT: FAIL 读档未恢复 relations")
		return

	# 8) 重新开墙读取 relations（与 _open_wall 一致）
	var wall2 = RW.new()
	add_child(wall2)
	await get_tree().process_frame
	wall2.setup(clues, hypo, Callable(), Callable(), 1, Callable(), ClueSystem.case_wall_state, Callable(), true, -1, Callable(), false, [], false, false)
	await get_tree().process_frame

	var restored_rels: Array = wall2._relations
	print("[REOPEN] wall._relations = ", restored_rels.size())
	if restored_rels.size() >= 1:
		_ok = true
		print("RESULT: PASS 推理墙关系 建立→退出→存档→读档→重开 全链路往返成功")
	else:
		_ok = false
		print("RESULT: FAIL 重开墙未恢复关系: ", restored_rels)
