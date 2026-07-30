extends Control

## 推理墙 — MVP 基础层 (v2: 简化实现避免 inner class 问题)
## 设计依据: 06_推理墙运行机制.md S2

enum Verdict { INSUFFICIENT=1, SUPPORTED=2, VERIFIED=3, CONTRADICTORY=0 }
enum Diff { EASY=0, NORMAL=1, HARD=2 }   # 与 DifficultyManager 对齐（06 §八 难度适配）

var _clues: Array = []       # [{id, name, desc, correct, associated}]
var _difficulty: int = Diff.NORMAL
var _milestones: Array = []        # [{id, text, lit}] 结论里程碑节点（06 §2.4）
var _milestone_confirmed: int = 0
var _milestone_total: int = 0
var _milestone_lbl: Label = null
var _last_report: String = ""
var _hypothesis: Dictionary = {}
var _battle: Dictionary = {}  # hypothesis["battlefield"]: {hypotheses:[{id,text,correct}], contradictions:[{id,text}]}
var _battle_hypo_states: Dictionary = {}  # 假设卡状态: id -> 0未定 / 1采纳 / 2排除
var _battle_contra_states: Dictionary = {}  # 矛盾卡状态: id -> bool(已识别)
var _battle_hypo_btns: Dictionary = {}  # 假设卡按钮引用
var _battle_contra_btns: Dictionary = {}  # 矛盾卡按钮引用
var _battle_status: Label
var _associated := 0
var _contradicting := 0
var _on_verify: Callable
var _card_btns: Dictionary = {}  # clue_id -> Button
var _hypo_list: VBoxContainer = null   # 关联面板：已关联线索列表（点击条目弹详情）
var _status_lbl: Label
var _on_close: Callable = Callable()   # 关闭时回调（用于返回玩家进入前的状态）
var _verifying := false                 # 验证结果展示中，锁定「返回」避免误关

func setup(clues: Array, hypothesis: Dictionary, on_verify: Callable, on_close: Callable = Callable(), difficulty: int = Diff.NORMAL) -> void:
	_clues = clues
	_hypothesis = hypothesis
	_on_verify = on_verify
	_on_close = on_close
	_difficulty = difficulty
	_battle = hypothesis.get("battlefield", {})
	_init_milestones(hypothesis)
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
	_add_label("点击左栏线索卡 = 推入关联面板（再点退出）· 点关联面板内线索 = 查看详情 · 绿色=已关联", 14, Color(0.45, 0.40, 0.30), Vector2(40, 65), Vector2(1840, 25))

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
		var display_name: String = c.get("name", c.get("label", c.get("id", "")))
		var display_desc: String = c.get("desc", "")
		card.text = display_name
		if display_desc.length() > 0:
			# 副文本：截断描述作为提示（解决"无线索提示"）
			card.tooltip_text = display_desc if display_desc.length() <= 120 else display_desc.left(117) + "..."
		card.position = Vector2(40, 155 + i * 72)  # 加大间距容纳副标签
		card.size = Vector2(280, 62)
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		_style_card(card, false)

		# 正确/误导标记（困难模式不泄露可靠性，由玩家自行判断 — 06 §八）
		if _difficulty != Diff.HARD and not c.get("correct", true):
			var tag := Label.new()
			tag.text = "⚠"
			tag.add_theme_font_size_override("font_size", 12)
			tag.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
			tag.position = Vector2(252, 4)
			card.add_child(tag)

		card.pressed.connect(_on_card_clicked.bind(c["id"]))
		add_child(card)
		_card_btns[c["id"]] = card

	# 中央：关联面板（点击左栏线索推入/退出；点面板内线索看详情）
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
	_add_label("关联面板 — 点击左栏线索推入，再点退出；点面板内线索看详情", 17, Color(0.85, 0.78, 0.62), Vector2(20, 100), Vector2(760, 26))

	# 关联面板：可滚动列表（已关联线索）
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 132); scroll.size = Vector2(760, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hypo_area.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "AssocList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	_hypo_list = list
	_update_hypo()

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

	# 返回（回到玩家进入推理墙前的场景状态）
	var back = Button.new()
	back.text = "← 返回探索"
	back.position = Vector2(340, 620)
	back.size = Vector2(250, 60)
	back.add_theme_font_size_override("font_size", 24)
	back.add_theme_color_override("font_color", Color(0.85, 0.80, 0.66))
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.16, 0.14, 0.10, 0.95); bs.border_color = Color(0.55, 0.45, 0.25)
	bs.border_width_left = 2; bs.border_width_right = 2
	bs.border_width_top = 2; bs.border_width_bottom = 2
	bs.set_corner_radius_all(4)
	back.add_theme_stylebox_override("normal", bs)
	var bsh = bs.duplicate(); bsh.border_color = Color(0.80, 0.68, 0.38)
	back.add_theme_stylebox_override("hover", bsh)
	back.pressed.connect(_on_back_pressed)
	add_child(back)

	# 关闭
	var cl = Button.new()
	cl.text = "X 关闭"
	cl.position = Vector2(1800, 15); cl.size = Vector2(80, 35)
	cl.add_theme_font_size_override("font_size", 14)
	cl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	cl.pressed.connect(_on_back_pressed)
	add_child(cl)

	# 结论里程碑（06 §2.4）：底部进度条，验证达到「已获证实」时点亮事实节点
	_milestone_lbl = Label.new()
	_milestone_lbl.add_theme_font_size_override("font_size", 16)
	_milestone_lbl.add_theme_color_override("font_color", Color(0.80, 0.70, 0.40))
	_milestone_lbl.position = Vector2(40, 762); _milestone_lbl.size = Vector2(1840, 30)
	add_child(_milestone_lbl)
	_update_milestone_ui()

	_create_battlefield_ui()
	_add_label("提示: 点击左栏线索卡=推入关联面板（再点退出）；点关联面板内线索=弹出详情。绿色=已关联。", 13, Color(0.40, 0.35, 0.28), Vector2(40, 700), Vector2(1840, 25))

