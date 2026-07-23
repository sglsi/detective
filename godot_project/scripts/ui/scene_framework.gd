extends Control
class_name SceneFramework

## 统一场景 UI 框架 — 优化版（按游戏内容界面.jpg 调整）
## 字体规范：
##   - 英文标题/按钮：GOLD 大写、加间距、深色描边
##   - 中文标签：米色/金色、清晰字号
##   - 对话正文：羊皮纸底 + 深褐衬线 + 合理行距

signal nav_clicked(nav_id: String)
signal action_clicked(action_id: String)

const TOP_H := 50
const LEFT_W := 140
const DIALOGUE_H := 230

# 配色（维多利亚古典）
const COL_BG := Color(0.07, 0.05, 0.03)              # 深褐底
const COL_GOLD := Color(0.86, 0.70, 0.32)            # 烫金
const COL_GOLD_LIGHT := Color(1.0, 0.85, 0.35)       # 亮金
const COL_GOLD_DARK := Color(0.55, 0.40, 0.15)       # 暗金边
const COL_RED := Color(0.50, 0.18, 0.10)             # 暗红
const COL_PARCH := Color(0.86, 0.78, 0.58)            # 羊皮纸
const COL_PARCH_DARK := Color(0.20, 0.14, 0.08)      # 羊皮纸暗（文字）
const COL_PARCH_LIGHT := Color(0.92, 0.85, 0.65)     # 羊皮纸亮
const COL_SHADOW := Color(0.03, 0.02, 0.0)            # 描边黑

var _location := ""
var _time_text := "DAY 1 上午10:30"
var _top_bar: Control
var _left_bar: Control
var _scene_area: Control
var _dialogue_bar: Control
var _speaker_label: Label
var _dialogue_label: Label
var _portraits: Array = []
var _action_btns: Dictionary = {}
var _nav_btns: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_all()

func setup(location: String, time_str: String, bg_tex: Texture2D = null, portraits: Array = []) -> void:
	_location = location
	_time_text = time_str
	_set_top_bar_text()
	if bg_tex: set_scene_background(bg_tex)
	for p in portraits:
		if p is Dictionary and p.has("texture"):
			add_portrait(p["texture"], p.get("name", ""), p.get("pos", Vector2(50, 350)), p.get("size", Vector2(280, 360)))

func set_scene_background(tex: Texture2D) -> void:
	if not _scene_area: return
	var existing = _scene_area.find_child("scene_bg", true, false)
	if existing: existing.queue_free()
	var bg = TextureRect.new()
	bg.name = "scene_bg"
	bg.texture = tex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_area.add_child(bg)
	_scene_area.move_child(bg, 0)

func add_portrait(tex: Texture2D, name_text: String, pos: Vector2, size: Vector2) -> Control:
	var port = _make_portrait(tex, name_text, pos, size)
	_scene_area.add_child(port)
	_portraits.append(port)
	return port

func get_scene_area() -> Control: return _scene_area

func set_dialogue(speaker: String, text: String) -> void:
	if _speaker_label: _speaker_label.text = speaker
	if _dialogue_label: _dialogue_label.text = text

func set_dialogue_color(c: Color) -> void:
	if _speaker_label: _speaker_label.add_theme_color_override("font_color", c)

func show_notification(msg: String) -> void:
	# 顶部 toast 通知（金边背景条）
	var bar = Panel.new()
	bar.name = "notification_bar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.size = Vector2(1920, 56)
	bar.position = Vector2(0, 60)
	bar.z_index = 100
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	sb.border_color = COL_GOLD
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	move_child(bar, get_child_count() - 1)
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.add_theme_color_override("font_outline_color", COL_SHADOW)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(0, 0)
	lbl.size = Vector2(1920, 56)
	lbl.horizontal_alignment = 1
	lbl.vertical_alignment = 1
	bar.add_child(lbl)
	# 淡出动画
	var tw = create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(bar, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		if is_instance_valid(bar): bar.queue_free()
	)

