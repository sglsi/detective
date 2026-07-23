extends Control

## 主菜单 — 完整版（渐进构建）

enum MenuState { TITLE, OPTIONS, LOGIN, REGISTER }
var _state := MenuState.TITLE

func _ready() -> void:
	# 背景图
	var bg = TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex = load("res://assets/ui/textures/主标题界面.jpg")
	if tex: bg.texture = tex
	add_child(bg)

	# 221B BAKER STREET
	_add_label("--  221B  BAKER  STREET  --", 22, Color(0.85, 0.78, 0.62), Vector2(0, 60), Vector2(1920, 35), 1)
	# SHERLOCK
	_add_label_big("SHERLOCK", 110, Color(0.92, 0.82, 0.45), Vector2(0, 130), true)
	# HOLMES
	_add_label_big("HOLMES", 110, Color(0.92, 0.82, 0.45), Vector2(0, 270), true)
	# THE CASE of the CRIMSON LETTER
	_add_label("THE  CASE  of  the  CRIMSON  LETTER", 26, Color(0.75, 0.30, 0.25), Vector2(0, 425), Vector2(1920, 35), 1)
	# 福尔摩斯：猩红情书
	_add_label("福尔摩斯：猩红情书", 32, Color(0.88, 0.74, 0.42), Vector2(0, 470), Vector2(1920, 45), 1)

	# 分割线
	var div = ColorRect.new()
	div.color = Color(0.65, 0.50, 0.20, 0.6)
	div.position = Vector2(660, 530); div.size = Vector2(600, 2)
	add_child(div)

	# 开始游戏
	_add_btn("开 始 游 戏", Vector2(660, 600), Vector2(600, 90), true, func(): _on_start())
	# 选项
	_add_btn("选    项", Vector2(720, 720), Vector2(220, 60), false, func(): _show_options())
	# 退出
	_add_btn("退出游戏", Vector2(980, 720), Vector2(220, 60), false, func(): _on_quit())
	# 游客
	_add_btn("以游客身份继续", Vector2(660, 810), Vector2(600, 45), false, func(): _on_guest(), 20)
	# 版权
	_add_label("(C)  维多利亚伦敦探案  -  侦探推理游戏", 14, Color(0.45, 0.38, 0.28), Vector2(0, 1030), Vector2(1920, 30), 1)

	# Auth 信号
	if AuthManager:
		AuthManager.login_success.connect(func(_id, _un): _check_and_go())
		AuthManager.registration_success.connect(func(_id, _un): _check_and_go())
		AuthManager.login_failed.connect(func(err): _set_msg(err))
		AuthManager.registration_failed.connect(func(err): _set_msg(err))

# -- 辅助方法 --

func _add_label(text: String, fs: int, fc: Color, pos: Vector2, sz: Vector2, align: int) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", fc)
	l.position = pos; l.size = sz
	l.horizontal_alignment = align
	add_child(l)

func _add_label_big(text: String, fs: int, fc: Color, pos: Vector2, has_outline: bool) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", fc)
	if has_outline:
		l.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05))
		l.add_theme_constant_override("outline_size", 6)
	l.position = pos; l.size = Vector2(1920, 140)
	l.horizontal_alignment = 1; l.vertical_alignment = 1
	add_child(l)

func _add_btn(text: String, pos: Vector2, sz: Vector2, primary: bool, callback: Callable, fs_override := 0) -> void:
	var btn = Button.new()
	btn.text = text; btn.position = pos; btn.size = sz
	var fs := fs_override
	if fs == 0: fs = 32 if primary else 22
	btn.add_theme_font_size_override("font_size", fs)
	var fc := Color(0.92, 0.84, 0.55) if primary else Color(0.95, 0.90, 0.78)
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.65))

	var sn = StyleBoxFlat.new()
	var sh = StyleBoxFlat.new()
	var sp = StyleBoxFlat.new()
	if primary:
		sn.bg_color = Color(0.50, 0.10, 0.10, 0.95); sn.border_color = Color(0.85, 0.65, 0.25)
		sh.bg_color = Color(0.60, 0.15, 0.15, 0.98); sh.border_color = Color(0.95, 0.78, 0.40)
		sp.bg_color = Color(0.40, 0.08, 0.08, 0.95); sp.border_color = Color(0.75, 0.55, 0.20)
	else:
		sn.bg_color = Color(0.20, 0.16, 0.10, 0.85); sn.border_color = Color(0.55, 0.42, 0.20)
		sh.bg_color = Color(0.30, 0.24, 0.15, 0.92); sh.border_color = Color(0.75, 0.58, 0.30)
		sp.bg_color = Color(0.15, 0.12, 0.08, 0.95); sp.border_color = Color(0.50, 0.38, 0.18)

	for sb in [sn, sh, sp]:
		sb.border_width_left = 2; sb.border_width_right = 2
		sb.border_width_top = 2; sb.border_width_bottom = 2
		sb.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", sh)
	btn.pressed.connect(callback)
	add_child(btn)