func _add_label(t: String, fs: int, fc: Color, pos: Vector2, sz: Vector2) -> void:
	var l = Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", fc)
	l.position = pos; l.size = sz
	add_child(l)

func _style_card(btn: Button, associated: bool) -> void:
	var sn = StyleBoxFlat.new()
	if associated:
		sn.bg_color = Color(0.08, 0.30, 0.08, 0.95)
		sn.border_color = Color(0.2, 0.8, 0.2)
	else:
		sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
		sn.border_color = Color(0.55, 0.42, 0.20)
	sn.border_width_left = 2; sn.border_width_right = 2
	sn.border_width_top = 2; sn.border_width_bottom = 2
	sn.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sn)

func _on_card_clicked(cid: String) -> void:
	# 点击左栏线索卡片 = 推入/退出关联面板（toggle）。
	# 在关联面板内点击某条线索时，才会弹出线索详情（见 _update_hypo）。
	_toggle_association(cid)

## 线索详情弹窗：显示完整信息 + 关联/取消操作
var _detail_popup: AcceptDialog = null

func _show_clue_detail(clue: Dictionary) -> void:
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()

	_detail_popup = AcceptDialog.new()
	_detail_popup.title = "线索详情"
	_detail_popup.min_size = Vector2(420, 300)
	_detail_popup.exclusive = true

	var vb := VBoxContainer.new()
	vb.name = "DetailContent"
	vb.add_theme_constant_override("separation", 8)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = clue.get("name", clue.get("label", clue.get("id", "")))
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	vb.add_child(name_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = clue.get("desc", "（暂无描述）")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(380, 80)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	vb.add_child(desc_lbl)

		# 属性标签（困难模式不泄露可靠性 — 06 §八）
	var tags := HBoxContainer.new()
	if _difficulty != Diff.HARD:
		var correct_tag: bool = clue.get("correct", true)
		var ct := Button.new()
		ct.text = "✓ 正确线索" if correct_tag else "⚠ 误导项"
		ct.disabled = true
		if correct_tag:
			ct.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		else:
			ct.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		tags.add_child(ct)
	var src_tag := Label.new()
	src_tag.text = "  来源: " + str(clue.get("source", "?"))
	src_tag.add_theme_color_override("font_color", Color(0.5, 0.48, 0.40))
	tags.add_child(src_tag)
	vb.add_child(tags)

	# 操作按钮行
	var btn_row := HBoxContainer.new()
	var assoc_btn := Button.new()
	var is_assoc: bool = clue.get("associated", false)
	assoc_btn.text = "取消关联" if is_assoc else "→ 关联到假设面板"
	assoc_btn.pressed.connect(func():
		_detail_popup.hide()
		_toggle_association(clue["id"])
	)
	btn_row.add_child(assoc_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): _detail_popup.hide())
	btn_row.add_child(close_btn)
	vb.add_child(btn_row)

	_detail_popup.add_child(vb)
	add_child(_detail_popup)
	_detail_popup.popup_centered()