func set_action_active(action_id: String, active: bool) -> void:
	if not _action_btns.has(action_id): return
	var btn = _action_btns[action_id]
	var sb = btn.get_theme_stylebox("normal") as StyleBoxFlat
	if sb == null: return
	if active:
		sb.bg_color = Color(0.45, 0.20, 0.10, 0.95)
		sb.border_color = COL_GOLD_LIGHT
	else:
		sb.bg_color = Color(0.12, 0.09, 0.06, 0.95)
		sb.border_color = COL_GOLD_DARK

# ===== 工具方法 =====

func _mk_gold_box(w: float, h: float, radius: int = 4) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.09, 0.06, 0.95)
	s.border_color = COL_GOLD_DARK
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(radius)
	return s

func _mk_gold_label(t: String, fs: int, color: Color, outline: int = 2) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", COL_SHADOW)
	l.add_theme_constant_override("outline_size", outline)
	return l

# ===== 构建 =====

func _build_all() -> void:
	_build_top_bar()
	_build_left_bar()
	_build_scene_area()
	_build_dialogue_bar()

# === 顶部栏 ===

func _build_top_bar() -> void:
	_top_bar = Control.new()
	_top_bar.name = "top_bar"
	_top_bar.position = Vector2(0, 0); _top_bar.size = Vector2(1920, TOP_H)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_bar)

	# 深褐底
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.03, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(bg)

	# 底部烫金线
	var bar = ColorRect.new()
	bar.color = Color(0.78, 0.62, 0.25, 0.85)
	bar.position = Vector2(0, TOP_H - 3); bar.size = Vector2(1920, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(bar)

	# 左侧位置标识 "221B BAKER STREET" — 加框金边
	var loc_frame = Panel.new()
	loc_frame.size = Vector2(250, TOP_H - 6)
	loc_frame.position = Vector2(10, 3)
	loc_frame.name = "location_frame"
	var lsb = StyleBoxFlat.new()
	lsb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	lsb.border_color = COL_GOLD
	lsb.border_width_left = 2; lsb.border_width_right = 2
	lsb.border_width_top = 2; lsb.border_width_bottom = 2
	lsb.set_corner_radius_all(3)
	loc_frame.add_theme_stylebox_override("panel", lsb)
	loc_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(loc_frame)
	var loc = _mk_gold_label("221B BAKER STREET", 16, COL_GOLD, 2)
	loc.name = "loc_label"
	loc.position = Vector2(10, 3); loc.size = Vector2(250, TOP_H - 6)
	loc.horizontal_alignment = 1; loc.vertical_alignment = 1
	loc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(loc)

	# 中部 5 个导航按钮
	var navs = [
		{"id":"map", "en":"MAP", "zh":"地图", "icon":"🗺"},
		{"id":"casebook", "en":"CASEBOOK", "zh":"案件簿", "icon":"📂"},
		{"id":"evidence", "en":"EVIDENCE", "zh":"证物", "icon":"🔍"},
		{"id":"inventory", "en":"INVENTORY", "zh":"物品栏", "icon":"🎒"},
		{"id":"options", "en":"OPTIONS", "zh":"选项", "icon":"⚙"},
	]
	var nav_y := 4
	var nav_h := TOP_H - 8
	var total_nav_w := 5 * 110
	var nav_x0 := (1920 - total_nav_w) / 2
	for i in navs.size():
		var n = navs[i]
		var btn = _make_nav_button(n, nav_x0 + i * 110, nav_y, 106, nav_h)
		btn.pressed.connect(func(nid=n["id"]): nav_clicked.emit(nid))
		_top_bar.add_child(btn)
		_nav_btns[n["id"]] = btn

	# 右侧时间
	var time_frame = Panel.new()
	time_frame.size = Vector2(180, TOP_H - 6)
	time_frame.position = Vector2(1920 - 8 - 180, 3)
	time_frame.name = "time_frame"
	var tsb = StyleBoxFlat.new()
	tsb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	tsb.border_color = COL_GOLD
	tsb.border_width_left = 2; tsb.border_width_right = 2
	tsb.border_width_top = 2; tsb.border_width_bottom = 2
	tsb.set_corner_radius_all(3)
	time_frame.add_theme_stylebox_override("panel", tsb)
	time_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(time_frame)
	var tl = _mk_gold_label(_time_text, 14, COL_GOLD, 2)
	tl.name = "time_label"
	tl.position = Vector2(1920 - 8 - 180, 3); tl.size = Vector2(180, TOP_H - 6)
	tl.horizontal_alignment = 1; tl.vertical_alignment = 1
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(tl)

func _make_nav_button(n: Dictionary, x: int, y: int, w: int, h: int) -> Button:
	var btn = Button.new()
	btn.name = "nav_" + n["id"]
	btn.text = ""  # 用子节点绘制
	btn.position = Vector2(x, y); btn.size = Vector2(w, h)
	btn.add_theme_stylebox_override("normal", _mk_gold_box(w, h, 3))
	var sh = _mk_gold_box(w, h, 3)
	sh.bg_color = Color(0.20, 0.14, 0.07, 0.95)
	sh.border_color = COL_GOLD_LIGHT
	btn.add_theme_stylebox_override("hover", sh)
	# 英文
	var en = _mk_gold_label(n["en"], 13, COL_GOLD, 2)
	en.text = n["en"]
	en.position = Vector2(0, 4); en.size = Vector2(w, 18)
	en.horizontal_alignment = 1
	en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(en)
	# 中文
	var zh = Label.new()
	zh.text = n["zh"]
	zh.add_theme_font_size_override("font_size", 12)
	zh.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))
	zh.add_theme_color_override("font_outline_color", COL_SHADOW)
	zh.add_theme_constant_override("outline_size", 1)
	zh.position = Vector2(0, 24); zh.size = Vector2(w, 16)
	zh.horizontal_alignment = 1
	zh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(zh)
	return btn

