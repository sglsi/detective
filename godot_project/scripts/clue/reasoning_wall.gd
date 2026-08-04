extends Control

## 推理墙 — 设计文档 P0 实现（五区布局 + 线索库 + 假设树 + 四级验证 + 结论里程碑）
## 依据：docs/02_核心设计/06_推理墙运行机制.md

enum Verdict { INSUFFICIENT=1, SUPPORTED=2, VERIFIED=3, CONTRADICTORY=0 }
enum Diff { EASY=0, NORMAL=1, HARD=2 }
enum ClueState { COLLECTED=0, ASSOCIATED=1, VERIFIED=2, INVALID=3 }

# === 数据 ===
var _clues: Array = []                       # 线索字典数组
var _hypothesis: Dictionary = {}             # 假设定义
var _difficulty: int = Diff.NORMAL
var _on_verify: Callable = Callable()
var _on_close: Callable = Callable()
var _on_continue: Callable = Callable()
var _verifying := false
var _associated := 0
var _contradicting := 0
var _milestones: Array = []
var _milestone_confirmed: int = 0
var _milestone_total: int = 0
var _last_report: String = ""
var _case_name: String = "血字的研究"

# === 战场状态 ===
var _battle: Dictionary = {}
var _battle_hypo_states: Dictionary = {}     # id -> 0未定/1采纳/2排除
var _battle_contra_states: Dictionary = {}   # id -> bool
var _battle_hypo_btns: Dictionary = {}
var _battle_contra_btns: Dictionary = {}

# === UI 引用 ===
var _top_bar: Control = null
var _left_panel: Control = null
var _center_panel: Control = null
var _right_panel: Control = null
var _bottom_bar: Control = null
var _search_edit: LineEdit = null
var _filter_all: Button = null
var _filter_assoc: Button = null
var _filter_unassoc: Button = null
var _filter_misleading: Button = null
var _clue_list: VBoxContainer = null
var _tree_root: VBoxContainer = null
var _assoc_list: HBoxContainer = null
var _battlefield_box: VBoxContainer = null
var _milestone_lbl: Label = null
var _star_lbl: Label = null
var _status_lbl: Label = null
var _verdict_lbl: Label = null
var _detail_popup: AcceptDialog = null

var _card_btns: Dictionary = {}              # clue_id -> Button

# === 常量 ===
const COL_GOLD := Color(0.92, 0.84, 0.55)
const COL_GOLD_LIGHT := Color(0.95, 0.90, 0.78)
const COL_BG := Color(0.06, 0.05, 0.08, 0.97)
const COL_PANEL := Color(0.10, 0.08, 0.06, 0.92)
const COL_GREEN := Color(0.4, 0.85, 0.4)
const COL_YELLOW := Color(0.95, 0.8, 0.2)
const COL_RED := Color(0.95, 0.3, 0.3)


func setup(clues: Array, hypothesis: Dictionary, on_verify: Callable, on_close: Callable = Callable(), difficulty: int = Diff.NORMAL, on_continue: Callable = Callable()) -> void:
	_clues = clues
	_hypothesis = hypothesis
	_on_verify = on_verify
	_on_close = on_close
	_on_continue = on_continue
	_difficulty = difficulty
	_battle = hypothesis.get("battlefield", {})
	_init_milestones(hypothesis)
	_create_ui()
	_update_all()


func get_verdict() -> int:
	if _contradicting > 0: return Verdict.CONTRADICTORY
	if _associated >= 3: return Verdict.VERIFIED
	if _associated >= 1: return Verdict.SUPPORTED
	return Verdict.INSUFFICIENT


func close_wall() -> void:
	_on_back_pressed()


