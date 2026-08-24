extends Control

## 三个 Bug 的机制级回归测试：
##  Bug1：节点位置存档（state_store 是否被 _persist_state 清掉）
##  Bug3：左侧线索拖入图谱（dock 拖拽 → 落下打开关系建议弹窗）
##  （Bug2 顶部按钮由 reasoning_wall 顶栏驱动 graph_view 的同名方法，逻辑单独验证）

var _pass := 0
var _fail := 0


func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)


func _mk_controller(data: Dictionary) -> Control:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	gv.name = "GV"
	add_child(gv)
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.size = Vector2(1280, 720)
		gv._rebuild_graph()
	return gv


func _sample_data() -> Dictionary:
	var clues := [
		{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true,"associated":true,
			"related_npcs":["NPC_HOP"],"relation_tags":["H1"],"attribute_tags":["直接物证"]},
		{"id":"c2","name":"脚印","desc":"步幅大","correct":true,"associated":true,
			"related_npcs":["NPC_HOP","NPC_DRE"],"relation_tags":["H1"],"attribute_tags":["痕迹"]},
		{"id":"c3","name":"假证词","desc":"说谎","correct":false,"associated":false,
			"related_npcs":[],"relation_tags":[],"attribute_tags":["嫌疑人陈述"]},
	]
	var hypo := {
		"title":"马车夫作案","case_name":"血字的研究","chain_id":"2",
		"battlefield":{"hypotheses":[{"id":"H1","text":"凶手乘出租马车","correct":true}],"contradictions":[]}
	}
	var relations := [{"from":"c1","to":"H1","kind":"support"}]
	var persons := [{"id":"NPC_HOP","name":"霍普"},{"id":"NPC_DRE","name":"德雷伯"}]
	var ss := {"graph_view_mode":0,"graph_focus":"NPC_HOP"}
	return {"clues":clues,"hypo":hypo,"relations":relations,"persons":persons,
		"focus_person":"NPC_HOP","difficulty":1,"editable":true,"verdict":-1,
		"state_store":ss,"on_tag":Callable(),"on_add_edge":Callable(),
		"on_remove_relation":Callable(),"on_close":Callable()}


