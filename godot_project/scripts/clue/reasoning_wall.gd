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
var _on_persist: Callable = Callable()
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
var _auto_fold: bool = false                 # 场景切换进入已建立关系的墙时自动折叠既有推理主干
var _case_wide: bool = false                 # 全案大墙(use_case_wide)：多人物平铺全部已收集线索/推断/结论
var _verified: bool = false                  # 本次/历史是否已提交过验证（拿到判定）
var _verified_verdict: int = -1              # 最近一次提交得到的判定
var _on_advance: Callable = Callable()       # 验证后关墙时推进剧情的回调（仅推理阶段有效）
var _closing: bool = false                    # 关墙重入保护：ESC/返回/X 只触发一次真正销毁（防 Web 同步 free 栈溢出 + 双触发）

# === UI 引用 ===
var _top_bar: Control = null
var _left_panel: Control = null
var _center_panel: Control = null
var _right_panel: Control = null
var _bottom_bar: Control = null
var _search_edit: LineEdit = null
var _filter_sel: OptionButton = null
var _fold_btn: Button = null
var _export_btn: Button = null
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
var _graph_view: Control = null               # 图谱视图（GraphViewController）叠加层
var _recycle_panel: PanelContainer = null     # 回收站恢复面板

# === 统一顶栏：线型/颜色/视图/焦点 选择器 ===
var _pen_solid_btn: Button = null
var _pen_dashed_btn: Button = null
var _color_btns: Dictionary = {}
var _mode_c_btn: Button = null
var _mode_b_btn: Button = null
var _top_focus_sel: OptionButton = null
var _top_undo_btn: Button = null
var _top_redo_btn: Button = null
var _top_verify_btn: Button = null

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

# === 自由连线（各线索/假设之间拖拽相互关系）===
# 关系数组元素：{"from": String, "to": String, "kind": String}
#   kind ∈ "support"(线索→假设 支持) / "oppose"(线索→假设 反对) /
#         "contradict"(线索↔线索 矛盾) / "relate"(弱关联/假设↔假设 仅连线)
# 设计依据：docs/02_核心设计/06_推理墙运行机制.md §2.2 双交互模式（自由连线模式）
var _relations: Array = []
var _connect_mode: bool = false               # 顶部栏「🔗连线」开关
var _connect_btn: Button = null
var _rel_layer: Control = null                # 关系连线绘制层（全屏覆盖，不拦截输入）
var _hypo_nodes: Dictionary = {}              # 假设节点 id -> Control（用于连线命中与绘制）
var _dragging_link: bool = false
var _link_src: String = ""
var _link_kind: String = "support"
var _drag_src: String = ""                # 左栏拖入图谱：当前拖动的线索 id（"" = 未拖动）
var _drag_origin := Vector2(-1, -1)       # 按下时的鼠标位置，用于判定「是否真拖拽」
var _drag_ghost: Control = null           # 拖拽跟随的幽灵标签
var _link_preview: Vector2 = Vector2.ZERO

# === 常量 ===
const COL_GOLD := Color(0.92, 0.84, 0.55)
const COL_GOLD_LIGHT := Color(0.95, 0.90, 0.78)
const COL_BG := Color(0.06, 0.05, 0.08, 0.97)
const COL_PANEL := Color(0.10, 0.08, 0.06, 0.92)
const COL_GREEN := Color(0.4, 0.85, 0.4)
const COL_YELLOW := Color(0.95, 0.8, 0.2)
const COL_RED := Color(0.95, 0.3, 0.3)
const COL_GREY := Color(0.6, 0.6, 0.6)

# 关系性质按钮 label 映射（_sync_pen_buttons 激活态字体颜色用）
const _COLOR_LABELS := {"green": "支持", "orange": "矛盾存疑", "red": "反对", "grey": "弱关联"}

# === NPC id → 中文名映射（与 graph_view_controller._NPC_DISPLAY_NAMES 镜像）===
# 修根因（2026-08-19 v3 之后 v4）：_derive_persons 把 id 当 name 传出，导致中心节点显示"NPC_WT"。
# graph_view 端三级 fallback（_persons.name → _NPC_DISPLAY_NAMES → 原 id）只在 _persons 的 name ≠ id
# 时才走第二级。直接在这里把 name 填中文，中心永远显示真名，不再依赖下游 fallback。
const _NPC_DISPLAY_NAMES := {
	"NPC_WT": "华生",
		"NPC_MSG": "信使",
	"NPC_HOP": "霍普",
	"NPC_DRE": "德雷伯",
	"NPC_LUCY": "露西",
	"NPC_STAN": "斯丹格森",
	"NPC_LANCE": "兰斯",
}

# === 身份揭示门控（需求2）：某些 NPC 在「揭示名字的证据」被收集前，不得作为已知人物
# 出现在推理墙人物中心。霍普的名字只在收到从美国来的电报（C_SOTCB_501/502，场景五后）
# 才揭晓；此前现场线索（c203-206 等）虽真实关联他，但不得提前显示「霍普」。
const _IDENTITY_REVEAL_GATES := {
	"NPC_HOP": ["C_SOTCB_501", "C_SOTCB_502"],
}

func _npc_display_name(id: String) -> String:
	return _NPC_DISPLAY_NAMES.get(id, id)


## 身份揭示门控（需求2）：判定某 NPC 是否应以"已知人物"出现。live 为当前已收集线索。
func _identity_revealed(pid: String, live: Array) -> bool:
	var gates: Array = _IDENTITY_REVEAL_GATES.get(pid, [])
	if gates.is_empty():
		return true
	for g in gates:
		for c in live:
			if c.get("id", "") == g:
				return true
	return false


