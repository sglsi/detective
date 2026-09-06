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
var _speaker_portrait: TextureRect
var _name_panel: Panel
var _portraits: Array = []
var _action_btns: Dictionary = {}
var _nav_btns: Dictionary = {}
# 放大镜可观察节点：背景 + 各立绘图片纹理（供 ToolBar 直接放大其真实纹理，不依赖屏幕捕获）
var _mag_bg: TextureRect = null
var _mag_portraits: Array[TextureRect] = []

# 摄像机/观察层：可缩放+平移的「世界子树」（背景+立绘+线索圈都挂这里），
# 与对话框/工具栏/推理墙等 UI 分离 —— 缩放世界层时 UI 永远不变形。
# 这是 Control 架构下对 Camera2D 的等价替代（Camera2D 只影响 Node2D，不作用于 Control）。
var _world: Control = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_all()

func setup(location: String, time_str: String, bg_tex: Texture2D = null, portraits: Array = []) -> void:
	# ⚠️ 关键时序修复：父节点（DetectiveScene）在自身 _ready 内 add_child 本框架后，
	# 会立刻调用 _create_observers() → _ui.get_world_layer()。但子节点 _ready 被 Godot 延迟到
	# 父 _ready 之后才执行，届时 _build_all 才建 _world。若此处不同步建好 _world，
	# 则 _create_observers 拿到 null world_layer → 地点类热点 btn 落到错误父节点、圆圈不画
	#（表现为「场景二/三点击线索无反应」）。setup 在 add_child(_ui) 后同步调用，故在此先把世界层建好。
	_ensure_world()
	_location = location
	_time_text = time_str
	_set_top_bar_text()
	if bg_tex: set_scene_background(bg_tex)
	for p in portraits:
		if p is Dictionary and p.has("texture"):
			add_portrait(p["texture"], p.get("name", ""), p.get("pos", Vector2(50, 350)), p.get("size", Vector2(280, 360)))

func set_scene_background(tex: Texture2D) -> void:
	if not _world: return
	var existing = _world.find_child("scene_bg", true, false)
	if existing: existing.queue_free()
	var bg = TextureRect.new()
	bg.name = "scene_bg"
	bg.texture = tex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 背景置于最底层，确保迷雾/灯光层（z_index=-5）叠在背景之上、人物立绘（z=0）之下。
	bg.z_index = -10
	_world.add_child(bg)
	_world.move_child(bg, 0)
	_mag_bg = bg   # 供放大镜直接放大背景纹理

func add_portrait(tex: Texture2D, name_text: String, pos: Vector2, size: Vector2, flip: bool = false) -> Control:
	var port = _make_portrait(tex, name_text, pos, size, flip)
	_world.add_child(port)
	_portraits.append(port)
	return port

func get_scene_area() -> Control: return _scene_area

## M2.x：摄像机世界层与「场景根→世界局部」偏移，供地点类线索命中区/提示圈挂入，
## 使其随缩放/平移与背景一起变换（缩放后仍能精准点）。_world 局部原点 = _scene_area 左上角。
func get_world_layer() -> Control: return _world
func get_world_offset() -> Vector2: return _scene_area.position

# === 对话人物位置映射 ===
# 需求：有福尔摩斯时福尔摩斯在左下角；其他人物在右上角。
# 底部人物对话内容左对齐，顶部人物对话内容右对齐。
const POS_BL := "bottom_left"   # 福尔摩斯
const POS_TR := "top_right"     # 华生 / NPC

## 返回说话人的屏幕位置角色（bottom_left 或 top_right）
static func speaker_position(speaker: String) -> String:
	if speaker == "福尔摩斯":
		return POS_BL
	return POS_TR

func set_dialogue(speaker: String, text: String, mood: String = "") -> void:
	# 台词历史（回看用）：新台词到来即记录并退出回看态
	if not text.strip_edges().is_empty():
		_dlg_history.append({"speaker": speaker, "text": text, "mood": mood})
		if _dlg_history.size() > REVIEW_MAX:
			_dlg_history.pop_front()
	_review_idx = -1
	_update_review_ui()
	_apply_dialogue(speaker, text, mood)

