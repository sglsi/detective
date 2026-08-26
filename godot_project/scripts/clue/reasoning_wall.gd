extends Control
class_name ReasoningWall

## 推理墙 — 设计文档 P0 实现（五区布局 + 线索库 + 假设树 + 四级验证 + 结论里程碑）
## 依据：docs/02_核心设计/06_推理墙运行机制.md
## 架构（Request C 后分层）：状态/线索库/假设树/战场/对比台/关系/验证/历史 抽到 scripts/clue/wall/

enum Verdict { INSUFFICIENT=1, SUPPORTED=2, VERIFIED=3, CONTRADICTORY=0 }
enum Diff { EASY=0, NORMAL=1, HARD=2 }
enum ClueState { COLLECTED=0, ASSOCIATED=1, VERIFIED=2, INVALID=3 }

# === 分层（Request C 后架构拆分）：状态/线索库/假设树/战场/对比台/关系/验证/历史 抽到 wall/ ===
const WallState = preload("res://scripts/clue/wall/wall_state.gd")
var _state_ctl: WallState
const WallClueLibrary = preload("res://scripts/clue/wall/wall_clue_library.gd")
var _clue_ctl: WallClueLibrary
const WallHypothesis = preload("res://scripts/clue/wall/wall_hypothesis.gd")
var _hypo_ctl: WallHypothesis
const WallBattlefield = preload("res://scripts/clue/wall/wall_battlefield.gd")
var _bf_ctl: WallBattlefield
const WallComparison = preload("res://scripts/clue/wall/wall_comparison.gd")
var _cmp_ctl: WallComparison
const WallRelations = preload("res://scripts/clue/wall/wall_relations.gd")
var _rel_ctl: WallRelations
const WallVerify = preload("res://scripts/clue/wall/wall_verify.gd")
var _verify_ctl: WallVerify
const WallHistory = preload("res://scripts/clue/wall/wall_history.gd")
var _hist_ctl: WallHistory

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
var _scene_clue_ids: Array = []               # 本场景「采集页」收集到的线索 id（跨场景带入·任务：左栏仅显示这些）
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
var _candidate_btn: Button = null
var _candidate_panel: PanelContainer = null
var _notice_lbl: Label = null
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

## 身份揭示门控（需求2）：判定某 NPC 是否应以"已知人物"出现。live 为当前已收集线索。
func setup(clues: Array, hypothesis: Dictionary, on_verify: Callable, on_close: Callable = Callable(), difficulty: int = Diff.NORMAL, on_continue: Callable = Callable(), state_store: Dictionary = {}, on_advance: Callable = Callable(), persist: bool = false, local_clue_count: int = -1, on_persist: Callable = Callable(), auto_fold: bool = false, scene_clue_ids: Array = []) -> void:
	_state_ctl = WallState.new()
	_state_ctl.owner = self
	_clue_ctl = WallClueLibrary.new()
	_clue_ctl.owner = self
	_hypo_ctl = WallHypothesis.new()
	_hypo_ctl.owner = self
	_bf_ctl = WallBattlefield.new()
	_bf_ctl.owner = self
	_cmp_ctl = WallComparison.new()
	_cmp_ctl.owner = self
	_rel_ctl = WallRelations.new()
	_rel_ctl.owner = self
	_verify_ctl = WallVerify.new()
	_verify_ctl.owner = self
	_hist_ctl = WallHistory.new()
	_hist_ctl.owner = self
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
	_scene_clue_ids = scene_clue_ids
	_battle = hypothesis.get("battlefield", {})
	_case_name = hypothesis.get("case_name", _case_name)
	_chain_id = hypothesis.get("chain_id", "")
	_expected_clues = hypothesis.get("expected_clues", _clues.size())
	# 案件级大墙：_clues 可能是全案池（跨场景），观察星须按「本场景已收集条数」计，避免被池扩大抬高
	_local_clue_count = local_clue_count if local_clue_count >= 0 else _clues.size()
	_insight_bonus = hypothesis.get("insight_bonus", 0)
	_state_ctl._init_milestones(hypothesis)
	_state_ctl._restore_state()      # 构建 UI 前回填关联/战场/里程碑/verified（首次为空则 no-op）
	_create_ui()
	_update_all()
	_on_open_graph_view()    # 图谱=默认主视图（覆盖列表区；左/右/中/底面板已隐藏）