func setup(clues: Array, hypothesis: Dictionary, on_verify: Callable, on_close: Callable = Callable(), difficulty: int = Diff.NORMAL, on_continue: Callable = Callable(), state_store: Dictionary = {}, on_advance: Callable = Callable(), persist: bool = false, local_clue_count: int = -1, on_persist: Callable = Callable(), auto_fold: bool = false) -> void:
	_clues = clues
	_hypothesis = hypothesis
	_on_verify = on_verify
	_on_close = on_close
	_on_continue = on_continue
	_difficulty = difficulty
	_state_store = state_store
	_persist_enabled = persist
	_on_advance = on_advance
	_on_persist = on_persist
	_auto_fold = auto_fold
	_case_wide = auto_fold
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
	_on_open_graph_view()    # 图谱=默认主视图（覆盖列表区；左/右/中/底面板已隐藏）


func get_verdict() -> int:
	# 矛盾信号：误导线索(_contradicting) + 关系中的矛盾/反对（线索↔线索矛盾、线索→假设反对）
	if _contradiction_signals() > 0: return Verdict.CONTRADICTORY
	# 支持信号：已关联线索(_associated) + 线索→假设 支持关系
	if _support_signals() >= 3: return Verdict.VERIFIED
	if _support_signals() >= 1: return Verdict.SUPPORTED
	return Verdict.INSUFFICIENT


## 关系信号：把「拖拽相互关系」接入验证判定（原判定只看 _associated/_contradicting 计数，
## 与 design doc §2.2『关联推理应实时更新验证等级』一致）
func _contradiction_signals() -> int:
	var n := _contradicting
	for r in _relations:
		# 虚线（存疑）只显示、不计入判定，防止玩家乱连误判结案
		if r.get("dashed", false):
			continue
		if r.kind == "contradict" or r.kind == "oppose":
			n += 1
	return n


func _support_signals() -> int:
	var n := _associated
	for r in _relations:
		if r.get("dashed", false):
			continue
		if r.kind == "support":
			n += 1
	return n


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
	_relations = []
	for r in _state_store.get("relations", []):
		_relations.append({"from": r.get("from", ""), "to": r.get("to", ""), "kind": r.get("kind", "relate"),
			"color_key": r.get("color_key", _kind_to_key(r.get("kind", "relate"))), "dashed": r.get("dashed", false)})
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
	# ⚠️ 不要 _state_store.clear()！
	# 图谱视图（GraphViewController）把「玩家移动节点位置 / 当前模式 / 焦点 / 引导是否看过」
	# 也写进同一份 _state_store 引用（graph_node_positions / graph_view_mode /
	# graph_focus / graph_seed / graph_tutorial_seen）。clear() 会把它们一起抹掉，
	# 造成「关系能存档、节点位置读档后回到默认」的 Bug1。
	# 这里只覆盖推理墙自身关心的键；图谱键原样保留（读取时各自 get 默认值即可）。
	_state_store["associated"] = assoc
	_state_store["milestones_lit"] = m_lit
	_state_store["battlefield"] = bf
	_state_store["verified"] = _verified
	_state_store["verdict"] = _verified_verdict
	_state_store["doubt_book"] = _doubt_book
	_state_store["relations"] = _relations.duplicate()


# === 入口：构建五区布局 ===
func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 关系连线绘制层：全屏覆盖、不拦截输入，连线绘制在面板之上（z=15，低于验证窗口 z=19/20）
	_rel_layer = Control.new()
	_rel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rel_layer.z_index = 15
	_rel_layer.draw.connect(_on_rel_layer_draw)
	add_child(_rel_layer)

	# 顶部功能栏 (高度 60)
	_top_bar = _create_top_bar()
	add_child(_top_bar)

	# 底部进度栏 (高度 70)
	_bottom_bar = _create_bottom_bar()
	add_child(_bottom_bar)

	# 剩余中间区域：左右中三栏
	var mid := Control.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.offset_top = 110
	mid.offset_bottom = -240   # 收拢到底部对话栏(y=850~1080)之上，避免三栏内容被对话栏遮挡（mid 底≈840）
	add_child(mid)

	# 左侧「已收集线索」面板（线索库，宽 540）
	# 常驻图谱模式左侧上方层：z=20（> 图谱 z=5、< 顶栏 z=100），置于画布之上而非被图谱遮挡，
	# 作为「从左栏把线索拖入图谱」的入口载体（需求3）。
	_left_panel = _create_left_panel()
	_left_panel.z_index = 20
	add_child(_left_panel)
	_left_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_left_panel.offset_right = 540  # 1920*0.28 ≈ 538
	_left_panel.offset_top = 110    # 对齐中部区域（顶栏之下）
	_left_panel.offset_bottom = -240

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

	# 图谱模式：左侧已收集线索栏保留（已在画布之上）；右/中/底隐藏
	_right_panel.visible = false
	_center_panel.visible = false
	_bottom_bar.visible = false