## 实际渲染一条台词（set_dialogue 与回看共用；回看不写历史）
func _apply_dialogue(speaker: String, text: String, mood: String = "") -> void:
	if _speaker_label: _speaker_label.text = speaker
	var pos := speaker_position(speaker)

	# 文本对齐：底部人物左对齐，顶部人物右对齐
	if _dialogue_label:
		_dialogue_label.text = text
		_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if pos == POS_BL else HORIZONTAL_ALIGNMENT_RIGHT

	# 立绘 / 角色名 / 正文：统一放进对话栏内——立绘占一侧、正文占另一侧、互不重叠
	if _speaker_portrait:
		var tex: Texture2D = PortraitLibrary.get_portrait(speaker, mood)
		if tex != null:
			_speaker_portrait.texture = tex
			_speaker_portrait.show()
			# 手动算 contain 进 220x220 框（EXPAND_IGNORE_SIZE 让 size 生效；expand_mode=2 会正方形化）
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var box := Vector2(220, 220)
			var sc: float = min(box.x / tw, box.y / th)
			var dw: float = tw * sc
			var dh: float = th * sc
			_speaker_portrait.size = Vector2(dw, dh)
			match pos:
				POS_BL:  # 福尔摩斯：立绘在框内左侧(220x220)居中，名字框与正文在右侧、名字在正文上方（左对齐）
					_speaker_portrait.position = Vector2(15, 5) + (box - Vector2(dw, dh)) * 0.5
					if _name_panel:
						_name_panel.show()
						_name_panel.position = Vector2(250, 8)
						_name_panel.size = Vector2(300, 34)
					if _speaker_label:
						_speaker_label.position = Vector2(255, 12)
						_speaker_label.size = Vector2(290, 28)
					if _dialogue_label:
						_dialogue_label.position = Vector2(250, 50)
						_dialogue_label.size = Vector2(1650, 168)
				POS_TR:  # 其他人物：立绘在框内右侧(220x220)居中，名字框与正文在左侧、名字在正文上方（右对齐）
					_speaker_portrait.position = Vector2(1920 - 15 - 220, 5) + (box - Vector2(dw, dh)) * 0.5
					if _name_panel:
						_name_panel.show()
						_name_panel.position = Vector2(20, 8)
						_name_panel.size = Vector2(300, 34)
					if _speaker_label:
						_speaker_label.position = Vector2(25, 12)
						_speaker_label.size = Vector2(290, 28)
					if _dialogue_label:
						_dialogue_label.position = Vector2(20, 50)
						_dialogue_label.size = Vector2(1650, 168)
		else:
			# 无立绘：名字框与正文占满整框，名字在正文上方
			_speaker_portrait.hide()
			if _name_panel:
				_name_panel.show()
				_name_panel.position = Vector2(20, 8)
				_name_panel.size = Vector2(300, 34)
			if _speaker_label:
				_speaker_label.position = Vector2(25, 12)
				_speaker_label.size = Vector2(290, 28)
			if _dialogue_label:
				_dialogue_label.position = Vector2(20, 50)
				_dialogue_label.size = Vector2(1880, 168)

func set_dialogue_color(c: Color) -> void:
	if _speaker_label: _speaker_label.add_theme_color_override("font_color", c)

# === 台词回看（对话栏中间 ◀ ▶ 半透明按钮 / ←→键 / 鼠标滚轮） ===
const REVIEW_MAX := 300
var _dlg_history: Array[Dictionary] = []
var _review_idx: int = -1               # -1 = 实时最新
var _rv_prev: Button = null
var _rv_next: Button = null
var _rv_badge: Label = null

func is_reviewing() -> bool:
	return _review_idx >= 0

## 回看步进：delta=-1 更早，delta=1 更新；走到最新自动退出回看态
func review_step(delta: int) -> void:
	if _dlg_history.is_empty():
		return
	var cur := _review_idx if is_reviewing() else _dlg_history.size() - 1
	var target := cur + delta
	if target >= _dlg_history.size() - 1:
		exit_review()
		return
	target = clampi(target, 0, _dlg_history.size() - 2)
	_review_idx = target
	var e: Dictionary = _dlg_history[target]
	_apply_dialogue(str(e.get("speaker", "")), str(e.get("text", "")), str(e.get("mood", "")))
	_update_review_ui()

