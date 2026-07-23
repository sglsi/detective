extends Control

## 主菜单 -- 注册/登录 + 存档（仅注册用户）

enum MenuState { TITLE, OPTIONS, LOGIN, REGISTER }
var _state := MenuState.TITLE
var _auth_panel: Control
var _message_lbl: Label
var _root: Control

func _ready() -> void:
	# 背景
	var bg = TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex = load("res://assets/ui/textures/主标题界面.jpg")
	if tex: bg.texture = tex
	add_child(bg)
	var dim = ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 221B BAKER STREET
	var addr = Label.new()
	addr.text = "--  221B  BAKER  STREET  --"
	addr.add_theme_font_size_override("font_size", 22)
	addr.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	addr.position = Vector2(0, 60); addr.size = Vector2(1920, 35)
	addr.horizontal_alignment = 1; addr.vertical_alignment = 1
	_root.add_child(addr)

	# SHERLOCK
	var t1 = Label.new()
	t1.text = "SHERLOCK"
	t1.add_theme_font_size_override("font_size", 110)
	t1.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t1.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05))
	t1.add_theme_constant_override("outline_size", 6)
	t1.position = Vector2(0, 130); t1.size = Vector2(1920, 140)
	t1.horizontal_alignment = 1; t1.vertical_alignment = 1
	_root.add_child(t1)

	# HOLMES
	var t2 = Label.new()
	t2.text = "HOLMES"
	t2.add_theme_font_size_override("font_size", 110)
	t2.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t2.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05))
	t2.add_theme_constant_override("outline_size", 6)
	t2.position = Vector2(0, 270); t2.size = Vector2(1920, 140)
	t2.horizontal_alignment = 1; t2.vertical_alignment = 1
	_root.add_child(t2)

	# Subtitle
	var sub1 = Label.new()
	sub1.text = "THE  CASE  of  the  CRIMSON  LETTER"
	sub1.add_theme_font_size_override("font_size", 26)
	sub1.add_theme_color_override("font_color", Color(0.75, 0.30, 0.25))
	sub1.position = Vector2(0, 425); sub1.size = Vector2(1920, 35)
	sub1.horizontal_alignment = 1; sub1.vertical_alignment = 1
	_root.add_child(sub1)

	var sub2 = Label.new()
	sub2.text = "福尔摩斯：猩红情书"
	sub2.add_theme_font_size_override("font_size", 32)
	sub2.add_theme_color_override("font_color", Color(0.88, 0.74, 0.42))
	sub2.position = Vector2(0, 470); sub2.size = Vector2(1920, 45)
	sub2.horizontal_alignment = 1; sub2.vertical_alignment = 1
	_root.add_child(sub2)

	# 分割线
	var div = ColorRect.new()
	div.color = Color(0.65, 0.50, 0.20, 0.6)
	div.position = Vector2(660, 530); div.size = Vector2(600, 2)
	_root.add_child(div)

	# 开始游戏（需登录后查存档）
	var bs = mkbtn("开 始 游 戏", Vector2(660, 600), Vector2(600, 90), true)
	bs.pressed.connect(func(): _on_start_pressed())
	_root.add_child(bs)

	# 选项
	var bo = mkbtn("选    项", Vector2(720, 720), Vector2(220, 60), false)
	bo.pressed.connect(func(): _show_options())
	_root.add_child(bo)

	# 退出
	var bq = mkbtn("退出游戏", Vector2(980, 720), Vector2(220, 60), false)
	bq.pressed.connect(func():
		if OS.has_feature("web"):
			if JavaScriptBridge: JavaScriptBridge.eval("window.location.reload()", true)
		else: get_tree().quit())
	_root.add_child(bq)

	# 游客（不存档，直进游戏）
	var bg2 = mkbtn("以游客身份继续", Vector2(660, 810), Vector2(600, 45), false, true)
	bg2.pressed.connect(func():
		if GameManager: GameManager.is_guest = true
		_go_scene("res://scenes/scene1.tscn"))
	_root.add_child(bg2)

	# 版权
	var footer = Label.new()
	footer.text = "(C)  维多利亚伦敦探案  -  侦探推理游戏"
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28))
	footer.position = Vector2(0, 1030); footer.size = Vector2(1920, 30)
	footer.horizontal_alignment = 1
	_root.add_child(footer)

	# Auth signals
	if AuthManager:
		AuthManager.login_success.connect(func(_id, _un):
			if _auth_panel and is_instance_valid(_auth_panel): _auth_panel.queue_free(); _auth_panel = null
			_check_and_go())
		AuthManager.login_failed.connect(func(err):
			if _message_lbl: _message_lbl.text = "X " + err)
		AuthManager.registration_success.connect(func(_id, _un):
			if _auth_panel and is_instance_valid(_auth_panel): _auth_panel.queue_free(); _auth_panel = null
			_check_and_go())
		AuthManager.registration_failed.connect(func(err):
			if _message_lbl: _message_lbl.text = "X " + err)