# === 入口：构建五区布局 ===
func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 顶部功能栏 (高度 60)
	_top_bar = _create_top_bar()
	add_child(_top_bar)

	# 底部进度栏 (高度 70)
	_bottom_bar = _create_bottom_bar()
	add_child(_bottom_bar)

	# 剩余中间区域：左右中三栏
	var mid := Control.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.offset_top = 66
	mid.offset_bottom = -76
	add_child(mid)

	# 左侧面板 (线索库) 28%
	_left_panel = _create_left_panel()
	_left_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_left_panel.offset_right = 540  # 1920*0.28 ≈ 538
	mid.add_child(_left_panel)

	# 右侧面板 (扩展/战场) 26%
	_right_panel = _create_right_panel()
	_right_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_right_panel.offset_left = -500  # 1920*0.26 ≈ 500
	mid.add_child(_right_panel)

	# 中央推理看板 填充左右之间
	_center_panel = _create_center_panel()
	_center_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_panel.offset_left = 548
	_center_panel.offset_right = -508
	mid.add_child(_center_panel)


func _create_top_bar() -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 60

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)

	var title := Label.new()
	title.text = "推理墙 — %s" % _case_name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	title.offset_left = 20
	bar.add_child(title)

	var diff_lbl := Label.new()
	diff_lbl.text = "难度：%s" % ["简单", "普通", "困难"][_difficulty]
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	diff_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	diff_lbl.offset_left = 320
	bar.add_child(diff_lbl)

	var help_btn := Button.new()
	help_btn.text = "❓ 求助"
	help_btn.add_theme_font_size_override("font_size", 16)
	help_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	help_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	help_btn.offset_right = -110
	help_btn.pressed.connect(_on_help_pressed)
	bar.add_child(help_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_right = -20
	close_btn.pressed.connect(_on_back_pressed)
	bar.add_child(close_btn)

	var line := ColorRect.new()
	line.color = Color(0.45, 0.35, 0.15, 0.5)
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -2
	bar.add_child(line)

	return bar


func _create_bottom_bar() -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -70

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)

	_milestone_lbl = Label.new()
	_milestone_lbl.add_theme_font_size_override("font_size", 16)
	_milestone_lbl.add_theme_color_override("font_color", Color(0.80, 0.70, 0.40))
	_milestone_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_milestone_lbl.offset_left = 20
	bar.add_child(_milestone_lbl)

	_star_lbl = Label.new()
	_star_lbl.add_theme_font_size_override("font_size", 20)
	_star_lbl.add_theme_color_override("font_color", COL_GOLD)
	_star_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	_star_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_star_lbl.offset_right = -20
	bar.add_child(_star_lbl)

	var line := ColorRect.new()
	line.color = Color(0.45, 0.35, 0.15, 0.5)
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_bottom = 2
	bar.add_child(line)

	return bar


func _create_left_panel() -> Control:
	var panel := Control.new()

	var bg := ColorRect.new()
	bg.color = COL_PANEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_right = -8
	panel.add_child(bg)

	var title := Label.new()
	title.text = "已收集线索"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 14
	title.offset_top = 10
	title.offset_bottom = 40
	panel.add_child(title)

	# 搜索框
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索线索..."
	_search_edit.add_theme_font_size_override("font_size", 14)
	_search_edit.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_search_edit.offset_left = 14
	_search_edit.offset_top = 44
	_search_edit.offset_right = -22
	_search_edit.offset_bottom = 74
	_search_edit.text_changed.connect(_on_search_changed)
	panel.add_child(_search_edit)

	# 筛选按钮行
	var filter_row := HBoxContainer.new()
	filter_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	filter_row.offset_left = 14
	filter_row.offset_top = 80
	filter_row.offset_right = -22
	filter_row.offset_bottom = 110
	filter_row.add_theme_constant_override("separation", 6)
	panel.add_child(filter_row)

	_filter_all = _make_filter_btn("全部", true)
	_filter_assoc = _make_filter_btn("已关联", false)
	_filter_unassoc = _make_filter_btn("未关联", false)
	_filter_misleading = _make_filter_btn("干扰", false)
	filter_row.add_child(_filter_all)
	filter_row.add_child(_filter_assoc)
	filter_row.add_child(_filter_unassoc)
	filter_row.add_child(_filter_misleading)

	# 线索滚动列表
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14
	scroll.offset_top = 118
	scroll.offset_right = -22
	scroll.offset_bottom = -14
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_clue_list = VBoxContainer.new()
	_clue_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_clue_list)

	return panel