func get_verdict() -> int:
	# 矛盾信号：误导线索(_contradicting) + 关系中的矛盾/反对（线索↔线索矛盾、线索→假设反对）
	if _state_ctl._contradiction_signals() > 0: return Verdict.CONTRADICTORY
	# 支持信号：已关联线索(_associated) + 线索→假设 支持关系
	if _state_ctl._support_signals() >= 3: return Verdict.VERIFIED
	if _state_ctl._support_signals() >= 1: return Verdict.SUPPORTED
	return Verdict.INSUFFICIENT


## 关系信号：把「拖拽相互关系」接入验证判定（原判定只看 _associated/_contradicting 计数，
## 与 design doc §2.2『关联推理应实时更新验证等级』一致）
func close_wall() -> void:
	_on_back_pressed()


# === 跨重开持久化（#场景二卡死修复）===
## 推理墙为瞬时节点，重建即丢失进度。状态由场景持有的 _state_store 引用保存：
## 关联线索 id、战场假设/矛盾状态、里程碑点亮、verified 标记与最近判定。

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
	_rel_layer.draw.connect(_rel_ctl._on_rel_layer_draw)
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
	_pen_solid_btn.pressed.connect(func(): _rel_ctl._set_pen_dashed(false))
	row1.add_child(_pen_solid_btn)
	_pen_dashed_btn = _mk_top_btn("虚线", false)
	_pen_dashed_btn.add_theme_color_override("font_color", COL_GREY)
	_pen_dashed_btn.pressed.connect(func(): _rel_ctl._set_pen_dashed(true))
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
		b.pressed.connect(func(): _rel_ctl._set_pen_color(key))
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
	_top_verify_btn.pressed.connect(_verify_ctl._on_verify_pressed)
	row1.add_child(_top_verify_btn)

	var help_btn := _mk_top_btn("❓ 求助", false)
	help_btn.pressed.connect(_on_help_pressed)
	row1.add_child(help_btn)

	var fit_btn := _mk_top_btn("🔎 适应", false)
	fit_btn.pressed.connect(_on_fit_view_pressed)
	row1.add_child(fit_btn)

	var auto_btn := _mk_top_btn("✶ 自动排列", false)
	auto_btn.tooltip_text = "按推理层级自动重排文本框（人物在右，结论/推断/线索逐列向左），尽量减小连线交叉"
	auto_btn.pressed.connect(_on_auto_arrange_pressed)
	row1.add_child(auto_btn)

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
	filter_sel.item_selected.connect(_clue_ctl._on_filter_selected)
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

	# 「候选采纳」：把场景预设的候选推断（按难度供给/甄别）采纳进图谱并自动连支撑证据
	var cand_btn := _mk_top_btn("🧠 候选采纳", false)
	cand_btn.tooltip_text = "查看场景预设的可采纳候选推断：简单=系统直接给、普通=含误导需甄别、困难=自行推断不预设"
	cand_btn.pressed.connect(_on_candidates_pressed)
	row2.add_child(cand_btn)
	_candidate_btn = cand_btn

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
	_connect_btn.pressed.connect(_rel_ctl._on_top_connect_toggle)
	row2.add_child(_connect_btn)

	_rel_ctl._sync_top_bar()

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
	_search_edit.text_changed.connect(_clue_ctl._on_search_changed)
	vb.add_child(_search_edit)

	# 筛选按钮行
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	filter_row.custom_minimum_size = Vector2(200, 32)
	vb.add_child(filter_row)

	_filter_all = _clue_ctl._make_filter_btn("全部", true)
	_filter_assoc = _clue_ctl._make_filter_btn("已关联", false)
	_filter_unassoc = _clue_ctl._make_filter_btn("未关联", false)
	_filter_misleading = _clue_ctl._make_filter_btn("干扰", false)
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
	var rec_btn := _clue_ctl._make_action_btn("调查记录")
	rec_btn.pressed.connect(_hist_ctl._on_investigate_pressed)
	rec_row.add_child(rec_btn)

	return panel


# 统一风格的动作按钮（提交验证 / 返回 / 调查记录 共用）
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

	var verify_btn := _clue_ctl._make_action_btn("提交验证")
	verify_btn.pressed.connect(_verify_ctl._on_verify_pressed)
	bottom_row.add_child(verify_btn)

	# 阶段3：线索对比台固定在中央区底部，预留 ~150px 高度
	margin.offset_bottom = -162
	var desk := _cmp_ctl._build_comparison_desk()
	desk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	desk.offset_top = -150
	desk.offset_bottom = -8
	panel.add_child(desk)
	_comparison_desk = desk

	return panel