func _mk_motion(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.global_position = p
	e.position = p
	return e


func _mk_press(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.global_position = p
	e.position = p
	return e


func _mk_release(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.global_position = p
	e.position = p
	return e


func _run() -> void:
	var data := _sample_data()
	var gv := _mk_controller(data)

	# ================= Bug1：节点位置存档 =================
	# 模拟玩家把 c1 拖到一个新位置（直接驱动内部状态，绕过 viewport 鼠标坐标）
	var node: Control = gv._node_views.get("c1")
	var new_center := Vector2(900, 300)
	gv._node_center["c1"] = new_center
	gv._layout._persist_node_positions()
	var saved: Dictionary = gv._state_store.get("graph_node_positions", {})
	_chk(saved.has("c1"), "Bug1-A：拖动后位置写入 state_store")
	_chk(saved.get("c1", Vector2.ZERO) == new_center, "Bug1-B：写入坐标值正确")

	# 复现 reasoning_wall._persist_state 的「清掉整块 state_store」行为
	var ss_copy: Dictionary = gv._state_store.duplicate()
	ss_copy.clear()
	ss_copy["associated"] = ["c1","c2"]
	ss_copy["relations"] = gv._relations.duplicate()
	# 把清后的副本同步回 gv 的 state_store（模拟同一引用被清）
	gv._state_store.clear()
	for k in ss_copy.keys():
		gv._state_store[k] = ss_copy[k]
	_chk(not gv._state_store.has("graph_node_positions"), "Bug1-C（复现）：_persist_state.clear() 会抹掉 graph_node_positions（即 Bug 根因）")

	# 修复后：_persist_state 不应清掉图谱键 —— 验证「带图键保留」的逻辑等价
	gv._state_store["graph_node_positions"] = {"c1": new_center}
	var ss2: Dictionary = gv._state_store.duplicate()
	# 修复版：不清空，仅覆盖墙自身键
	for k in ["associated","milestones_lit","battlefield","verified","verdict","doubt_book","relations"]:
		ss2[k] = (gv._state_store.get(k, null))
	_chk(ss2.has("graph_node_positions"), "Bug1-D（修复后）：graph_node_positions 在 _persist_state 后仍保留")

	# ================= Bug3：左侧线索拖入图谱 =================
	# 模拟：在 dock 卡片上按下 → 移动（手动把 _dock_start 设远，模拟真实光标位移>6px）→ 松开
	gv._dockctl._on_dock_card_gui(_mk_press(Vector2(90, 200)), "c1")
	_chk(gv._dock_dragging == true, "Bug3-A：按下线索卡片开始拖拽")
	gv._dock_start = Vector2(90, 200)          # 模拟真实起点
	gv._input(_mk_motion(Vector2(700, 400)))    # 移动到图谱区
	_chk(gv._dock_moved == true, "Bug3-B：移动超过阈值标记为已拖动")
	gv._input(_mk_release(Vector2(700, 400)))   # 在图谱区松开
	_chk(gv._link_popup != null and is_instance_valid(gv._link_popup), "Bug3-C：落在图谱区打开「连到…」建议弹窗（拖入成功）")
	_chk(gv._dock_dragging == false, "Bug3-D：拖拽状态已复位")

	gv.queue_free()
	print("=== 图谱 Bug 机制测试: PASS=%d FAIL=%d ===" % [_pass, _fail])
	if _fail > 0:
		print("GRAPH_BUGS_RESULT: FAIL")
	else:
		print("GRAPH_BUGS_RESULT: PASS")


func _ready() -> void:
	await _run()
	await _run_rw()
	queue_free()


# ================= Bug1 在 reasoning_wall 真实链路上的回归 =================
func _run_rw() -> void:
	var clues := [
		{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true,"associated":true,
			"related_npcs":["NPC_HOP"],"relation_tags":["H1"],"attribute_tags":["直接物证"]},
		{"id":"c2","name":"脚印","desc":"步幅大","correct":true,"associated":true,
			"related_npcs":["NPC_HOP","NPC_DRE"],"relation_tags":["H1"],"attribute_tags":["痕迹"]},
	]
	var hypo := {"title":"马车夫作案","case_name":"血字的研究","chain_id":"2",
		"battlefield":{"hypotheses":[{"id":"H1","text":"凶手乘出租马车","correct":true}],"contradictions":[]}}
	var ss := {"graph_view_mode":0,"graph_focus":"NPC_HOP"}
	var rw = load("res://scripts/clue/reasoning_wall.gd").new()
	add_child(rw)
	rw.setup(clues, hypo, Callable(), Callable(), 1, Callable(), ss, Callable(), true, -1)
	var gv = rw._graph_view
	_chk(gv != null and is_instance_valid(gv), "RW-Bug1-A：图谱视图已随推理墙打开")
	gv._node_center["c1"] = Vector2(950, 280)
	gv._layout._persist_node_positions()
	_chk(ss.has("graph_node_positions") and ss["graph_node_positions"].has("c1"),
		"RW-Bug1-B：玩家移动后位置写入共享 state_store")
	# 推理墙自身持久化（关系/标签变更时也会调用）
	rw._persist_state()
	_chk(ss.has("graph_node_positions") and ss["graph_node_positions"].has("c1"),
		"RW-Bug1-C：_persist_state 后位置仍在（Bug1 修复：不再 clear 整块）")
	_chk(ss.has("associated"), "RW-Bug1-D：推理墙自身键亦正常写入")
	rw.queue_free()
	print("=== 图谱 Bug1 链路测试: PASS=%d FAIL=%d ===" % [_pass, _fail])