func _make_filter_btn(text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.20, 0.12, 0.95) if active else Color(0.14, 0.12, 0.08, 0.95)
	s.border_color = Color(0.65, 0.55, 0.30)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(_on_filter_pressed.bind(btn))
	return btn


func _create_center_panel() -> Control:
	var panel := Control.new()

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 8
	bg.offset_right = -8
	panel.add_child(bg)

	# 核心问题
	var core_title := Label.new()
	core_title.text = "核心问题：" + _hypothesis.get("title", "")
	core_title.add_theme_font_size_override("font_size", 22)
	core_title.add_theme_color_override("font_color", COL_GOLD)
	core_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	core_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	core_title.offset_left = 20
	core_title.offset_top = 14
	core_title.offset_right = -20
	core_title.offset_bottom = 48
	panel.add_child(core_title)

	var core_desc := Label.new()
	core_desc.text = _hypothesis.get("description", "")
	core_desc.add_theme_font_size_override("font_size", 14)
	core_desc.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	core_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	core_desc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	core_desc.offset_left = 20
	core_desc.offset_top = 50
	core_desc.offset_right = -20
	core_desc.offset_bottom = 86
	panel.add_child(core_desc)

	# 验证等级标签
	_verdict_lbl = Label.new()
	_verdict_lbl.text = "当前判定：证据不足"
	_verdict_lbl.add_theme_font_size_override("font_size", 16)
	_verdict_lbl.add_theme_color_override("font_color", COL_YELLOW)
	_verdict_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_verdict_lbl.offset_top = 14
	_verdict_lbl.offset_right = -20
	panel.add_child(_verdict_lbl)

	# 假设树滚动区
	var tree_scroll := ScrollContainer.new()
	tree_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_scroll.offset_left = 14
	tree_scroll.offset_top = 96
	tree_scroll.offset_right = -14
	tree_scroll.offset_bottom = -110
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(tree_scroll)

	_tree_root = VBoxContainer.new()
	_tree_root.add_theme_constant_override("separation", 10)
	tree_scroll.add_child(_tree_root)

	# 关联面板（底部）
	var assoc_bg := ColorRect.new()
	assoc_bg.color = Color(0.12, 0.10, 0.08, 0.95)
	assoc_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	assoc_bg.offset_left = 14
	assoc_bg.offset_right = -14
	assoc_bg.offset_top = -100
	panel.add_child(assoc_bg)

	var assoc_title := Label.new()
	assoc_title.text = "关联面板（已推入的线索）"
	assoc_title.add_theme_font_size_override("font_size", 15)
	assoc_title.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	assoc_title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	assoc_title.offset_left = 24
	assoc_title.offset_right = -24
	assoc_title.offset_bottom = -78
	panel.add_child(assoc_title)

	var assoc_scroll := ScrollContainer.new()
	assoc_scroll.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	assoc_scroll.offset_left = 24
	assoc_scroll.offset_right = -24
	assoc_scroll.offset_top = -74
	assoc_scroll.offset_bottom = -10
	assoc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(assoc_scroll)

	_assoc_list = HBoxContainer.new()
	_assoc_list.add_theme_constant_override("separation", 8)
	assoc_scroll.add_child(_assoc_list)

	# 验证按钮
	var verify_btn := Button.new()
	verify_btn.text = "提交验证"
	verify_btn.add_theme_font_size_override("font_size", 18)
	verify_btn.add_theme_color_override("font_color", COL_GOLD)
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color(0.50, 0.10, 0.10, 0.95)
	vs.border_color = Color(0.85, 0.65, 0.25)
	vs.border_width_left = 2; vs.border_width_right = 2
	vs.border_width_top = 2; vs.border_width_bottom = 2
	vs.set_corner_radius_all(4)
	verify_btn.add_theme_stylebox_override("normal", vs)
	verify_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	verify_btn.offset_right = -14
	verify_btn.offset_bottom = -108
	verify_btn.offset_top = -148
	verify_btn.offset_left = -160
	verify_btn.pressed.connect(_on_verify_pressed)
	panel.add_child(verify_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "点击左侧线索推入关联面板，再次点击可移除"
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
	_status_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status_lbl.offset_left = 24
	_status_lbl.offset_right = 300
	_status_lbl.offset_bottom = -116
	panel.add_child(_status_lbl)

	return panel


func _create_right_panel() -> Control:
	var panel := Control.new()

	var bg := ColorRect.new()
	bg.color = COL_PANEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 8
	panel.add_child(bg)

	var title := Label.new()
	title.text = "推理战场"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 14
	title.offset_top = 10
	title.offset_bottom = 40
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14
	scroll.offset_top = 44
	scroll.offset_right = -14
	scroll.offset_bottom = -14
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_battlefield_box = VBoxContainer.new()
	_battlefield_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_battlefield_box)

	return panel


