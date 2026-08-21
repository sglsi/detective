extends SceneTree
## 推理墙：左侧线索 dock 拖入图谱 的真实事件流回归。
## 用 Input.parse_input_event 投递带坐标的真实鼠标事件（浏览器真实链路），await 让引擎刷新视口坐标，
## 从而真正走通：dock 卡按下 -> 移动出 dock -> 松手落到图谱 -> 弹「连到…」面板 -> _confirm_link 建边。
## 同时验证 ESC 重入保护（_closing）：两次 ESC 只触发一次关墙回调，且销毁节点已移出 _input 派发（防 Web 栈溢出）。
## 运行：godot --headless --script res://tools/test_wall_drag.gd

var _pass := 0
var _fail := 0
var _close_count := 0

func _initialize() -> void:
	await _run()

func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)

func _on_close() -> void:
	_close_count += 1

func _run() -> void:
	var clues := [
		{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true},
		{"id":"c2","name":"身高特征","desc":"凶手高大","correct":true},
	]
	var hypo := {"title":"测试假设","battlefield":{"hypotheses":[{"id":"H1","text":"马车夫作案"}]}}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW"
	root.add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(self, "_on_close"), 1)

	await process_frame
	await process_frame
	var gv = wall._graph_view
	_chk(gv != null and is_instance_valid(gv), "图谱视图已构建")

	# ===== 真实拖拽流（带坐标的鼠标事件，经引擎派发 + await 刷新视口坐标）=====
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 300)
	press.global_position = Vector2(100, 300)
	Input.parse_input_event(press)
	await process_frame                      # 视口坐标 -> (100,300)
	gv._on_dock_card_gui(press, "c1")        # 真实：dock 卡 gui_input 按下（_dock_start 取 (100,300)）
	_chk(gv._dock_dragging == true, "按下 dock 卡进入拖拽态")

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(900, 400)
	motion.global_position = Vector2(900, 400)
	Input.parse_input_event(motion)
	await process_frame                      # 视口坐标 -> (900,400)，gv._input(移动) 跑 -> _dock_moved=true
	_chk(gv._dock_moved == true, "移出 dock 超过阈值标记已拖动")

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(900, 400)
	release.global_position = Vector2(900, 400)
	Input.parse_input_event(release)
	await process_frame                      # gv._input(松开) -> _on_dock_drop -> 弹面板
	_chk(gv._link_popup != null, "拖入图谱弹出「连到…」面板（拖拽成功）")

	var rels0: int = wall.get_relations().size()
	gv._confirm_link("c1", "conclusion", "conclusion")
	_chk(gv._link_popup == null, "确认后面板关闭")
	var rels1: Array = wall.get_relations()
	var edge_ok := false
	for r in rels1:
		if (r.from == "c1" and r.to == "conclusion") or (r.from == "conclusion" and r.to == "c1"):
			edge_ok = true
	_chk(edge_ok, "确认后在 c1 与 conclusion 间建立关系 (rels %d->%d)" % [rels0, rels1.size()])

	# ===== 无移动=取消：dock 内按下后直接松开不应弹面板/建边 =====
	press.position = Vector2(100, 300)
	press.global_position = Vector2(100, 300)
	Input.parse_input_event(press)
	await process_frame
	gv._on_dock_card_gui(press, "c2")
	release.position = Vector2(100, 300)
	release.global_position = Vector2(100, 300)
	Input.parse_input_event(release)
	await process_frame
	_chk(gv._link_popup == null, "未移动直接松开不弹面板（视为取消）")

	# ===== clue↔clue 自动矛盾检测（connect_nodes auto 加入关系）=====
	wall.connect_nodes("c1", "c2", "auto")
	var auto_added := false
	for r in wall.get_relations():
		if (r.from == "c1" and r.to == "c2") or (r.from == "c2" and r.to == "c1"):
			auto_added = true
	_chk(auto_added, "connect_nodes(auto) 在 c1↔c2 间加入关系")

	# ===== ESC 重入保护：两次 ESC 只触发一次关墙回调，且销毁已移出 _input（不再同步 free）=====
	_close_count = 0
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	esc.echo = false
	wall._input(esc)        # 真实：rw._input 内 ESC 现在 call_deferred(_on_back_pressed)
	wall._input(esc)        # 第二次（模拟 graph_view 延迟 _on_close_pressed 绕回 + 玩家连按）
	_chk(is_instance_valid(wall), "ESC 后墙未同步销毁（free 已移出 _input 派发，防 Web 栈溢出）")
	await process_frame      # 让 deferred _on_back_pressed 跑完
	await process_frame
	_chk(_close_count == 1, "两次 ESC 仅触发一次关墙回调 (_closing 重入保护, 实得 %d)" % _close_count)
	_chk(not is_instance_valid(wall), "延迟关墙后墙已被销毁")

	print("=== DRAG_RESULT: %s (PASS=%d FAIL=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	quit()
