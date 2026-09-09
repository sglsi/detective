extends DetectiveScene
## 场景一教学墙（华生/信使）关系持久化回归测试：
## 忠实复现 scene1._show_watson_reasoning_wall 的调用
##   _open_wall("watson", hypo, cb, resume, true, _watson_wall_state)
## 验证：即使 _watson_wall_state 初始为空字典({})，经修复后的 _open_wall（teaching 强制使用 override）
## 建关系 → 退出 → 关系必须写回该 override 字典（按引用）；并模拟 scene1._do_save 的
## wall_state_watson 存盘 + 读档恢复，重开墙后关系仍在。
## 回归点：detective_scene.gd _open_wall effective_state 选择（teaching 空 override 必须被使用）。
## 运行：godot --headless --path . "res://scenes/test_scene1_wall_persist.tscn"

var _ok := false
var _ws: Dictionary = {}

func scene_id() -> String: return "scene1"
func clue_source() -> String: return "watson"
func hotspots() -> Array: return [{"id":"clue_a"}]

func _ready() -> void:
	_wall_state = {}
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
	# 预填 watson 线索，使 _open_wall 守卫放行
	if ClueSystem:
		ClueSystem.clear_source("watson")
		ClueSystem.collect_clue_from_catalog("clue_a", "线索A", "desc", true, "watson")
	await get_tree().process_frame
	await _run()
	get_tree().quit(0 if _ok else 1)

func _run() -> void:
	if ClueSystem == null:
		printerr("FATAL: ClueSystem 缺失"); return
	var hypo := {
		"title":"测试墙","battlefield":{},"hypotheses":[],"conclusions":[],
		"milestones":[],"persons":[{"id":"NPC_X","name":"某人"}]
	}
	# 模拟 scene1：首次开墙，override 为空字典（这正是此前丢失关系的根因触发条件）
	_ws = {}
	_open_wall("watson", hypo, func(v, stars={}): pass, Callable(), true, _ws)
	await get_tree().process_frame
	var wall = _wall_instance
	if wall == null or not is_instance_valid(wall):
		printerr("FATAL: 墙未打开"); return
	var gv = wall._graph_view
	if gv == null:
		printerr("FATAL: 无图谱视图"); return
	print("[OPEN] teaching wall, state keys=", _ws.keys())
	# 建关系（真实图谱视图路径：点选两节点 → _edge._add_edge）
	gv._edge._add_edge("clue_a", "hypo_x", "support", "green", false)
	await get_tree().process_frame
	print("[WALL→STATE] relations = ", _ws.get("relations", []).size())
	if _ws.get("relations", []).size() < 1:
		_ok = false
		print("RESULT: FAIL 关系未写回 teaching override 字典（回归未修复：is_empty 误退回 _wall_state）")
		return
	# 退出墙（触发 _on_back_pressed → _persist_state 写回 _ws）
	wall._on_back_pressed()
	await get_tree().process_frame
	# 模拟 scene1._do_save 的存盘结构（只存 wall_state_watson/messenger，不存 _wall_state）
	var saved := {"wall_state_watson": _ws.duplicate(true), "wall_state_messenger": {}}
	print("[SAVE] wall_state_watson.relations = ", saved["wall_state_watson"].get("relations", []).size())
	# 读档恢复
	var restored: Dictionary = saved["wall_state_watson"]
	print("[RESTORE] restored.relations = ", restored.get("relations", []).size())
	# 重开墙（恢复态传入，teaching=true override）
	var wall2 = load("res://scripts/clue/reasoning_wall.gd").new()
	add_child(wall2)
	await get_tree().process_frame
	wall2.setup([{"id":"clue_a","name":"线索A","correct":true,"related_npcs":["NPC_X"]}], hypo, Callable(), Callable(), 1, Callable(), restored, Callable(), true, -1, Callable(), false, [], false, true)
	await get_tree().process_frame
	var r2 = wall2._relations
	print("[REOPEN] wall._relations = ", r2.size())
	if r2.size() >= 1:
		_ok = true
		print("RESULT: PASS 场景一教学墙关系 建立→退出→存盘→读档→重开 往返成功")
	else:
		_ok = false
		print("RESULT: FAIL 重开墙未恢复关系: ", r2)
