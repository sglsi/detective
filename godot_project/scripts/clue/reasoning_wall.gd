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

# === v4.0 三星评价：逐链离散判定 ===
var _chain_id: String = ""          # 当前推理链 ID（由 hypothesis.chain_id 提供；空则不计分）
var _expected_clues: int = 0        # 本链应收集线索总数（观察之星「缺失条数」分母）
var _local_clue_count: int = 0       # 本场景已收集条数（案件级大墙下，观察星按此计，不受全案池扩大影响）
var _insight_bonus: int = 0         # 隐藏线索/全追问等洞察加成（场景经 hypothesis.insight_bonus 传入）
var _last_stars: Dictionary = {"observation": 1, "reasoning": 1, "insight": 1}

# === 战场状态 ===
var _battle: Dictionary = {}
var _battle_hypo_states: Dictionary = {}     # id -> 0未定/1采纳/2排除
var _battle_contra_states: Dictionary = {}   # id -> bool
var _battle_hypo_btns: Dictionary = {}
var _battle_contra_btns: Dictionary = {}

# === 跨重开持久化（#场景二卡死修复）===
# 推理墙是瞬时节点，每次 setup() 从 0 重建会丢失已提交状态。
# _state_store 由场景持有（scene._wall_state），墙在 setup 时读取、在状态变化时写回，
# 使「提交验证后关墙再重开」能恢复到已提交状态，且验证后关墙可推进剧情。
var _state_store: Dictionary = {}            # 外部传入的持久化字典引用（场景持有）
var _persist_enabled: bool = false           # 是否启用跨重开持久化（由调用方 setup 时开启）
var _verified: bool = false                  # 本次/历史是否已提交过验证（拿到判定）
var _verified_verdict: int = -1              # 最近一次提交得到的判定
var _on_advance: Callable = Callable()       # 验证后关墙时推进剧情的回调（仅推理阶段有效）

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
var _assoc_list: GridContainer = null
var _battlefield_box: VBoxContainer = null
var _milestone_lbl: Label = null
var _star_lbl: Label = null
var _status_lbl: Label = null
var _verdict_lbl: Label = null
var _detail_popup: AcceptDialog = null
var _history_panel: Control = null
var _hist_win: PanelContainer = null          # 可拖动的窗口本体
var _hist_drag := false
var _hist_drag_offset := Vector2.ZERO
var _verify_win: Control = null               # 「提交验证」结果窗口
var _verify_v: int = 0                        # 当前判定等级（供 ESC 确认）
var _verify_drag := false
var _verify_drag_offset := Vector2.ZERO

var _card_btns: Dictionary = {}              # clue_id -> Button

# === 阶段3：线索对比台 + 矛盾疑点册 ===
var _compare_slots: Array = []               # 对比台两条线索（clue dict），最多 2 条
var _doubt_book: Array = []                  # 已发现疑点：[{"cid":..,"a":..,"b":..}]
var _comparison_desk: Control = null
var _desk_body: VBoxContainer = null
var _slot_a_lbl: Label = null
var _slot_b_lbl: Label = null
var _result_lbl: Label = null
var _notebook_vb: VBoxContainer = null

# === 常量 ===
const COL_GOLD := Color(0.92, 0.84, 0.55)
const COL_GOLD_LIGHT := Color(0.95, 0.90, 0.78)
const COL_BG := Color(0.06, 0.05, 0.08, 0.97)
const COL_PANEL := Color(0.10, 0.08, 0.06, 0.92)
const COL_GREEN := Color(0.4, 0.85, 0.4)
const COL_YELLOW := Color(0.95, 0.8, 0.2)
const COL_RED := Color(0.95, 0.3, 0.3)


func setup(clues: Array, hypothesis: Dictionary, on_verify: Callable, on_close: Callable = Callable(), difficulty: int = Diff.NORMAL, on_continue: Callable = Callable(), state_store: Dictionary = {}, on_advance: Callable = Callable(), persist: bool = false, local_clue_count: int = -1) -> void:
	_clues = clues
	_hypothesis = hypothesis
	_on_verify = on_verify
	_on_close = on_close
	_on_continue = on_continue
	_difficulty = difficulty
	_state_store = state_store
	_persist_enabled = persist
	_on_advance = on_advance
	_battle = hypothesis.get("battlefield", {})
	_case_name = hypothesis.get("case_name", _case_name)
	_chain_id = hypothesis.get("chain_id", "")
	_expected_clues = hypothesis.get("expected_clues", _clues.size())
	# 案件级大墙：_clues 可能是全案池（跨场景），观察星须按「本场景已收集条数」计，避免被池扩大抬高
	_local_clue_count = local_clue_count if local_clue_count >= 0 else _clues.size()
	_insight_bonus = hypothesis.get("insight_bonus", 0)
	_init_milestones(hypothesis)
	_restore_state()      # 构建 UI 前回填关联/战场/里程碑/verified（首次为空则 no-op）
	_create_ui()
	_update_all()


func get_verdict() -> int:
	if _contradicting > 0: return Verdict.CONTRADICTORY
	if _associated >= 3: return Verdict.VERIFIED
	if _associated >= 1: return Verdict.SUPPORTED
	return Verdict.INSUFFICIENT


func close_wall() -> void:
	_on_back_pressed()


# === 跨重开持久化（#场景二卡死修复）===
## 推理墙为瞬时节点，重建即丢失进度。状态由场景持有的 _state_store 引用保存：
## 关联线索 id、战场假设/矛盾状态、里程碑点亮、verified 标记与最近判定。