# -- 按钮响应 --

func _on_start() -> void:
	if AuthManager and AuthManager.is_authenticated():
		_check_and_go()
	else:
		_show_auth(false)

func _on_guest() -> void:
	if GameManager: GameManager.is_guest = true
	if GameManager: GameManager.current_case_id = "case_blood_letter"
	if GameManager: GameManager.current_scene_id = "scene1"
	get_tree().change_scene_to_file("res://scenes/scene1.tscn")

func _on_quit() -> void:
	if OS.has_feature("web"):
		if JavaScriptBridge: JavaScriptBridge.eval("window.location.reload()", true)
	else: get_tree().quit()

# -- 存档检查（仅注册用户） --

func _check_and_go() -> void:
	if not SaveManager or not APIManager or not APIManager.is_online:
		_go("res://scenes/scene1.tscn"); return

	if GameManager: GameManager.current_case_id = "case_blood_letter"
	var r = await APIManager.get_latest_save("case_blood_letter")
	var has = not r.get("error", true) and not r.get("data", {}).is_empty()
	if has: _show_save_dialog()
	else: _go("res://scenes/scene1.tscn")

func _show_save_dialog() -> void:
	var p = _make_panel(600, 380)
	var t = Label.new()
	t.text = "检测到存档进度"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t.position = Vector2(40, 30); t.size = Vector2(520, 45)
	p.add_child(t)
	_add_sep(p, 85)
	var d = Label.new()
	d.text = "之前的冒险尚未完成。\n是否继续上次的进度？"
	d.add_theme_font_size_override("font_size", 20)
	d.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	d.position = Vector2(40, 105); d.size = Vector2(520, 70)
	p.add_child(d)
	var bc = Button.new(); _style_btn(bc, "继 续 游 戏", Vector2(40, 190), Vector2(520, 60), true, 28)
	bc.pressed.connect(func(): p.get_parent().queue_free(); _load_save())
	p.add_child(bc)
	var bn = Button.new(); _style_btn(bn, "重 新 开 始", Vector2(40, 265), Vector2(520, 48), false, 22)
	bn.pressed.connect(func(): p.get_parent().queue_free(); _go("res://scenes/scene1.tscn"))
	p.add_child(bn)
	var bx = Button.new(); _style_btn(bx, "返    回", Vector2(40, 324), Vector2(520, 38), false, 18)
	bx.pressed.connect(func(): p.get_parent().queue_free())
	p.add_child(bx)

func _load_save() -> void:
	if GameManager: GameManager.current_case_id = "case_blood_letter"
	if SaveManager:
		var ok = await SaveManager.load_game()
		if ok and GameManager.current_scene_id != "":
			var sp = "res://scenes/" + GameManager.current_scene_id + ".tscn"
			if ResourceLoader.exists(sp): _go(sp); return
	_go("res://scenes/scene1.tscn")

func _go(path: String) -> void:
	if ResourceLoader.exists(path): get_tree().change_scene_to_file(path)
	else: get_tree().change_scene_to_file("res://scenes/scene1.tscn")

# -- 登录/注册面板 --

var _msg_lbl: Label