func _create_top_bar() -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 110
	# 顶栏 z_index 必须远高于 graph_view 叠加层（z=5），否则线型/颜色/视图按钮被全屏图谱拦截
	bar.z_index = 100
	bar.mouse_filter = Control.MOUSE_FILTER_STOP   # 显式 STOP，截停向下传播

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(col)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	row1.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 5)
	row2.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(row2)

	# ===== 第一行：标题 + 难度 + 线型 + 性质 + 右上关键操作（人物星型/推理链/焦点/撤销/重做/提交验证/求助/关闭）=====
	var title := Label.new()
	title.text = "推理墙 — %s" % _case_name
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.custom_minimum_size = Vector2(196, 46)
	row1.add_child(title)

	var diff_lbl := Label.new()
	diff_lbl.text = "难度：%s" % ["简单", "普通", "困难"][_difficulty]
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	diff_lbl.custom_minimum_size = Vector2(72, 46)
	row1.add_child(diff_lbl)

	row1.add_child(_mk_sep())

	var lt_lbl := Label.new()
	lt_lbl.text = "线型"
	lt_lbl.add_theme_font_size_override("font_size", 16)
	lt_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	lt_lbl.custom_minimum_size = Vector2(28, 46)
	row1.add_child(lt_lbl)
	_pen_solid_btn = _mk_top_btn("实线", true)
	_pen_solid_btn.pressed.connect(func(): _set_pen_dashed(false))
	row1.add_child(_pen_solid_btn)
	_pen_dashed_btn = _mk_top_btn("虚线", false)
	_pen_dashed_btn.add_theme_color_override("font_color", COL_GREY)
	_pen_dashed_btn.pressed.connect(func(): _set_pen_dashed(true))
	row1.add_child(_pen_dashed_btn)

	row1.add_child(_mk_sep())

	var col_lbl := Label.new()
	col_lbl.text = "性质"
	col_lbl.add_theme_font_size_override("font_size", 16)
	col_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	col_lbl.custom_minimum_size = Vector2(28, 46)
	row1.add_child(col_lbl)
	var ck := ["green", "orange", "red", "grey"]
	var cl := ["支持", "矛盾存疑", "反对", "弱关联"]
	for i in ck.size():
		var b := _mk_top_btn(cl[i], i == 0)
		b.add_theme_color_override("font_color", _gw_color(ck[i]))
		var key: String = ck[i]
		b.pressed.connect(func(): _set_pen_color(key))
		_color_btns[key] = b
		row1.add_child(b)

	row1.add_child(_mk_sep())

	# 弹簧把右侧关键操作推右，窗口变宽时仍保持可见
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)

	# 视图模式（右上可见）
	_mode_c_btn = _mk_top_btn("● 人物星型", true)
	_mode_c_btn.pressed.connect(_on_top_mode.bind(0))
	row1.add_child(_mode_c_btn)
	_mode_b_btn = _mk_top_btn("推理链", false)
	_mode_b_btn.pressed.connect(_on_top_mode.bind(1))
	row1.add_child(_mode_b_btn)

	# 焦点人物下拉
	_top_focus_sel = OptionButton.new()
	_top_focus_sel.add_theme_font_size_override("font_size", 14)
	_top_focus_sel.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_top_focus_sel.custom_minimum_size = Vector2(120, 44)
	_top_focus_sel.tooltip_text = "切换焦点人物（星型中心）"
	_top_focus_sel.item_selected.connect(_on_top_focus_selected)
	row1.add_child(_top_focus_sel)

	_top_undo_btn = _mk_top_btn("↶", false)
	_top_undo_btn.tooltip_text = "撤销 (Ctrl+Z)"
	_top_undo_btn.custom_minimum_size = Vector2(44, 44)
	_top_undo_btn.pressed.connect(_on_top_undo)
	row1.add_child(_top_undo_btn)
	_top_redo_btn = _mk_top_btn("↷", false)
	_top_redo_btn.tooltip_text = "重做 (Ctrl+Y)"
	_top_redo_btn.custom_minimum_size = Vector2(44, 44)
	_top_redo_btn.pressed.connect(_on_top_redo)
	row1.add_child(_top_redo_btn)

	# 提交验证（右上关键按钮）
	_top_verify_btn = _mk_top_btn("✓ 提交验证", false)
	_top_verify_btn.tooltip_text = "提交当前推理，正式判定（可推进剧情）"
	_top_verify_btn.custom_minimum_size = Vector2(130, 44)
	_top_verify_btn.pressed.connect(_on_verify_pressed)
	row1.add_child(_top_verify_btn)

	var help_btn := _mk_top_btn("❓ 求助", false)
	help_btn.pressed.connect(_on_help_pressed)
	row1.add_child(help_btn)

	var fit_btn := _mk_top_btn("🔎 适应", false)
	fit_btn.pressed.connect(_on_fit_view_pressed)
	row1.add_child(fit_btn)

	var recycle_btn := _mk_top_btn("🚮 回收站", false)
	recycle_btn.pressed.connect(_on_recycle_pressed)
	row1.add_child(recycle_btn)

	var close_btn := _mk_top_btn("✕", false)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(_on_back_pressed)
	row1.add_child(close_btn)

	# ===== 第二行：搜索 + 过滤 + 折叠 + 导出 + 连线 =====
	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "🔍 搜索线索/推断/人物..."
	search_edit.add_theme_font_size_override("font_size", 14)
	search_edit.custom_minimum_size = Vector2(180, 40)
	search_edit.tooltip_text = "输入关键词，Enter 跳转"
	search_edit.text_submitted.connect(func(t: String): _on_search_submitted(t))
	row2.add_child(search_edit)
	_search_edit = search_edit

	var filter_sel := OptionButton.new()
	filter_sel.add_theme_font_size_override("font_size", 14)
	filter_sel.custom_minimum_size = Vector2(100, 40)
	filter_sel.tooltip_text = "按标记过滤显示"
	filter_sel.add_item("全部", 0)
	filter_sel.add_item("已排除", 1)
	filter_sel.add_item("待查", 2)
	filter_sel.add_item("关键", 3)
	filter_sel.item_selected.connect(_on_filter_selected)
	row2.add_child(filter_sel)
	_filter_sel = filter_sel

	var fold_btn := _mk_top_btn("🪗 折叠", true)
	fold_btn.tooltip_text = "折叠/展开当前焦点人物的关联线索"
	fold_btn.pressed.connect(_on_toggle_fold)
	row2.add_child(fold_btn)
	_fold_btn = fold_btn

	var export_btn := _mk_top_btn("📤 导出", true)
	export_btn.tooltip_text = "导出推理进度为 Markdown 文本"
	export_btn.pressed.connect(_on_export_pressed)
	row2.add_child(export_btn)
	_export_btn = export_btn

	row2.add_child(_mk_sep())

	# 「添加文本框」工具组：将自定义文本框加入画布（线索/推断/结论/人物）
	var add_label := Label.new()
	add_label.text = "➕ 添加"
	add_label.add_theme_font_size_override("font_size", 15)
	add_label.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	add_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row2.add_child(add_label)
	var add_defs := [
		["clue", "🧾 线索", "在画布添加一个线索文本框"],
		["hypo", "💡 推断", "在画布添加一个推断文本框"],
		["conclusion", "🏁 结论", "在画布添加一个结论文本框"],
		["person", "🧑 人物", "在画布添加一个人物文本框"],
	]
	for i in range(add_defs.size()):
		var ad: Array = add_defs[i]
		var add_btn := _mk_top_btn(ad[1], false)
		add_btn.tooltip_text = ad[2]
		add_btn.pressed.connect(func(k: String = ad[0]): _on_add_text_node(k))
		row2.add_child(add_btn)

	row2.add_child(_mk_sep())

	_connect_btn = _mk_top_btn("🔗 连线", false)
	_connect_btn.tooltip_text = "开启后：依次点两个节点 = 建立连线；两节点已有连线时再点两次 = 取消该连线"
	_connect_btn.pressed.connect(_on_top_connect_toggle)
	row2.add_child(_connect_btn)

	_sync_top_bar()

	return bar