func _restore_state() -> void:
	if not _persist_enabled: return
	if _state_store.is_empty(): return
	var saved_assoc: Array = _state_store.get("associated", [])
	var assoc_set := {}
	for s in saved_assoc: assoc_set[s] = true
	_associated = 0; _contradicting = 0
	_doubt_book = _state_store.get("doubt_book", [])
	for c in _clues:
		if assoc_set.has(c.get("id", "")):
			c["associated"] = true
			_associated += 1
			if not c.get("correct", true): _contradicting += 1
		else:
			c["associated"] = false
	var bf: Dictionary = _state_store.get("battlefield", {})
	_battle_hypo_states = {}
	_battle_contra_states = {}
	for h in _battle.get("hypotheses", []):
		var hid: String = h.get("id", "")
		if bf.has(hid): _battle_hypo_states[hid] = int(bf[hid])
	for c in _battle.get("contradictions", []):
		var cid: String = c.get("id", "")
		if bf.has(cid): _battle_contra_states[cid] = bool(bf[cid])
	for m in _milestones:
		m["lit"] = (m["id"] in _state_store.get("milestones_lit", []))
	_verified = _state_store.get("verified", false)
	_verified_verdict = _state_store.get("verdict", -1)


func _persist_state() -> void:
	if not _persist_enabled: return   # 调用方未开启持久化则不写（兼容旧调用方）
	var assoc := []
	for c in _clues:
		if c.get("associated", false): assoc.append(c.get("id", ""))
	var m_lit := []
	for m in _milestones:
		if m["lit"]: m_lit.append(m["id"])
	var bf := {}
	for h in _battle.get("hypotheses", []):
		bf[h.get("id", "")] = _battle_hypo_states.get(h.get("id", ""), 0)
	for c in _battle.get("contradictions", []):
		bf[c.get("id", "")] = _battle_contra_states.get(c.get("id", ""), false)
	_state_store.clear()
	_state_store["associated"] = assoc
	_state_store["milestones_lit"] = m_lit
	_state_store["battlefield"] = bf
	_state_store["verified"] = _verified
	_state_store["verdict"] = _verified_verdict
	_state_store["doubt_book"] = _doubt_book


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
	mid.offset_bottom = -240   # 收拢到底部对话栏(y=850~1080)之上，避免三栏内容被对话栏遮挡（mid 底≈840）
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
	title.offset_right = 320
	bar.add_child(title)

	var diff_lbl := Label.new()
	diff_lbl.text = "难度：%s" % ["简单", "普通", "困难"][_difficulty]
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	diff_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	diff_lbl.offset_left = 320
	diff_lbl.offset_right = 480
	bar.add_child(diff_lbl)

	var help_btn := Button.new()
	help_btn.text = "❓ 求助"
	help_btn.add_theme_font_size_override("font_size", 16)
	help_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	help_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	help_btn.offset_right = -130
	help_btn.offset_left = -250
	help_btn.pressed.connect(_on_help_pressed)
	bar.add_child(help_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_right = -20
	close_btn.offset_left = -110
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
	_milestone_lbl.offset_right = 900
	bar.add_child(_milestone_lbl)

	_star_lbl = Label.new()
	_star_lbl.add_theme_font_size_override("font_size", 20)
	_star_lbl.add_theme_color_override("font_color", COL_GOLD)
	_star_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	_star_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_star_lbl.offset_right = -20
	_star_lbl.offset_left = -400
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

	# 使用 MarginContainer + VBoxContainer 管理内部，避免锚点导致子控件被压窄
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 14
	margin.offset_top = 10
	margin.offset_right = -22
	margin.offset_bottom = -14
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "已收集线索"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.custom_minimum_size = Vector2(200, 30)
	vb.add_child(title)

	# 搜索框
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索线索..."
	_search_edit.add_theme_font_size_override("font_size", 14)
	_search_edit.custom_minimum_size = Vector2(200, 34)
	_search_edit.text_changed.connect(_on_search_changed)
	vb.add_child(_search_edit)

	# 筛选按钮行
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	filter_row.custom_minimum_size = Vector2(200, 32)
	vb.add_child(filter_row)

	_filter_all = _make_filter_btn("全部", true)
	_filter_assoc = _make_filter_btn("已关联", false)
	_filter_unassoc = _make_filter_btn("未关联", false)
	_filter_misleading = _make_filter_btn("干扰", false)
	filter_row.add_child(_filter_all)
	filter_row.add_child(_filter_assoc)
	filter_row.add_child(_filter_unassoc)
	filter_row.add_child(_filter_misleading)

	# 线索滚动列表（整列可滚轮滚动：含线索卡片 + 底部「调查记录」按钮）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP   # 悬停即捕获滚轮，Web/桌面通用
	vb.add_child(scroll)

	# inner 包住线索列表 + 调查记录按钮，保证整列（含最底部按钮）都能滚到
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = 0   # 高度由内容决定，ScrollContainer 才能检测溢出并滚动
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	_clue_list = VBoxContainer.new()
	_clue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 关键：不可设为垂直 EXPAND_FILL —— 否则列表撑满 scroll 高度、永远不出现滚动条，
	# 长列表最底部的卡片/「调查记录」按钮会被下方对话栏/底栏盖住且点不到。
	_clue_list.size_flags_vertical = 0
	_clue_list.add_theme_constant_override("separation", 8)
	inner.add_child(_clue_list)

	# 右下角：调查记录按钮（查看历史信息，方案 A）——放入滚动区，确保最底部也能滚到
	var rec_row := HBoxContainer.new()
	rec_row.alignment = BoxContainer.ALIGNMENT_END
	rec_row.add_theme_constant_override("separation", 8)
	rec_row.custom_minimum_size = Vector2(200, 44)
	inner.add_child(rec_row)
	var rec_btn := _make_action_btn("调查记录")
	rec_btn.pressed.connect(_on_investigate_pressed)
	rec_row.add_child(rec_btn)

	return panel


func _make_filter_btn(text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.20, 0.12, 0.95) if active else Color(0.14, 0.12, 0.08, 0.95)
	s.border_color = Color(0.65, 0.55, 0.30)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(_on_filter_pressed.bind(btn))
	return btn


# 统一风格的动作按钮（提交验证 / 返回 / 调查记录 共用）
func _make_action_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", COL_GOLD)
	btn.custom_minimum_size = Vector2(140, 44)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.50, 0.10, 0.10, 0.95)
	s.border_color = Color(0.85, 0.65, 0.25)
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", s)
	return btn