# -- 按钮创建 --

func mkbtn(text: String, pos: Vector2, sz: Vector2, primary: bool, small := false) -> Button:
	var btn = Button.new()
	btn.text = text; btn.position = pos; btn.size = sz
	var fs := 32
	if small: fs = 20
	elif not primary: fs = 22
	btn.add_theme_font_size_override("font_size", fs)
	var fc := Color(0.92, 0.84, 0.55) if primary else Color(0.95, 0.90, 0.78)
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.65))
	var sn = StyleBoxFlat.new(); var sh = StyleBoxFlat.new(); var sp = StyleBoxFlat.new()
	if primary:
		sn.bg_color = Color(0.50, 0.10, 0.10, 0.95); sn.border_color = Color(0.85, 0.65, 0.25)
		sh.bg_color = Color(0.60, 0.15, 0.15, 0.98); sh.border_color = Color(0.95, 0.78, 0.40)
		sp.bg_color = Color(0.40, 0.08, 0.08, 0.95); sp.border_color = Color(0.75, 0.55, 0.20)
	else:
		sn.bg_color = Color(0.20, 0.16, 0.10, 0.85); sn.border_color = Color(0.55, 0.42, 0.20)
		sh.bg_color = Color(0.30, 0.24, 0.15, 0.92); sh.border_color = Color(0.75, 0.58, 0.30)
		sp.bg_color = Color(0.15, 0.12, 0.08, 0.95); sp.border_color = Color(0.50, 0.38, 0.18)
	for s in [sn, sh, sp]:
		s.border_width_left = 2; s.border_width_right = 2
		s.border_width_top = 2; s.border_width_bottom = 2; s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", sh)
	return btn

# -- 开始游戏流程 --

func _on_start_pressed() -> void:
	if AuthManager and AuthManager.is_authenticated():
		_check_and_go()
	else:
		_show_auth(false)

## 注册用户查存档，游客跳过
func _check_and_go() -> void:
	var is_guest := GameManager.is_guest if GameManager else false
	if is_guest:
		_go_scene("res://scenes/scene1.tscn")
		return

	# 注册用户：查云端存档
	if not SaveManager or not APIManager or not APIManager.is_online:
		_go_scene("res://scenes/scene1.tscn")
		return

	if GameManager: GameManager.current_case_id = "case_blood_letter"
	var r = await APIManager.get_latest_save("case_blood_letter")
	var has = not r.get("error", true) and not r.get("data", {}).is_empty()
	if has: _show_save_dialog()
	else: _go_scene("res://scenes/scene1.tscn")

