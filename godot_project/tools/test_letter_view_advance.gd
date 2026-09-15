extends Control

## 回归测试：场景一「委托信手写信笺」必须能被点击/按键继续。
## 现象（用户报）：推进到手写信笺后，鼠标、键盘都没有反应，游戏无法继续。
## 根因：点击处理只挂在 layer 的 gui_input 上，而全屏 bg(ColorRect) 是 MOUSE_FILTER_STOP——
##   GUI 拾取只给「最上层非 IGNORE 控件」（bg），且 gui_input 不向父级冒泡 → layer 永不触发；
##   键盘也因 layer 不可获焦 / 无键位处理而无响应。
##
## ⚠️ headless 下 GUI 拾取本身不可用（push_input 后 gui_get_hovered_control() 恒为 null），
##   故本测试用两条可靠手段：
##   (A) 结构性不变量：全屏点击承接者必须「非 IGNORE 且自身 gui_input 已连接」（旧代码即违反此项）；
##   (B) 直接向处理函数投递鼠标/键盘事件，断言信笺关闭且后段对话启动。
##
## 运行：godot --headless --path godot_project res://scenes/test_letter_view_advance.tscn

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

	# ① 打开委托信信笺（等价于 cl0 说完触发 _open_letter_view）
	s._open_letter_view()
	await get_tree().process_frame
	_chk(s._letter_view != null, "信笺全屏层已打开")
	if s._letter_view == null:
		print("=== LETTER_VIEW: FAIL (fail=%d) ===" % _fail)
		get_tree().quit(1)
		return

	var lv: Control = s._letter_view
	var full := lv.get_rect().size
	print("  layer rect=%s focus_mode=%d" % [str(full), lv.focus_mode])

	# ② (A) 结构性不变量：存在「非 IGNORE 且自身接了 gui_input」的全屏承接者
	var catcher_ok := false
	var visual_all_ignore := true
	print("  layer 子节点：")
	for c in lv.get_children():
		var conns := 0
		if c.has_signal("gui_input"):
			conns = c.gui_input.get_connections().size()
		var is_full := c is Control and (c as Control).get_rect().size.x >= full.x - 1.0
		print("    - %-12s filter=%d conns=%d fullwidth=%s" % [c.get_class(), c.mouse_filter, conns, is_full])
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if is_full and conns > 0:
				catcher_ok = true
		else:
			pass
	# 纯视觉子节点（非全屏的 Label / 背景图）不应拦截
	for c in lv.get_children():
		if c is TextureRect or c is Label:
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				visual_all_ignore = false
	_chk(catcher_ok, "(A) 存在全屏点击承接者且其 gui_input 已连接（旧代码违反＝点击无反应）")
	_chk(visual_all_ignore, "(A2) 纯视觉子节点(贴图/提示字)均为 IGNORE，不拦截点击")
	_chk(lv.focus_mode != Control.FOCUS_NONE, "(A3) 信笺层可获焦（键盘事件能送进 gui_input）")

	# ③ (B) 鼠标左键 → 关闭并续播
	s._on_letter_view_input(_mouse_click())
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s._letter_view == null, "(B1) 鼠标左键 → 信笺关闭（修复前不响应=卡死）")
	var res = s._dm.dialogue_resource if s._dm != null else null
	var sid: String = str(res.scene_id) if res != null else ""
	_chk(s._dm != null and sid == "s1_letter_rest", "(B2) 关闭后已启动后半段对话 s1_letter_rest（实=%s）" % sid)

	# ④ (B) 键盘（空格 / Esc 各试一次）→ 关闭并续播
	for k in [KEY_SPACE, KEY_ESCAPE]:
		s._open_letter_view()
		await get_tree().process_frame
		_chk(s._letter_view != null, "(B3) 重开信笺成功")
		s._on_letter_view_input(_key(k))
		await get_tree().process_frame
		await get_tree().process_frame
		_chk(s._letter_view == null, "(B4) 按键 %d → 信笺关闭" % k)
		var r2 = s._dm.dialogue_resource if s._dm != null else null
		var s2: String = str(r2.scene_id) if r2 != null else ""
		_chk(s2 == "s1_letter_rest", "(B5) 按键关闭后仍启动 s1_letter_rest（实=%s）" % s2)

	print("=== LETTER_VIEW: %s (fail=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)