func _create_center_panel() -> Control:
	var panel := Control.new()

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 8
	bg.offset_right = -8
	panel.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 14
	margin.offset_top = 12
	margin.offset_right = -14
	margin.offset_bottom = -12
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	# 顶部行：核心问题 + 验证等级
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vb.add_child(top_row)

	var core_title := Label.new()
	core_title.text = "核心问题：" + _hypothesis.get("title", "")
	core_title.add_theme_font_size_override("font_size", 22)
	core_title.add_theme_color_override("font_color", COL_GOLD)
	core_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	core_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_title.custom_minimum_size = Vector2(300, 32)
	top_row.add_child(core_title)

	_verdict_lbl = Label.new()
	_verdict_lbl.text = "当前判定：证据不足"
	_verdict_lbl.add_theme_font_size_override("font_size", 16)
	_verdict_lbl.add_theme_color_override("font_color", COL_YELLOW)
	_verdict_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	_verdict_lbl.custom_minimum_size = Vector2(160, 28)
	top_row.add_child(_verdict_lbl)

	var core_desc := Label.new()
	core_desc.text = _hypothesis.get("description", "")
	core_desc.add_theme_font_size_override("font_size", 14)
	core_desc.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	core_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	core_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_desc.custom_minimum_size = Vector2(200, 40)
	vb.add_child(core_desc)

	# 假设树滚动区
	var tree_scroll := ScrollContainer.new()
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(tree_scroll)

	_tree_root = VBoxContainer.new()
	_tree_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_root.size_flags_vertical = 0   # 内容高度驱动滚动：长假设树可滚轮滚动
	_tree_root.add_theme_constant_override("separation", 10)
	tree_scroll.add_child(_tree_root)

	# 关联面板（底部固定高度）
	var assoc_box := VBoxContainer.new()
	assoc_box.add_theme_constant_override("separation", 6)
	assoc_box.custom_minimum_size = Vector2(200, 110)
	vb.add_child(assoc_box)

	var assoc_title := Label.new()
	assoc_title.text = "关联面板（已推入的线索，点击查看详情）"
	assoc_title.add_theme_font_size_override("font_size", 15)
	assoc_title.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	assoc_title.custom_minimum_size = Vector2(200, 22)
	assoc_box.add_child(assoc_title)

	var assoc_scroll := ScrollContainer.new()
	assoc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assoc_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assoc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	assoc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # 关联线索多时纵向滚动，不向右溢出
	assoc_box.add_child(assoc_scroll)

	# 用 GridContainer 自动换行，关联线索再多也只在中心面板宽度内折行，
	# 不会向右溢出盖住右侧「推理战场」栏（原 HBox 单行横排会一直向右延伸）。
	_assoc_list = GridContainer.new()
	_assoc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_assoc_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_assoc_list.columns = 4
	_assoc_list.add_theme_constant_override("h_separation", 8)
	_assoc_list.add_theme_constant_override("v_separation", 8)
	assoc_scroll.add_child(_assoc_list)

	# 底部操作行
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	bottom_row.custom_minimum_size = Vector2(200, 48)
	vb.add_child(bottom_row)

	_status_lbl = Label.new()
	_status_lbl.text = "点击左侧线索推入关联面板，再次点击可移除"
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.custom_minimum_size = Vector2(200, 40)
	bottom_row.add_child(_status_lbl)

	var verify_btn := _make_action_btn("提交验证")
	verify_btn.pressed.connect(_on_verify_pressed)
	bottom_row.add_child(verify_btn)

	# 阶段3：线索对比台固定在中央区底部，预留 ~150px 高度
	margin.offset_bottom = -162
	var desk := _build_comparison_desk()
	desk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	desk.offset_top = -150
	desk.offset_bottom = -8
	panel.add_child(desk)
	_comparison_desk = desk

	return panel


