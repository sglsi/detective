extends Control
## GUI 真实输入模拟：①鼠标点击顶栏「虚线」按钮 ②鼠标拖拽线索 c1 → 推断 H_core
## 用 Input.parse_input_event 走 Viewport GUI 拾取（headless 下也分发），验证事件是否真到达按钮/节点。
## 运行：godot --headless res://tools/test_gui_sim.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	var clues: Array = []
	if ClueSystem:
		ClueSystem.clear_source("gui_sim")
		ClueSystem.collect_clue_from_catalog("c1", "车轮印", "窄轮距马车", true, "gui_sim", -1, "", "", [], [], [], ["NPC_WT"])
		clues = ClueSystem.get_collected("gui_sim")
	var hypo := {"title": "马车夫作案", "description": "凶手是出租马车夫", "milestones": []}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW_SIM"
	add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1)
	await get_tree().create_timer(0.4).timeout
	var gv = wall.get("_graph_view")
	print("[SIM] gv=%s" % gv)
	if gv == null:
		print("[SIM] FATAL: no graph view"); get_tree().quit(1); return

	# ---------- 测1：真实点击「虚线」按钮 ----------
	var btn: Button = wall._pen_dashed_btn
	var r: Rect2 = btn.get_global_rect()
	print("[SIM] dashed btn global rect=%s center=%s visible=%s disabled=%s" % [r, r.get_center(), btn.visible, btn.disabled])
	_send_click(r.get_center())
	await get_tree().create_timer(0.15).timeout
	print("[SIM] after REAL click 虚线: gv._pen_dashed=%s btn.pressed=%s btn.font_color=%s" % [
		gv._pen_dashed, btn.button_pressed, btn.get_theme_color("font_color")])

	# ---------- 测2：真实拖拽 c1 → 推断 ----------
	var hypo_id: String = ""
	for id in gv._node_kind:
		if gv._node_kind[id] == "hypo":
			hypo_id = id; break
	if hypo_id == "":
		print("[SIM] no hypo node"); get_tree().quit(0); return
	var n1: Control = gv._node_views.get("c1")
	var n2: Control = gv._node_views.get(hypo_id)
	if n1 == null or n2 == null:
		print("[SIM] nodes missing c1=%s hypo=%s" % [n1, n2]); get_tree().quit(0); return
	var p1: Vector2 = n1.get_global_rect().get_center()
	var p2: Vector2 = n2.get_global_rect().get_center()
	print("[SIM] c1 center=%s -> hypo(%s) center=%s" % [p1, hypo_id, p2])
	_send_press(p1)
	await get_tree().create_timer(0.08).timeout
	print("[SIM] after press: dragging=%s drag_id=%s mode=%s" % [gv._dragging, gv._drag_id, gv._drag_mode])
	_send_motion(p2)
	await get_tree().create_timer(0.08).timeout
	_send_release(p2)
	await get_tree().create_timer(0.15).timeout
	print("[SIM] after drag: relations.size=%d" % wall._relations.size())
	for rr in wall._relations:
		print("[SIM]   rel: %s -> %s kind=%s ck=%s dashed=%s" % [rr.get("from",""), rr.get("to",""), rr.get("kind",""), rr.get("color_key",""), rr.get("dashed",false)])
	get_tree().quit(0)

func _mk_btn(button_index: int, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button_index
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	return e

func _send_click(pos: Vector2) -> void:
	Input.parse_input_event(_mk_btn(MOUSE_BUTTON_LEFT, true, pos))
	Input.parse_input_event(_mk_btn(MOUSE_BUTTON_LEFT, false, pos))

func _send_press(pos: Vector2) -> void:
	Input.parse_input_event(_mk_btn(MOUSE_BUTTON_LEFT, true, pos))

func _send_release(pos: Vector2) -> void:
	Input.parse_input_event(_mk_btn(MOUSE_BUTTON_LEFT, false, pos))

func _send_motion(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