## 退出回看态，恢复实时最新台词
func exit_review() -> void:
	if not is_reviewing():
		return
	_review_idx = -1
	if not _dlg_history.is_empty():
		var e: Dictionary = _dlg_history[_dlg_history.size() - 1]
		_apply_dialogue(str(e.get("speaker", "")), str(e.get("text", "")), str(e.get("mood", "")))
	_update_review_ui()

func _update_review_ui() -> void:
	if _rv_prev:
		_rv_prev.visible = _dlg_history.size() > 1 and (not is_reviewing() or _review_idx > 0)
	if _rv_next:
		_rv_next.visible = is_reviewing()
	if _rv_badge:
		if is_reviewing():
			_rv_badge.text = "回看 %d/%d" % [_review_idx + 1, _dlg_history.size()]
			_rv_badge.show()
		else:
			_rv_badge.hide()

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
	# 注意：不要用 lambda 捕获 bar——若 bar 在 3.1s 内被释放（如测试快速重建 UI 树），
	# 游离 tween 回调在捕获阶段会抛 "Lambda capture" 错误（错误发生在 lambda 体执行前，
	# 内部 is_instance_valid 守卫拦不住）。改用 bound 方法：bar 即便已释放也只作为参数失效，
	# 由方法内部判活，安全无报错。
	tw.tween_callback(_free_node_safe.bind(bar))

func _free_node_safe(node: Node) -> void:
	# 供 tween_callback 安全释放节点：node 即便已释放，也只是参数失效，这里判活即可，
	# 不会在捕获阶段抛出 "Lambda capture" 错误。
	if is_instance_valid(node):
		node.queue_free()

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
	# 顶部栏只作装饰/导航容器，绝不可吞掉下方场景区点击。

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
		{"id":"map", "en":"MAP", "zh":"地图", "icon":"res://assets/ui/icons/map.png"},
		{"id":"casebook", "en":"CASEBOOK", "zh":"案件簿", "icon":"res://assets/ui/icons/casebook.png"},
		{"id":"evidence", "en":"EVIDENCE", "zh":"证物", "icon":"res://assets/ui/icons/evidence_box.png"},
		{"id":"options", "en":"OPTIONS", "zh":"选项", "icon":"res://assets/ui/icons/gear.png"},
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
	# 图标（黄铜浮雕 png）
	var nic = TextureRect.new()
	nic.texture = load(n["icon"])
	nic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nic.position = Vector2(6, 15); nic.size = Vector2(24, 24)
	nic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(nic)
	# 英文
	var en = _mk_gold_label(n["en"], 13, COL_GOLD, 2)
	en.text = n["en"]
	en.position = Vector2(30, 4); en.size = Vector2(w - 32, 18)
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
	zh.position = Vector2(30, 24); zh.size = Vector2(w - 32, 16)
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
	divider.position = Vector2(LEFT_W - 2, 0); divider.size = Vector2(2, _left_bar.size.y)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_bar.add_child(divider)

	# 按钮放入可滚动容器，避免 9 个按钮 + 底栏遮挡导致最下方按钮点不到
	var scroll := ScrollContainer.new()
	scroll.name = "left_bar_scroll"
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(LEFT_W, _left_bar.size.y)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_left_bar.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.name = "left_bar_vbox"
	vb.size = Vector2(LEFT_W, _left_bar.size.y)
	vb.size_flags_horizontal = Control.SIZE_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	var actions = [
		{"id":"look", "en":"LOOK", "zh":"观察", "icon":"res://assets/ui/icons/eye.png"},
		{"id":"talk", "en":"TALK", "zh":"对话", "icon":"res://assets/ui/icons/chat.png"},
		{"id":"examine", "en":"EXAMINE", "zh":"调查", "icon":"res://assets/ui/icons/lens.png"},
		{"id":"think", "en":"THINK", "zh":"思考", "icon":"res://assets/ui/icons/lightbulb.png"},
		{"id":"prop", "en":"PROP", "zh":"道具", "icon":"res://assets/ui/icons/satchel.png"},
		{"id":"journal", "en":"JOURNAL", "zh":"日志", "icon":"res://assets/ui/icons/journal_book.png"},
		{"id":"kb", "en":"ENCYCLOPEDIA", "zh":"百科", "icon":"res://assets/ui/icons/directory.png"},
		{"id":"save", "en":"SAVE", "zh":"保存", "icon":"res://assets/ui/icons/floppy.png"},
		{"id":"load", "en":"LOAD", "zh":"读取", "icon":"res://assets/ui/icons/folder.png"},
	]
	var btn_w := 132
	var btn_h := 64
	for i in actions.size():
		var a = actions[i]
		var btn = _make_action_button(a, btn_w, btn_h, i)
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func(aid=a["id"]): action_clicked.emit(aid))
		vb.add_child(btn)
		_action_btns[a["id"]] = btn