# === 阶段3：线索对比台 + 矛盾疑点册 ===
func _build_comparison_desk() -> Control:
	var desk := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.11, 0.09, 0.98)
	s.border_color = Color(0.55, 0.65, 0.45, 0.7)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(6)
	desk.add_theme_stylebox_override("panel", s)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_theme_constant_override("margin_left", 10)
	vb.add_theme_constant_override("margin_top", 6)
	vb.add_theme_constant_override("margin_right", 10)
	vb.add_theme_constant_override("margin_bottom", 6)
	desk.add_child(vb)

	var hdr := HBoxContainer.new()
	var title := Label.new()
	title.text = "线索对比台（放入两条线索比对，发现矛盾即入疑点册）"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var collapse_btn := Button.new()
	collapse_btn.text = "▾"
	collapse_btn.add_theme_font_size_override("font_size", 14)
	collapse_btn.pressed.connect(_on_desk_collapse)
	hdr.add_child(collapse_btn)
	vb.add_child(hdr)

	_desk_body = VBoxContainer.new()
	_desk_body.add_theme_constant_override("separation", 6)
	vb.add_child(_desk_body)

	var rowA := HBoxContainer.new()
	_slot_a_lbl = Label.new()
	_slot_a_lbl.text = "槽A：空"
	_slot_a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_a_lbl.add_theme_font_size_override("font_size", 14)
	_slot_a_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.65))
	rowA.add_child(_slot_a_lbl)
	_desk_body.add_child(rowA)

	var rowB := HBoxContainer.new()
	_slot_b_lbl = Label.new()
	_slot_b_lbl.text = "槽B：空"
	_slot_b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_b_lbl.add_theme_font_size_override("font_size", 14)
	_slot_b_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.65))
	rowB.add_child(_slot_b_lbl)
	_desk_body.add_child(rowB)

	var cmp_row := HBoxContainer.new()
	var cmp_btn := Button.new()
	cmp_btn.text = "比对"
	cmp_btn.add_theme_font_size_override("font_size", 15)
	cmp_btn.add_theme_color_override("font_color", COL_GOLD)
	cmp_btn.pressed.connect(_on_compare_pressed)
	cmp_row.add_child(cmp_btn)
	var clr_btn := Button.new()
	clr_btn.text = "清空"
	clr_btn.add_theme_font_size_override("font_size", 13)
	clr_btn.pressed.connect(func(): _compare_slots = []; _refresh_desk())
	cmp_row.add_child(clr_btn)
	_desk_body.add_child(cmp_row)

	_result_lbl = Label.new()
	_result_lbl.text = "（把两条线索放入对比台，点击「比对」）"
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_lbl.add_theme_font_size_override("font_size", 14)
	_result_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.6))
	_desk_body.add_child(_result_lbl)

	_notebook_vb = VBoxContainer.new()
	_notebook_vb.add_theme_constant_override("separation", 3)
	_desk_body.add_child(_notebook_vb)

	return desk


func _on_desk_collapse() -> void:
	if not _desk_body: return
	_desk_body.visible = not _desk_body.visible


func _find_clue(cid: String) -> Dictionary:
	for c in _clues:
		if c.get("id", "") == cid: return c
	return {}


func _clue_name(cid: String) -> String:
	var c: Dictionary = _find_clue(cid)
	if c.is_empty(): return cid
	return c.get("name", cid)


func _load_comparison(cid: String) -> void:
	var clue: Dictionary = _find_clue(cid)
	if clue.is_empty(): return
	if _compare_slots.size() < 2:
		for i in range(_compare_slots.size()):
			if _compare_slots[i].get("id", "") == cid:
				_compare_slots.remove_at(i)
				break
		_compare_slots.append(clue)
	else:
		_compare_slots.remove_at(0)
		_compare_slots.append(clue)
	_refresh_desk()


func _refresh_desk() -> void:
	if not _slot_a_lbl or not _slot_b_lbl: return
	var a: String = "空"
	var b: String = "空"
	if _compare_slots.size() >= 1: a = _compare_slots[0].get("name", _compare_slots[0].get("id", "?"))
	if _compare_slots.size() >= 2: b = _compare_slots[1].get("name", _compare_slots[1].get("id", "?"))
	_slot_a_lbl.text = "槽A：" + a
	_slot_b_lbl.text = "槽B：" + b
	if _notebook_vb:
		for c in _notebook_vb.get_children(): c.queue_free()
		if _doubt_book.is_empty():
			var empty := Label.new()
			empty.text = "（疑点册为空）"
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", Color(0.5, 0.48, 0.40))
			_notebook_vb.add_child(empty)
		else:
			for d in _doubt_book:
				var lab := Label.new()
				lab.text = "• %s  （%s ↔ %s）" % [_contradiction_title(d.get("cid", "")), _clue_name(d.get("a", "")), _clue_name(d.get("b", ""))]
				lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lab.add_theme_font_size_override("font_size", 13)
				lab.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
				_notebook_vb.add_child(lab)


func _contradiction_title(cid: String) -> String:
	for c in _battle.get("contradictions", []):
		if c.get("id", "") == cid: return c.get("text", cid)
	return cid


func _detect_contradiction(a: Dictionary, b: Dictionary) -> Array:
	var ta: Array = a.get("relation_tags", [])
	var tb: Array = b.get("relation_tags", [])
	var ca: Array = []
	var cb: Array = []
	for t in ta:
		if t.begins_with("C"): ca.append(t)
	for t in tb:
		if t.begins_with("C"): cb.append(t)
	var out := []
	for t in ca:
		if cb.has(t) and not out.has(t):
			out.append(t)
	return out


func _on_compare_pressed() -> void:
	if _compare_slots.size() < 2:
		if _result_lbl: _result_lbl.text = "请先放入两条线索再比对"
		return
	var a: Dictionary = _compare_slots[0]
	var b: Dictionary = _compare_slots[1]
	var hits: Array = _detect_contradiction(a, b)
	if hits.is_empty():
		if _result_lbl: _result_lbl.text = "暂未发现冲突（无矛盾，无任何惩罚）"
		return
	var names := []
	for cid in hits:
		names.append(_contradiction_title(cid))
	if _result_lbl: _result_lbl.text = "发现疑点：" + ", ".join(names)
	for cid in hits:
		_add_doubt(cid, a.get("id", ""), b.get("id", ""))
		_battle_contra_states[cid] = true   # 直接标记（键可能原不存在，幂等）
	_refresh_battlefield_status_only()
	_refresh_desk()
	_persist_state()


func _add_doubt(cid: String, a: String, b: String) -> void:
	for d in _doubt_book:
		if d.get("cid", "") == cid:
			return
	_doubt_book.append({"cid": cid, "a": a, "b": b})