func _mk_sep() -> Control:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(6, 40)
	return s


func _mk_top_btn(text: String, active: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", COL_GOLD if active else COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(64, 42)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.30, 0.24, 0.14, 0.95) if active else Color(0.16, 0.13, 0.08, 0.95)
	s.border_color = COL_GOLD if active else Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", s)
	# 按下/悬停/聚焦视觉反馈（此前缺失 → 用户点按钮"无反应"）
	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(0.52, 0.40, 0.20, 1.0)
	sp.border_color = Color(1.0, 0.86, 0.50)
	sp.border_width_left = 2; sp.border_width_right = 2; sp.border_width_top = 2; sp.border_width_bottom = 2
	sp.set_corner_radius_all(5)
	b.add_theme_stylebox_override("hover", sp)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("focus", sp)
	return b


func _gw_color(label: String) -> Color:
	match label:
		"支持": return COL_GREEN
		"矛盾存疑": return Color(0.95, 0.55, 0.25)
		"反对": return COL_RED
		_: return COL_GREY



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
	core_title.add_theme_font_size_override("font_size", 26)
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
	_status_lbl.text = "点击左侧线索推入关联面板，再次点击可移除；点右上「🔗连线」可拖拽线索/假设互建关系"
	_status_lbl.add_theme_font_size_override("font_size", 16)
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

	var placed: Array = _state_store.get("graph_placed_clues", []) as Array
	# 任务7：画布上当前可见的线索也视为「已入图」，从左栏去重——线索在推理墙整体中唯一，
	# 不能同时存在于左栏与画布（含因「关联焦点人物/有关系」而自动出现在画布上的线索）。
	var visible: Array = []
	if _graph_view and is_instance_valid(_graph_view) and _graph_view.has_method("visible_clue_ids"):
		visible = _graph_view.visible_clue_ids()
	for clue in _clues:
		var cid: String = clue.get("id", "")
		if placed.has(cid) or visible.has(cid):
			continue
		var name: String = clue.get("name", clue.get("label", cid))
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
	card.add_theme_font_size_override("font_size", 18)

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
	card.gui_input.connect(_on_node_gui.bind(clue["id"]))
	card.gui_input.connect(_on_clue_drag.bind(clue["id"]))
	card.mouse_default_cursor_shape = Control.CURSOR_CROSS if _connect_mode else Control.CURSOR_ARROW
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
	card.gui_input.connect(_on_node_gui.bind(id))
	card.mouse_default_cursor_shape = Control.CURSOR_CROSS if _connect_mode else Control.CURSOR_ARROW
	_hypo_nodes[id] = card
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
	if _connect_mode: return   # 连线模式下点击不弹详情，由拖拽建立关系
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


# === 自由连线：各线索/假设之间拖拽相互关系 ===
# 关系信号接入验证见 _contradiction_signals()/_support_signals()/get_verdict()。
# 设计依据：docs/02_核心设计/06_推理墙运行机制.md §2.2（拖拽模式默认；自由连线模式 M2+ 线索↔线索）

## 建立一条关系。kind="auto" 时（线索↔线索）自动跑矛盾检测：有矛盾→"contradict"，否则→"relate"。
## 返回 false 表示无效或重复（不建立）。
func connect_nodes(from_id: String, to_id: String, kind: String, color_key: String = "", dashed: bool = false) -> bool:
	if from_id == "" or to_id == "" or from_id == to_id: return false
	for r in _relations:
		if r.from == from_id and r.to == to_id and r.kind == kind: return false
	var resolved := kind
	if kind == "auto":
		var a := _find_clue(from_id); var b := _find_clue(to_id)
		if not a.is_empty() and not b.is_empty() and not _detect_contradiction(a, b).is_empty():
			resolved = "contradict"
		else:
			resolved = "relate"
	var ck := color_key if color_key != "" else _kind_to_key(resolved)
	_relations.append({"from": from_id, "to": to_id, "kind": resolved, "color_key": ck, "dashed": dashed})
	_refresh_relations()
	_persist_state()
	return true


func remove_relation(from_id: String, to_id: String) -> void:
	var kept := []
	for r in _relations:
		if not (r.from == from_id and r.to == to_id):
			kept.append(r)
	_relations = kept
	_refresh_relations()
	_persist_state()


func clear_relations() -> void:
	_relations = []
	_refresh_relations()
	_persist_state()


func get_relations() -> Array:
	return _relations.duplicate()


func set_connect_mode(on: bool) -> void:
	_connect_mode = on


func _on_connect_toggled() -> void:
	_connect_mode = not _connect_mode
	mouse_default_cursor_shape = Control.CURSOR_CROSS if _connect_mode else Control.CURSOR_ARROW
	if _connect_btn and is_instance_valid(_connect_btn):
		_connect_btn.text = "🔗 连线：" + ("开" if _connect_mode else "关")
		if _connect_mode:
			_connect_btn.add_theme_color_override("font_color", COL_GREEN)
		else:
			_connect_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	for n in _card_btns.values():
		if is_instance_valid(n): n.mouse_default_cursor_shape = Control.CURSOR_CROSS if _connect_mode else Control.CURSOR_ARROW
	for n in _hypo_nodes.values():
		if is_instance_valid(n): n.mouse_default_cursor_shape = Control.CURSOR_CROSS if _connect_mode else Control.CURSOR_ARROW
	if _status_lbl:
		_status_lbl.text = "连线模式：" + ("开（在节点上按住左键拖到另一节点建立关系；Shift=反对，否则支持）" if _connect_mode else "关（点击线索查看详情；点「🔗连线」可拖拽建立关系）")


func _on_clear_relations() -> void:
	clear_relations()
	if _status_lbl:
		_status_lbl.text = "已清除全部关系（%d 条）" % _relations.size()


# ===================== 图谱视图（GraphViewController 叠加层） =====================
## doc 09/10：在列表式推理墙之上叠加一个图视图（模式 C 星型 + 模式 B 链聚焦），
## 读取同一份数据（_clues/_hypothesis/_relations/_state_store），通过回调回写，数据层零改动。

func _on_open_graph_view() -> void:
	if _graph_view and is_instance_valid(_graph_view):
		return
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	gv.name = "GraphView"
	add_child(gv)
	# z_index 远低于顶栏（z=100），确保顶栏按钮可点击
	gv.z_index = 5
	var persons := _derive_persons()
	var focus: String = _state_store.get("graph_focus", "")
	# 防串位守卫：持久化的 graph_focus 若不属于当前墙的人物集合（多墙共享 wall_state 时
	# 会从上一墙残留焦点，造成信使墙误显示华生），回退到本墙人物首项并写回，杜绝张冠李戴。
	if focus == "" or not _persons_contain(persons, focus):
		focus = persons[0].get("id", "") if not persons.is_empty() else ""
		_state_store["graph_focus"] = focus
	gv.build({
		"clues": _clues, "hypo": _hypothesis, "relations": _relations,
		"persons": persons, "focus_person": focus, "difficulty": _difficulty,
		"editable": not _verified, "verdict": get_verdict(),
		"state_store": _state_store,
		"auto_fold": _auto_fold,
		"case_wide": _case_wide,
		"on_tag": Callable(self, "_gv_tag_person"),
		"on_relations_changed": Callable(self, "_gv_relations_changed"),
		"on_pen_changed": Callable(self, "_gv_pen_changed"),
		"on_verify": Callable(self, "_on_verify_pressed"),
		"on_close": Callable(self, "_on_back_pressed")
	})
	_graph_view = gv
	_refresh_clue_list()   # 任务7：图谱构建后立即按画布可见线索去重左栏（打开墙即保证唯一）
	_sync_top_bar()
	_sync_connect_btn()


func _derive_persons() -> Array:
	var seen := {}
	var out := []
	# 兜底（修根因 2026-08-19 v4）：如果调用方传入的 _clues 为空但 ClueSystem 实际有已收集线索，
	# 实时拉一次（在 easy 模式下对话可能提前结束导致 _clues 没被填到；这层兜底保证人物中心至少能渲染）。
	if _clues.is_empty() and ClueSystem and ClueSystem.has_method("get_collected"):
		var live: Array = ClueSystem.get_collected("")
		if not live.is_empty():
			print("[reasoning_wall] 兜底从 ClueSystem.get_collected 拉取 %d 条线索" % live.size())
			_clues = live
	for c in _clues:
		for p in c.get("related_npcs", []):
			if not seen.has(p):
				seen[p] = true
				# 身份揭示门控：未满足揭示条件（如霍普未收到电报）时仍保留人物中心，
				# 但以「神秘嫌疑犯」占位居替，避免提前暴露真名（需求2）且不让人物消失（需求4）。
				var npc_name: String = _npc_display_name(p) if _identity_revealed(p, _clues) else "神秘嫌疑犯"
				out.append({"id": p, "name": npc_name})
	var extra: Array = _hypothesis.get("persons", [])
	for p in extra:
		var pid: String = p.get("id", "") if p is Dictionary else str(p)
		if not seen.has(pid):
			seen[pid] = true
			out.append({"id": pid, "name": _npc_display_name(pid)})
	return out


func _persons_contain(persons: Array, pid: String) -> bool:
	for p in persons:
		if p.get("id", "") == pid:
			return true
	return false


func _gv_tag_person(clue_id: String, person_id: String) -> void:
	var clue: Dictionary = _find_clue(clue_id)
	if clue.is_empty(): return
	var rns: Array = clue.get("related_npcs", [])
	if not rns.has(person_id):
		rns.append(person_id)
		clue["related_npcs"] = rns
	_persist_state()
	_update_all()


func _gv_add_edge(from_id: String, to_id: String, kind: String, color_key: String = "", dashed: bool = false) -> void:
	connect_nodes(from_id, to_id, kind, color_key, dashed)
	_update_all()


func _gv_remove_relation(from_id: String, to_id: String) -> void:
	remove_relation(from_id, to_id)
	_update_all()


# === 统一顶栏：线型/颜色/视图/焦点 选择器驱动图谱 ===
func _set_pen_dashed(d: bool) -> void:
	print("[topbar] _set_pen_dashed(%s) gv=%s _pen_color_key=%s" % [
		d, "YES" if (_graph_view and is_instance_valid(_graph_view)) else "NULL",
		_graph_view._pen_color_key if (_graph_view and is_instance_valid(_graph_view)) else "?"
	])
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.set_pen(_graph_view._pen_color_key, d)
		_graph_view._toast_msg("线型：%s" % ("虚线" if d else "实线"))
	_sync_pen_buttons()


func _set_pen_color(key: String) -> void:
	var names := {"green": "支持", "orange": "矛盾存疑", "red": "反对", "grey": "弱关联"}
	print("[topbar] _set_pen_color(%s) gv=%s" % [key, "YES" if (_graph_view and is_instance_valid(_graph_view)) else "NULL"])
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.set_pen(key, _graph_view._pen_dashed)
		_graph_view._toast_msg("性质：%s" % names.get(key, key))
	_sync_pen_buttons()


func _sync_pen_buttons() -> void:
	if not _graph_view or not is_instance_valid(_graph_view): return
	_pen_solid_btn.button_pressed = not _graph_view._pen_dashed
	_pen_dashed_btn.button_pressed = _graph_view._pen_dashed
	_pen_solid_btn.add_theme_color_override("font_color", COL_GOLD if not _graph_view._pen_dashed else COL_GOLD_LIGHT)
	_pen_dashed_btn.add_theme_color_override("font_color", COL_GOLD if _graph_view._pen_dashed else COL_GOLD_LIGHT)
	for k in _color_btns.keys():
		var active2: bool = (k == _graph_view._pen_color_key)
		_color_btns[k].button_pressed = active2
		_color_btns[k].add_theme_color_override("font_color", _gw_color(_COLOR_LABELS.get(k, "支持")) if active2 else COL_GREY)


func _gv_pen_changed(color_key: String, dashed: bool) -> void:
	_sync_pen_buttons()


func _on_top_connect_toggle() -> void:
	print("[topbar] _on_top_connect_toggle pressed=%s gv=%s" % [
		_connect_btn.button_pressed if _connect_btn else "NULL_BTN",
		"YES" if (_graph_view and is_instance_valid(_graph_view)) else "NULL"
	])
	if not _graph_view or not is_instance_valid(_graph_view):
		_connect_btn.button_pressed = false
		return
	var want: bool = _connect_btn.button_pressed
	# 已结案（verdict 已出）→ 禁止进入连线模式
	if want and _graph_view._state != 0:   # State.EDITABLE
		_connect_btn.button_pressed = false
		if _status_lbl:
			_status_lbl.text = "已结案，推理墙只读（不能新增连线）"
		return
	_graph_view.set_connect_mode(want)
	_connect_btn.text = "🔗 连线：" + ("开" if want else "关")
	_connect_btn.add_theme_color_override("font_color", COL_GREEN if want else COL_GOLD_LIGHT)
	if want:
		if _status_lbl:
			_status_lbl.text = "连线模式：依次点两个节点建边（线型+性质决定连线颜色/虚实）；点「🔗 连线：关」退出"
	else:
		if _status_lbl:
			_status_lbl.text = "连线模式已关：可拖动线索到推断上直接建立关系"


func _sync_connect_btn() -> void:
	if not _connect_btn or not _graph_view or not is_instance_valid(_graph_view): return
	var on: bool = _graph_view.get_connect_mode()
	_connect_btn.button_pressed = on
	_connect_btn.text = "🔗 连线：" + ("开" if on else "关")
	_connect_btn.add_theme_color_override("font_color", COL_GREEN if on else COL_GOLD_LIGHT)


func _on_top_mode(m: int) -> void:
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.set_mode(m)
	_mode_c_btn.button_pressed = (m == 0)
	_mode_b_btn.button_pressed = (m == 1)


func _on_top_focus_selected(idx: int) -> void:
	if not _graph_view or not is_instance_valid(_graph_view): return
	var pid: String = _top_focus_sel.get_item_metadata(idx)
	_graph_view.set_focus(pid)


func _on_top_undo() -> void:
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.undo()


func _on_top_redo() -> void:
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.redo()


# === P0/P1/P2 新增：搜索 / 状态过滤 / 折叠 / 导出 ===
func _on_search_submitted(text: String) -> void:
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.set_search_query(text)


func _on_add_text_node(kind: String) -> void:
	if _graph_view and is_instance_valid(_graph_view) and _graph_view.has_method("add_text_node"):
		_graph_view.add_text_node(kind)
		if _status_lbl:
			_status_lbl.text = "已添加文本框到画布"


func _on_fit_view_pressed() -> void:
	if _graph_view and is_instance_valid(_graph_view) and _graph_view.has_method("fit_view"):
		_graph_view.fit_view()
		if _status_lbl:
			_status_lbl.text = "已适应画布"


func _on_recycle_pressed() -> void:
	if not _graph_view or not is_instance_valid(_graph_view): return
	if not _graph_view.has_method("get_deleted_nodes") or not _graph_view.has_method("restore_text_node"):
		return
	var deleted: Array = _graph_view.get_deleted_nodes()
	if deleted.is_empty():
		if _status_lbl: _status_lbl.text = "回收站为空"
		return
	if _recycle_panel:
		_recycle_panel.queue_free()
		_recycle_panel = null
	var panel := PanelContainer.new()
	panel.name = "recycle_panel"
	_recycle_panel = panel
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360, 420)
	panel.add_child(vb)
	var lab := Label.new()
	lab.text = "🚮 已删除文本框（点击恢复）"
	lab.add_theme_font_size_override("font_size", 18)
	vb.add_child(lab)
	for n in deleted:
		var b := Button.new()
		var nm: String = str(n.get("label", n.get("id", "?")))
		b.text = nm
		b.add_theme_font_size_override("font_size", 15)
		var nid: String = str(n.get("id", ""))
		b.pressed.connect(_restore_one.bind(nid))
		vb.add_child(b)
	panel.position = Vector2(660, 160)
	panel.z_index = 95
	add_child(panel)