## 切换关联状态（从原 _on_card_clicked 的核心逻辑提取）
func _toggle_association(cid: String) -> void:
	var clue: Dictionary = {}
	for c in _clues:
		if c["id"] == cid:
			clue = c; break
	if clue.is_empty(): return

	var card = _card_btns.get(cid)
	if not card: return

	if clue.get("associated", false):
		clue["associated"] = false
		_associated -= 1
		if not clue.get("correct", true): _contradicting -= 1
		_style_card(card, false)
		_status_lbl.text = "已取消关联: " + cid + " (共" + str(_associated) + "条)"
		_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.35))
	else:
		clue["associated"] = true
		_associated += 1
		if not clue.get("correct", true): _contradicting += 1
		_style_card(card, true)
		_status_lbl.text = "线索已关联: " + cid + " (共" + str(_associated) + "条)"
		_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))

	_update_hypo()

# ===== 推理战场 M1：假设/矛盾可交互卡 =====
## 在右侧渲染推理战场：假设卡（三态：未定/采纳/排除）+ 矛盾卡（识别/未识别），
## 玩家标记判断后实时显示命中评定；验证时附战场小结。
func _create_battlefield_ui() -> void:
	if _battle.is_empty(): return
	var hypos: Array = _battle.get("hypotheses", [])
	var contras: Array = _battle.get("contradictions", [])
	if hypos.is_empty() and contras.is_empty(): return

	var bx := 1240
	var bw := 660
	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.07, 0.10, 0.92)
	panel.position = Vector2(bx, 95); panel.size = Vector2(bw, 595)
	add_child(panel)
	_add_label("推理战场 · M1（标记你的判断）", 20, Color(0.85, 0.78, 0.62), Vector2(bx+15, 108), Vector2(bw-30, 30))

	var y := 150
	if not hypos.is_empty():
		_add_label("活跃假设（点按钮：未定→采纳✓→排除✗）", 15, Color(0.70, 0.85, 0.95), Vector2(bx+15, y), Vector2(bw-30, 24)); y += 30
		for h in hypos:
			y = _add_battle_hypo_card(h, bx+15, y, bw-30)
	if not contras.is_empty():
		_add_label("矛盾标记（点按钮：未识别→已识别）", 15, Color(0.95, 0.80, 0.70), Vector2(bx+15, y), Vector2(bw-30, 24)); y += 30
		for c in contras:
			y = _add_battle_contra_card(c, bx+15, y, bw-30)

	_battle_status = Label.new()
	_battle_status.add_theme_font_size_override("font_size", 16)
	_battle_status.add_theme_color_override("font_color", Color(0.60, 0.90, 0.60))
	_battle_status.position = Vector2(bx+15, y+8); _battle_status.size = Vector2(bw-30, 60)
	add_child(_battle_status)
	_update_battle_status()

func _add_battle_hypo_card(h: Dictionary, x: int, y: int, w: int) -> int:
	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var card = Control.new()
	card.position = Vector2(x, y); card.size = Vector2(w, 64)
	var tl = Label.new()
	tl.text = id + "  " + text
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_font_size_override("font_size", 13)
	tl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	tl.position = Vector2(0, 0); tl.size = Vector2(w-200, 60)
	card.add_child(tl)
	var btn = Button.new()
	btn.text = "未定"
	btn.position = Vector2(w-190, 14); btn.size = Vector2(180, 36)
	btn.add_theme_font_size_override("font_size", 14)
	_style_battle_btn(btn, 0)
	btn.pressed.connect(_on_battle_hypo_pressed.bind(id))
	card.add_child(btn)
	_battle_hypo_btns[id] = btn
	add_child(card)
	return y + 70

func _add_battle_contra_card(c: Dictionary, x: int, y: int, w: int) -> int:
	var id: String = c.get("id", "?")
	var text: String = c.get("text", "")
	var card = Control.new()
	card.position = Vector2(x, y); card.size = Vector2(w, 52)
	var tl = Label.new()
	tl.text = id + "  " + text
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_font_size_override("font_size", 13)
	tl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	tl.position = Vector2(0, 0); tl.size = Vector2(w-200, 48)
	card.add_child(tl)
	var btn = Button.new()
	btn.text = "未识别"
	btn.position = Vector2(w-190, 8); btn.size = Vector2(180, 36)
	btn.add_theme_font_size_override("font_size", 14)
	_style_battle_btn(btn, 0)
	btn.pressed.connect(_on_battle_contra_pressed.bind(id))
	card.add_child(btn)
	_battle_contra_btns[id] = btn
	add_child(card)
	return y + 58