func _create_right_panel() -> Control:
	var panel := Control.new()

	var bg := ColorRect.new()
	bg.color = COL_PANEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 8
	panel.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 14
	margin.offset_top = 10
	margin.offset_right = -14
	margin.offset_bottom = -14
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "推理战场"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.custom_minimum_size = Vector2(200, 30)
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_battlefield_box = VBoxContainer.new()
	_battlefield_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battlefield_box.size_flags_vertical = 0   # 内容高度驱动滚动：战场假设多时可滚轮滚动
	_battlefield_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_battlefield_box)

	# 右下角：返回按钮（立即关闭推理墙，回到观察阶段，方案 A）
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_END
	back_row.add_theme_constant_override("separation", 8)
	back_row.custom_minimum_size = Vector2(200, 44)
	vb.add_child(back_row)
	var back_btn := _make_action_btn("返回")
	back_btn.pressed.connect(_on_back_pressed)
	back_row.add_child(back_btn)

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


# === 阶段2：证据属性标签 + 可信度（由 attribute_tags 派生）===
func _attribute_label_of(clue: Dictionary) -> String:
	var at: Array = clue.get("attribute_tags", [])
	if at.is_empty(): return "其他"
	return at[0]


func _credibility_of(clue: Dictionary) -> String:
	var at: Array = clue.get("attribute_tags", [])
	if at.has("直接物证"): return "高"
	if at.has("目击证词"): return "中"
	if at.has("嫌疑人陈述"): return "中"
	if at.has("二手传闻"): return "低"
	return "中"


func _make_clue_card(clue: Dictionary) -> Button:
	var card := Button.new()
	var name: String = clue.get("name", clue.get("label", clue.get("id", "")))
	var state := _clue_state(clue)
	var state_text: String = ["已收集", "已关联", "已验证", "已失效"][state]
	var attr: String = _attribute_label_of(clue)
	var cred: String = _credibility_of(clue)
	card.text = name
	if _difficulty != Diff.HARD:
		card.text += "  [%s]" % state_text
	card.text += "\n%s · 可信度:%s" % [attr, cred]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.tooltip_text = clue.get("desc", "")
	card.custom_minimum_size = Vector2(200, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(200, 40)
		_tree_root.add_child(empty)
		return

	for h in hypos:
		var node := _make_hypothesis_node(h)
		_tree_root.add_child(node)


func _make_hypothesis_node(h: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.45, 0.35, 0.15, 0.5)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var correct: bool = h.get("correct", false)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vb.add_child(top_row)

	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(160, 24)
	top_row.add_child(lbl)

	# 状态标记
	if _difficulty != Diff.HARD:
		var tag := Label.new()
		tag.text = "正确" if correct else "待定"
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4) if correct else Color(0.7, 0.7, 0.7))
		tag.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		tag.custom_minimum_size = Vector2(48, 20)
		top_row.add_child(tag)

	# 子假设/证据行
	var evi := _evidence_for_hypothesis(id)
	var evi_lbl := Label.new()
	evi_lbl.text = "证据：" + (", ".join(evi) if not evi.is_empty() else "（暂无）")
	evi_lbl.add_theme_font_size_override("font_size", 13)
	evi_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.55) if not evi.is_empty() else Color(0.50, 0.45, 0.38))
	evi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evi_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evi_lbl.custom_minimum_size = Vector2(160, 20)
	vb.add_child(evi_lbl)

	return card


func _evidence_for_hypothesis(hid: String) -> Array:
	var out := []
	# 标签驱动（阶段1）：仅当线索「已关联」且其 relation_tags 含该假设节点 id 时，
	# 才作为该节点的证据。替换原退化逻辑（relation_tags 为空则全量罗列），
	# 实现「线索按标签自动匹配假设」——不同线索精确落到对应假设/矛盾节点。
	for c in _clues:
		if c.get("associated", false):
			var tags: Array = c.get("relation_tags", [])
			if tags.has(hid):
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
		ph.custom_minimum_size = Vector2(160, 40)
		_assoc_list.add_child(ph)
		return
	for c in assoc:
		var b := Button.new()
		b.text = c.get("name", c.get("id", ""))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 长线索名在格子内换行，宽度跟随列宽，不撑破中心面板
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_horizontal = Control.SIZE_FILL
		b.size_flags_vertical = Control.SIZE_FILL
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
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(160, 40)
		_battlefield_box.add_child(empty)
		return

	if not hypos.is_empty():
		var hl := Label.new()
		hl.text = "活跃假设（点击标记：未定→采纳→排除）"
		hl.add_theme_font_size_override("font_size", 14)
		hl.add_theme_color_override("font_color", Color(0.70, 0.85, 0.95))
		hl.custom_minimum_size = Vector2(160, 22)
		_battlefield_box.add_child(hl)
		for h in hypos:
			_battlefield_box.add_child(_make_battle_hypo_card(h))

	if not contras.is_empty():
		var cl := Label.new()
		cl.text = "矛盾标记（点击标记是否已识别）"
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.70))
		cl.custom_minimum_size = Vector2(160, 22)
		_battlefield_box.add_child(cl)
		for c in contras:
			_battlefield_box.add_child(_make_battle_contra_card(c))

	var status := Label.new()
	status.text = _battle_status_text()
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", COL_GREEN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.custom_minimum_size = Vector2(160, 40)
	_battlefield_box.add_child(status)


