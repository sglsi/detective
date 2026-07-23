extends Control

## 推理墙 — MVP 基础层 (v2: 简化实现避免 inner class 问题)
## 设计依据: 06_推理墙运行机制.md S2

enum Verdict { INSUFFICIENT=1, SUPPORTED=2, VERIFIED=3, CONTRADICTORY=0 }

var _clues: Array = []       # [{id, name, desc, correct, associated}]
var _hypothesis: Dictionary = {}
var _associated := 0
var _contradicting := 0
var _on_verify: Callable
var _card_btns: Dictionary = {}  # clue_id -> Button
var _hypo_btn: Button
var _status_lbl: Label
<omitted />

func setup(clues: Array, hypothesis: Dictionary, on_verify: Callable) -> void:
	_clues = clues
	_hypothesis = hypothesis
	_on_verify = on_verify
	_create_ui()

func get_verdict() -> int:
	if _contradicting > 0: return Verdict.CONTRADICTORY
	if _associated >= 3: return Verdict.VERIFIED
	if _associated >= 1: return Verdict.SUPPORTED
	return Verdict.INSUFFICIENT

func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 标题
	_add_label("推理墙 — 假设构建", 32, Color(0.92, 0.82, 0.45), Vector2(40, 20), Vector2(1840, 45))
	_add_label("点击线索卡片直接推入面板 | 再次点击取消 | 绿色=已关联", 14, Color(0.45, 0.40, 0.30), Vector2(40, 65), Vector2(1840, 25))

	# 分割线
	var div = ColorRect.new()
	div.color = Color(0.45, 0.35, 0.15, 0.5)
	div.position = Vector2(40, 95); div.size = Vector2(1840, 2)
	add_child(div)

	# 左侧：线索列表
	_add_label("已收集线索", 22, Color(0.85, 0.78, 0.62), Vector2(40, 110), Vector2(300, 35))
	for i in _clues.size():
		var c = _clues[i]
		var card = Button.new()
		card.text = c["name"] if c.has("name") else c["id"]
		card.position = Vector2(40, 155 + i * 65)
		card.size = Vector2(280, 55)
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		_style_card(card, false)
		card.pressed.connect(_on_card_clicked.bind(c["id"]))
		add_child(card)
		_card_btns[c["id"]] = card

	# 中央：假设区域
	var hypo_area = Control.new()
	hypo_area.position = Vector2(380, 110)
	hypo_area.size = Vector2(800, 600)
	add_child(hypo_area)

	var hbg = ColorRect.new()
	hbg.color = Color(0.10, 0.08, 0.06, 0.9)
	hbg.position = Vector2(0, 0); hbg.size = Vector2(800, 480)
	hypo_area.add_child(hbg)

	_add_label("核心问题: " + _hypothesis.get("title", ""), 24, Color(0.88, 0.82, 0.72), Vector2(20, 15), Vector2(760, 35))
	_add_label(_hypothesis.get("description", ""), 15, Color(0.6, 0.55, 0.45), Vector2(20, 55), Vector2(760, 45))

	# 假设卡槽
	_hypo_btn = Button.new()
	_hypo_btn.text = "关联的证据将在此显示\n\n点击左侧线索卡片加入或移除"
	_hypo_btn.position = Vector2(50, 130)
	_hypo_btn.size = Vector2(700, 320)
	_hypo_btn.add_theme_font_size_override("font_size", 20)
	_hypo_btn.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
	var hbn = StyleBoxFlat.new()
	hbn.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	hbn.border_color = Color(0.45, 0.35, 0.15)
	hbn.border_width_left = 3; hbn.border_width_right = 3
	hbn.border_width_top = 3; hbn.border_width_bottom = 3
	hbn.set_corner_radius_all(9)
	_hypo_btn.add_theme_stylebox_override("normal", hbn)
	var hbh = hbn.duplicate()
	hbh.border_color = Color(0.75, 0.58, 0.30)
	_hypo_btn.add_theme_stylebox_override("hover", hbh)
	_hypo_btn.pressed.connect(_on_hypo_clicked)
	hypo_area.add_child(_hypo_btn)

	# 状态标签
	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_status_lbl.position = Vector2(1200, 110); _status_lbl.size = Vector2(680, 35)
	add_child(_status_lbl)

	# 验证按钮
	var vb = Button.new()
	vb.text = "提交验证 (Step 6)"
	vb.position = Vector2(600, 620)
	vb.size = Vector2(320, 60)
	vb.add_theme_font_size_override("font_size", 24)
	vb.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	var vs = StyleBoxFlat.new()
	vs.bg_color = Color(0.50, 0.10, 0.10, 0.95); vs.border_color = Color(0.85, 0.65, 0.25)
	vs.border_width_left = 2; vs.border_width_right = 2
	vs.border_width_top = 2; vs.border_width_bottom = 2
	vs.set_corner_radius_all(4)
	vb.add_theme_stylebox_override("normal", vs)
	vb.pressed.connect(_on_verify_pressed)
	add_child(vb)

	# 关闭
	var cl = Button.new()
	cl.text = "X 关闭"
	cl.position = Vector2(1800, 15); cl.size = Vector2(80, 35)
	cl.add_theme_font_size_override("font_size", 14)
	cl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	cl.pressed.connect(func(): queue_free())
	add_child(cl)

	_add_label("提示: 点击线索卡片=推入面板，再次点击=取消关联。绿色=已关联，灰色=未关联。", 13, Color(0.40, 0.35, 0.28), Vector2(40, 700), Vector2(1840, 25))