# === 线索库 ===
func _refresh_clue_list() -> void:
	if not _clue_list: return
	for c in _clue_list.get_children(): c.queue_free()
	_card_btns.clear()

	var term := _search_edit.text.strip_edges().to_lower()
	var filter := _current_filter()

	for clue in _clues:
		var name: String = clue.get("name", clue.get("label", clue.get("id", "")))
		var state := _clue_state(clue)
		if filter != -1 and state != filter:
			continue
		if term != "" and not name.to_lower().contains(term):
			continue
		var card := _make_clue_card(clue)
		_clue_list.add_child(card)
		_card_btns[clue["id"]] = card


func _current_filter() -> int:
	if _filter_assoc and _filter_assoc.button_pressed: return ClueState.ASSOCIATED
	if _filter_unassoc and _filter_unassoc.button_pressed: return ClueState.COLLECTED
	if _filter_misleading and _filter_misleading.button_pressed: return ClueState.INVALID
	return -1


func _clue_state(clue: Dictionary) -> int:
	if clue.get("associated", false):
		return ClueState.ASSOCIATED if clue.get("correct", true) else ClueState.INVALID
	return ClueState.COLLECTED


func _make_clue_card(clue: Dictionary) -> Button:
	var card := Button.new()
	var name: String = clue.get("name", clue.get("label", clue.get("id", "")))
	var state := _clue_state(clue)
	var state_text: String = ["已收集", "已关联", "已验证", "已失效"][state]
	card.text = name
	if _difficulty != Diff.HARD:
		card.text += "  [%s]" % state_text
	card.tooltip_text = clue.get("desc", "")
	card.custom_minimum_size = Vector2(0, 56)
	card.add_theme_font_size_override("font_size", 15)

	var sn := StyleBoxFlat.new()
	match state:
		ClueState.ASSOCIATED:
			sn.bg_color = Color(0.08, 0.28, 0.08, 0.95)
			sn.border_color = Color(0.2, 0.8, 0.2)
			sn.border_width_left = 2; sn.border_width_right = 2
			sn.border_width_top = 2; sn.border_width_bottom = 2
		ClueState.INVALID:
			sn.bg_color = Color(0.25, 0.10, 0.10, 0.95)
			sn.border_color = Color(0.8, 0.35, 0.25)
			sn.border_width_left = 2; sn.border_width_right = 2
			sn.border_width_top = 2; sn.border_width_bottom = 2
		_:
			sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
			sn.border_color = Color(0.55, 0.42, 0.20)
			sn.border_width_left = 1; sn.border_width_right = 1
			sn.border_width_top = 1; sn.border_width_bottom = 1
	sn.set_corner_radius_all(6)
	card.add_theme_stylebox_override("normal", sn)
	card.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	card.pressed.connect(_on_clue_card_pressed.bind(clue["id"]))
	return card


func _on_filter_pressed(btn: Button) -> void:
	_filter_all.button_pressed = false
	_filter_assoc.button_pressed = false
	_filter_unassoc.button_pressed = false
	_filter_misleading.button_pressed = false
	btn.button_pressed = true
	_refresh_clue_list()