func _make_battle_hypo_card(h: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.45, 0.35, 0.15, 0.5)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	# 纵向布局：上方为假设文字，下方为整行铺满卡片宽度的状态按钮（点击区=整个按钮区域）
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(0, 32)
	vb.add_child(lbl)

	var btn := Button.new()
	var hst: int = _battle_hypo_states.get(id, 0)
	btn.text = ["未定", "采纳✓", "排除✗"][hst]
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(93, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_battle_hypo_pressed.bind(id))
	_style_battle_btn(btn, hst)
	vb.add_child(btn)
	_battle_hypo_btns[id] = btn

	return card


func _make_battle_contra_card(c: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 84)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.45, 0.35, 0.15, 0.5)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var id: String = c.get("id", "?")
	var text: String = c.get("text", "")
	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(0, 32)
	vb.add_child(lbl)

	var btn := Button.new()
	var cst: bool = _battle_contra_states.get(id, false)
	btn.text = "已识别" if cst else "未识别"
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(93, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_battle_contra_pressed.bind(id))
	_style_battle_btn(btn, 1 if cst else 0)
	vb.add_child(btn)
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
	_persist_state()


func _on_battle_contra_pressed(id: String) -> void:
	var st: bool = not _battle_contra_states.get(id, false)
	_battle_contra_states[id] = st
	var btn = _battle_contra_btns.get(id)
	if btn:
		btn.text = "已识别" if st else "未识别"
		_style_battle_btn(btn, 1 if st else 0)
	_refresh_battlefield_status_only()
	_persist_state()


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

	# 阶段2：证据属性（人证/物证）与可信度
	var ac_row := HBoxContainer.new()
	var ac_lbl := Label.new()
	ac_lbl.text = "证据属性: %s    可信度: %s" % [_attribute_label_of(clue), _credibility_of(clue)]
	ac_lbl.add_theme_font_size_override("font_size", 14)
	ac_lbl.add_theme_color_override("font_color", Color(0.78, 0.72, 0.50))
	ac_row.add_child(ac_lbl)
	vb.add_child(ac_row)

	# 阶段3：从详情弹窗把线索放入对比台
	var desk_row := HBoxContainer.new()
	var to_desk := Button.new()
	to_desk.text = "→ 放入对比台"
	to_desk.add_theme_font_size_override("font_size", 15)
	to_desk.add_theme_color_override("font_color", COL_GOLD)
	to_desk.pressed.connect(func():
		_load_comparison(clue["id"])
		_detail_popup.hide()
	)
	desk_row.add_child(to_desk)
	vb.add_child(desk_row)

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
	var clue: Dictionary = _find_clue(cid)
	if not clue.is_empty():
		_show_clue_detail(clue)


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
	_persist_state()


func _update_all() -> void:
	_refresh_clue_list()
	_refresh_hypothesis_tree()
	_refresh_assoc_panel()
	_refresh_desk()
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

	# 半透明遮罩，吸收窗口外的点击，并压暗底层推理墙
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.z_index = 19
	backdrop.name = "VerifyBackdrop"
	add_child(backdrop)

	# 居中结果窗口（手动计算 position 确保真正居中；PRESET_CENTER 在 add_child 前因 size=0 失效）
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(720, 440)
	win.size = Vector2(720, 440)
	win.z_index = 20
	win.name = "VerifyResult"
	add_child(win)
	win.position = (get_viewport_rect().size - win.size) / 2

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	pstyle.border_color = [COL_RED, COL_YELLOW, Color(0.4, 0.85, 0.4), COL_GREEN][v] as Color
	pstyle.border_width_left = 3; pstyle.border_width_right = 3
	pstyle.border_width_top = 3; pstyle.border_width_bottom = 3
	pstyle.set_corner_radius_all(10)
	win.add_theme_stylebox_override("panel", pstyle)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	win.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	# 标题栏（拖拽手柄）
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 42)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.add_theme_constant_override("separation", 10)
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	tstyle.set_corner_radius_all(6)
	title_bar.add_theme_stylebox_override("panel", tstyle)
	title_bar.gui_input.connect(_on_verify_title_gui)
	vb.add_child(title_bar)

	var title_cap := Label.new()
	title_cap.text = "🔍 验证结果"
	title_cap.add_theme_font_size_override("font_size", 20)
	title_cap.add_theme_color_override("font_color", COL_GOLD)
	title_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_cap)

	var vclose := Button.new()
	vclose.text = "✕"
	vclose.add_theme_font_size_override("font_size", 18)
	vclose.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	vclose.custom_minimum_size = Vector2(40, 32)
	var vcstyle := StyleBoxFlat.new()
	vcstyle.bg_color = Color(0.30, 0.18, 0.18, 0.95)
	vcstyle.border_color = Color(0.7, 0.4, 0.4)
	vcstyle.set_corner_radius_all(4)
	vclose.add_theme_stylebox_override("normal", vcstyle)
	vclose.pressed.connect(_close_verify_win)
	title_bar.add_child(vclose)

	var title := Label.new()
	title.text = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v] as String
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", [COL_RED, COL_YELLOW, Color(0.4, 0.85, 0.4), COL_GREEN][v] as Color)
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(title)

	var rep := Label.new()
	rep.text = _last_report
	rep.add_theme_font_size_override("font_size", 18)
	rep.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(rep)

	if v == Verdict.VERIFIED:
		for m in _milestones: m["lit"] = true
		_milestone_confirmed = _milestone_total
		_update_milestone_ui()

	var ok := Button.new()
	ok.text = "确定"
	ok.add_theme_font_size_override("font_size", 18)
	ok.add_theme_color_override("font_color", COL_GOLD)
	ok.custom_minimum_size = Vector2(160, 46)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.50, 0.10, 0.10, 0.95)
	ks.border_color = Color(0.85, 0.65, 0.25)
	ks.border_width_left = 2; ks.border_width_right = 2
	ks.border_width_top = 2; ks.border_width_bottom = 2
	ks.set_corner_radius_all(4)
	ok.add_theme_stylebox_override("normal", ks)
	ok.pressed.connect(_on_verify_confirm.bind(v))
	vb.add_child(ok)

	_verify_win = win
	_verify_v = v


