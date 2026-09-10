extends DetectiveScene
## 忠实到「渲染层」的回归测试（2026-09-09）：用真实 CH01W 墙数据，
## 模拟玩家采纳推断节点 W-A1 并建关系 clue→W-A1，验证「退出→再进墙」后
## 不仅 _relations 在，且 _node_list（实际渲染节点）仍含 W-A1 —— 否则边无端点→看起来像初始页。
## 这是此前 test_scene1_exit_reopen 只断言 _relations 漏掉的真 bug 触发点。
## 运行：godot --headless --path . "res://scenes/test_scene1_render_reopen.tscn"

var _ok := false
var _ws: Dictionary = {}

func scene_id() -> String: return "scene1"
func clue_source() -> String: return "watson"
func hotspots() -> Array: return [{"id":"wrist"},{"id":"face_dark"},{"id":"pose"},{"id":"medical"},{"id":"arm"},{"id":"face_haggard"}]

func _ready() -> void:
	_wall_state = {}
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
	if ClueSystem:
		ClueSystem.clear_source("watson")
		for cid in ["wrist","face_dark","pose","medical","arm","face_haggard"]:
			ClueSystem.collect_clue_from_catalog(cid, cid, "desc", true, "watson")
	await get_tree().process_frame
	await _run()
	get_tree().quit(0 if _ok else 1)

func _node_ids(gv) -> Array:
	var ids := []
	for nd in gv._node_list():
		ids.append(nd.get("id",""))
	return ids

func _run() -> void:
	if ClueSystem == null:
		printerr("FATAL: ClueSystem 缺失"); return
	var rc = load("res://data/reasoning_chains.gd")
	var hypo: Dictionary = rc.build_wall_dict("CH01W")
	if hypo.is_empty():
		printerr("FATAL: CH01W 构建失败"); return

	# 模拟「读档恢复」后的 _watson_wall_state：含已采纳节点 + 关系（如同真实存档）
	_ws = {
		"relations": [{"from":"wrist","to":"W-A1","kind":"support","color_key":"green","dashed":false}],
		"graph_nodes": [{"id":"W-A1","kind":"hypo","label":"不是原来的肤色","sub":"推断","color":"#aaa"}],
		"graph_placed_clues": ["wrist"]
	}

	# —— 第一次进墙 ——
	_open_wall("watson", hypo, func(v, stars={}): pass, Callable(), true, _ws)
	await get_tree().process_frame
	var wall1 = _wall_instance
	if wall1 == null:
		printerr("FATAL: 墙1未打开"); return
	var gv1 = wall1._graph_view
	var ids1 = _node_ids(gv1)
	print("[ENTER1] relations=", wall1._relations.size(), " node_ids=", ids1, " has_W-A1=", ids1.has("W-A1"))
	if not ids1.has("W-A1") or wall1._relations.size() < 1:
		printerr("前置失败：首次进墙也未恢复节点/关系"); return

	# —— 退出墙 ——
	wall1._on_back_pressed()
	await get_tree().process_frame
	print("[EXIT1] _ws.graph_nodes=", _ws.get("graph_nodes", []).size(), " relations=", _ws.get("relations", []).size())

	# —— 第二次进墙（纯内存，无存读档）——
	_open_wall("watson", hypo, func(v, stars={}): pass, Callable(), true, _ws)
	await get_tree().process_frame
	var wall2 = _wall_instance
	if wall2 == null:
		printerr("FATAL: 墙2未打开"); return
	var gv2 = wall2._graph_view
	var ids2 = _node_ids(gv2)
	print("[ENTER2] relations=", wall2._relations.size(), " node_ids=", ids2, " has_W-A1=", ids2.has("W-A1"))

	if wall2._relations.size() >= 1 and ids2.has("W-A1"):
		_ok = true
		print("RESULT: PASS 读档→进墙→退出→再进墙，节点与关系均保留")
	else:
		_ok = false
		print("RESULT: FAIL 读档→进墙→退出→再进墙，节点或关系丢失（进入初始页）ws=", _ws)