func _show_save_dialog() -> void:
	var p = Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dim)

	var f = Panel.new()
	f.size = Vector2(600, 380)
	f.position = Vector2(1920/2 - 300, 1080/2 - 190)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, 0.97)
	sb.border_color = Color(0.78, 0.62, 0.28)
	sb.border_width_left = 3; sb.border_width_right = 3
	sb.border_width_top = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	f.add_theme_stylebox_override("panel", sb)
	p.add_child(f)

	var tl = Label.new()
	tl.text = "检测到存档进度"
	tl.add_theme_font_size_override("font_size", 30)
	tl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	tl.position = Vector2(40, 30); tl.size = Vector2(520, 45)
	f.add_child(tl)

	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.42, 0.20, 0.5)
	sep.position = Vector2(40, 85); sep.size = Vector2(520, 2)
	f.add_child(sep)

	var dl = Label.new()
	dl.text = "你之前在贝克街221B的冒险尚未完成。\n是否要继续上次的进度？"
	dl.add_theme_font_size_override("font_size", 20)
	dl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	dl.position = Vector2(40, 105); dl.size = Vector2(520, 70)
	f.add_child(dl)

	var bc = mkbtn("继 续 游 戏", Vector2(40, 190), Vector2(520, 60), true)
	bc.pressed.connect(func():
		p.queue_free()
		_go_save())
	f.add_child(bc)

	var bn = mkbtn("重 新 开 始", Vector2(40, 265), Vector2(520, 48), false)
	bn.pressed.connect(func():
		p.queue_free()
		if GameManager: GameManager.current_scene_id = "scene1"
		_go_scene("res://scenes/scene1.tscn"))
	f.add_child(bn)

	var bx = mkbtn("返    回", Vector2(40, 324), Vector2(520, 38), false, true)
	bx.pressed.connect(func(): p.queue_free())
	f.add_child(bx)

# -- 加载存档 --

func _go_save() -> void:
	if not SaveManager:
		_go_scene("res://scenes/scene1.tscn")
		return
	if GameManager: GameManager.current_case_id = "case_blood_letter"
	var ok = await SaveManager.load_game()
	if ok and GameManager.current_scene_id != "":
		var spath = "res://scenes/" + GameManager.current_scene_id + ".tscn"
		if ResourceLoader.exists(spath):
			_go_scene(spath)
			return
	# 加载失败 → 从头开始
	if GameManager: GameManager.current_scene_id = "scene1"
	_go_scene("res://scenes/scene1.tscn")

## 可靠场景跳转
func _go_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		# 兜底：总是跳 scene1
		get_tree().change_scene_to_file("res://scenes/scene1.tscn")

# -- 登录/注册面板 --