func _on_verify_confirm(v: int) -> void:
	_verify_win = null
	_verified = true
	_verified_verdict = v
	_persist_state()
	# 立即隐藏并销毁墙，解除全屏 MOUSE_FILTER_STOP 拦截，确保过渡对话可点击/渲染；
	# 不再依赖「等一帧」的 await（Web 运行时偶发不可靠导致卡死）。
	visible = false
	queue_free()
	if _on_verify.is_valid(): _on_verify.call(v)


# 仅关闭验证结果窗口（不确认验证、不关闭推理墙），保留推理墙继续操作
func _close_verify_win() -> void:
	_verify_drag = false
	_verifying = false
	if _verify_win and is_instance_valid(_verify_win):
		_verify_win.queue_free()
		_verify_win = null


# 验证结果窗口标题栏拖拽
func _on_verify_title_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_verify_drag = true
		if _verify_win and is_instance_valid(_verify_win):
			_verify_drag_offset = get_viewport().get_mouse_position() - _verify_win.global_position


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
	# ---- v4.0 三维离散判定（§B-11.5 / 06 §4.1）----
	# 1) 观察之星：按缺失条数（缺≥3→1⭐ / 缺1-2→2⭐ / 缺0→3⭐），不区分线索重要性
	# 案件级大墙下，观察星按「本场景已收集条数」(_local_clue_count) 计，不受全案线索池扩大影响
	var collected := _local_clue_count
	var missing := maxi(0, _expected_clues - collected)
	var observe_stars := 3
	if missing >= 3:
		observe_stars = 1
	elif missing >= 1:
		observe_stars = 2

	# 2) 推理之星：按已关联线索的正确比例（4/4→3⭐ / 3/4→2⭐ / ≤2/4→1⭐），错误无惩罚
	var correct_assoc := 0; var total_assoc := 0
	for c in _clues:
		if c.get("associated", false):
			total_assoc += 1
			if c.get("correct", true): correct_assoc += 1
	var reasoning_stars := 1
	if total_assoc > 0:
		if correct_assoc == total_assoc:
			reasoning_stars = 3
		elif correct_assoc * 4 >= 3 * total_assoc:   # 正确比例 ≥ 3/4
			reasoning_stars = 2
		else:
			reasoning_stars = 1

	# 3) 洞察之星：战场命中比例（绕路/重要方向/最优顺序的代理）+ 隐藏线索加成，封顶 3⭐
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
					else: insight_stars = 1
	# 隐藏线索/全追问等洞察加成（场景经 hypothesis.insight_bonus 传入）
	insight_stars = clampi(insight_stars + _insight_bonus, 1, 3)

	_last_stars = {"observation": observe_stars, "reasoning": reasoning_stars, "insight": insight_stars}
	_star_lbl.text = "观察%d⭐ 推理%d⭐ 洞察%d⭐" % [observe_stars, reasoning_stars, insight_stars]

	# 提交逐链三星到 StarRatingSystem（幂等覆盖；逐链离散制 v4.0）
	if StarRatingSystem and _chain_id != "":
		StarRatingSystem.submit_chain(_chain_id, observe_stars, reasoning_stars, insight_stars)


# === 返回调查 + 历史信息面板 ===
func _on_investigate_pressed() -> void:
	if _verifying: return
	_show_history_panel()


