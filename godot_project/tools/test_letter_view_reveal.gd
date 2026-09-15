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
		# 然后再等一帧（让 call_deferred 的 _close_letter_view 有机会执行）才断言，
		# 否则"同帧被关"在同步断言下看不出来（deferred 尚未 flush）＝假通过。
		s._on_letter_view_input(ev)
		await get_tree().process_frame
		var still := s._letter_view != null
		_chk(opened and still, "(A) %s：同帧输入后信笺仍在（旧代码=同帧被关，玩家看不到）" % tag)
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
	s._on_letter_view_input(_mouse_click())
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s._letter_view == null, "(B2) 隔帧点击 → 信笺关闭（不能因修复而点不动）")
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
			# 再确认隔帧能正常关闭
			s._on_letter_view_input(_mouse_click())
			await get_tree().process_frame
			await get_tree().process_frame
			var r2 = s._dm.dialogue_resource if s._dm != null else null
			var s2: String = str(r2.scene_id) if r2 != null else ""
			_chk(s2 == "s1_letter_rest", "(C2) 端到端关闭后仍进 s1_letter_rest（实=%s）" % s2)
	else:
		print("  [SKIP] (C) 无法建立 cl0 对话前置")

	print("=== LETTER_REVEAL: %s (fail=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)