func _set_top_bar_text() -> void:
	if not _top_bar: return
	var loc = _top_bar.find_child("loc_label", true, false)
	if loc: loc.text = _location if _location != "" else "221B BAKER STREET"
	var tl = _top_bar.find_child("time_label", true, false)
	if tl: tl.text = _time_text

# === 左侧栏 ===

func _build_left_bar() -> void:
	_left_bar = Control.new()
	_left_bar.name = "left_bar"
	_left_bar.position = Vector2(0, TOP_H)
	_left_bar.size = Vector2(LEFT_W, 1080 - TOP_H - DIALOGUE_H)
	_left_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_left_bar)

	# 深褐底
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.03, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_bar.add_child(bg)

	# 右边烫金竖线
	var divider = ColorRect.new()
	divider.color = Color(0.78, 0.62, 0.25, 0.7)
	divider.position = Vector2(LEFT_W - 2, 0); divider.size = Vector2(2, 800)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_bar.add_child(divider)

	var actions = [
		{"id":"look", "en":"LOOK", "zh":"观察", "icon":"👁"},
		{"id":"talk", "en":"TALK", "zh":"对话", "icon":"💬"},
		{"id":"examine", "en":"EXAMINE", "zh":"调查", "icon":"🔍"},
		{"id":"think", "en":"THINK", "zh":"思考", "icon":"💡"},
		{"id":"journal", "en":"JOURNAL", "zh":"日志", "icon":"📓"},
		{"id":"save", "en":"SAVE", "zh":"保存", "icon":"💾"},
		{"id":"load", "en":"LOAD", "zh":"读取", "icon":"📂"},
	]
	var btn_w := 116
	var btn_h := 96
	var gap := 8
	var total_h := actions.size() * btn_h + (actions.size() - 1) * gap
	var start_y := 16
	for i in actions.size():
		var a = actions[i]
		var btn = _make_action_button(a, btn_w, btn_h, i)
		btn.position = Vector2((LEFT_W - btn_w) / 2, start_y + i * (btn_h + gap))
		btn.pressed.connect(func(aid=a["id"]): action_clicked.emit(aid))
		_left_bar.add_child(btn)
		_action_btns[a["id"]] = btn