func _restore_one(nid: String) -> void:
	if _graph_view and is_instance_valid(_graph_view) and _graph_view.has_method("restore_text_node"):
		_graph_view.restore_text_node(nid)
		if _recycle_panel:
			_recycle_panel.queue_free()
			_recycle_panel = null


func _on_filter_selected(idx: int) -> void:
	if _graph_view and not is_instance_valid(_graph_view): return
	var labels := ["all", "excluded", "pending", "key"]
	var key: String = labels[idx] if idx < labels.size() else "all"
	_graph_view.set_status_filter(key)


func _on_toggle_fold() -> void:
	if _graph_view and is_instance_valid(_graph_view):
		var folded: bool = _graph_view.toggle_fold_focus()
		_fold_btn.text = "🪗 展开" if folded else "🪗 折叠"
		if _status_lbl:
			_status_lbl.text = ("已折叠焦点人物的关联线索" if folded else "已展开全部线索")


func _on_export_pressed() -> void:
	if _graph_view and is_instance_valid(_graph_view):
		_graph_view.export_markdown()
		# 导出结果由 graph_view 弹一个可复制面板


func _gv_relations_changed(rels: Array) -> void:
	_relations = rels
	_persist_state()
	_update_verdict_label()
	_refresh_clue_list()


func _kind_to_key(kind: String) -> String:
	match kind:
		"support", "imply": return "green"
		"contradict": return "orange"
		"oppose": return "red"
		_: return "grey"