func _on_search_changed(_txt: String) -> void:
	_refresh_clue_list()


# === 假设树 ===
func _refresh_hypothesis_tree() -> void:
	if not _tree_root: return
	for c in _tree_root.get_children(): c.queue_free()

	var hypos: Array = _battle.get("hypotheses", [])
	if hypos.is_empty():
		var empty := Label.new()
		empty.text = "（本推理链暂无结构化假设节点，请直接关联线索）"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		_tree_root.add_child(empty)
		return

	for h in hypos:
		var node := _make_hypothesis_node(h)
		_tree_root.add_child(node)


func _make_hypothesis_node(h: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.08, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)

	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var correct: bool = h.get("correct", false)

	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_left = 12
	lbl.offset_top = 8
	lbl.offset_right = -12
	lbl.offset_bottom = 44
	card.add_child(lbl)

	# 子假设/证据行
	var evi := _evidence_for_hypothesis(id)
	var evi_lbl := Label.new()
	evi_lbl.text = "证据：" + (", ".join(evi) if not evi.is_empty() else "（暂无）")
	evi_lbl.add_theme_font_size_override("font_size", 13)
	evi_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.55) if not evi.is_empty() else Color(0.50, 0.45, 0.38))
	evi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evi_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	evi_lbl.offset_left = 12
	evi_lbl.offset_right = -12
	evi_lbl.offset_bottom = -8
	card.add_child(evi_lbl)

	# 状态标记
	if _difficulty != Diff.HARD:
		var tag := Label.new()
		tag.text = "正确" if correct else "待定"
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4) if correct else Color(0.7, 0.7, 0.7))
		tag.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_top = 8
		tag.offset_right = -12
		card.add_child(tag)

	return card


func _evidence_for_hypothesis(hid: String) -> Array:
	var out := []
	# 简单策略：若线索有关联标记，且其 tags 含该假设 id，则视为证据。
	#  scene1 当前数据未打 relation_tags，退化为：所有已关联线索都作为全局证据展示。
	for c in _clues:
		if c.get("associated", false):
			var tags: Array = c.get("relation_tags", [])
			if tags.is_empty() or tags.has(hid):
				out.append(c.get("name", c.get("id", "")))
	return out


# === 关联面板 ===
func _refresh_assoc_panel() -> void:
	if not _assoc_list: return
	for c in _assoc_list.get_children(): c.queue_free()
	var assoc: Array = []
	for c in _clues:
		if c.get("associated", false): assoc.append(c)
	if assoc.is_empty():
		var ph := Label.new()
		ph.text = "（暂无关联线索）"
		ph.add_theme_font_size_override("font_size", 14)
		ph.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		_assoc_list.add_child(ph)
		return
	for c in assoc:
		var b := Button.new()
		b.text = c.get("name", c.get("id", ""))
		b.custom_minimum_size = Vector2(120, 40)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", COL_GOLD_LIGHT)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.08, 0.30, 0.08, 0.95)
		s.border_color = Color(0.2, 0.8, 0.2)
		s.border_width_left = 1; s.border_width_right = 1
		s.border_width_top = 1; s.border_width_bottom = 1
		s.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", s)
		b.pressed.connect(_show_clue_detail.bind(c))
		_assoc_list.add_child(b)


# === 推理战场 ===
func _refresh_battlefield() -> void:
	if not _battlefield_box: return
	for c in _battlefield_box.get_children(): c.queue_free()
	_battle_hypo_btns.clear()
	_battle_contra_btns.clear()

	var hypos: Array = _battle.get("hypotheses", [])
	var contras: Array = _battle.get("contradictions", [])

	if hypos.is_empty() and contras.is_empty():
		var empty := Label.new()
		empty.text = "（本推理链未配置推理战场）"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_battlefield_box.add_child(empty)
		return

	if not hypos.is_empty():
		var hl := Label.new()
		hl.text = "活跃假设（点击标记：未定→采纳→排除）"
		hl.add_theme_font_size_override("font_size", 14)
		hl.add_theme_color_override("font_color", Color(0.70, 0.85, 0.95))
		_battlefield_box.add_child(hl)
		for h in hypos:
			_battlefield_box.add_child(_make_battle_hypo_card(h))

	if not contras.is_empty():
		var cl := Label.new()
		cl.text = "矛盾标记（点击标记是否已识别）"
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.70))
		_battlefield_box.add_child(cl)
		for c in contras:
			_battlefield_box.add_child(_make_battle_contra_card(c))

	var status := Label.new()
	status.text = _battle_status_text()
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", COL_GREEN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battlefield_box.add_child(status)