func _show_history_panel() -> void:
	if _history_panel and is_instance_valid(_history_panel):
		_history_panel.queue_free()
		_history_panel = null
		return

	_history_panel = Control.new()
	_history_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_history_panel.z_index = 10
	_history_panel.name = "HistoryPanel"
	add_child(_history_panel)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_panel.add_child(overlay)

	# 可自由拖动的窗口本体
	var win := PanelContainer.new()
	win.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	win.custom_minimum_size = Vector2(720, 560)
	win.size = Vector2(720, 560)
	var wstyle := StyleBoxFlat.new()
	wstyle.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	wstyle.border_color = Color(0.65, 0.55, 0.30)
	wstyle.border_width_left = 2; wstyle.border_width_right = 2
	wstyle.border_width_top = 2; wstyle.border_width_bottom = 2
	wstyle.set_corner_radius_all(8)
	win.add_theme_stylebox_override("panel", wstyle)
	overlay.add_child(win)
	_hist_win = win
	win.position = (get_viewport_rect().size - win.size) / 2

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	win.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# 标题栏（拖拽手柄）
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 42)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.add_theme_constant_override("separation", 10)
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	tstyle.set_corner_radius_all(6)
	title_bar.add_theme_stylebox_override("panel", tstyle)
	title_bar.gui_input.connect(_on_hist_title_gui)
	vb.add_child(title_bar)

	var title := Label.new()
	title.text = "📋 调查历史记录"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title)

	var hclose := Button.new()
	hclose.text = "✕"
	hclose.add_theme_font_size_override("font_size", 18)
	hclose.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	hclose.custom_minimum_size = Vector2(40, 32)
	var hcstyle := StyleBoxFlat.new()
	hcstyle.bg_color = Color(0.30, 0.18, 0.18, 0.95)
	hcstyle.border_color = Color(0.7, 0.4, 0.4)
	hcstyle.set_corner_radius_all(4)
	hclose.add_theme_stylebox_override("normal", hcstyle)
	hclose.pressed.connect(_close_history_panel)
	title_bar.add_child(hclose)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	# 1. 当前推理状态
	var state_sec := _history_section(content, "当前推理状态")
	var v := get_verdict()
	var verdict_text: String = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v]
	var state_lbl := Label.new()
	state_lbl.text = "核心问题：%s\n当前判定：%s\n已关联线索：%d 条" % [_hypothesis.get("title", ""), verdict_text, _associated]
	state_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_lbl.add_theme_font_size_override("font_size", 15)
	state_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	state_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_lbl.custom_minimum_size = Vector2(200, 60)
	state_sec.add_child(state_lbl)

	# 2. 已收集线索
	var clue_sec := _history_section(content, "已收集线索 (%d)" % _clues.size())
	if _clues.is_empty():
		var empty := Label.new()
		empty.text = "（暂无已收集线索）"
		empty.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		clue_sec.add_child(empty)
	else:
		for c in _clues:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			clue_sec.add_child(row)

			var mark := Label.new()
			var is_assoc: bool = c.get("associated", false)
			var correct: bool = c.get("correct", true)
			mark.text = "✓" if is_assoc else "○"
			mark.add_theme_color_override("font_color", COL_GREEN if is_assoc else Color(0.55, 0.50, 0.40))
			mark.custom_minimum_size = Vector2(24, 24)
			row.add_child(mark)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)

			var name_lbl := Label.new()
			name_lbl.text = c.get("name", c.get("id", ""))
			name_lbl.add_theme_font_size_override("font_size", 15)
			name_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(name_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = c.get("desc", "")
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 13)
			desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_lbl.custom_minimum_size = Vector2(160, 20)
			info.add_child(desc_lbl)

			if _difficulty != Diff.HARD:
				var tag := Label.new()
				tag.text = "已关联" if is_assoc else ("正确" if correct else "干扰")
				tag.add_theme_color_override("font_color", COL_GREEN if is_assoc else (COL_GREEN if correct else COL_RED))
				tag.custom_minimum_size = Vector2(60, 24)
				row.add_child(tag)

	# 3. 结论里程碑
	var ms_sec := _history_section(content, "结论里程碑")
	var ms_lbl := Label.new()
	var ms_text := ""
	for m in _milestones:
		ms_text += "■ " if m["lit"] else "□ "
		ms_text += m["text"] + "\n"
	ms_lbl.text = ms_text.strip_edges() if ms_text != "" else "（暂无里程碑）"
	ms_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ms_lbl.add_theme_font_size_override("font_size", 14)
	ms_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	ms_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ms_lbl.custom_minimum_size = Vector2(200, 40)
	ms_sec.add_child(ms_lbl)

	# 底部按钮
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.custom_minimum_size = Vector2(200, 48)
	vb.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	close_btn.custom_minimum_size = Vector2(120, 44)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.22, 0.18, 0.12, 0.95)
	cs.border_color = Color(0.55, 0.45, 0.25)
	cs.border_width_left = 2; cs.border_width_right = 2
	cs.border_width_top = 2; cs.border_width_bottom = 2
	cs.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.pressed.connect(_close_history_panel)
	btn_row.add_child(close_btn)


func _history_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 6)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sec)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", COL_GOLD)
	lbl.custom_minimum_size = Vector2(200, 26)
	sec.add_child(lbl)

	var line := ColorRect.new()
	line.color = Color(0.45, 0.35, 0.15, 0.5)
	line.custom_minimum_size = Vector2(200, 2)
	sec.add_child(line)

	return sec


func _close_history_panel() -> void:
	_hist_drag = false
	_hist_win = null
	if _history_panel and is_instance_valid(_history_panel):
		_history_panel.queue_free()
	_history_panel = null


# 标题栏拖拽
func _on_hist_title_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hist_drag = true
		if _hist_win and is_instance_valid(_hist_win):
			_hist_drag_offset = get_viewport().get_mouse_position() - _hist_win.global_position


# === 输入/关闭 ===
func _input(event: InputEvent) -> void:
	# 历史窗口拖动中：处理移动与松开（即使光标移出标题栏也能停止拖动）
	if _hist_drag:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_hist_drag = false
			return
		if event is InputEventMouseMotion and _hist_win and is_instance_valid(_hist_win):
			_hist_win.global_position = get_viewport().get_mouse_position() - _hist_drag_offset
			return
	# 验证结果窗口拖动中
	if _verify_drag:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_verify_drag = false
			return
		if event is InputEventMouseMotion and _verify_win and is_instance_valid(_verify_win):
			_verify_win.global_position = get_viewport().get_mouse_position() - _verify_drag_offset
			return
	# 验证结果窗口：ESC 直接确认
	if _verify_win and is_instance_valid(_verify_win):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_verify_confirm(_verify_v)
		return
	if _verifying: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _history_panel and is_instance_valid(_history_panel):
				_close_history_panel()
			else:
				_on_back_pressed()


func _on_back_pressed() -> void:
	if _verifying: return
	if _history_panel and is_instance_valid(_history_panel):
		_close_history_panel()
		return
	_persist_state()
	# 已提交验证且本墙为「验证后自动推进」类型（推理阶段打开）：关墙即推进剧情，
	# 解决「提交验证后用返回/X 关墙（而非点确定）导致卡在推理阶段」的问题。
	if _verified and _on_advance.is_valid():
		_on_advance.call()
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


func _debug_ui_counts() -> Dictionary:
	return {
		"clue_list": _clue_list.get_child_count() if _clue_list else -1,
		"tree_root": _tree_root.get_child_count() if _tree_root else -1,
		"battlefield": _battlefield_box.get_child_count() if _battlefield_box else -1,
		"assoc_list": _assoc_list.get_child_count() if _assoc_list else -1,
	}