func _sync_top_bar() -> void:
	if not _graph_view or not is_instance_valid(_graph_view): return
	_sync_pen_buttons()
	_mode_c_btn.button_pressed = (_graph_view._mode == 0)
	_mode_b_btn.button_pressed = (_graph_view._mode == 1)
	_top_focus_sel.clear()
	var persons := _derive_persons()
	for p in persons:
		_top_focus_sel.add_item(p.get("name", p.get("id", "?")))
		_top_focus_sel.set_item_metadata(_top_focus_sel.get_item_count() - 1, p.get("id", ""))
	for i in _top_focus_sel.get_item_count():
		if _top_focus_sel.get_item_metadata(i) == _graph_view._focus_person:
			_top_focus_sel.select(i)
	if _top_verify_btn:
		_top_verify_btn.disabled = _verified


## 节点 gui_input：连线模式下，左键按下即开始拖拽建立关系（Shift=反对，否则=支持）
func _on_node_gui(event: InputEvent, id: String) -> void:
	if not _connect_mode: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_link(id, event.shift_pressed)
		get_viewport().set_input_as_handled()


## 左栏「已收集线索」卡拖入图谱：把线索拖到图谱画布区（左栏之外）即放入图谱为节点。
## 仅在推理墙打开图谱时生效；不构成拖拽的普通点击仍归卡片自身处理。
func _on_clue_drag(event: InputEvent, cid: String) -> void:
	if not _graph_view or not is_instance_valid(_graph_view):
		return
	if _state_store.get("graph_placed_clues", []).has(cid):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _drag_src == "":
				_drag_src = cid
				_drag_origin = get_viewport().get_mouse_position()
		else:
			var was: String = _drag_src
			_drag_src = ""
			_clear_drag_ghost()
			if was == cid and _drag_origin != Vector2(-1, -1):
				_finish_clue_drag(cid)
	elif event is InputEventMouseMotion and _drag_src == cid and _drag_origin != Vector2(-1, -1):
		var mp := get_viewport().get_mouse_position()
		if mp.distance_to(_drag_origin) > 12:
			_ensure_drag_ghost(cid)
			if _drag_ghost and is_instance_valid(_drag_ghost):
				_drag_ghost.global_position = mp - _drag_ghost.size * 0.5