func _make_battle_hypo_card(h: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 64)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	lbl.offset_right = -180
	card.add_child(lbl)

	var btn := Button.new()
	btn.text = "未定"
	btn.add_theme_font_size_override("font_size", 13)
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	btn.offset_right = -8
	btn.pressed.connect(_on_battle_hypo_pressed.bind(id))
	card.add_child(btn)
	_battle_hypo_btns[id] = btn

	return card


func _make_battle_contra_card(c: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var id: String = c.get("id", "?")
	var text: String = c.get("text", "")
	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	lbl.offset_right = -180
	card.add_child(lbl)

	var btn := Button.new()
	btn.text = "未识别"
	btn.add_theme_font_size_override("font_size", 13)
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	btn.offset_right = -8
	btn.pressed.connect(_on_battle_contra_pressed.bind(id))
	card.add_child(btn)
	_battle_contra_btns[id] = btn

	return card


func _on_battle_hypo_pressed(id: String) -> void:
	var st: int = _battle_hypo_states.get(id, 0)
	st = (st + 1) % 3
	_battle_hypo_states[id] = st
	var btn = _battle_hypo_btns.get(id)
	if btn:
		btn.text = ["未定", "采纳✓", "排除✗"][st]
		_style_battle_btn(btn, st)
	_refresh_battlefield_status_only()


func _on_battle_contra_pressed(id: String) -> void:
	var st: bool = not _battle_contra_states.get(id, false)
	_battle_contra_states[id] = st
	var btn = _battle_contra_btns.get(id)
	if btn:
		btn.text = "已识别" if st else "未识别"
		_style_battle_btn(btn, 1 if st else 0)
	_refresh_battlefield_status_only()


func _style_battle_btn(btn: Button, st: int) -> void:
	var sn := StyleBoxFlat.new()
	match st:
		1:
			sn.bg_color = Color(0.08, 0.28, 0.08, 0.95)
			sn.border_color = Color(0.2, 0.8, 0.2)
		2:
			sn.bg_color = Color(0.32, 0.08, 0.08, 0.95)
			sn.border_color = Color(0.85, 0.35, 0.25)
		_:
			sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
			sn.border_color = Color(0.55, 0.42, 0.20)
	sn.border_width_left = 1; sn.border_width_right = 1
	sn.border_width_top = 1; sn.border_width_bottom = 1
	sn.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sn)


func _battle_status_text() -> String:
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
	return "推理战场：假设命中 %d/%d · 矛盾识别 %d/%d" % [h_ok, h_tot, c_ok, c_tot]


func _refresh_battlefield_status_only() -> void:
	if not _battlefield_box: return
	for c in _battlefield_box.get_children():
		if c is Label and c.text.begins_with("推理战场："):
			c.text = _battle_status_text()
			return