func _make_action_button(a: Dictionary, w: int, h: int, idx: int) -> Button:
	var btn = Button.new()
	btn.name = "action_" + a["id"]
	btn.custom_minimum_size = Vector2(w, h)
	btn.text = ""
	# 圆形金边背景
	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.09, 0.06, 0.95)
	sn.border_color = COL_GOLD
	sn.border_width_left = 2; sn.border_width_right = 2
	sn.border_width_top = 2; sn.border_width_bottom = 2
	sn.set_corner_radius_all(48)  # 接近圆形
	btn.add_theme_stylebox_override("normal", sn)
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.25, 0.16, 0.08, 0.95)
	sh.border_color = COL_GOLD_LIGHT
	sh.border_width_left = 2; sh.border_width_right = 2
	sh.border_width_top = 2; sh.border_width_bottom = 2
	sh.set_corner_radius_all(48)
	btn.add_theme_stylebox_override("hover", sh)
	# 图标（大字号）
	var icon = Label.new()
	icon.text = a["icon"]
	icon.add_theme_font_size_override("font_size", 28)
	icon.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	icon.add_theme_color_override("font_outline_color", COL_SHADOW)
	icon.add_theme_constant_override("outline_size", 1)
	icon.position = Vector2(0, 6); icon.size = Vector2(w, 36)
	icon.horizontal_alignment = 1
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	# 英文大写
	var en = _mk_gold_label(a["en"], 16, COL_GOLD, 2)
	en.position = Vector2(0, 42); en.size = Vector2(w, 22)
	en.horizontal_alignment = 1
	en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(en)
	# 中文
	var zh = Label.new()
	zh.text = a["zh"]
	zh.add_theme_font_size_override("font_size", 13)
	zh.add_theme_color_override("font_color", Color(0.85, 0.72, 0.50))
	zh.add_theme_color_override("font_outline_color", COL_SHADOW)
	zh.add_theme_constant_override("outline_size", 1)
	zh.position = Vector2(0, 66); zh.size = Vector2(w, 18)
	zh.horizontal_alignment = 1
	zh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(zh)
	return btn

# === 中央场景区 ===