func _ensure_drag_ghost(cid: String) -> void:
	if _drag_ghost and is_instance_valid(_drag_ghost):
		return
	var label := Label.new()
	var clue := _find_clue(cid)
	label.text = clue.get("name", cid)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(1, 1, 1, 0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.3, 0.2, 0.9)
	sb.border_color = Color(0.4, 0.9, 0.4)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	label.add_theme_stylebox_override("normal", sb)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	add_child(label)
	_drag_ghost = label


func _clear_drag_ghost() -> void:
	if _drag_ghost and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null


func _finish_clue_drag(cid: String) -> void:
	var gp := get_viewport().get_mouse_position()
	# 只有放到图谱画布上（左栏矩形之外）才算「拖入图谱」；丢回左栏内则取消。
	var inside_panel := _left_panel and is_instance_valid(_left_panel) and _left_panel.get_global_rect().has_point(gp)
	if not inside_panel and _graph_view and is_instance_valid(_graph_view):
		# 落点若命中图上一个节点，place_clue 会在放置线索同时自动建绿实线支持关系
		_graph_view.place_clue(cid, gp)
		_persist_state()
		_refresh_clue_list()
	else:
		_ui_show_toast("把线索拖到右侧图谱画布上即可放入图谱")


func _start_link(id: String, shift: bool) -> void:
	_dragging_link = true
	_link_src = id
	_link_kind = "oppose" if shift else "support"
	_link_preview = get_viewport().get_mouse_position()
	if _rel_layer: _rel_layer.queue_redraw()


## 松开时命中测试：返回光标下、且非源节点的线索/假设节点 id
func _link_target_at(gp: Vector2) -> String:
	for cid in _card_btns.keys():
		var n: Control = _card_btns[cid]
		if is_instance_valid(n) and n.get_global_rect().has_point(gp): return cid
	for hid in _hypo_nodes.keys():
		var n: Control = _hypo_nodes[hid]
		if is_instance_valid(n) and n.get_global_rect().has_point(gp): return hid
	return ""


func _commit_link(src: String, dst: String) -> void:
	var src_clue := _card_btns.has(src)
	var dst_clue := _card_btns.has(dst)
	var kind := "relate"
	if src_clue and dst_clue:
		kind = "auto"          # 线索↔线索：自动矛盾检测
	elif src_clue != dst_clue:
		kind = _link_kind      # 线索↔假设：支持/反对
	connect_nodes(src, dst, kind)


func _refresh_relations() -> void:
	if _rel_layer: _rel_layer.queue_redraw()