func _show_auth(is_reg: bool) -> void:
	if _auth_panel and is_instance_valid(_auth_panel): _auth_panel.queue_free()
	_state = MenuState.REGISTER if is_reg else MenuState.LOGIN
	_auth_panel = Control.new()
	_auth_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_auth_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_auth_panel)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auth_panel.add_child(dim)

	var p = Panel.new()
	p.size = Vector2(640, 640)
	p.position = Vector2(1920/2 - 320, 1080/2 - 320)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, 0.97)
	sb.border_color = Color(0.78, 0.62, 0.28)
	sb.border_width_left = 3; sb.border_width_right = 3
	sb.border_width_top = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	_auth_panel.add_child(p)

	var t = Label.new()
	t.text = "账户登录" if not is_reg else "注册新账号"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t.position = Vector2(40, 30); t.size = Vector2(560, 45)
	p.add_child(t)

	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.42, 0.20, 0.5)
	sep.position = Vector2(40, 85); sep.size = Vector2(560, 2)
	p.add_child(sep)

	var fnames: Array
	if is_reg: fnames = ["用户名", "邮箱", "密码", "手机号（可选）"]
	else: fnames = ["邮箱", "密码"]

	for i in fnames.size():
		var lbl = Label.new()
		lbl.text = "  " + fnames[i] + ":"
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
		lbl.position = Vector2(40, 110 + i * 75); lbl.size = Vector2(560, 28)
		p.add_child(lbl)
		var inp = LineEdit.new()
		inp.name = "fi_" + str(i)
		inp.placeholder_text = "请输入" + fnames[i]
		inp.position = Vector2(40, 110 + i * 75 + 30); inp.size = Vector2(560, 38)
		inp.add_theme_font_size_override("font_size", 18)
		if fnames[i] == "密码": inp.secret = true
		var isb = StyleBoxFlat.new()
		isb.bg_color = Color(0.20, 0.16, 0.10, 0.95); isb.border_color = Color(0.55, 0.42, 0.20)
		isb.border_width_left = 1; isb.border_width_right = 1
		isb.border_width_top = 1; isb.border_width_bottom = 1; isb.set_corner_radius_all(4)
		inp.add_theme_stylebox_override("normal", isb)
		var isb2 = isb.duplicate()
		isb2.border_color = Color(0.85, 0.65, 0.25)
		isb2.border_width_left = 2; isb2.border_width_right = 2
		isb2.border_width_top = 2; isb2.border_width_bottom = 2
		inp.add_theme_stylebox_override("focus", isb2)
		p.add_child(inp)

	_message_lbl = Label.new()
	_message_lbl.add_theme_font_size_override("font_size", 16)
	_message_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	_message_lbl.position = Vector2(40, 430); _message_lbl.size = Vector2(560, 25)
	_message_lbl.horizontal_alignment = 1
	p.add_child(_message_lbl)

	var bs = mkbtn("立即登录" if not is_reg else "立即注册", Vector2(40, 470), Vector2(560, 60), true)
	bs.pressed.connect(func():
		if not AuthManager: return
		var vals: Array = []
		for i in fnames.size():
			var inp = _auth_panel.find_child("fi_" + str(i), true, false)
			if inp and inp is LineEdit: vals.append((inp as LineEdit).text)
			else: vals.append("")
		_message_lbl.text = ""
		if _state == MenuState.LOGIN:
			if vals.size() < 2 or vals[0] == "" or vals[1] == "": _message_lbl.text = "请填写邮箱和密码"; return
			await AuthManager.login(vals[0], vals[1])
		else:
			if vals.size() < 3 or vals[0] == "" or vals[1] == "" or vals[2] == "": _message_lbl.text = "请填写用户名、邮箱和密码"; return
			await AuthManager.register(vals[0], vals[1], vals[2], vals[3] if vals.size() > 3 else ""))
	p.add_child(bs)

	var sw = mkbtn("还没有账号？立即注册" if not is_reg else "已有账号？返回登录", Vector2(40, 545), Vector2(560, 42), false, true)
	sw.pressed.connect(func(): _show_auth(not is_reg))
	p.add_child(sw)

	var cx = mkbtn("返回", Vector2(40, 595), Vector2(560, 35), false, true)
	cx.pressed.connect(func(): _auth_panel.queue_free() if _auth_panel else null)
	p.add_child(cx)

# -- 选项面板 --

func _show_options() -> void:
	var p = Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dim)

	var f = Panel.new()
	f.size = Vector2(640, 480)
	f.position = Vector2(1920/2 - 320, 1080/2 - 240)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, 0.97)
	sb.border_color = Color(0.78, 0.62, 0.28)
	sb.border_width_left = 3; sb.border_width_right = 3
	sb.border_width_top = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	f.add_theme_stylebox_override("panel", sb)
	p.add_child(f)

	var t = Label.new()
	t.text = "选    项"
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t.position = Vector2(40, 25); t.size = Vector2(560, 50)
	f.add_child(t)

	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.42, 0.20, 0.5)
	sep.position = Vector2(40, 90); sep.size = Vector2(560, 2)
	f.add_child(sep)

	var ph = Label.new()
	ph.text = "    难度选择      普通 / 困难 / 简单\n\n    音效与音乐    即将开放\n\n    画面质量      自适应\n\n    语言          简体中文\n\n    操作说明      点击 / Enter 推进对话"
	ph.add_theme_font_size_override("font_size", 18)
	ph.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	ph.position = Vector2(40, 110); ph.size = Vector2(560, 280)
	f.add_child(ph)

	var bc = mkbtn("返    回", Vector2(180, 400), Vector2(280, 50), true)
	bc.pressed.connect(func(): p.queue_free())
	f.add_child(bc)