func _add_label(t: String, fs: int, fc: Color, pos: Vector2, sz: Vector2) -> void:
	var l = Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", fc)
	l.position = pos; l.size = sz
	add_child(l)

func _style_card(btn: Button, selected: bool) -> void:
	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
	sn.border_color = Color(0.95, 0.78, 0.40) if selected else Color(0.55, 0.42, 0.20)
	sn.border_width_left = 2; sn.border_width_right = 2
	sn.border_width_top = 2; sn.border_width_bottom = 2
	sn.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sn)

func _on_card_clicked(cid: String) -> void:
	# 查找线索数据
	var clue: Dictionary = {}
	var idx := -1
	for i in _clues.size():
		if _clues[i]["id"] == cid:
			clue = _clues[i]; idx = i
			break
	if idx < 0: return

	var card = _card_btns.get(cid)
	if not card: return

	if clue.get("associated", false):
		# 已关联 → 取消关联（从面板移除）
		clue["associated"] = false
		_associated -= 1
		if not clue.get("correct", true): _contradicting -= 1
		# 恢复卡片样式
		var sn = StyleBoxFlat.new()
		sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
		sn.border_color = Color(0.55, 0.42, 0.20)
		sn.border_width_left = 2; sn.border_width_right = 2
		sn.border_width_top = 2; sn.border_width_bottom = 2
		sn.set_corner_radius_all(6)
		card.add_theme_stylebox_override("normal", sn)
		_status_lbl.text = "已取消关联: " + cid + " (共" + str(_associated) + "条)"
		_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.35))
	else:
		# 未关联 → 直接推入面板
		clue["associated"] = true
		_associated += 1
		if not clue.get("correct", true): _contradicting += 1
		# 卡片变绿
		var sn = StyleBoxFlat.new()
		sn.bg_color = Color(0.08, 0.30, 0.08, 0.95)
		sn.border_color = Color(0.2, 0.8, 0.2)
		sn.border_width_left = 2; sn.border_width_right = 2
		sn.border_width_top = 2; sn.border_width_bottom = 2
		sn.set_corner_radius_all(6)
		card.add_theme_stylebox_override("normal", sn)
		_status_lbl.text = "线索已关联: " + cid + " (共" + str(_associated) + "条)"
		_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))

	_update_hypo()

<omitted />

func _on_verify_pressed() -> void:
	var v = get_verdict()
	var txt = ""
	var tc = Color.WHITE
	match v:
		Verdict.VERIFIED:
			txt = "VERIFIED — 推理完全正确，证据链完整"
			tc = Color(0.3, 0.95, 0.3)
		Verdict.SUPPORTED:
			txt = "SUPPORTED — 方向正确，证据基本完整"
			tc = Color(0.4, 0.8, 0.4)
		Verdict.INSUFFICIENT:
			txt = "INSUFFICIENT — 证据不足，请补充"
			tc = Color(0.95, 0.8, 0.2)
		Verdict.CONTRADICTORY:
			txt = "CONTRADICTORY — 存在矛盾证据"
			tc = Color(0.95, 0.3, 0.3)

	var rl = Label.new()
	rl.text = txt
	rl.add_theme_font_size_override("font_size", 36)
	rl.add_theme_color_override("font_color", tc)
	rl.position = Vector2(0, 350); rl.size = Vector2(1920, 80)
	rl.horizontal_alignment = 1
	add_child(rl)

	await get_tree().create_timer(2.5).timeout
	if _on_verify: _on_verify.call(v)
	queue_free()
