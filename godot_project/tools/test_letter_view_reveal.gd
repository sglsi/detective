extends Control

## 回归测试：委托信信笺必须**真的显示出来**（不能与"开启它的那一次输入"同帧被关掉）。
##
## 现象（用户报）：对话推进到「葛莱森警长的委托信」后，手写信笺没有在剧情中展示出来。
##
## 根因：`detective_scene.gd:_input()` 处理点击/按键并调用 `_dm.advance()`；而 `dialogue_ended`
##   是在 `advance()` 里**同步**发出的 → `_open_letter_view()` 在 **`_input` 阶段**就创建了信笺层
##   并 `grab_focus()`。Godot 的单事件传播顺序是 `_input` → GUI(`_gui_input`)，于是**同一次点击/按键
##   随后又落到刚弹出的信笺层**（全屏承接者 / 已获焦的 layer）→ 立刻 `_close_letter_view()`。
##   结果：信笺同帧生灭，玩家根本看不到（但"能继续"所以不表现为卡死）。
##
## 断言：
##   A. 同一帧内「开启 → 投递输入」不得关闭信笺（旧代码违反）
##   B. 下一帧再输入 → 正常关闭并启动 s1_letter_rest
##   C. 端到端：走真实 `_input`（push_input 空格）推进 cl0 至结束，信笺在结束后必须仍在
##
## 运行：godot --headless --path godot_project res://scenes/test_letter_view_reveal.tscn

var _fail := 0

func _ready() -> void:
	_run()

func _chk(cond: bool, name: String) -> void:
	if cond:
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)


func _mouse_click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(400, 300)
	e.global_position = e.position
	return e

func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e