# === 阶段3：线索对比台 + 矛盾疑点册 ===
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
	var back_btn := _clue_ctl._make_action_btn("返回")
	back_btn.pressed.connect(_on_back_pressed)
	back_row.add_child(back_btn)

	return panel


# === 线索库 ===
# === 阶段2：证据属性标签 + 可信度（由 attribute_tags 派生）===
# === 假设树 ===
# === 关联面板 ===
# === 推理战场 ===
# === 线索详情弹窗 ===
# === 关联逻辑 ===
# === 自由连线：各线索/假设之间拖拽相互关系 ===
# 关系信号接入验证见 _state_ctl._contradiction_signals()/_state_ctl._support_signals()/get_verdict()。
# 设计依据：docs/02_核心设计/06_推理墙运行机制.md §2.2（拖拽模式默认；自由连线模式 M2+ 线索↔线索）

## 建立一条关系。kind="auto" 时（线索↔线索）自动跑矛盾检测：有矛盾→"contradict"，否则→"relate"。
## 返回 false 表示无效或重复（不建立）。
# ===================== 图谱视图（GraphViewController 叠加层） =====================
## doc 09/10：在列表式推理墙之上叠加一个图视图（模式 C 星型 + 模式 B 链聚焦），
## 读取同一份数据（_clues/_hypothesis/_relations/_state_store），通过回调回写，数据层零改动。

func _on_open_graph_view() -> void:
	if _graph_view and is_instance_valid(_graph_view):
		return
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	gv.name = "GraphView"
	# 图谱契回墙顶层铺满；图谱内部 _clip 契入让出「左栏右侧、顶栏之下」的图谱交互区（几何让出）。
	# clip 同一区域既承接显示又承接画布交互（平移/缩放/shift 建边/折叠），不被顶栏/左栏覆盖，
	# 故顶栏(z=100)/左栏(z=20) 天然优先可点、无需命中分离层。
	add_child(gv)
	gv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gv.z_index = 5
	# 契入让出区须与顶栏底(offset_bottom=110)/左栏右缘(offset_right=540)一致；
	# 改顶栏/左栏尺寸时须同步此两值（图谱 _clip 用它们避开 UI 浮层）。
	gv.hit_off_top = 110
	gv.hit_off_left = 540
	var persons := _state_ctl._derive_persons()
	var focus: String = _state_store.get("graph_focus", "")
	# 防串位守卫：持久化的 graph_focus 若不属于当前墙的人物集合（多墙共享 wall_state 时
	# 会从上一墙残留焦点，造成信使墙误显示华生），回退到本墙人物首项并写回，杜绝张冠李戴。
	if focus == "" or not _state_ctl._persons_contain(persons, focus):
		focus = persons[0].get("id", "") if not persons.is_empty() else ""
		_state_store["graph_focus"] = focus
	gv.build({
		"clues": _clues, "hypo": _hypothesis, "relations": _relations,
		"persons": persons, "focus_person": focus, "difficulty": _difficulty,
		"editable": not _verified, "verdict": get_verdict(),
		"state_store": _state_store,
		"auto_fold": _auto_fold,
		"case_wide": _case_wide,
		"scene_clue_ids": _scene_clue_ids,
		"on_tag": Callable(_rel_ctl, "_gv_tag_person"),
		"on_relations_changed": Callable(self, "_gv_relations_changed"),
		"on_pen_changed": Callable(_rel_ctl, "_gv_pen_changed"),
		"on_verify": Callable(_verify_ctl, "_on_verify_pressed"),
		"on_close": Callable(self, "_on_back_pressed")
	})
	_graph_view = gv
	_clue_ctl._refresh_clue_list()   # 任务7：图谱构建后立即按画布可见线索去重左栏（打开墙即保证唯一）
	_rel_ctl._sync_top_bar()
	_rel_ctl._sync_connect_btn()


# === 统一顶栏：线型/颜色/视图/焦点 选择器驱动图谱 ===
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


func _on_auto_arrange_pressed() -> void:
	if _graph_view and is_instance_valid(_graph_view) and _graph_view.has_method("auto_layout"):
		_graph_view.auto_layout()
		if _status_lbl:
			_status_lbl.text = "已自动排列"


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


