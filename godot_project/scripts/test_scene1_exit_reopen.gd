extends DetectiveScene
## 精确复现思傅报告的 BUG 路径（2026-09-09）：
## 读档后 _watson_wall_state 已含关系 → 进入推理墙(正确) → 退出墙(persist 写回 _ws)
## → 再次进入推理墙（纯内存，无重新存/读档）→ 应仍展示关系；若丢失则进入初始页。
## 与 test_scene1_wall_persist 的区别：本测试不经历 save+restore 文件往返，
## 只验证「退出→再进」这一内存闭环，正是此前漏判的真 bug 触发点。
## 运行：godot --headless --path . "res://scenes/test_scene1_exit_reopen.tscn"

var _ok := false
var _ws: Dictionary = {}

func scene_id() -> String: return "scene1"
func clue_source() -> String: return "watson"
func hotspots() -> Array: return [{"id":"clue_a"}]

func _ready() -> void:
	_wall_state = {}
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
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
	# 模拟「读档恢复」后的 _watson_wall_state：已含一条关系
	_ws = {"relations": [{"from":"clue_a","to":"hypo_x","kind":"support","color_key":"green","dashed":false}]}

	# —— 第一次进墙（读档后进入，应正确展示）——
	_open_wall("watson", hypo, func(v, stars={}): pass, Callable(), true, _ws)
	await get_tree().process_frame
	var wall1 = _wall_instance
	if wall1 == null:
		printerr("FATAL: 墙1未打开"); return
	print("[ENTER1] relations=", wall1._relations.size(), " ws_keys=", _ws.keys())
	if wall1._relations.size() < 1:
		printerr("前置失败：首次进墙也未恢复关系"); return

	# —— 退出墙（persist 写回 _ws）——
	wall1._on_back_pressed()
	await get_tree().process_frame
	print("[EXIT1] _ws.relations=", _ws.get("relations", []).size())

	# —— 第二次进墙（退出后再进入，纯内存，无存读档）——
	_open_wall("watson", hypo, func(v, stars={}): pass, Callable(), true, _ws)
	await get_tree().process_frame
	var wall2 = _wall_instance
	if wall2 == null:
		printerr("FATAL: 墙2未打开"); return
	print("[ENTER2] relations=", wall2._relations.size())
	if wall2._relations.size() >= 1:
		_ok = true
		print("RESULT: PASS 读档→进墙→退出→再进墙，关系保留")
	else:
		_ok = false
		print("RESULT: FAIL 读档→进墙→退出→再进墙，关系丢失（进入初始页）ws=", _ws)