func _on_battle_hypo_pressed(id: String) -> void:
	var st: int = _battle_hypo_states.get(id, 0)
	st = (st + 1) % 3
	_battle_hypo_states[id] = st
	var btn = _battle_hypo_btns.get(id)
	if btn:
		btn.text = ["未定", "采纳✓", "排除✗"][st]
		_style_battle_btn(btn, st)
	_update_battle_status()

func _on_battle_contra_pressed(id: String) -> void:
	var st: bool = not _battle_contra_states.get(id, false)
	_battle_contra_states[id] = st
	var btn = _battle_contra_btns.get(id)
	if btn:
		btn.text = "已识别" if st else "未识别"
		_style_battle_btn(btn, 1 if st else 0)
	_update_battle_status()

func _update_battle_status() -> void:
	if not _battle_status: return
	var hypos: Array = _battle.get("hypotheses", [])
	var contras: Array = _battle.get("contradictions", [])
	var h_ok := 0; var h_tot := hypos.size()
	for h in hypos:
		var id: String = h.get("id", "")
		var st: int = _battle_hypo_states.get(id, 0)
		var correct: bool = h.get("correct", false)
		if (st == 1 and correct) or (st == 2 and not correct):
			h_ok += 1
	var c_ok := 0; var c_tot := contras.size()
	for c in contras:
		var cid: String = c.get("id", "")
		if _battle_contra_states.get(cid, false):
			c_ok += 1
	_battle_status.text = "推理战场评定：假设命中 %d/%d · 矛盾识别 %d/%d" % [h_ok, h_tot, c_ok, c_tot]

func _style_battle_btn(btn: Button, st: int) -> void:
	var sn = StyleBoxFlat.new()
	match st:
		1:  # 采纳/已识别（绿）
			sn.bg_color = Color(0.08, 0.28, 0.08, 0.95)
			sn.border_color = Color(0.2, 0.8, 0.2)
		2:  # 排除（红）
			sn.bg_color = Color(0.32, 0.08, 0.08, 0.95)
			sn.border_color = Color(0.85, 0.35, 0.25)
		_:  # 未定（灰）
			sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
			sn.border_color = Color(0.55, 0.42, 0.20)
	sn.border_width_left = 2; sn.border_width_right = 2
	sn.border_width_top = 2; sn.border_width_bottom = 2
	sn.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sn)

func _update_hypo() -> void:
	if not _hypo_list: return
	for c in _hypo_list.get_children(): c.queue_free()
	var assoc: Array = []
	for c in _clues:
		if c.get("associated", false):
			assoc.append(c)
	if assoc.is_empty():
		var ph := Label.new()
		ph.text = "（暂无关联线索）\n点击左栏线索卡片推入此面板；再次点击同一卡片可退出。"
		ph.add_theme_font_size_override("font_size", 16)
		ph.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ph.custom_minimum_size = Vector2(720, 80)
		_hypo_list.add_child(ph)
		return
	for c in assoc:
		var b := Button.new()
		b.text = c.get("name", c.get("label", c.get("id", "")))
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		b.custom_minimum_size = Vector2(720, 46)
		_style_card(b, true)
		b.pressed.connect(_show_clue_detail.bind(c))
		_hypo_list.add_child(b)

func _input(event: InputEvent) -> void:
	if _verifying: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()

## 公开关闭入口（供 DetectiveScene 做「点一次开/再点一次关」单例切换）。
func close_wall() -> void:
	_on_back_pressed()

## 返回/关闭：先通知场景（用于恢复玩家进入前的状态），再销毁浮层。
## 验证结果展示期间锁定，避免误关丢失判定。
func _on_back_pressed() -> void:
	if _verifying: return
	if _on_close.is_valid(): _on_close.call()
	queue_free()