func _show_auth(is_reg: bool) -> void:
	_state = MenuState.REGISTER if is_reg else MenuState.LOGIN
	var p = _make_panel(640, 640)
	var t = Label.new()
	t.text = "账户登录" if not is_reg else "注册新账号"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t.position = Vector2(40, 30); t.size = Vector2(560, 45)
	p.add_child(t)
	_add_sep(p, 85)

	var fnames: Array
	if is_reg: fnames = ["用户名", "邮箱", "密码", "手机号"]
	else: fnames = ["邮箱", "密码"]

	for i in fnames.size():
		var lb = Label.new()
		lb.text = "  " + fnames[i] + ":"
		lb.add_theme_font_size_override("font_size", 18)
		lb.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
		lb.position = Vector2(40, 110 + i*75); lb.size = Vector2(560, 28)
		p.add_child(lb)
		var inp = LineEdit.new()
		inp.name = "fi_" + str(i)
		inp.placeholder_text = "请输入" + fnames[i]
		inp.position = Vector2(40, 140 + i*75); inp.size = Vector2(560, 38)
		inp.add_theme_font_size_override("font_size", 18)
		if fnames[i] == "密码": inp.secret = true
		p.add_child(inp)

	_msg_lbl = Label.new()
	_msg_lbl.add_theme_font_size_override("font_size", 16)
	_msg_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	_msg_lbl.position = Vector2(40, 430); _msg_lbl.size = Vector2(560, 25)
	_msg_lbl.horizontal_alignment = 1
	p.add_child(_msg_lbl)

	var bs = Button.new()
	_style_btn(bs, "立即登录" if not is_reg else "立即注册", Vector2(40, 470), Vector2(560, 60), true, 28)
	bs.pressed.connect(func(): _on_auth_submit(p, is_reg))
	p.add_child(bs)

	var sw = Button.new()
	_style_btn(sw, "还没有账号？立即注册" if not is_reg else "已有账号？返回登录", Vector2(40, 540), Vector2(560, 42), false, 18)
	sw.pressed.connect(func(): p.get_parent().queue_free(); _show_auth(not is_reg))
	p.add_child(sw)

	var cx = Button.new()
	_style_btn(cx, "返回", Vector2(40, 590), Vector2(560, 35), false, 16)
	cx.pressed.connect(func(): p.get_parent().queue_free())
	p.add_child(cx)

func _on_auth_submit(p: Panel, is_reg: bool) -> void:
	if not AuthManager: return
	var v: Array = []
	for i in range(2 if not is_reg else 4):
		var inp = p.find_child("fi_" + str(i), true, false)
		v.append(inp.text if inp and inp is LineEdit else "")

	if is_reg:
		if v[0] == "" or v[1] == "" or v[2] == "": _set_msg("请填写用户名、邮箱和密码"); return
		await AuthManager.register(v[0], v[1], v[2], v[3])
	else:
		if v[0] == "" or v[1] == "": _set_msg("请填写邮箱和密码"); return
		await AuthManager.login(v[0], v[1])

func _set_msg(txt: String) -> void:
	if _msg_lbl: _msg_lbl.text = txt

# -- 选项面板 --

func _show_options() -> void:
	var p = _make_panel(640, 480)
	var t = Label.new()
	t.text = "选    项"
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	t.position = Vector2(40, 25); t.size = Vector2(560, 50)
	p.add_child(t)
	_add_sep(p, 90)
	var ph = Label.new()
	ph.text = "    难度选择      普通 / 困难 / 简单\n\n    音效与音乐    即将开放\n\n    画面质量      自适应\n\n    语言          简体中文\n\n    操作说明      点击 / Enter 推进对话"
	ph.add_theme_font_size_override("font_size", 18)
	ph.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	ph.position = Vector2(40, 110); ph.size = Vector2(560, 280)
	p.add_child(ph)
	var bc = Button.new()
	_style_btn(bc, "返    回", Vector2(180, 400), Vector2(280, 50), true, 28)
	bc.pressed.connect(func(): p.get_parent().queue_free())
	p.add_child(bc)

# -- 面板/按钮工厂 --

func _make_panel(w: int, h: int) -> Panel:
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var f = Panel.new()
	f.size = Vector2(w, h)
	f.position = Vector2(1920/2 - w/2, 1080/2 - h/2)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, 0.97)
	sb.border_color = Color(0.78, 0.62, 0.28)
	sb.border_width_left = 3; sb.border_width_right = 3
	sb.border_width_top = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	f.add_theme_stylebox_override("panel", sb)
	overlay.add_child(f)
	return f

func _add_sep(parent: Node, y: int) -> void:
	var s = ColorRect.new()
	s.color = Color(0.55, 0.42, 0.20, 0.5)
	s.position = Vector2(40, y); s.size = Vector2(parent.size.x - 80, 2)
	parent.add_child(s)

func _style_btn(btn: Button, text: String, pos: Vector2, sz: Vector2, primary: bool, fs: int) -> void:
	btn.text = text; btn.position = pos; btn.size = sz
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
		s.border_width_top = 2; s.border_width_bottom = 2
		s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", sh)