func _build_scene_area() -> void:
	_scene_area = Control.new()
	_scene_area.name = "scene_area"
	_scene_area.position = Vector2(LEFT_W, TOP_H)
	_scene_area.size = Vector2(1920 - LEFT_W, 1080 - TOP_H - DIALOGUE_H)
	_scene_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scene_area)

	# 默认深色背景
	var bg = ColorRect.new()
	bg.name = "default_bg"
	bg.color = Color(0.10, 0.07, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_area.add_child(bg)

# === 底部对话栏 ===

func _build_dialogue_bar() -> void:
	_dialogue_bar = Control.new()
	_dialogue_bar.name = "dialogue_bar"
	_dialogue_bar.position = Vector2(0, 1080 - DIALOGUE_H)
	_dialogue_bar.size = Vector2(1920, DIALOGUE_H)
	add_child(_dialogue_bar)

	# 羊皮纸底
	var bg = ColorRect.new()
	bg.color = COL_PARCH
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(bg)

	# 顶部烫金条
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.78, 0.62, 0.25, 0.9)
	top_bar.position = Vector2(0, 0); top_bar.size = Vector2(1920, 4)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(top_bar)

	# 底部烫金条
	var bot_bar = ColorRect.new()
	bot_bar.color = Color(0.55, 0.40, 0.15, 0.7)
	bot_bar.position = Vector2(0, DIALOGUE_H - 2); bot_bar.size = Vector2(1920, 2)
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(bot_bar)

	# 角色名 (左侧烫金深褐框)
	var name_panel = Panel.new()
	name_panel.size = Vector2(280, 42)
	name_panel.position = Vector2(28, 16)
	var nsb = StyleBoxFlat.new()
	nsb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	nsb.border_color = COL_GOLD
	nsb.border_width_left = 2; nsb.border_width_right = 2
	nsb.border_width_top = 2; nsb.border_width_bottom = 2
	nsb.set_corner_radius_all(4)
	name_panel.add_theme_stylebox_override("panel", nsb)
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(name_panel)
	_speaker_label = Label.new()
	_speaker_label.name = "speaker"
	_speaker_label.text = "Holmes:"
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_speaker_label.add_theme_color_override("font_outline_color", COL_SHADOW)
	_speaker_label.add_theme_constant_override("outline_size", 2)
	_speaker_label.position = Vector2(36, 20); _speaker_label.size = Vector2(264, 34)
	_speaker_label.vertical_alignment = 1
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(_speaker_label)

	# 对话文本（衬线深褐，大字号，羊皮纸上易读）
	_dialogue_label = Label.new()
	_dialogue_label.name = "dialogue_text"
	_dialogue_label.text = ""
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 24)
	_dialogue_label.add_theme_color_override("font_color", COL_PARCH_DARK)
	_dialogue_label.add_theme_constant_override("line_spacing", 6)
	_dialogue_label.position = Vector2(50, 70); _dialogue_label.size = Vector2(1840, 140)
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(_dialogue_label)

	# 底部进度提示
	var hint = Label.new()
	hint.name = "dialogue_hint"
	hint.text = "▼ 点击继续"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.40, 0.30, 0.20))
	hint.position = Vector2(1700, 205); hint.size = Vector2(200, 20)
	hint.horizontal_alignment = 2
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(hint)

# === 角色立绘（带金边框+名字烫金条） ===

func _make_portrait(tex: Texture2D, name_text: String, pos: Vector2, size: Vector2) -> Control:
	var port = Control.new()
	port.name = "portrait_" + name_text.replace(" ", "_")
	port.position = pos; port.size = size
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 烫金边框
	var frame = Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	fsb.border_color = COL_GOLD
	fsb.border_width_left = 3; fsb.border_width_right = 3
	fsb.border_width_top = 3; fsb.border_width_bottom = 3
	fsb.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port.add_child(frame)

	# 图片
	var img = TextureRect.new()
	img.name = "img"
	img.texture = tex
	img.position = Vector2(6, 6); img.size = size - Vector2(12, 12)
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port.add_child(img)

	# 名字标签
	if name_text != "":
		var name_lbl = Label.new()
		name_lbl.name = "name_label"
		name_lbl.text = name_text
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
		name_lbl.add_theme_color_override("font_outline_color", COL_SHADOW)
		name_lbl.add_theme_constant_override("outline_size", 2)
		var name_panel = Panel.new()
		name_panel.position = Vector2(15, size.y - 36); name_panel.size = Vector2(size.x - 30, 30)
		var npsb = StyleBoxFlat.new()
		npsb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
		npsb.border_color = COL_GOLD
		npsb.border_width_left = 1; npsb.border_width_right = 1
		npsb.border_width_top = 1; npsb.border_width_bottom = 1
		npsb.set_corner_radius_all(3)
		name_panel.add_theme_stylebox_override("panel", npsb)
		name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		port.add_child(name_panel)
		name_lbl.position = Vector2(0, 0); name_lbl.size = Vector2(size.x - 30, 30)
		name_lbl.horizontal_alignment = 1; name_lbl.vertical_alignment = 1
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_panel.add_child(name_lbl)

	return port