# === 线索详情弹窗 ===
func _show_clue_detail(clue: Dictionary) -> void:
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()

	_detail_popup = AcceptDialog.new()
	_detail_popup.title = "线索详情"
	_detail_popup.min_size = Vector2(440, 320)
	_detail_popup.exclusive = true

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = clue.get("name", clue.get("label", clue.get("id", "")))
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = clue.get("desc", "（暂无描述）")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(380, 80)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	vb.add_child(desc_lbl)

	if _difficulty != Diff.HARD:
		var tags := HBoxContainer.new()
		var correct: bool = clue.get("correct", true)
		var ct := Button.new()
		ct.text = "✓ 正确线索" if correct else "⚠ 干扰项"
		ct.disabled = true
		ct.add_theme_color_override("font_color", COL_GREEN if correct else COL_RED)
		tags.add_child(ct)
		var src_tag := Label.new()
		src_tag.text = "来源: " + str(clue.get("source", "?"))
		src_tag.add_theme_color_override("font_color", Color(0.5, 0.48, 0.40))
		tags.add_child(src_tag)
		vb.add_child(tags)

	var btn_row := HBoxContainer.new()
	var assoc_btn := Button.new()
	var is_assoc: bool = clue.get("associated", false)
	assoc_btn.text = "取消关联" if is_assoc else "→ 关联到假设面板"
	assoc_btn.pressed.connect(func():
		_detail_popup.hide()
		_toggle_association(clue["id"])
	)
	btn_row.add_child(assoc_btn)
	vb.add_child(btn_row)

	_detail_popup.add_child(vb)
	add_child(_detail_popup)
	_detail_popup.popup_centered()


# === 关联逻辑 ===
func _on_clue_card_pressed(cid: String) -> void:
	_toggle_association(cid)


func _toggle_association(cid: String) -> void:
	var clue: Dictionary = {}
	for c in _clues:
		if c["id"] == cid:
			clue = c; break
	if clue.is_empty(): return

	if clue.get("associated", false):
		clue["associated"] = false
		_associated -= 1
		if not clue.get("correct", true): _contradicting -= 1
		_status_lbl.text = "已取消关联: %s (共%d条)" % [cid, _associated]
		_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.35))
	else:
		clue["associated"] = true
		_associated += 1
		if not clue.get("correct", true): _contradicting += 1
		_status_lbl.text = "线索已关联: %s (共%d条)" % [cid, _associated]
		_status_lbl.add_theme_color_override("font_color", COL_GREEN)

	_update_all()


func _update_all() -> void:
	_refresh_clue_list()
	_refresh_hypothesis_tree()
	_refresh_assoc_panel()
	_refresh_battlefield()
	_update_verdict_label()
	_update_milestone_ui()
	_update_star_rating()


func _update_verdict_label() -> void:
	if not _verdict_lbl: return
	var v := get_verdict()
	var txt: String = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v]
	var col: Color = [COL_RED, COL_YELLOW, Color(0.4, 0.85, 0.4), COL_GREEN][v]
	_verdict_lbl.text = "当前判定：" + txt
	_verdict_lbl.add_theme_color_override("font_color", col)


# === 验证 ===
func _on_verify_pressed() -> void:
	if _verifying: return
	_verifying = true
	var v := get_verdict()
	_last_report = _compute_report(v)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.name = "VerifyOverlay"
	add_child(overlay)

	var title := Label.new()
	title.text = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v] as String
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", [COL_RED, COL_YELLOW, Color(0.4, 0.85, 0.4), COL_GREEN][v] as Color)
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 120
	title.offset_bottom = 180
	overlay.add_child(title)

	var rep := Label.new()
	rep.text = _last_report
	rep.add_theme_font_size_override("font_size", 18)
	rep.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	rep.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	rep.offset_top = 220
	rep.offset_bottom = 420
	rep.offset_left = 160
	rep.offset_right = -160
	overlay.add_child(rep)

	if v == Verdict.VERIFIED:
		for m in _milestones: m["lit"] = true
		_milestone_confirmed = _milestone_total
		_update_milestone_ui()

	await get_tree().create_timer(2.5).timeout
	if _on_verify.is_valid(): _on_verify.call(v)
	queue_free()