func _make_action_button(a: Dictionary, w: int, h: int, idx: int) -> Button:
	var btn = Button.new()
	btn.name = "action_" + a["id"]
	btn.custom_minimum_size = Vector2(w, h)
	btn.text = ""
	# 古董金属牌：深底 + 外粗内细双线金边
	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.07, 0.05, 0.03, 0.96)
	sn.border_color = COL_GOLD
	sn.border_width_left = 2; sn.border_width_right = 2
	sn.border_width_top = 2; sn.border_width_bottom = 2
	sn.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", sn)
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.22, 0.14, 0.07, 0.96)
	sh.border_color = COL_GOLD_LIGHT
	sh.border_width_left = 2; sh.border_width_right = 2
	sh.border_width_top = 2; sh.border_width_bottom = 2
	sh.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", sh)
	# 内细线（双线效果）
	var inner = Panel.new()
	inner.position = Vector2(4, 4)
	inner.size = Vector2(w - 8, h - 8)
	var si = StyleBoxFlat.new()
	si.draw_center = false
	si.border_color = Color(0.78, 0.62, 0.25, 0.45)
	si.border_width_left = 1; si.border_width_right = 1
	si.border_width_top = 1; si.border_width_bottom = 1
	si.set_corner_radius_all(7)
	inner.add_theme_stylebox_override("panel", si)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)
	# 图标（黄铜浮雕 png）居左
	var icon = TextureRect.new()
	icon.texture = load(a["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(10, h / 2 - 16); icon.size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	# 英文大写
	var en = _mk_gold_label(a["en"], 11, COL_GOLD, 1)
	en.position = Vector2(48, h / 2 - 18); en.size = Vector2(w - 54, 17)
	en.horizontal_alignment = 1
	en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(en)
	# 中文
	var zh = Label.new()
	zh.text = a["zh"]
	zh.add_theme_font_size_override("font_size", 14)
	zh.add_theme_color_override("font_color", Color(0.85, 0.72, 0.50))
	zh.add_theme_color_override("font_outline_color", COL_SHADOW)
	zh.add_theme_constant_override("outline_size", 1)
	zh.position = Vector2(48, h / 2); zh.size = Vector2(w - 54, 18)
	zh.horizontal_alignment = 1
	zh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(zh)
	return btn

# === 中央场景区 ===

## 幂等建世界层：供 setup() 在 _ready 前同步调用，也供 _build_all 复用（已建则跳过）。
func _ensure_world() -> void:
	if _world != null:
		return
	_build_scene_area()

func _build_scene_area() -> void:
	if _scene_area != null:
		return
	_scene_area = Control.new()
	_scene_area.name = "scene_area"
	_scene_area.position = Vector2(LEFT_W, TOP_H)
	_scene_area.size = Vector2(1920 - LEFT_W, 1080 - TOP_H - DIALOGUE_H)
	_scene_area.mouse_filter = Control.MOUSE_FILTER_PASS
	# 裁切溢出：世界层缩放/平移超出视野时不侵入左侧栏/对话栏等 UI
	_scene_area.clip_contents = true
	add_child(_scene_area)

	# 默认深色背景（z 必须低于 scene_bg 的 -10，否则会盖住背景图）
	var bg = ColorRect.new()
	bg.name = "default_bg"
	bg.color = Color(0.10, 0.07, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -20
	_scene_area.add_child(bg)

	# 世界子树（摄像机作用对象）：背景 + 立绘 + 线索圈都挂在这里。
	# 初始铺满 _scene_area、不缩放；缩放/平移由摄像机方法施加。
	_world = Control.new()
	_world.name = "world_layer"
	_world.position = Vector2.ZERO
	_world.size = _scene_area.size
	_world.mouse_filter = Control.MOUSE_FILTER_PASS   # PASS：空白区点击落到 _unhandled_input（供拖拽平移），不拦截子节点命中
	_world.z_index = 0
	_scene_area.add_child(_world)

# === 底部对话栏 ===

func _build_dialogue_bar() -> void:
	_dialogue_bar = Control.new()
	_dialogue_bar.name = "dialogue_bar"
	_dialogue_bar.position = Vector2(0, 1080 - DIALOGUE_H)
	_dialogue_bar.size = Vector2(1920, DIALOGUE_H)
	# 对话栏只承载显示与台词回看按钮，不能整体拦截场景区点击；
	# 否则场景二/三等地点类线索圈会被底部栏吞掉（圆圈在 _world，栏在上方 sibling）。
	_dialogue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# 说话人立绘（置于对话栏内左侧/右侧，不浮出框外；无立绘时隐藏）
	_speaker_portrait = TextureRect.new()
	_speaker_portrait.name = "speaker_portrait"
	_speaker_portrait.position = Vector2(15, 5)   # 默认在框内（_apply_dialogue 会按角色左右重定位），尺寸 220x220
	_speaker_portrait.size = Vector2(220, 220)
	_speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 同 _make_portrait：本 Godot 4.7 构建中 expand_mode=2 会把 size 重算成正方形，
	# 改用 EXPAND_IGNORE_SIZE(=1)，实际显示尺寸在 _apply_dialogue 设纹理时手动算 contain。
	_speaker_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_speaker_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_portrait.visible = false
	_dialogue_bar.add_child(_speaker_portrait)

	# 角色名（烫金深褐框，置于对话栏内、立绘上方；_apply_dialogue 按角色左右重定位）
	_name_panel = Panel.new()
	_name_panel.name = "speaker_name_panel"
	_name_panel.size = Vector2(300, 34)
	_name_panel.position = Vector2(250, 8)
	var nsb = StyleBoxFlat.new()
	nsb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	nsb.border_color = COL_GOLD
	nsb.border_width_left = 2; nsb.border_width_right = 2
	nsb.border_width_top = 2; nsb.border_width_bottom = 2
	nsb.set_corner_radius_all(4)
	_name_panel.add_theme_stylebox_override("panel", nsb)
	_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(_name_panel)
	_speaker_label = Label.new()
	_speaker_label.name = "speaker"
	_speaker_label.text = "Holmes:"
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_speaker_label.add_theme_color_override("font_outline_color", COL_SHADOW)
	_speaker_label.add_theme_constant_override("outline_size", 2)
	_speaker_label.position = Vector2(255, 12); _speaker_label.size = Vector2(290, 28)
	_speaker_label.vertical_alignment = 1
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(_speaker_label)

	# 对话文本（衬线深褐，大字号，羊皮纸上易读；位置随角色左右，避免与立绘重叠）
	_dialogue_label = Label.new()
	_dialogue_label.name = "dialogue_text"
	_dialogue_label.text = ""
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 24)
	_dialogue_label.add_theme_color_override("font_color", COL_PARCH_DARK)
	_dialogue_label.add_theme_constant_override("line_spacing", 6)
	_dialogue_label.position = Vector2(250, 50); _dialogue_label.size = Vector2(1650, 168)
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_bar.add_child(_dialogue_label)

	# 台词回看按钮（对话栏顶部中央，半透明 ◀ ▶）
	_rv_prev = _make_review_btn("◀")
	_rv_prev.position = Vector2(1920 / 2.0 - 52, 10)
	_rv_prev.pressed.connect(func() -> void: review_step(-1))
	_dialogue_bar.add_child(_rv_prev)
	_rv_next = _make_review_btn("▶")
	_rv_next.position = Vector2(1920 / 2.0 + 12, 10)
	_rv_next.pressed.connect(func() -> void: review_step(1))
	_rv_next.visible = false
	_dialogue_bar.add_child(_rv_next)
	_rv_badge = Label.new()
	_rv_badge.name = "review_badge"
	_rv_badge.add_theme_font_size_override("font_size", 14)
	_rv_badge.add_theme_color_override("font_color", Color(0.55, 0.42, 0.22))
	_rv_badge.position = Vector2(1920 / 2.0 - 60, 44); _rv_badge.size = Vector2(120, 20)
	_rv_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rv_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rv_badge.hide()
	_dialogue_bar.add_child(_rv_badge)

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

## 半透明回看箭头按钮（悬停时提高不透明度）
func _make_review_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(40, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.45)
	b.mouse_entered.connect(func() -> void: b.modulate = Color(1, 1, 1, 0.95))
	b.mouse_exited.connect(func() -> void: b.modulate = Color(1, 1, 1, 0.45))
	b.tooltip_text = "回看台词（← → 键 / 鼠标滚轮）"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.04, 0.85)
	sb.border_color = COL_GOLD
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	return b

# === 角色立绘（带金边框+名字烫金条） ===

func _make_portrait(tex: Texture2D, name_text: String, pos: Vector2, size: Vector2, flip: bool = false) -> Control:
	var port = Control.new()
	port.name = "portrait_" + name_text.replace(" ", "_")
	port.position = pos; port.size = size
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 图片
	var img = TextureRect.new()
	img.name = "img"
	img.flip_h = flip
	# 等比 contain：本 Godot 4.7 构建 expand_mode 枚举语义反转，FIT_* 名字与效果相反，
	# 隐藏数字 2 实测会把 size 重算成正方形（竖图被压成中间窄条）。故改用手动算 contain：
	# 用 EXPAND_IGNORE_SIZE(=1) 让「手动计算的 contain 尺寸」生效，配 STRETCH_KEEP_ASPECT_CENTERED 居中。
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var box := size - Vector2(12, 12)
	var sc: float = min(box.x / tw, box.y / th)
	var dw: float = tw * sc
	var dh: float = th * sc
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size = Vector2(dw, dh)
	img.position = Vector2(6, 6) + (box - Vector2(dw, dh)) * 0.5
	img.texture = tex
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port.add_child(img)
	_mag_portraits.append(img)   # 供放大镜放大立绘纹理（立绘在上层，命中立绘优先于背景）

	# 注：立绘名字条已按需求移除（scene_framework.gd 不再在场景中显示角色名）。
	return port

## 返回鼠标全局位置命中的最上层可放大节点（立绘优先于背景），供放大镜直接采样其纹理。
## 不依赖屏幕捕获机制，Web 导出可靠。
## 返回鼠标全局位置命中的最上层可放大节点（立绘优先于背景），供放大镜直接采样其纹理。
## 要求节点必须仍在场景树中且实际可见（避免 queue_free 后残留引用返回旧 global_rect 误命中）。
func get_magnifiable_at(global_pos: Vector2) -> TextureRect:
	var candidates: Array[TextureRect] = []
	for i in range(_mag_portraits.size() - 1, -1, -1):
		var n := _mag_portraits[i] as TextureRect
		if n and is_instance_valid(n) and n.is_inside_tree() and n.is_visible_in_tree() \
				and n.get_global_rect().has_point(global_pos):
			candidates.append(n)
	if _mag_bg and is_instance_valid(_mag_bg) and _mag_bg.is_inside_tree() and _mag_bg.is_visible_in_tree() \
			and _mag_bg.get_global_rect().has_point(global_pos):
		candidates.append(_mag_bg)
	if candidates.is_empty():
		return null
	# 同 z_index 时取后添加者（数组末尾即上层），不同 z_index 取大者
	candidates.sort_custom(func(a: TextureRect, b: TextureRect) -> bool:
		if a.z_index == b.z_index:
			return _mag_portraits.find(a) > _mag_portraits.find(b)
		return a.z_index > b.z_index
	)
	return candidates[0]

# === 通用存/读档辅助（场景复用） ===

## 恢复观察器：显示按钮 → 标记已收线索（隐藏按钮+登记 ID+计数器）
func restore_observer(obs: ClueObserver, saved_ids: Array, owned_ids: Array) -> void:
	obs.show()
	for cid in saved_ids:
		if cid in owned_ids:
			obs.mark_recorded(cid)

## 检查存档：返回 saved phase（-1 表示无存档或不属于本场景）
func get_saved_phase(scene_id: String) -> int:
	if not GameManager: return -1
	var ss = GameManager.scene_state
	if ss.is_empty(): return -1
	if ss.get("scene_id", "") != scene_id: return -1
	return ss.get("phase", -1)

## 取存档中的线索 ID 列表
func get_saved_clue_ids() -> Array:
	if not GameManager: return []
	return GameManager.scene_state.get("clue_ids", []).duplicate()

# ===== 摄像机 / 观察层（M1：统览 + 滚轮缩放 + 拖拽平移 + 点线索推近） =====
# 缩放/平移作用于 _world（背景+立绘+线索圈），UI 层与之分离，故缩放时永不变形。
# 这是 Control 架构下对 Camera2D 的等价替代（Camera2D 只影响 Node2D，不作用于 Control）。
# 坐标系：_world 局部原点 = _scene_area 左上角；世界点 w 在屏幕上的局部坐标 s = _world.position + w * zoom。

const CAM_ZOOM_MIN := 1.0        # 最小=统览全场景（背景正好铺满视野，不能再缩小）
const CAM_ZOOM_MAX := 3.0        # 最大=推近看细节
const CAM_OVERVIEW_ZOOM := 1.0
var _camera_zoom := 1.0
var _camera_enabled := true
var _camera_panning := false
var _camera_tween: Tween = null

## 阶段开关：对话/推理墙阶段设为 false（避免滚轮/拖拽误触），观察阶段设为 true
func set_camera_enabled(b: bool) -> void:
	_camera_enabled = b
	if not b:
		_camera_panning = false

## 平滑把摄像机移到「世界坐标 world_pt 居中、缩放 zoom」状态（点线索推近用）
func focus_world_point(world_pt: Vector2, zoom: float) -> void:
	if not _world: return
	zoom = clamp(zoom, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	var center_local := _scene_area.size * 0.5
	var target_pos := center_local - world_pt * zoom
	_tween_camera(target_pos, Vector2(zoom, zoom))

## 回到统览态（zoom=1, position=0）
func reset_camera() -> void:
	if not _world: return
	_tween_camera(Vector2.ZERO, Vector2(CAM_OVERVIEW_ZOOM, CAM_OVERVIEW_ZOOM))

## Tab 切换：非统览态→回到统览；已在统览态→忽略
func toggle_overview() -> void:
	if not _world: return
	if abs(_world.scale.x - CAM_OVERVIEW_ZOOM) < 0.02 and _world.position.is_equal_approx(Vector2.ZERO):
		return
	reset_camera()

func _tween_camera(target_pos: Vector2, target_scale: Vector2) -> void:
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(_world, "position", target_pos, 0.35).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_world, "scale", target_scale, 0.35).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if not _camera_enabled or not _world: return
	if event is InputEventMouseButton:
		var in_area := _scene_area.get_global_rect().has_point(get_global_mouse_position())
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not in_area: return
				var local := get_global_mouse_position() - _scene_area.global_position
				var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else (1.0 / 1.12)
				_zoom_at(local, factor)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				# 左键拖拽：仅在观察阶段（_camera_enabled）生效，对话框/推理墙已禁用，不与点击推进冲突
				if event.pressed:
					_camera_panning = true
				else:
					_camera_panning = false
	elif event is InputEventMouseMotion and _camera_panning:
		_world.position += event.relative
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_overview()

## 以场景区局部坐标 local_pt 为锚点缩放（鼠标在哪、放大哪）
func _zoom_at(local_pt: Vector2, factor: float) -> void:
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	var z_old: float = _world.scale.x
	var z_new: float = clamp(z_old * factor, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	if abs(z_new - z_old) < 0.001:
		return
	# 缩放前落在指针下的世界点：w = (local_pt - position) / z_old
	var w := (local_pt - _world.position) / z_old
	_world.scale = Vector2(z_new, z_new)
	_world.position = local_pt - w * z_new