## 「🧠 候选采纳」：打开场景预设候选推断面板，按难度决定供给与甄别方式
## EASY  = 只列正确推断，点采纳→自动连支撑证据；NORMAL = 混入误导项，采纳/排除需甄别；
## HARD  = 不预设候选，仅提示玩家自行添加推断/连线，归案时再与预设比对（比对走验证）。
func _on_candidates_pressed() -> void:
	if _candidate_panel:
		_candidate_panel.queue_free()
		_candidate_panel = null
	var hypos: Array = []
	if _battle is Dictionary and _battle.has("hypotheses") and _battle["hypotheses"] is Array:
		hypos = _battle["hypotheses"]
	if _difficulty == Diff.HARD or hypos.is_empty():
		if _status_lbl:
			if _difficulty == Diff.HARD:
				_status_lbl.text = "困难模式：请自行添加推断/连线，归案时系统将比对剧情预设"
			else:
				_status_lbl.text = "本场景暂无预设候选推断"
		return

	var is_normal: bool = _difficulty == Diff.NORMAL
	var panel := PanelContainer.new()
	panel.name = "candidate_panel"
	_candidate_panel = panel
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(460, 480)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "🧠 候选推断采纳（%s）" % ("普通" if is_normal else "简单")
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)
	var tip := Label.new()
	tip.text = "点「采纳」把推断接入图谱并自动连其支撑证据线索" + ("；误导项需甄别排除" if is_normal else "")
	tip.add_theme_font_size_override("font_size", 13)
	tip.modulate = Color(0.62, 0.62, 0.55)
	vb.add_child(tip)
	vb.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 340)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var listv := VBoxContainer.new()
	listv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(listv)

	for h in hypos:
		var hd: Dictionary = h
		var hid: String = str(hd.get("id", ""))
		var htext: String = str(hd.get("text", "未命名推断"))
		var is_true: bool = str(hd.get("kind", "true")) == "true" or bool(hd.get("correct", true))
		if not is_normal and not is_true:
			continue
		var card := VBoxContainer.new()
		card.name = "cand_" + hid
		var inner := PanelContainer.new()
		inner.add_theme_stylebox_override("panel", _mk_hint_box(is_true))
		var cvb := VBoxContainer.new()
		inner.add_child(cvb)
		var hl := Label.new()
		hl.text = ("✅ " if is_true else "⚠️ 误导 ") + htext
		hl.add_theme_font_size_override("font_size", 15)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvb.add_child(hl)
		var nhl := Label.new()
		var ndesc: String = str(hd.get("new_clue_hint", ""))
		if ndesc == "":
			ndesc = str(hd.get("adopt_desc", ""))
		nhl.text = ("> " + ndesc) if ndesc != "" else "已收集相关线索后采纳将自动连线"
		nhl.add_theme_font_size_override("font_size", 12)
		nhl.modulate = Color(0.78, 0.74, 0.6)
		nhl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvb.add_child(nhl)
		var hb := HBoxContainer.new()
		hb.add_child(_mk_cand_act("采纳", hid, is_true, hd))
		if is_normal and not is_true:
			hb.add_child(_mk_cand_act("排除误导", hid, is_true, hd))
		inner.add_child(hb)
		card.add_child(inner)
		listv.add_child(card)
		listv.add_child(HSeparator.new())

	var status := Label.new()
	status.text = "提示：采纳后仍需在图上自行拖动建链，最终归案以提交验证为准。"
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = Color(0.6, 0.6, 0.54)
	vb.add_child(status)
	panel.position = Vector2(600, 120)
	panel.z_index = 95
	add_child(panel)


func _mk_cand_act(act: String, hid: String, is_true: bool, hd: Dictionary) -> Button:
	var b := Button.new()
	b.text = act
	b.add_theme_font_size_override("font_size", 14)
	if act == "采纳":
		b.pressed.connect(_adopt_candidate.bind(hid, hd))
	else:
		b.pressed.connect(_reject_candidate.bind(hid, hd))
	return b


func _adopt_candidate(hid: String, hd: Dictionary) -> void:
	if _candidate_panel:
		_candidate_panel.queue_free()
		_candidate_panel = null
	if _graph_view and is_instance_valid(_graph_view) and _graph_view.has_method("adopt_candidate"):
		_graph_view.adopt_candidate(hd)
		_state_ctl._persist_state()
		if _status_lbl:
			_status_lbl.text = "已采纳候选推断：" + str(hd.get("text", hid))