func _compute_report(v: int) -> String:
	var levels := {0: "矛盾冲突", 1: "证据不足", 2: "倾向成立", 3: "已获证实"}
	var hypo_name: String = _hypothesis.get("title", "")
	var support := 0; var misleading := 0
	for c in _clues:
		if c.get("associated", false):
			if c.get("correct", true): support += 1
			else: misleading += 1
	if _difficulty == Diff.HARD:
		return "假设：%s\n验证等级：%s" % [hypo_name, levels.get(v, "?")]
	var report := "假设：%s\n验证等级：%s\n" % [hypo_name, levels.get(v, "?")]
	match v:
		Verdict.VERIFIED:
			report += "支持依据：%d 条正确证据，证据链完整闭合\n行动建议：提交结论，推进结案" % support
		Verdict.SUPPORTED:
			report += "支持依据：%d 条证据倾向支持\n存疑点：%d 条误导项待排除\n行动建议：深挖剩余疑点，寻找决定性证据完成闭环" % [support, misleading]
		Verdict.INSUFFICIENT:
			report += "存疑点：证据不足（仅关联 %d 条）\n行动建议：补充更多相关证据，或转向其他假设调查" % _associated
		Verdict.CONTRADICTORY:
			report += "存疑点：存在 %d 条矛盾证据\n行动建议：推翻该假设，或寻找证据解释矛盾" % _contradicting
	return report


# === 里程碑 ===
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
	var lit := 0
	for m in _milestones:
		if m["lit"]:
			blocks += "■"
			lit += 1
		else:
			blocks += "□"
	_milestone_lbl.text = "结论里程碑：%s  已确认事实 %d/%d" % [blocks, lit, _milestone_total]


# === 三星评价 ===
func _update_star_rating() -> void:
	if not _star_lbl: return
	var v := get_verdict()
	# 简化版：推理之星随验证等级；观察之星按已关联正确线索比例；洞察之星按战场命中
	var reasoning_stars := 1
	match v:
		Verdict.SUPPORTED: reasoning_stars = 2
		Verdict.VERIFIED: reasoning_stars = 3
	var correct_assoc := 0; var total_assoc := 0
	for c in _clues:
		if c.get("associated", false):
			total_assoc += 1
			if c.get("correct", true): correct_assoc += 1
	var observe_stars := 1
	if total_assoc > 0:
		var ratio := float(correct_assoc) / total_assoc
		if ratio >= 1.0: observe_stars = 3
		elif ratio >= 0.5: observe_stars = 2
	var insight_stars := 1
	if not _battle.is_empty():
		var txt := _battle_status_text()
		var parts := txt.split("·")
		if parts.size() >= 2:
			var hpart := parts[0].strip_edges()  # "推理战场：假设命中 x/y"
			var cp := hpart.split("/")
			if cp.size() == 2:
				var ok := int(cp[0].split(" ")[-1])
				var tot := int(cp[1])
				if tot > 0:
					var ratio2 := float(ok) / tot
					if ratio2 >= 1.0: insight_stars = 3
					elif ratio2 >= 0.5: insight_stars = 2
	_star_lbl.text = "观察%d⭐ 推理%d⭐ 洞察%d⭐" % [observe_stars, reasoning_stars, insight_stars]


# === 输入/关闭 ===
func _input(event: InputEvent) -> void:
	if _verifying: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()


func _on_back_pressed() -> void:
	if _verifying: return
	if _on_continue.is_valid(): _on_continue.call()
	elif _on_close.is_valid(): _on_close.call()
	queue_free()


func _on_help_pressed() -> void:
	_ui_show_toast("求助次数已在其他系统管理，当前推理链暂无全局扫描报告。")


func _ui_show_toast(msg: String) -> void:
	var toast := Label.new()
	toast.text = msg
	toast.add_theme_font_size_override("font_size", 15)
	toast.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast.offset_top = 70
	toast.offset_right = -20
	add_child(toast)
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(toast): toast.queue_free()


# === 测试用访问器（headless 集成验证）===
func get_milestone_state() -> Dictionary:
	var lit_ids: Array = []
	for m in _milestones:
		if m["lit"]: lit_ids.append(m["id"])
	var lit := 0
	for m in _milestones:
		if m["lit"]: lit += 1
	return {"confirmed": lit, "total": _milestone_total, "lit_ids": lit_ids}


func get_last_report() -> String:
	return _last_report


func get_difficulty() -> int:
	return _difficulty


func test_associate(cid: String) -> void:
	_toggle_association(cid)