func _on_verify_pressed() -> void:
	_verifying = true
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

	# 结构化验证报告（06 §2.3）：假设名 + 等级 + 支持依据 + 存疑点 + 行动建议
	_last_report = _compute_report(v)
	var rep = Label.new()
	rep.text = _last_report
	rep.add_theme_font_size_override("font_size", 18)
	rep.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	rep.position = Vector2(160, 430); rep.size = Vector2(1600, 220)
	rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep.horizontal_alignment = 1
	add_child(rep)

	# 结论里程碑（06 §2.4）：达到「已获证实」则点亮全部事实节点
	if v == Verdict.VERIFIED:
		for m in _milestones: m["lit"] = true
		_milestone_confirmed = _milestone_total
		_update_milestone_ui()

	# 推理战场小结（M1）：若本场景结构化了假设/矛盾，验证时一并汇报命中
	if not _battle.is_empty() and _battle_status:
		var summ = Label.new()
		summ.text = _battle_status.text
		summ.add_theme_font_size_override("font_size", 18)
		summ.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		summ.position = Vector2(0, 660); summ.size = Vector2(1920, 40)
		summ.horizontal_alignment = 1
		add_child(summ)

	await get_tree().create_timer(2.5).timeout
	if _on_verify: _on_verify.call(v)
	queue_free()

## 结构化验证报告（06 §2.3 验证报告规范）
func _compute_report(v: int) -> String:
	var levels = {0: "矛盾冲突", 1: "证据不足", 2: "倾向成立", 3: "已获证实"}
	var hypo_name: String = _hypothesis.get("title", "")
	var support := 0; var misleading := 0
	for c in _clues:
		if c.get("associated", false):
			if c.get("correct", true): support += 1
			else: misleading += 1
	# 困难模式仅给等级，不暴露支持/矛盾明细（06 §八）
	if _difficulty == Diff.HARD:
		return "假设：%s\n验证等级：%s" % [hypo_name, levels.get(v, "?")]
	var report := "假设：%s\n验证等级：%s\n" % [hypo_name, levels.get(v, "?")]
	var actions = {
		Verdict.VERIFIED: "提交结论，推进结案",
		Verdict.SUPPORTED: "深挖剩余疑点，寻找决定性证据完成闭环",
		Verdict.INSUFFICIENT: "补充更多相关证据，或转向其他假设调查",
		Verdict.CONTRADICTORY: "推翻该假设，或寻找证据解释矛盾",
	}
	match v:
		Verdict.VERIFIED:
			report += "支持依据：%d 条正确证据，证据链完整闭合\n行动建议：%s" % [support, actions[v]]
		Verdict.SUPPORTED:
			report += "支持依据：%d 条证据倾向支持\n存疑点：%d 条误导项待排除\n行动建议：%s" % [support, misleading, actions[v]]
		Verdict.INSUFFICIENT:
			report += "存疑点：证据不足（仅关联 %d 条）\n行动建议：%s" % [_associated, actions[v]]
		Verdict.CONTRADICTORY:
			report += "存疑点：存在 %d 条矛盾证据\n行动建议：%s" % [_contradicting, actions[v]]
	return report

## 结论里程碑初始化（06 §2.4）：优先用假设提供的 milestones，否则退化为本场景单节点
func _init_milestones(hypo: Dictionary) -> void:
	_milestones = []
	var ms: Array = hypo.get("milestones", [])
	for m in ms:
		_milestones.append({"id": m.get("id", ""), "text": m.get("text", ""), "lit": false})
	if _milestones.is_empty():
		_milestones.append({"id": "core", "text": hypo.get("title", "核心结论"), "lit": false})
	_milestone_total = _milestones.size()
	_milestone_confirmed = 0

func _update_milestone_ui() -> void:
	if not _milestone_lbl: return
	var blocks := ""
	for m in _milestones:
		blocks += "■" if m["lit"] else "□"
	_milestone_lbl.text = "结论里程碑：%s  已确认事实 %d/%d" % [blocks, _milestone_confirmed, _milestone_total]

## 测试用访问器（headless 集成验证）
func get_milestone_state() -> Dictionary:
	var lit_ids: Array = []
	for m in _milestones:
		if m["lit"]: lit_ids.append(m["id"])
	return {"confirmed": _milestone_confirmed, "total": _milestone_total, "lit_ids": lit_ids}

func get_last_report() -> String:
	return _last_report

func get_difficulty() -> int:
	return _difficulty

## 测试用：直接施加一条线索的关联/取消（绕过鼠标点击，headless 可调用）
func test_associate(cid: String) -> void:
	_toggle_association(cid)