func _wheel(up: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = Vector2(960, 540)
	e.global_position = e.position
	return e

## 关闭信笺判定的是"左键**抬起**且位移很小"（以支持放大后拖动平移），
## 故必须按下 + 抬起成对投递
func _mouse_release() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = Vector2(400, 300)
	e.global_position = e.position
	return e

func _click(s) -> void:
	s._on_letter_view_input(_mouse_click())
	s._on_letter_view_input(_mouse_release())

## 完整一次拖动：按下 → 移动 → 抬起
func _drag(s, from: Vector2, to: Vector2) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = from
	d.global_position = from
	s._on_letter_view_input(d)
	var m := InputEventMouseMotion.new()
	m.position = to
	m.global_position = to
	m.relative = to - from
	s._on_letter_view_input(m)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = to
	u.global_position = to
	s._on_letter_view_input(u)


func _run() -> void:
	await get_tree().process_frame
	if GameManager == null:
		printerr("FATAL: GameManager 未就绪")
		get_tree().quit(2)
		return
	var s = load("res://scenes/scene1.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------- A. 同一帧：开启后立即投递输入，不得关闭 ----------
	print("--- A. 同帧输入不得关闭（信笺可见性核心断言）---")
	for tag in ["鼠标左键", "空格"]:
		s._letter_view = null
		s._open_letter_view()
		var opened := s._letter_view != null
		var ev: InputEvent = _mouse_click() if tag == "鼠标左键" else _key(KEY_SPACE)
		# 不 await 地投递：与 _open_letter_view 处于**同一帧**，模拟"_input 阶段开启 → 同事件走 GUI 阶段"。
		# 鼠标要**按下+抬起成对**投递：真实点击就是一对，抬起单独来也可能关掉信笺（曾漏判）。
		# 然后再等一帧（让 call_deferred 的 _close_letter_view 有机会执行）才断言，
		# 否则"同帧被关"在同步断言下看不出来（deferred 尚未 flush）＝假通过。
		s._on_letter_view_input(ev)
		if tag == "鼠标左键":
			s._on_letter_view_input(_mouse_release())
		await get_tree().process_frame
		var still := s._letter_view != null
		_chk(opened and still, "(A) %s：同帧按下+抬起后信笺仍在（旧代码=同帧被关，玩家看不到）" % tag)
		# 清理，避免影响下一轮
		if s._letter_view != null:
			s._letter_view.queue_free()
			s._letter_view = null
		await get_tree().process_frame
		await get_tree().process_frame

	# ---------- B. 下一帧输入 → 正常关闭并续播 ----------
	print("--- B. 下一帧输入应正常关闭并续播 ---")
	s._letter_view = null
	s._open_letter_view()
	await get_tree().process_frame
	_chk(s._letter_view != null, "(B1) 信笺已打开")
	_click(s)
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s._letter_view == null, "(B2) 点击（按下+抬起）→ 信笺关闭（不能因修复而点不动）")
	var r = s._dm.dialogue_resource if s._dm != null else null
	var sid: String = str(r.scene_id) if r != null else ""
	_chk(sid == "s1_letter_rest", "(B3) 关闭后启动后半段对话 s1_letter_rest（实=%s）" % sid)

	# ---------- C. 端到端：真实 _input 路径（push_input 空格） ----------
	print("--- C. 端到端：真实 _input 推进 cl0 → 信笺应仍在 ---")
	if s._dm != null and s._dm.is_active():
		s._dm.dialogue_ended.emit()          # 结束残留对话，避免干扰
		await get_tree().process_frame
	s._letter_view = null
	s._show_commission_letter_dialogue()      # 重放"cl0 说完 → 开信笺"的真实前置
	await get_tree().process_frame
	var active_before: bool = s._dm != null and s._dm.is_active()
	print("  前置：_dm active=%s（若不是 true 则本项 SKIP）" % active_before)
	if active_before:
		var vp := get_viewport()
		vp.push_input(_key(KEY_SPACE))        # 走真实 _input：detective_scene._input → _dm.advance() → dialogue_ended → 开信笺
		# 注意：push_input 是同步派发，_input 阶段结束后同事件的 GUI 阶段也已派发完
		await get_tree().process_frame
		_chk(s._letter_view != null, "(C) 真实按键推进到信笺后，信笺仍在（旧代码=被同一次按键关掉）")
		if s._letter_view != null:
			# 再确认隔帧能正常关闭（按下+抬起）
			_click(s)
			await get_tree().process_frame
			await get_tree().process_frame
			_chk(s._letter_view == null, "(C1) 端到端点掉信笺 → 关闭")
			var r2 = s._dm.dialogue_resource if s._dm != null else null
			var s2: String = str(r2.scene_id) if r2 != null else ""
			_chk(s2 == "s1_letter_rest", "(C2) 端到端关闭后仍进 s1_letter_rest（实=%s）" % s2)
	else:
		print("  [SKIP] (C) 无法建立 cl0 对话前置")

	# ---------- D. 贴图缺失 → 必须走文本兜底（绝不只剩黑幕） ----------
	print("--- D. 贴图不可用时必须有文本兜底 ---")
	s._letter_view = null
	var saved_path: String = s._letter_tex_path
	s._letter_tex_path = "res://assets/ui/__no_such_letter__.jpg"
	s._open_letter_view()
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s._letter_view == null, "(D1) 贴图缺失时不再建出空的信笺黑幕（旧逻辑＝一片黑，玩家观感为没展示）")
	var r3 = s._dm.dialogue_resource if s._dm != null else null
	var s3: String = str(r3.scene_id) if r3 != null else ""
	_chk(s3 == "s1_letter_text", "(D2) 改用对话栏呈递信件全文（实=%s）" % s3)
	var has_body := false
	if r3 != null:
		for n in r3.nodes:
			if str(n.text).find("劳瑞斯顿花园街三号") >= 0:
				has_body = true
	_chk(has_body, "(D3) 兜底文案确实包含信件正文（不是空文本）")
	s._letter_tex_path = saved_path

	# ---------- E. 鼠标滚轮缩放 ----------
	print("--- E. 滚轮缩放（放大/缩小/上下限/重开复位）---")
	s._letter_view = null
	s._open_letter_view()
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s._letter_view != null, "(E1) 信笺已打开")
	_chk(absf(s._letter_zoom - 1.0) < 0.001, "(E2) 初始缩放 = 100%")
	var z0: float = s._letter_zoom
	s._on_letter_view_input(_wheel(true))
	s._on_letter_view_input(_wheel(true))
	s._on_letter_view_input(_wheel(true))
	await get_tree().process_frame
	_chk(s._letter_zoom > z0, "(E3) 向上滚轮 → 放大（%.3f → %.3f）" % [z0, s._letter_zoom])
	_chk(s._letter_view != null, "(E4) 滚轮**不会**关闭信笺")
	if s._letter_tex != null:
		var sz: Vector2 = s._letter_tex.size
		_chk(sz.x > 0.0 and sz.y > 0.0, "(E5) 贴图控件已有尺寸（%s）→ 缩放可实际生效" % str(sz))
		if sz.x > 0.0:
			_chk(absf(s._letter_tex.scale.x - s._letter_zoom) < 0.001,
				"(E6) 缩放已应用到贴图（scale=%.3f / zoom=%.3f）" % [s._letter_tex.scale.x, s._letter_zoom])
	var z1: float = s._letter_zoom
	s._on_letter_view_input(_wheel(false))
	await get_tree().process_frame
	_chk(s._letter_zoom < z1, "(E7) 向下滚轮 → 缩小（%.3f → %.3f）" % [z1, s._letter_zoom])
	for _i in 60:
		s._on_letter_view_input(_wheel(true))
	await get_tree().process_frame
	_chk(s._letter_zoom <= s._LETTER_ZOOM_MAX + 0.001,
		"(E8) 放大有上限 %.1f（实=%.3f）" % [s._LETTER_ZOOM_MAX, s._letter_zoom])
	for _j in 200:
		s._on_letter_view_input(_wheel(false))
	await get_tree().process_frame
	_chk(s._letter_zoom >= s._LETTER_ZOOM_MIN - 0.001,
		"(E9) 缩小有下限 %.1f（实=%.3f）" % [s._LETTER_ZOOM_MIN, s._letter_zoom])
	s._letter_view = null
	s._open_letter_view()
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(absf(s._letter_zoom - 1.0) < 0.001, "(E10) 重新打开 → 缩放复位 100%")
	_click(s)
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------- F. 放大后拖动平移 ----------
	print("--- F. 拖动平移（放大后查看边缘字迹）---")
	s._letter_view = null
	s._open_letter_view()
	await get_tree().process_frame
	await get_tree().process_frame
	_drag(s, Vector2(960, 540), Vector2(1200, 700))
	await get_tree().process_frame
	_chk(s._letter_pan.length() < 0.001, "(F1) 未放大（100%）时拖不动，pan 钳制为 0")
	for _k in 8:
		s._on_letter_view_input(_wheel(true))
	await get_tree().process_frame
	_chk(s._letter_zoom > 1.5, "(F2) 已放大到 %.2f" % s._letter_zoom)
	_drag(s, Vector2(960, 540), Vector2(1160, 740))
	await get_tree().process_frame
	_chk(s._letter_pan.length() > 1.0, "(F3) 放大后拖动 → 平移生效（pan=%s）" % str(s._letter_pan))
	_chk(s._letter_view != null, "(F4) 拖动**不会**关闭信笺")
	for _m in 40:
		_drag(s, Vector2(200, 200), Vector2(1800, 1000))
	await get_tree().process_frame
	var saturated: Vector2 = s._clamp_letter_pan(s._letter_pan * 100.0)
	_chk(s._letter_pan.distance_to(saturated) < 0.001,
		"(F5) 平移有界，会停在可视边界而非无限拖走（pan=%s）" % str(s._letter_pan))
	_click(s)
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s._letter_view == null, "(F6) 拖动之后再点击 → 仍能正常关闭并续播")
	var r4 = s._dm.dialogue_resource if s._dm != null else null
	var s4: String = str(r4.scene_id) if r4 != null else ""
	_chk(s4 == "s1_letter_rest", "(F7) 拖动后关闭仍进 s1_letter_rest（实=%s）" % s4)

	print("=== LETTER_REVEAL: %s (fail=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)