func _reject_candidate(hid: String, hd: Dictionary) -> void:
	var rdesc: String = str(hd.get("reject_desc", ""))
	if _status_lbl:
		_status_lbl.text = "已排除误导：%s%s" % [str(hd.get("text", hid)), ("　" + rdesc if rdesc != "" else "")]
	if rdesc != "":
		_mk_notice("⚠️ 误导排除：%s" % rdesc)
	if _candidate_panel:
		_candidate_panel.queue_free()
		_candidate_panel = null


func _mk_hint_box(true_kind: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if true_kind:
		sb.bg_color = Color(0.08, 0.18, 0.12, 1.0)
		sb.border_color = Color(0.35, 0.75, 0.42, 1.0)
	else:
		sb.bg_color = Color(0.18, 0.1, 0.1, 1.0)
		sb.border_color = Color(0.8, 0.36, 0.3, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


## 顶部临时提示浮窗（用于误导排除等详细文案，避免只用状态栏一行字）
func _mk_notice(text: String) -> void:
	if _notice_lbl:
		_notice_lbl.queue_free()
		_notice_lbl = null
	var lbl := Label.new()
	_notice_lbl = lbl
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(560, 0)
	lbl.modulate = Color(1, 0.86, 0.5)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _mk_hint_box(true))
	p.add_child(lbl)
	p.position = Vector2(620, 80)
	p.z_index = 96
	add_child(p)


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
	_state_ctl._persist_state()
	_verify_ctl._update_verdict_label()
	_clue_ctl._refresh_clue_list()


## 节点 gui_input：连线模式下，左键按下即开始拖拽建立关系（Shift=反对，否则=支持）
## 左栏「已收集线索」卡拖入图谱：把线索拖到图谱画布区（左栏之外）即放入图谱为节点。
## 仅在推理墙打开图谱时生效；不构成拖拽的普通点击仍归卡片自身处理。
## 松开时命中测试：返回光标下、且非源节点的线索/假设节点 id
func _update_all() -> void:
	_clue_ctl._refresh_clue_list()
	_hypo_ctl._refresh_hypothesis_tree()
	_hypo_ctl._refresh_assoc_panel()
	_cmp_ctl._refresh_desk()
	_bf_ctl._refresh_battlefield()
	_verify_ctl._update_verdict_label()
	_state_ctl._update_milestone_ui()
	_state_ctl._update_star_rating()
	_rel_ctl._refresh_relations()


# === 验证 ===
# 仅关闭验证结果窗口（不确认验证、不关闭推理墙），保留推理墙继续操作
# 验证结果窗口标题栏拖拽
# === 里程碑 ===
# === 三星评价 ===
# === 返回调查 + 历史信息面板 ===
# 标题栏拖拽
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
			var tgt := _rel_ctl._link_target_at(get_viewport().get_mouse_position())
			if tgt != "" and tgt != _link_src:
				_rel_ctl._commit_link(_link_src, tgt)
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
			_verify_ctl.call_deferred("_on_verify_confirm", _verify_v)
		return
	if _verifying: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _history_panel and is_instance_valid(_history_panel):
				_hist_ctl._close_history_panel()
			else:
				# 与 graph_view 的 ESC 修复同款：把"销毁墙节点"移出 _input 派发，
				# 否则 wasm(浏览器) 在 _input 内同步 queue_free 整棵墙会栈溢出（Maximum call stack size exceeded）。
				call_deferred("_on_back_pressed")


func _on_back_pressed() -> void:
	if _closing: return            # 重入保护：graph_view 延迟的 _on_close_pressed->_cb_close 也会调到这里，避免二次销毁
	if _verifying: return
	_closing = true
	if _history_panel and is_instance_valid(_history_panel):
		_hist_ctl._close_history_panel()
		return
	_state_ctl._persist_state()
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
	_clue_ctl._toggle_association(cid)


func _debug_ui_counts() -> Dictionary:
	return {
		"clue_list": _clue_list.get_child_count() if _clue_list else -1,
		"tree_root": _tree_root.get_child_count() if _tree_root else -1,
		"battlefield": _battlefield_box.get_child_count() if _battlefield_box else -1,
		"assoc_list": _assoc_list.get_child_count() if _assoc_list else -1,
	}