func _node_center(id: String) -> Vector2:
	var node: Control = null
	if _card_btns.has(id): node = _card_btns[id]
	elif _hypo_nodes.has(id): node = _hypo_nodes[id]
	if node == null or not is_instance_valid(node): return Vector2.ZERO
	return _rel_layer.get_global_transform().affine_inverse() * (node.global_position + node.size * 0.5)


func _rel_color(kind: String) -> Color:
	var key := _kind_to_key(kind)
	match key:
		"green": return Color(0.4, 0.85, 0.4)
		"orange": return Color(0.95, 0.55, 0.25)
		"red": return Color(0.95, 0.3, 0.3)
		_: return Color(0.55, 0.50, 0.42)


func _draw_dashed_line(canvas: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var dist := a.distance_to(b)
	var dash := 12.0; var gap := 8.0
	var seg := dash + gap
	if seg <= 0: return
	var steps := int(dist / seg)
	var dir := (b - a).normalized()
	var pos := a
	for i in steps:
		var p2 := pos + dir * dash
		if p2.distance_to(a) > dist: p2 = b
		canvas.draw_line(pos, p2, col, 2)
		pos = p2 + dir * gap
	if pos.distance_to(b) > 1.0:
		canvas.draw_line(pos, b, col, 2)


func _on_rel_layer_draw() -> void:
	if _relations.is_empty() and not _dragging_link:
		return
	for r in _relations:
		var a := _node_center(r.from); var b := _node_center(r.to)
		if a == Vector2.ZERO or b == Vector2.ZERO: continue
		var col := _rel_color(r.get("color_key", _kind_to_key(r.kind)))
		if r.get("dashed", false):
			_draw_dashed_line(_rel_layer, a, b, col)
		else:
			_rel_layer.draw_line(a, b, col, 3)
	if _dragging_link and _link_src != "":
		var a := _node_center(_link_src)
		if a != Vector2.ZERO:
			_rel_layer.draw_line(a, _rel_layer.get_global_transform().affine_inverse() * _link_preview, _rel_color(_link_kind), 2)


func _update_all() -> void:
	_refresh_clue_list()
	_refresh_hypothesis_tree()
	_refresh_assoc_panel()
	_refresh_desk()
	_refresh_battlefield()
	_update_verdict_label()
	_update_milestone_ui()
	_update_star_rating()
	_refresh_relations()


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
	if _verified: return   # 已提交过验证的墙不允许重复提交（顶栏/图谱入口共用）
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
	var support := _support_signals()
	var contra := _contradiction_signals()
	if _difficulty == Diff.HARD:
		return "假设：%s\n验证等级：%s" % [hypo_name, levels.get(v, "?")]
	var report := "假设：%s\n验证等级：%s\n" % [hypo_name, levels.get(v, "?")]
	match v:
		Verdict.VERIFIED:
			report += "支持依据：%d 条正确证据，证据链完整闭合\n行动建议：提交结论，推进结案" % support
		Verdict.SUPPORTED:
			report += "支持依据：%d 条证据倾向支持\n存疑点：%d 条矛盾/误导项待排除\n行动建议：深挖剩余疑点，寻找决定性证据完成闭环" % [support, contra]
		Verdict.INSUFFICIENT:
			report += "存疑点：证据不足（仅关联 %d 条）\n行动建议：补充更多相关证据，或转向其他假设调查" % _associated
		Verdict.CONTRADICTORY:
			report += "存疑点：存在 %d 条矛盾证据（含关系矛盾）\n行动建议：推翻该假设，或寻找证据解释矛盾" % contra
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
	title.add_theme_font_size_override("font_size", 26)
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
	# 自由连线拖拽中：鼠标移动实时预览，松开时在命中节点上建立关系
	if _dragging_link:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging_link = false
			var tgt := _link_target_at(get_viewport().get_mouse_position())
			if tgt != "" and tgt != _link_src:
				_commit_link(_link_src, tgt)
			_link_src = ""
			if _rel_layer: _rel_layer.queue_redraw()
			return
		if event is InputEventMouseMotion:
			_link_preview = get_viewport().get_mouse_position()
			if _rel_layer: _rel_layer.queue_redraw()
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
			# 同样把销毁墙移出 _input 派发（_on_verify_confirm 内 queue_free 整棵墙），防 wasm 栈溢出
			call_deferred("_on_verify_confirm", _verify_v)
		return
	if _verifying: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _history_panel and is_instance_valid(_history_panel):
				_close_history_panel()
			else:
				# 与 graph_view 的 ESC 修复同款：把"销毁墙节点"移出 _input 派发，
				# 否则 wasm(浏览器) 在 _input 内同步 queue_free 整棵墙会栈溢出（Maximum call stack size exceeded）。
				call_deferred("_on_back_pressed")


func _on_back_pressed() -> void:
	if _closing: return            # 重入保护：graph_view 延迟的 _on_close_pressed->_cb_close 也会调到这里，避免二次销毁
	if _verifying: return
	_closing = true
	if _history_panel and is_instance_valid(_history_panel):
		_close_history_panel()
		return
	_persist_state()
	# #4 双级存储：退出推理墙仅作「临时存储」——把图谱状态写进内存态 _state_store（随当前会话存活），
	# 不写入游戏存档。长期存储(写档)只由手动存档、场景结束自动存档触发（各场景 _do_save / _save_and_transition）。
	# 故原「关墙即 _on_persist（落盘）」已移除，实现「退出推理墙=临时存储」的需求。
	# 已提交验证且本墙为「验证后自动推进」类型（推理阶段打开）：关墙即推进剧情，
	# 解决「提交验证后用返回/X 关墙（而非点确定）导致卡在推理阶段」的问题。
	if _verified and _on_advance.is_valid():
		_on_advance.call()
	elif _on_continue.is_valid(): _on_continue.call()
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
