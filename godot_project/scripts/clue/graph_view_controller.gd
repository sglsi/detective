extends Control
class_name GraphViewController

## 推理墙 · 图谱视图控制器（GraphViewController）
## 设计依据：09_图谱视图专项 (v1.3/v1.4) + 10_推理墙界面与交互设计 (v1.0/v1.1)
##
## 定位（doc 10 §1.3）：本控制器是「数据 DAG 的投影」。它不持有任何视图私有数据，
## 全部节点位置 / 连线 / 焦点都从传入的数据每次重绘时实时派生（doc 10 §10.3）。
## 读取与老推理墙（reasoning_wall.gd）同一份数据：线索字典数组 + 假设字典 + 关系数组，
## 数据层零改动（doc 09/10 铁律）。
##
## Phase A 范围（09 v1.4 R-1）：仅模式 C（人物焦点星型，默认）+ 模式 B（推理链聚焦）；
##   模式 A（全局 DAG）/ 模式 D（折叠摘要）以灰显占位存在，点击提示 Phase D 开放。
##
## 玩家视角优先（10 v1.1）：界面不出现 ClueData/HypothesisData/C-1~C-7 等后台术语；
##   线索=「线索」、假设=「推断」、关系=「证据连线」、矛盾=「两种情况对不上」等案情语言。
##
## 架构（doc 10 §2.3）：Control 全架构，不用 Camera2D；主画布 _canvas 即推理墙的「_world」，
##   缩放/平移通过 _canvas.scale / .position 实现，复用 SceneFramework M1 摄像机 rig 思路。

enum ViewMode { MODE_C = 0, MODE_B = 1, MODE_A = 2, MODE_D = 3 }
enum State { EDITABLE = 0, LOCKED = 1 }
enum Diff { EASY = 0, NORMAL = 1, HARD = 2 }

# === 分层（Request C 后架构拆分）：数据/布局/折叠/边/线索栏 抽到 graph/ 子目录 ===
const GraphViewData = preload("res://scripts/clue/graph/graph_view_data.gd")
var _data: GraphViewData
const GraphViewLayout = preload("res://scripts/clue/graph/graph_view_layout.gd")
var _layout: GraphViewLayout
const GraphViewFold = preload("res://scripts/clue/graph/graph_view_fold.gd")
var _fold: GraphViewFold
const GraphViewEdge = preload("res://scripts/clue/graph/graph_view_edge.gd")
var _edge: GraphViewEdge
const GraphViewDock = preload("res://scripts/clue/graph/graph_view_dock.gd")
var _dockctl: GraphViewDock   # 左线索栏 dock 逻辑（注意：_dock 已用于线索栏 UI 节点本体）
const GraphViewCards = preload("res://scripts/clue/graph/graph_view_cards.gd")
var _cards: GraphViewCards   # 卡片渲染（统一三段式 / 纸纹 / 头像 / 图片区 / 金钉）
const GraphViewGuide = preload("res://scripts/clue/graph/graph_view_guide.gd")
var _guide: GraphViewGuide   # 首入引导 / 多步骤教程弹层
const GraphViewDetail = preload("res://scripts/clue/graph/graph_view_detail.gd")
var _detail: GraphViewDetail   # 节点详情卡（标题文案 / 删除 / 删除连线）
const GraphViewDrag = preload("res://scripts/clue/graph/graph_view_drag.gd")
var _drag: GraphViewDrag   # 拖拽/重叠子系统（移动提交/落点建边/换侧/命中测试/去重叠）
const GraphViewDerive = preload("res://scripts/clue/graph/graph_view_derive.gd")
var _derive: GraphViewDerive   # 正向推导子系统（线索→推断→结论，统一落节点建边）
# 结论文本宽容匹配（与 HardModeEvaluator 共用同一实现，避免口径漂移）
const ConclusionMatcher = preload("res://scripts/clue/conclusion_matcher.gd")
const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")

# === 入参数据（由推理墙传入，本控制器只读 + 通过回调回写）===
var _clues: Array = []
var _hypo: Dictionary = {}
var _hypo_current: Dictionary = {}   # 当前场景专属 battlefield（仅本场景预设推断/结论），供弹窗候选列表；与 _hypo（跨场景并集，供 def 检索）分离
var _relations: Array = []          # [{from, to, kind}]  kind∈ support/oppose/contradict/relate
var _persons: Array = []            # [{id, name}]
var _focus_person: String = ""
var _difficulty: int = Diff.NORMAL
var _editable: bool = true
var _verdict: int = -1              # -1 表示由本视图自行推算
var _state_store: Dictionary = {}
var _placed_clues: Array = []
var _auto_fold: bool = false
var _case_wide: bool = false
var _teaching: bool = false                   # 教学墙（场景一 watson/messenger）：禁用结论 gate 自动补边，关系由玩家逐个手动建立
var _manual_nodes: Array = []
var _root_anchor_pos: Dictionary = {}   # 第8节改造（A①+B①）：仅「关系树根」(人物/无人物的结论) 的位置被手动锁定并持久化
var _node_offsets: Dictionary = {}      # 需求3/5：非根节点（结论/推断）相对「父派生位」的偏移；拖动后保持随父移动
var _carried_ids: Array = []            # 开墙时已存在（上一场景携带）的节点 id；布局据此与「本场景新内容」分区域放置
var _scene_clue_ids: Array = []         # 本场景采集页收集到的线索 id（=「本场景新内容」）；布局分离时这些算新，其余算携带
var _deleted_target_edges: Dictionary = {}   # 需求1：玩家删除过的「结论→人物」target 边（key=conclusion_nid, value=person_id）；方案A 自动派生时跳过，使删除可持久
var _cb_tag: Callable = Callable()
var _cb_add_edge: Callable = Callable()
var _cb_remove_relation: Callable = Callable()
var _cb_close: Callable = Callable()
var _cb_verify: Callable = Callable()        # 提交验证（问题2：图谱内可直接提交，由推理墙 _on_verify_pressed 提供）

# === 视图状态 ===
var _mode: int = ViewMode.MODE_C
var _state: int = State.EDITABLE
var _undo := UndoRedo.new()
var _layout_seed: int = 1

# === 渲染容器 ===
var _clip: Control = null           # 裁剪视口（视觉显示，IGNORE）
var hit_off_top: int = 110          # 契入让出区上缘（顶栏高）——由推理墙传入，谱图 _clip 从顶栏之下开始
var hit_off_left: int = 540         # 契入让出区左缘（左栏右缘宽）——由推理墙传入，谱图 _clip 从左栏之右开始
var _did_initial_fit: bool = false  # 契入模式首帧已 fit_view（只在打开时缩放一次，后续 rebuild 不重置玩家缩放）
var _use_rank_layout: bool = false  # （DEPRECATED 保留）旧 BFS 深度分列一次性标志；顶栏「自动排列」已改走左右平衡
## 左右平衡整洁树（思傅 2026-09-09 定案）：默认 false = 纯右向；点顶栏「自动排列」后置 true 并**定格**
## （不再切回右向），布局层据其走 _balanced_tree_layout：人物居中、结论子树按茂盛度平衡分派左右。
var _balanced_layout: bool = false
## 玩家手动换侧覆盖 {人物直接子（结论）id: "L"/"R"}：把某分支拖过人物中线即记录，落盘持久
var _subtree_sides: Dictionary = {}
## 上一次平衡布局实际算出的分派结果 {子id: "L"/"R"}（供拖拽判定「当前在哪一侧」）
var _last_layout_sides: Dictionary = {}
var _fold_keep_layout: bool = false # 折叠/展开一次性标志：重建时跳过整体重排，仅按 _all_positions 摆放，避免折叠扰动其它/上级文本框
var _canvas: Control = null         # _world：节点与连线挂此（STOP，承接平移/缩放/空白点击）
var _hint_layer: Node2D = null     # 难度提示圈（最底）
var _edge_layer: Node2D = null     # 连线绘制层（节点下）
var _toolbar: Control = null
var _toast: Label = null
var _detail_card: PanelContainer = null
# 教程状态（_tutorial / _tut_*）已迁至 GraphViewGuide 组件（_guide）自持

# === 派生缓存 ===
var _node_views: Dictionary = {}    # id -> Control
var _node_center: Dictionary = {}   # id -> Vector2（画布本地中心）
var _node_kind: Dictionary = {}     # id -> String
var _node_data: Dictionary = {}     # id -> Dictionary（原始数据）
var _graph_nodes: Array = []        # 玩家顶栏「添文本框」新增的自定义节点 [{id,kind,label,sub}]（持久化于 state_store["graph_nodes"]）
var _chosen_conclusion: String = ""   # （旧单结论遗留字段，仅用于旧存档迁移）玩家推导选中的结论 id
var _chosen_conclusion_text: String = ""   # （旧单结论遗留字段，仅用于旧存档迁移）自定义结论文本
# 玩家已推导出的结论列表（多实例）：[{id, hid, text}]
#   id   = 预设 con_id（如 "CL2-1"）或 "custom_N"（玩家自定义，N 唯一递增）
#   hid  = 推导该结论所依据的推断 id（用于建 推断→结论 support 边）
#   text = 自定义结论文本（预设结论此项为空，文本取自 conclusions 数组）
var _derived_conclusions: Array = []
var _graph_deleted: Array = []      # 回收站：玩家删除的自定义文本框（state_store["graph_deleted_nodes"]）
var _edited_texts: Dictionary = {}  # 玩家在详情卡编辑过的节点文本 id -> 新文本（覆盖原生/自定义节点显示，持久化 state_store["graph_edited_texts"]）
var _edge_list: Array = []          # [{from,to,kind,color,dashed,dotted,always}]
var _highlight_id: String = ""
var _common_clues: Dictionary = {}  # clue_id -> true（被≥2人物关联）

# === 缩放/平移 ===
var _zoom := 1.0
var _panning := false
var _pan_last := Vector2.ZERO

# === 拖拽 ===
var _dragging := false
var _drag_id := ""
var _drag_hover := ""              # 拖拽中命中的目标节点 id（问题1：可建边视觉提示）
var _drag_from := Vector2.ZERO
var _drag_kind := ""
var _drag_mode := ""              # "move" 或 "edge"（_drag_kind 是关系 kind support/oppose）
var _drag_prestart_pos: Vector2 = Vector2.ZERO   # 拖动起点（算子树平移 delta）
var _drag_subtree: Array = []                         # 拖动节点的整棵子树（实时随拖平移，需求3）
var _post_drag := false             # 2026-09-05：拖拽松手触发的 rebuild 标记——跳过全局去重叠，
                                     # 否则被拖子树碰撞到的上游节点会被去重叠推走，玩家感知为「自动排列」（用户报 bug）
var _drag_offset := Vector2.ZERO   # move 模式专用，鼠标按下时在画布内相对节点 top-left 的偏移
var _drag_start := Vector2.ZERO    # 鼠标按下的全局位置（move 抖动阈值用）
var _drag_preview: Control = null

# === 连线模式（顶栏 toggle 控制；开启后左键点击两节点 = 建边）===
var _connect_mode := false         # 是否处于「连线模式」
var _connect_first_id := ""        # 第一次选中的节点 id
var _connect_first_kind := ""      # 第一次选中节点的 kind，用于提示

const COL_GOLD := Color(0.92, 0.84, 0.55)
const COL_GOLD_LIGHT := Color(0.95, 0.90, 0.78)
const COL_BG := Color(0.06, 0.05, 0.08, 0.97)
const COL_PANEL := Color(0.10, 0.08, 0.06, 0.92)
const COL_GREEN := Color(0.4, 0.85, 0.4)
const COL_YELLOW := Color(0.95, 0.8, 0.2)
const COL_ORANGE := Color(0.95, 0.55, 0.25)
const COL_RED := Color(0.95, 0.3, 0.3)
const COL_GREY := Color(0.55, 0.50, 0.42)
const COL_PERSON := Color(0.78, 0.72, 0.55)

# ===================== 统一卡片版式（2026-09-17） =====================
# 五类节点统一为「图片区 + 标题 + 副标题」三段式，尺寸统一，各类型配色不变。
const _CARD_W := 260.0          # 统一卡片宽
const _CARD_H := 400.0          # 统一卡片高（竖版，人物≈原170高的2.3倍）
const _CARD_IMG_H := 180.0      # 图片区固定高（约卡片高 45%，对照预览版式 2/5~1/2）
const _CARD_MARGIN := 12.0      # 卡片内边距
const DETAIL_CARD := preload("res://scripts/ui/detail_card.gd")  # 统一详情卡框架（暗棕底+金边圆角）

# === 节点配色（按需求：白=线索 / 灰=推断 / 原色=链&结论）===
const COL_CLUE_BG := Color(0.72, 0.84, 0.70, 0.98)         # 线索底色（浅绿，对照华生示范）
const COL_CLUE_BG_DIM := Color(0.68, 0.80, 0.66, 0.96)     # 干扰项线索底色（浅绿偏暗）
const COL_CLUE_BORDER := Color(0.32, 0.52, 0.30)           # 线索默认边框（绿，未关联=虚线）
const COL_CLUE_BORDER_ASSOC := Color(0.13, 0.42, 0.15)     # 已关联=深绿
const COL_CLUE_BORDER_DISTRACT := Color(0.85, 0.30, 0.30)  # 干扰项=红
const COL_HYPO_BG := Color(0.72, 0.80, 0.92, 0.98)         # 推断底色（浅蓝，对照华生示范）
const COL_HYPO_BG_DIM := Color(0.68, 0.77, 0.89, 0.96)     # 干扰项推断底色（浅蓝偏暗）
const COL_HYPO_BORDER := Color(0.32, 0.48, 0.70)           # 推断边框（蓝，未关联=虚线）
const COL_TEXT_DARK := Color(0.16, 0.13, 0.10)             # 深字
const COL_TEXT_RED := Color(0.86, 0.22, 0.22)             # 红字（干扰项）

# === NPC ID → 中文显示名（目录里只有 id，没有中文名；中心焦点显示用）===
const _NPC_DISPLAY_NAMES := {
	"NPC_WT": "华生",
	"NPC_HOP": "霍普",
	"NPC_DRE": "德雷伯",
	"NPC_LUCY": "露西",
	"NPC_STAN": "斯丹格森",
	"NPC_LANCE": "兰斯",
	"KILLER": "马车夫",
	"NPC_MSG": "信使",
	"NPC_SERGEANT": "海军军士",
}

# === 身份揭示门控（需求2）：某些 NPC 在「揭示名字的证据」被收集前，不得作为已知人物
# 出现在推理墙人物中心，避免现场线索 related_npcs 提前把未揭示身份的嫌疑人名带上墙。
# > 霍普的名字只在收到从美国来的电报（C_SOTCB_501 马车公司信息 / C_SOTCB_502 霍普身份，
#   均为场景五之后）才揭晓；此前现场勘查（c203/204/205/206 等）虽真实关联他，但推理墙
#   人物中心不得提前显示「霍普」。
const _IDENTITY_REVEAL_GATES := {
	"NPC_HOP": ["C_SOTCB_501", "C_SOTCB_502"],
	"NPC_DRE": ["c304"],
}

# === 身份未揭示时的占位名（需求2）：未满足揭示门控的 NPC 不暴露真名，用占位名替代。
# 同一案里可能有多人同时未揭示（如场景二：嫌疑人霍普 + 被害人德雷伯），用不同占位区分，
# 避免两个人物都显示成「神秘嫌疑犯」造成混淆。被害人用「死者」、其余默认「神秘嫌疑犯」。
const _NPC_MASKED_NAMES := {
	"NPC_DRE": "死者",
}

## 取某 NPC 未揭示身份时的占位显示名。
func _masked_name(pid: String) -> String:
	return _NPC_MASKED_NAMES.get(pid, "神秘嫌疑犯")

# === 圈层距离带（自由拖动 + 排序约束）===
# 单位像素（画布坐标）。约束：核心 < 结论/链 < 推断 < 线索（递增距离）。
# 节点拖动时钳制在对应 band 内，永不越层。
const _RING_BANDS := {
	"conclusion": {"min": 130.0, "max": 270.0, "default": 200.0},
	"chain":      {"min": 130.0, "max": 270.0, "default": 200.0},
	"hypo":       {"min": 290.0, "max": 430.0, "default": 360.0},
	"clue":       {"min": 450.0, "max": 640.0, "default": 540.0},
}

# 玩家视角文案（doc 10 v1.1）
const VERB_SUPPORT := "证据指向"
const VERB_OPPOSE := "两种情况对不上"
const VERB_CONTRADICT := "互相矛盾"
const VERB_RELATE := "可能有联系"

# === 线型 / 颜色键（玩家视角的「确定性 + 关系性质」）===
# 颜色键 → 颜色（绿=支持 / 橙=矛盾存疑 / 红=反对 / 灰=弱关联 / 金=归属指向）
const _COLOR_KEYS := {
	"green": Color(0.4, 0.85, 0.4),
	"orange": Color(1.0, 0.62, 0.02),
	"red": Color(0.93, 0.20, 0.26),
	"grey": Color(0.55, 0.50, 0.42),
	"gold": Color(0.85, 0.70, 0.30),
}
const _KEY_TO_KIND := {"green": "support", "orange": "contradict", "red": "oppose", "grey": "relate", "gold": "target"}
const _KIND_TO_KEY := {"support": "green", "imply": "green", "contradict": "orange", "oppose": "red", "relate": "grey", "target": "gold"}


## 组件在 _init 即实例化：build() 可能在节点进树(_ready)之前被调用
##（reasoning_wall._on_open_graph_view 在 add_child 后立即同步 build，而此时本控制器尚未进树），
## 若组件仅在 _ready 创建，build() 早期就会因组件 Nil 报错。_init 保证 .new() 起组件即可用。
func _init() -> void:
	_data = GraphViewData.new()
	_data.owner = self
	_layout = GraphViewLayout.new()
	_layout.owner = self
	_fold = GraphViewFold.new()
	_fold.owner = self
	_edge = GraphViewEdge.new()
	_edge.owner = self
	_dockctl = GraphViewDock.new()
	_dockctl.owner = self
	_cards = GraphViewCards.new()
	_cards.owner = self
	_guide = GraphViewGuide.new()
	_guide.owner = self
	_detail = GraphViewDetail.new()
	_detail.owner = self
	_drag = GraphViewDrag.new()
	_drag.owner = self
	_derive = GraphViewDerive.new()
	_derive.owner = self


# === 当前笔（由推理墙顶部栏 / 图谱内弹窗共同驱动）===
var _pen_color_key: String = "green"
var _pen_dashed: bool = false
var _cb_pen_changed: Callable = Callable()
var _cb_relations_changed: Callable = Callable()
var _cb_edge_selected: Callable = Callable()   # 连线选中/取消选中时通知顶栏同步（顶栏按钮↔选中线联动）
var _show_toolbar: bool = false

# === 浮层线索栏（左侧，可收缩）===
var _dock: Control = null
var _dock_collapsed: bool = false
var _dock_list: VBoxContainer = null
var _dock_toggle_btn: Button = null
var _dock_cards: Dictionary = {}
var _dock_dragging: bool = false
var _dock_clue_id: String = ""
var _dock_preview: Control = null
var _dock_moved: bool = false
var _dock_start: Vector2 = Vector2.ZERO

# === 「推断/结论」建议弹窗 ===
var _link_popup: Control = null
var _link_popup_clue_id: String = ""
# 弹窗统一拖动（与验证窗口同款拖拽机制）：标题栏按下置位，_input 中实时跟手
var _popup_dragging := false
var _popup_drag_panel: PanelContainer = null
var _popup_drag_offset: Vector2 = Vector2.ZERO

# === 图谱内拖拽笔（落点建关系时使用）===
var _drag_color_key: String = "green"
var _drag_dashed: bool = false

# === 连线选中/编辑（点击连线弹出右键菜单）===
var _selected_edge: int = -1      # _edge_list 中被点击选中的连线下标；-1 表示未选中
var _edge_menu: Control = null    # 连线右键浮动菜单
var _edge_menu_subs: Array = []   # 连线菜单的悬停子菜单（关闭时一并释放）
var _press_pos: Vector2 = Vector2.ZERO   # 画布左键按下时的视口坐标
var _press_moved: bool = false           # 按下后是否发生拖拽（用于区分点击与拖拽平移）

# === P0/P1/P2 新增状态（搜索/状态标记/折叠/导出）===
var _search_query: String = ""
var _status_filter: String = "all"   # all/excluded/pending/key
var _folded_nodes: Dictionary = {}       # node_id -> true：被折叠的"根"节点（XMind 式连线折叠）
var _all_positions: Dictionary = {}      # node_id -> Vector2：全部节点位置缓存（含隐藏者），持久化用
var _fold_controls: Dictionary = {}      # node_id -> Control：连线出口处的折叠点击控件（透明，只接 gui_input）
var _fold_layer: Node2D = null          # 折叠圆形绘制图层（统一在 draw 回调里画，规避"绘制时机"报错）
var _user_excluded := {}             # clue_id -> true（用户标"已排除"）
var _user_pending := {}              # clue_id -> true（用户标"待查"）
var _search_match_ids := []          # 当前搜索命中的节点 id 列表
var _export_panel: Node = null       # 导出结果窗口（Window，可拖动居中）


## 唯一入口：推理墙调用本方构建图谱视图。data 字段见文件头。
func build(data: Dictionary) -> void:
	_clues = data.get("clues", [])
	_hypo = data.get("hypo", {})
	# 当前场景专属 battlefield（来自调用方传入的 current_battlefield）；缺省回退到 _hypo.battlefield（教学/测试兼容）。
	_hypo_current = data.get("current_battlefield", data.get("hypo", {}).get("current_battlefield", _hypo.get("battlefield", {})))
	_relations = data.get("relations", [])
	_persons = data.get("persons", [])
	_focus_person = data.get("focus_person", "")
	_difficulty = data.get("difficulty", Diff.NORMAL)
	_editable = data.get("editable", true)
	# 不再冻结墙侧 verdict 快照（问题3）：结论节点红/橙/黄/绿与文字始终按图内关系实时推算，
	# 「关联正确后即时变色」，无需退出重进。LOCKED 墙关系不可变，实时推算与已定 verdict 一致。
	_verdict = -1
	_state_store = data.get("state_store", {})
	_deleted_target_edges = _state_store.get("graph_deleted_target", {})   # 需求1：恢复已删除的结论→人物边（从持久化 state_store 读）
	_cb_tag = data.get("on_tag", Callable())
	_cb_add_edge = data.get("on_add_edge", Callable())
	_cb_remove_relation = data.get("on_remove_relation", Callable())
	_cb_close = data.get("on_close", Callable())
	_cb_verify = data.get("on_verify", Callable())
	_cb_pen_changed = data.get("on_pen_changed", Callable())
	_cb_relations_changed = data.get("on_relations_changed", Callable())
	_cb_edge_selected = data.get("on_edge_selected", Callable())
	_show_toolbar = data.get("show_toolbar", false)
	_auto_fold = data.get("auto_fold", false)
	_case_wide = data.get("case_wide", false)
	_teaching = data.get("teaching", false)
	_scene_clue_ids = data.get("scene_clue_ids", [])

	# 视图记忆恢复（09 R-3）：读 SaveGame/state_store
	_mode = ViewMode.MODE_C  # MODE_B 纵向链已移除，恒为星型树
	_did_initial_fit = false
	_placed_clues = (_state_store.get("graph_placed_clues", []) as Array).duplicate()
	_manual_nodes = (Array(_state_store.get("graph_manual_nodes", [])) as Array).duplicate()
	_root_anchor_pos = (Dictionary(_state_store.get("graph_root_anchors", {})) as Dictionary).duplicate()
	_node_offsets = (Dictionary(_state_store.get("graph_node_offsets", {})) as Dictionary).duplicate()   # 需求3/5
	# 左右平衡布局（2026-09-09）：模式与玩家手动换侧结果随存档还原（点过「自动排列」后定格）
	_balanced_layout = bool(_state_store.get("graph_balanced_layout", false))
	_subtree_sides = (Dictionary(_state_store.get("graph_subtree_sides", {})) as Dictionary).duplicate()
	_graph_nodes = (Array(_state_store.get("graph_nodes", [])) as Array).duplicate()
	_graph_deleted = (Array(_state_store.get("graph_deleted_nodes", [])) as Array).duplicate()
	_edited_texts = (Dictionary(_state_store.get("graph_edited_texts", {})) as Dictionary).duplicate()
	_chosen_conclusion = str(_state_store.get("graph_chosen_conclusion", ""))
	_chosen_conclusion_text = str(_state_store.get("graph_chosen_conclusion_text", ""))
	_derived_conclusions = (Array(_state_store.get("graph_derived_conclusions", [])) as Array).duplicate()
	# 旧单结论存档迁移：把旧的 graph_chosen_conclusion 迁移为多结论列表的一条记录（仅迁移一次）
	if _chosen_conclusion != "" and _derived_conclusions.is_empty():
		_derived_conclusions.append({"id": _chosen_conclusion, "hid": "", "text": _chosen_conclusion_text})
		_state_store["graph_chosen_conclusion"] = ""
		_state_store["graph_chosen_conclusion_text"] = ""

	# 兜底（修根因 2026-08-19 v4）：如果调用方给的 _persons 是空但 ClueSystem 实际有相关线索，
	# 实时从 Autoload 拉并组装一次（避免 reasoning_wall 提前 _derive 之后又被另一层兜底覆盖，
	# 此处是最后一道）。
	# 用 Engine.get_singleton 取 Autoload，但先以 Engine.has_singleton 判存在：
	# - headless --script 下 autoload 不注册 → has_singleton 为 false，静默跳过（不编译报错、不运行报错）；
	# - web 运行时若单例缺失（旧包/缓存）也不打 "non-existent singleton" 错误，仅跳过兜底。
	var _cs: Object = null
	if Engine.has_singleton("ClueSystem"):
		_cs = Engine.get_singleton("ClueSystem")
	if _persons.is_empty() and _cs != null and _cs.has_method("get_collected"):
		var live: Array = _cs.get_collected("")
		if not live.is_empty():
			var seen := {}
			var out := []
			for c in live:
				for p in c.get("related_npcs", []):
					if not seen.has(p):
						seen[p] = true
						# 身份揭示门控占位：未揭示身份的人物仍保留，但用占位名居替（同 reasoning_wall._derive_persons）
						var npc_name: String = _NPC_DISPLAY_NAMES.get(p, p) if _data._identity_revealed(p, live) else _masked_name(p)
						out.append({"id": p, "name": npc_name})
			if not out.is_empty():
				print("[graph_view] build 时 _persons 兜底拉取 persons.size=%d" % out.size())
				_persons = out
	_layout_seed = _state_store.get("graph_seed", 1)

	# 折叠状态恢复（图谱折叠功能）：
	# 新键 graph_folded_nodes（任意节点可折叠）；兼容旧键 graph_folded_persons（仅焦点人物）并入。
	_folded_nodes = _state_store.get("graph_folded_nodes", {})
	var _old_fp: Dictionary = _state_store.get("graph_folded_persons", {})
	for _pid in _old_fp:
		_folded_nodes[_pid] = true
	# 跨场景累积改造（2026-08-29）：去掉「开墙自动折叠」，改为玩家全程自主折叠（信息缺失主因）。
	# 进入新场景：位置不随携带（清空坐标，由布局重排）；折叠态保留玩家手动折叠（不清 _folded_nodes）。
	# 仅 case_wide 全案墙清坐标（非 case_wide 教学墙沿用各自 state）。
	if _case_wide:
		if _state_store.has("graph_node_positions"):
			_state_store.erase("graph_node_positions")
		if _state_store.has("graph_root_anchors"):
			_state_store.erase("graph_root_anchors")
	_all_positions = {}
	_root_anchor_pos = {}

	# 升级兜底聚焦（修根因 2026-08-19 v3）：缓存里残留的 "__case__" 一律强制重置为空，
	# 不论 _persons 是否为空。这样可以让下面的缺省逻辑（如果用户实际有 NPC 线索）落到 NPC 真名。
	if _focus_person == "__case__":
		_focus_person = ""
	# 焦点缺省：取第一人物；若无人则造一个「未知人物」中心
	# （任一案只有唯一一个中心，命名规范：人物用真名；无人物兜底用「未知人物」，
	#   严禁出现「本案核心」之类的元叙事表述）
	if _focus_person == "" and not _persons.is_empty():
		_focus_person = _persons[0].get("id", "")
	if _focus_person == "":
		_focus_person = "__case__"
		if _persons.is_empty():
			_persons = [{"id": "__case__", "name": "未知人物"}]

	# debug log：让 console 里能直接看到节点数 + 真实焦点
	print("[graph_view] _persons.size=%d focus='%s' first='%s'" % [
		_persons.size(),
		_focus_person,
		(_persons[0].get("name", "?") if not _persons.is_empty() else "EMPTY")
	])

	_state = State.LOCKED if not _editable else State.EDITABLE
	if _state == State.LOCKED:
		_undo.clear_history(true)

	_create_ui()
	_rebuild_graph()
	# 跨场景累积改造（2026-08-29）：不再自动折叠（_apply_fold_to_roots 已废弃调用），玩家全程自主折叠。
	# case_wide 下计算「携带内容」集合（开墙时已存在、非本场景新收集线索），供布局左右分区（纯位置、不隐藏）。
	if _case_wide:
		_carried_ids = []
		for id in _node_kind.keys():
			if not (id in _scene_clue_ids):
				_carried_ids.append(id)
	# 已收集线索栏唯一入口：reasoning_wall 左栏（挂顶层 z=20，显示+选择+拖入放置+放置后消失）。
	# 这里不再创建图谱自带的第二套 dock（System B），避免"两套已收集线索"冗余。
	# _create_clue_dock()

	# 欢迎引导仅首次进入时展示（教学墙/普通墙一致）：关闭后写入 graph_tutorial_seen，再次进入不再自动弹。
	# 工具栏「?」按钮可随时重开。
	if not _state_store.get("graph_tutorial_seen", false):
		_guide.show_tutorial()


## 身份揭示门控（需求2）：判定某 NPC 是否应以"已知人物"出现在人物中心。
## 仅当已收集线索中存在其"揭示名字的证据"时才揭示；收集线索集合由 live（已收集线索）承载。
# ===================== UI 构建 =====================
func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠️ 关键：本控制器本体必须是 IGNORE，绝不能 STOP。
	# 它是全屏叠加层（覆盖 0~底部），若 STOP 会在「输入派发不按 z_index」的边界情况下
	# 把顶部栏（reasoning_wall 顶栏 z=100）的点击吞掉，导致「顶部按钮无反应」（Bug2）。
	# 真正的交互都由子节点承担：_canvas(平移/滚轮,STOP) / 节点(STOP) / _dock(STOP)。
	# self.IGNORE 后：顶部栏区域点击穿透到顶栏；图谱区点击落到 _canvas；`_input` 全局仍照常触发。
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_top = 60
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 裁剪视口：图谱契入「左栏右侧、顶栏之下」的图谱交互区（世界坐标 0,0 = 该区左上）。
	# clip 同时承担显示与命中：几何让出顶栏/左栏后，该区域天然既显示又接收画布操作，
	# 顶栏/左栏不被图谱覆盖故始终优先可点；画布操作（平移/滚轮/空白点击/shift 建边/折叠）
	# 一律经 _clip.gui_input → _on_canvas_gui 处理，无需另设命中层。
	_clip = Control.new()
	_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.offset_left = hit_off_left
	_clip.offset_top = hit_off_top
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_clip.clip_contents = true
	_clip.gui_input.connect(_on_canvas_gui)
	add_child(_clip)

	# _world 容器（缩放/平移等价 Camera2D；节点与连线挂此）。STOP 承担平移/滚轮/空白点击，
	# 节点卡片(z=0)自身 STOP 优先接收点击与拖拽，空白处落回 _canvas（与契入前一致）。
	# 【关键】契入让出只管“裁剪显示+命中”（_clip 偏移让出顶栏/左栏），布局基准不得跟随 compress：
	# 这里 offset 反补 -hit_off，使 _canvas 仍覆盖契入前整个墙画布(0,0..W,H)，
	# 世界坐标原点回到墙左上、画布宽回到契入前全屏值 → 横向阶梯树在宽松基准上重排，目标不会覆盖。
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.offset_left = -hit_off_left
	_canvas.offset_top = -hit_off_top
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_gui)
	_clip.add_child(_canvas)

	# ⚠️ 三绘制层必须用 Node2D 而非 Control（2026-09-17 修复 Problem3）：
	# Control 的裁剪包围盒 = 自身 rect（PRESET_FULL_RECT 即视口大小）；自动平衡布局产生宽图后，
	# 玩家平移/缩放到远端节点时该层矩形整体移出视口 → 整层被剔除 → 连线与折叠图示一起消失。
	# Node2D 的剔除盒继承自实际绘制几何（覆盖整张关系网），只要可见区域内有绘制内容就不会被剔除。
	_hint_layer = Node2D.new()
	_hint_layer.z_index = 0
	_hint_layer.draw.connect(_on_hint_draw)
	_canvas.add_child(_hint_layer)

	_edge_layer = Node2D.new()
	_edge_layer.z_index = 1
	_edge_layer.draw.connect(_edge._on_edge_draw)
	_canvas.add_child(_edge_layer)

	_fold_layer = Node2D.new()
	_fold_layer.z_index = 3
	_fold_layer.draw.connect(_fold._on_fold_draw)
	_canvas.add_child(_fold_layer)

	# 历史：2026-08-31 曾为「防画布平移缩放使图层矩形离开视口被裁剪」把三个绘制图层 offset 设为 ±200000，
	# 但 Control.draw 以自身 rect 左上角为局部绘制原点，offset 会把绘制原点平移 -200000 使连线/圆圈
	# 渲染到「节点坐标 +(-200000)」处（远偏出画布），节点本体仍以 _node_center 定位 → 连线/圆圈不显示、
	# 高亮圈错位。当时改回「绘制原点回到 _canvas 原点 + 关 clip_contents」缓解，但 Control 裁剪包围盒
	# 仍=视口大小，宽图平移/缩放远端时整层仍会被剔除（2026-09-17 用户实测连线+折叠图示消失）。
	# 根治：三绘制层已改为 Node2D（见上方创建处），其剔除盒继承实际绘制几何，彻底规避该问题。

	if _show_toolbar:
		_toolbar = _create_toolbar()
		add_child(_toolbar)

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -40
	_toast.offset_left = 16; _toast.offset_right = -16
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_toast.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate = Color(1, 1, 1, 0)
	add_child(_toast)


func _create_toolbar() -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 110
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12; row.offset_right = -12; row.offset_top = 12; row.offset_bottom = -12
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	var tab_c := _mk_tab("● 人物星型", true)
	tab_c.pressed.connect(_switch_mode.bind(ViewMode.MODE_C))
	row.add_child(tab_c)
	_tab_c_btn = tab_c
	var tab_a := _mk_tab("全局DAG▒", false, true)
	tab_a.pressed.connect(_on_greyed_tab.bind("全局 DAG"))
	row.add_child(tab_a)
	var tab_d := _mk_tab("摘要▒", false, true)
	tab_d.pressed.connect(_on_greyed_tab.bind("折叠摘要"))
	row.add_child(tab_d)

	# 焦点下拉（仅模式 C 启用）
	_focus_sel = OptionButton.new()
	_focus_sel.add_theme_font_size_override("font_size", 26)
	_focus_sel.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_focus_sel.custom_minimum_size = Vector2(220, 64)
	_focus_sel.tooltip_text = "切换焦点人物（星型中心）"
	for p in _persons:
		_focus_sel.add_item(p.get("name", p.get("id", "?")))
		_focus_sel.set_item_metadata(_focus_sel.get_item_count() - 1, p.get("id", ""))
	# 选中当前焦点
	for i in _focus_sel.get_item_count():
		if _focus_sel.get_item_metadata(i) == _focus_person:
			_focus_sel.select(i)
	_focus_sel.item_selected.connect(_on_focus_selected)
	row.add_child(_focus_sel)

	# 面包屑
	var crumb := Label.new()
	crumb.text = "  %s    %s" % [_hypo.get("case_name", "血字的研究"), _hypo.get("title", "")]
	crumb.add_theme_font_size_override("font_size", 26)
	crumb.add_theme_color_override("font_color", COL_GREY)
	crumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crumb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(crumb)

	# 撤销/重做
	var undo := _mk_tool_btn("↶", "撤销 (Ctrl+Z)")
	undo.pressed.connect(_on_undo)
	row.add_child(undo)
	var redo := _mk_tool_btn("↷", "重做 (Ctrl+Y)")
	redo.pressed.connect(_on_redo)
	row.add_child(redo)
	_undo_btn = undo; _redo_btn = redo

	# 提交验证（问题2）：图谱内形成的连线可直接提交判定，确认后推理墙销毁并推进剧情
	var verify := _mk_tool_btn("✓ 提交验证", "提交当前推理，正式判定（可推进剧情）")
	verify.custom_minimum_size = Vector2(240, 64)
	verify.add_theme_font_size_override("font_size", 28)
	verify.pressed.connect(_on_verify_pressed)
	row.add_child(verify)
	_verify_btn = verify

	var close := _mk_tool_btn("✕", "返回推理墙")
	close.pressed.connect(_on_close_pressed)
	row.add_child(close)

	# 操作帮助（随时重开教程引导，缓解首次进入推理墙的困惑）
	var help := _mk_tool_btn("?", "推理墙操作帮助 / 重新查看教程")
	help.pressed.connect(_guide.show_tutorial)
	row.add_child(help)

	_refresh_toolbar_state()
	return bar


var _focus_sel: OptionButton = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _verify_btn: Button = null
var _tab_c_btn: Button = null


## 提交验证（问题2）：转发给推理墙 _on_verify_pressed 弹验证结果窗；确认后墙被销毁并推进剧情。
## 已封存（LOCKED）墙在工具栏构建时按钮即禁用，此处再兜底一次。
func _on_verify_pressed() -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	if _cb_verify.is_valid():
		_cb_verify.call()


func _mk_tab(text: String, active: bool, greyed: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.disabled = greyed
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", COL_GOLD if active else COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(220, 64)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.30, 0.24, 0.14, 0.95) if active else Color(0.16, 0.13, 0.08, 0.95)
	s.border_color = COL_GOLD if active else Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", s)
	b.pressed.connect(func(): _sync_tabs())
	return b


func _mk_tool_btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(84, 64)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.13, 0.08, 0.95)
	s.border_color = Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", s)
	return b


func _sync_tabs() -> void:
	# 由 _switch_mode 设置按下态；这里仅保持视觉
	pass


func _refresh_toolbar_state() -> void:
	if _tab_c_btn: _tab_c_btn.button_pressed = (_mode == ViewMode.MODE_C)
	if _focus_sel:
		_focus_sel.disabled = (_mode != ViewMode.MODE_C)
	var can_edit := _state == State.EDITABLE
	if _undo_btn: _undo_btn.disabled = not can_edit
	if _redo_btn: _redo_btn.disabled = not can_edit
	if _verify_btn: _verify_btn.disabled = not can_edit


# ===================== 数据派生 =====================
## 人物显示名查找（按 优先顺序）：
##   1) _persons 列表里登记的 name（场景传入的别名）
##   2) NPC ID → 中文名静态映射（_NPC_DISPLAY_NAMES，目录里只有 id 没有中文名时的兜底）
##   3) 原 id 字符串
## 证据连线（数据边）派生：玩家关系 + 自动推断（clue.relation_tags→推断 / 推断→结论）
# ===================== 图重建 =====================
## 节点卡片真实高度：视图已测量用视图，否则回退字符估算
## 同列纵向去重叠：同一列（x 相邻）节点按真实卡片高度，保证相邻卡片上下边距 ≥15px，并把整列回居中避免整体下沉堆出画布
func _rebuild_graph() -> void:
	_data._compute_common_clues()
	_data._derive_edges()
	# 清旧节点 + 旧折叠控件（扫画布清除历史残留图元，避免拖动中重建叠加出重复同名节点）
	for ch in _canvas.get_children():
		if ch is Control and ch.has_meta("graph_node"):
			ch.queue_free()
	for n in _node_views.values():
		if is_instance_valid(n): n.queue_free()
	for c in _fold_controls.values():
		if is_instance_valid(c): c.queue_free()
	# 2026-09-05：清空 _node_center 前捕获「拖前实际位置」——下一行会清空它，
	# 但钉位重派生需要拖前位来平移后代（否则子树随根重排回弹）。
	var _pre_center := _node_center.duplicate()
	_node_views = {}; _node_center = {}; _node_kind = {}; _node_data = {}
	_fold_controls = {}
	_clear_drag_preview()

	# 载入已知节点位置（含隐藏者），保证展开后位置稳定（避免展开错位，见设计 §6）
	var _saved: Dictionary = _state_store.get("graph_node_positions", {})
	for _k in _saved:
		var _v: Vector2 = _saved.get(_k, Vector2.ZERO)
		if not _all_positions.has(_k):
			_all_positions[_k] = _v

	var nodes := _node_list()
	# ★ 测量前置（2026-09-08 治本）：先填 kind/data 字典、再建全部视图拿真实 size.y，
	# 供 _compute_layout 经 _real_node_height 消费真实尺寸；否则布局跑在视图前、_meas_lab 字体/主题
	# 未就绪会量出虚高（实测线索框竟达 1227px），使 _sibling_sep 半高基数虚大、兄弟线索间隙过远（1299/626px）。
	for nd in nodes:
		_node_kind[nd.id] = nd.kind
		_node_data[nd.id] = nd.data
	for nd in nodes:
		var v := _cards.make_node(nd)
		v.set_meta("graph_node", true)
		_node_views[nd.id] = v
		_canvas.add_child(v)
		# 位置留待布局算出后再设；v.size 已由 _make_node 同步写入真实高
	var pos: Dictionary
	if _fold_keep_layout:
		# 折叠/展开：一次性保持所有可见节点现有位置，仅增删视图，不整体重排 → 不影响其它/上级文本框
		_fold_keep_layout = false
		pos = {}
		for nd in nodes:
			pos[nd.id] = _all_positions.get(nd.id, Vector2.ZERO)
	else:
		pos = _layout._compute_layout(nodes, _pre_center)
		# 合并可见节点位置进全局缓存（隐藏节点的位置由 _all_positions 保留）。
		# ⚠️ 仅模式 C 合并：模式 B 是垂直分层的临时聚焦视图，若写入会污染 _all_positions，
		# 导致切回星型/重进时个别节点位置错乱回初始（问题2）。
		if _mode == ViewMode.MODE_C:
			for id in pos:
				_all_positions[id] = pos[id]
	_node_center = pos
	for nd in nodes:
		var v: Control = _node_views[nd.id]
		v.position = pos.get(nd.id, Vector2.ZERO) - v.size * 0.5
	# 同列纵向去重叠：按真实卡片高度硬保证相邻卡片上下边距 ≥15px（不依赖布局/估算，避免任何覆盖）
	# 跨场景累积改造（2026-08-29）：默认星形布局在高密度「多孤立根并入主根」时也会产生径向重叠，
	# 全局跨列去重叠必须同样执行以保证「零重叠」硬要求；仅当 AABB 真实相交才下移，玩家自由拖动不推挤。
	# 2026-09-05：拖拽松手引发的 rebuild 跳过去重叠——被拖子树已按玩家落点刚性定位，其碰撞到的
	# 上游节点若被推走会表现为「自动排列」（用户报 bug）；仅「非拖拽」rebuild（开墙/自动排列/折叠）才去重叠。
	if not _post_drag:
		if _use_rank_layout:
			_layout._apply_column_overlap_fix()
		_layout._apply_global_overlap_fix()
	_post_drag = false
	# 创建连线出口折叠控件（XMind 式 −/+N）。
	# 设计：非折叠叶子无下级，不常驻圆圈；但已折叠的叶子/根仍需保留控件，否则玩家无法展开。
	for nd in nodes:
		if _fold._direct_outer_neighbors(nd.id).is_empty() and not _folded_nodes.has(nd.id):
			continue
		var fc := _fold._make_fold_control(nd.id)
		fc.set_meta("graph_node", true)
		_fold_controls[nd.id] = fc
		_canvas.add_child(fc)
	# 首次 build（开墙）把焦点人物定格在画布中心（思傅 2026-09-17 需求）：原 fit_view 把整张 bbox
	# 居中，宽图 bbox 中心恰是空白区 → 进去后看不到内容、找不到推理链方向。改为人物居中，推理链自
	# 人物向两侧辐射，玩家以人物为锚点探索。后续 rebuild 不再重置玩家缩放（保留 _did_initial_fit 守卫）。
	if not _did_initial_fit:
		_did_initial_fit = true
		call_deferred("_center_on_person", 1.0)
	_redraw_all()


func _node_list() -> Array:
	var list := []
	var _in_list := {}   # 已在列表中的节点 id（函数级作用域，供结论块去重使用）
	if _case_wide:
		var fp: String = _focus_person
		for p in _persons:
			var pid: String = str(p.get("id", "")) if p is Dictionary else ""
			if pid == "" or pid == "__case__":
				continue
			var is_focus := pid == fp
			list.append({"id": pid, "kind": "person",
			"label": _data._person_name(pid), "sub": "焦点" if is_focus else "角色",
			"color": COL_PERSON, "data": {"id": pid},
			"masked": not _data._identity_revealed(pid, _clues)})
	else:
		# 中心：焦点人物
		list.append({"id": _focus_person, "kind": "person",
			"label": _data._person_name(_focus_person), "sub": "焦点", "color": COL_PERSON,
			"data": {"id": _focus_person},
			"masked": not _data._identity_revealed(_focus_person, _clues)})

	if _mode == ViewMode.MODE_C:
		# 第一圈：线索
		# 问题2：默认已收集线索放推理墙左侧「已收集线索栏」而非画布。全案墙(case_wide)只把
		# 已放置的线索（拖入图谱/建过关系，见 _placed_clues）作为图谱节点；未放置的孤立线索
		# 保留在左栏，由玩家逐条拖入或建边后再显示。非全案墙仍按焦点人物关联线索展示。
		var clues := []
		if _case_wide:
			var _placed_ids := {}
			for _pid in _placed_clues: _placed_ids[_pid] = true
			for _c_in_wall in _clues:
				var _cid_in_wall: String = str(_c_in_wall.get("id", ""))
				if _placed_ids.has(_cid_in_wall):
					clues.append(_c_in_wall)
		else:
			# 问题1：场景一教学墙(非 case_wide)与全案墙一致——只把已放置线索作为图谱节点，
			# 未放置孤立线索默认留在左栏「已收集线索栏」，由玩家拖入或建边后再显示。
			var _placed_ids2 := {}
			for _pid in _placed_clues: _placed_ids2[_pid] = true
			for _c_in_wall in _clues:
				var _cid_in_wall: String = str(_c_in_wall.get("id", ""))
				if _placed_ids2.has(_cid_in_wall):
					clues.append(_c_in_wall)
		# P0-2 状态过滤
		if _status_filter != "all" and not clues.is_empty():
			var sf := _status_filter
			clues = clues.filter(func(c): return _data._clue_matches_filter(c, sf))
		# 兜底显示全部线索（问题1）：无论全案墙或场景一教学墙，都不把孤立未放置线索无条件平铺
		# 进画布——未放置线索默认在左栏「已收集线索栏」，由下方「关联线索」「已放置线索」两段
		# 补入已拖入/已建关系的线索节点。这条兜底逻辑已移除，避免教学墙线索仍上画布。
		if clues.is_empty() and not _case_wide:
			pass
		for c in clues:
			var cid: String = c.get("id", "")
			var common: bool = _common_clues.has(cid)
			list.append({"id": cid, "kind": "clue",
				"label": c.get("name", cid), "sub": _data._clue_sub(c),
				"color": _data._clue_color(c), "data": c, "common": common})
		# 关联线索：被拖拽连到推断/结论/人物但本身未挂焦点人物的线索，也纳入星型视图，
		# 使其显示为节点并把连线画出来（修复「拖线索后线索不显示、不知是否关联」）。
		for _n in list: _in_list[_n.id] = true
		# 关联线索：被拖到推断/结论/人物但未挂焦点的线索也纳入（修复拖线索不显示）
		for c2 in _clues:
			var _cid2: String = c2.get("id", "")
			if _in_list.has(_cid2): continue
			if _data._clue_has_relation(_cid2):
				list.append({"id": _cid2, "kind": "clue",
					"label": c2.get("name", _cid2), "sub": _data._clue_sub(c2),
					"color": _data._clue_color(c2), "data": c2, "common": _common_clues.has(_cid2)})
				_in_list[_cid2] = true
		# 已放置线索（可能为孤立，如删除关系后）：始终保留为图谱节点（独立循环，杜绝重复叠加）
		for _p_cid in _placed_clues:
			if _in_list.has(_p_cid): continue
			var _p_c: Dictionary = _data._clue_by_id(_p_cid)
			if _p_c.is_empty(): continue
			list.append({"id": _p_cid, "kind": "clue",
				"label": _p_c.get("name", _p_cid), "sub": _data._clue_sub(_p_c),
				"color": _data._clue_color(_p_c), "data": _p_c, "common": _common_clues.has(_p_cid)})
			_in_list[_p_cid] = true
		# 第二圈：推断——不再自动铺 battlefield 预设节点。
		# 画布保持干净（仅线索节点 + 玩家已建节点 + 自定义文本框），推断/结论由玩家从「拖入线索/推导」弹窗
		# 手动创建（adopt_candidate 写入持久化 _graph_nodes，跨场景经 case_wall_state 携带）。
		# 这样场景二及之后不再一开墙就铺满其他场景的推断/结论（问题1/2）。
		# 第三圈：结论——MODE_C 下不显示 chain 节点，避免无意义的棕色空框占位且误触切换到 MODE_B。
		# chain 节点仅在 MODE_B（推理链视图）作为层级根显示。
	else:
		# 模式 B：分层
		var clues := _clues.filter(func(c): return c.get("associated", false))
		if clues.is_empty():
			clues = _clues
		for c in clues:
			var cid: String = c.get("id", "")
			list.append({"id": cid, "kind": "clue",
				"label": c.get("name", cid), "sub": _data._clue_sub(c),
				"color": _data._clue_color(c), "data": c, "common": _common_clues.has(cid)})
		var chain_id2: String = _hypo.get("chain_id", "")
		if chain_id2 != "":
			list.append({"id": "chain:" + chain_id2, "kind": "chain",
				"label": "#" + str(chain_id2), "sub": "推理链", "color": COL_GOLD, "data": {}})
	# 第三圈：结论——不再自动铺 battlefield 预设结论（画布清干净；
	# 结论由玩家从「推断推导结论」弹窗手动推导后动态加入 _derived_conclusions，跨场景经 case_wall_state 携带）。
	# ② 玩家推导结论（_derived_conclusions）
	if not _derived_conclusions.is_empty():
		for _dc in _derived_conclusions:
			var _dcid: String = str(_dc.get("id", ""))
			if _dcid == "":
				continue
			var _dnid: String = _conclusion_node_id(_dcid)
			if _in_list.has(_dnid):
				continue
			list.append({"id": _dnid, "kind": "conclusion",
				"label": _conclusion_text(_dcid), "sub": "结论", "color": _data._verdict_color(), "data": {}})

	# 顶栏「添文本框」新增的自定义节点：始终作为独立节点追加进画布（可连线、可移动）
	for gn in _graph_nodes:
		list.append({"id": gn.get("id", ""), "kind": gn.get("kind", "hypo"),
			"label": gn.get("label", "文本框"), "sub": gn.get("sub", "自定义"), "color": _gn_color(gn.get("kind", "hypo")), "data": {}})

	# 玩家在详情卡编辑过的文本覆盖：统一应用到所有节点（优先级最高）
	if not _edited_texts.is_empty():
		for _i in range(list.size()):
			var _oid: String = str(list[_i].get("id", ""))
			if _edited_texts.has(_oid):
				list[_i]["label"] = _edited_texts[_oid]

	# 图谱折叠：过滤掉被折叠根收起的"外层子树"（XMind 式）
	var hidden := _fold._compute_hidden()
	if not hidden.is_empty():
		var kept := []
		for nd in list:
			if hidden.has(nd.id): continue
			kept.append(nd)
		list = kept
	var ids2: Array = []
	for nd2 in list: ids2.append(nd2.get("id", ""))
	return list


# ===================== 图谱折叠（XMind 式连线折叠） =====================
## 圈层深度：结论/人物/链=0（最内，可折叠外层）；推断=1；线索=2（最外，叶子不可折叠）。
## 与布局 _RING_BANDS 解耦——仅用于折叠方向判定（设计 §1.1）。
## 任意节点 id 的 kind（不依赖可见性——隐藏节点也需判定圈层）
## 叶子节点（线索）不可折叠
## 无向邻接表（折叠遍历用）：玩家关系 + 数据边 + 模式C人物↔线索元数据边
## 节点的直接外层邻居（圈层深度严格更大的相连节点）——用于折叠控件数量与朝向
## 折叠隐藏集合：从各折叠根 BFS，收起所有圈层更深且可达的外层节点（设计 §4.1）
## 折叠控件上的计数：直接外层邻居数（设计 §4.3 / §9.4）
## 折叠控件上的字形：展开=−，折叠=+N
## 折叠控件位置：节点外缘、朝向外层邻居簇重心方向
## 节点半径（用于控件外移距离）
## 创建连线出口折叠控件的「点击热区」（透明 Control，只接 gui_input；圆形由 _fold_layer 统一绘制）
## 折叠圆形统一绘制（_fold_layer 的 draw 回调，绘制时机合法，规避"Drawing only allowed inside _draw"）
## 点击折叠控件：toggle（不触发节点拖动/连线）
## 拖动节点时同步所有折叠控件位置（点击热区 + 绘制图层都要刷新）
## 折叠根写回（供 UndoRedo 调用）
# P0-2 状态过滤辅助：判断线索是否匹配当前过滤
## 轻量结论推算（与 reasoning_wall.get_verdict 同规则，供结论节点着色；视图派生，不缓存）
## 布局算法（按需求1/6）：
##   - 每节点按 kind 分配「距离带 [min, max]」（_RING_BANDS）：核心<结论<链<推断<线索
##   - 节点可在带内自由拖动，distance 钳制到带内 → 永远维持排序
##   - 自适应半径：节点多时往外推到 max，保证总弧长 ≥ 节点宽 × 节点数（消除初始重叠）
##   - 手动位置持久化到 state_store（graph_node_positions）
## 按节点 kind 估算渲染宽度（用于自适应半径防重叠；与 _make_node 卡片尺寸×2 同步）
## 把点钳制到对应 kind 的距离带内（保持「核心 < 结论 < 推断 < 线索」排序）
# XMind 式布局：以焦点人物为中心，主分支（推断/结论/推理链）扇出，
# 线索沿其佐证分支向外剖列、轻微横向扇出；无佐证线索在外围柔性散布。
# 不再按 kind 分层成同心圆；已保存位置直接采用（自由排布，不钳回 ring）。
# ===================== 按关系驱动的横向阶梯树（华生示范对齐） =====================
## 思想：不再按 kind 一次性横排，而是把「整条推理链」作为一棵以人物为根的关系树：
##   人物(col0) → 结论(col1) → 推断/推理链(col2) → 线索(col3) 逐列向右阶梯铺开。
##  - 排列起自人物为根的 BFS 树（邻居层更深者作子），同父子树归组、父居子带中央；
##  - 多结论/多推断/多线索同列垂直整齐堆叠，不出现跨侧分叉（避免连线交叉）；
##  - direction 不硬性统一：人物偏右则树向左生长、偏左则向右，人物可自由摆放（保存位优先）；
##  - 孤立（未接入树）线索在外围散布；多人物每人一棵独立子树、水平错开不交叉。
## 后续遍历收集拓扑序，据此自底向上算子树叶子高
## 子树所需垂直带长（递归）：父带 ≥ max(自身估高, Σ子带长 + 兄弟间隙15)，保证后代不溢出、兄弟不交叠
## 递归布点：父居其子带中央；子带按各自子树带长精确切分（不足则居中留白），兄弟带间保证 ≥15px，绝不溢出交叠
## 估算节点卡片高度（与 _make_node 尺寸逻辑一致）：行数=ceil(文本宽/420)，行数×行高＋副标题＋内边距
# 灵活布局辅助：仅把节点限制在画布内（XMind 式自由排布，允许任意位置）
# 拖动自由摆放：放开范围限制（任务6）——允许节点中心拖到可视区之外较大范围，
# 配合画布平移（任务8）寻找；仅做极大值兜底避免坐标失控。
## 把当前所有节点位置写入 state_store（持久化手动布局，含隐藏节点——见设计 §6）
## 先用当前可见位置刷新缓存，再写入；隐藏节点位置由 _all_positions 保留（避免展开错位）。
# ===================== 节点视图 =====================
## 节点配色规则（用户需求）：
##   - 线索：底=白；已关联=实线绿边；未关联=虚线暗金边；干扰项(correct=false)=实线红边 + 红字
##   - 推断：底=灰；有关联=实线暗边；无关联=虚线暗边；干扰项=实线红边 + 红字
##   - 推理链/结论：维持当前（结论按 verdict 红/橙/黄/绿，链=金边）
##   - 中心人物：金边 + 暖金底
# 卡片渲染已拆至 scripts/clue/graph/graph_view_cards.gd（由 _cards 组件负责；节点配色规则见上方「节点视图」注释）


## 节点是否有「玩家手动建立的关系」（仅玩家关系，不含自动推断边）
# ===================== 绘制 =====================
func _redraw_all() -> void:
	if _hint_layer and is_instance_valid(_hint_layer): _hint_layer.queue_redraw()
	if _edge_layer and is_instance_valid(_edge_layer): _edge_layer.queue_redraw()
	if _fold_layer and is_instance_valid(_fold_layer): _fold_layer.queue_redraw()


func _on_hint_draw() -> void:
	if _difficulty > Diff.NORMAL: return   # 仅简单/普通显示可交互区高亮圈
	for id in _node_views:
		var n: Control = _node_views[id]
		if not is_instance_valid(n): continue
		var c: Vector2 = _node_center.get(id, Vector2.ZERO)
		if c == Vector2.ZERO: continue
		var kind: String = _node_kind.get(id, "")
		if kind in ["clue", "person"]:
			_hint_layer.draw_arc(c, 46, 0, TAU, 32, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.35), 2)
	# 连线模式选中节点：更显眼的金圈
	if _connect_first_id != "":
		var sel_center: Vector2 = _node_center.get(_connect_first_id, Vector2.ZERO)
		if sel_center != Vector2.ZERO:
			_hint_layer.draw_arc(sel_center, 56, 0, TAU, 36, COL_GOLD, 4)
			_hint_layer.draw_arc(sel_center, 64, 0, TAU, 36, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.4), 2)


## 边缘绘制（按需求5：连线用弧线代替直线）
## 用二次贝塞尔（控制点偏移路径中点垂直方向）实现自然弧度；虚线沿弧线采样。
## 沿 a→b 画一条二次贝塞尔弧线（控制点偏移中点垂直方向 curvature）
## 沿 a→b 画虚线弧线（沿贝塞尔采样，按 dash 长度切段）
## 旧的直线虚线（保留兼容，未再使用）
## 沿 a→b 画虚线弧线（沿贝塞尔采样，按 dash 长度切段）


func _drag_preview_pos() -> Vector2:
	if _canvas and is_instance_valid(_canvas) and get_viewport():
		return _canvas.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	return Vector2.ZERO


## 拖动带子树的节点时先折叠子树（先折叠后移动）：移动只带该节点本身，避免整棵子树跟移。
## BFS 沿连接收集本节点（kind 更深）的整棵子树 id（不含 id 自身），与 _relation_tree_layout 同款方向判据。
## deferred：折叠子树（含本体），重排后拖动只体现该节点本身；可经节点折叠控件展开。
# ===================== 交互 =====================
func _on_node_hover(id: String, entered: bool) -> void:
	if entered:
		_highlight_id = id
	else:
		if _highlight_id == id: _highlight_id = ""
	_redraw_all()


## 节点交互：
##   - 默认：左键拖动=移动节点；Shift+左键=建证据连线；右键=标签菜单
##   - 连线模式（顶栏 toggle 控制）：左键点击节点=选择/建边；两节点依次点击=建边
##   - 移动节点：distance 实时钳制到 kind 距离带（保持核心<结论<推断<线索 排序）
##   - 建边：玩家按住 Shift 后拖到另一节点上松开，触发 _add_edge（沿用原笔色/线型）
##   - 注意：move 拖动期间 MouseMotion 必须在 _input 里处理（gui_input 在鼠标离开节点后停发）
func _on_node_gui(event: InputEvent, id: String, kind: String) -> void:
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# === 连线模式：单击两节点建边 ===
			if _connect_mode:
				if _state != State.EDITABLE:
					_toast_msg("已封存，仅可浏览")
					return
				if _handle_connect_click(id, kind):
					return
				# 命中节点且未建边（自环），不继续后续处理
				return
			if _state != State.EDITABLE: return
			if not (kind in ["clue", "hypo", "conclusion", "chain", "person"]): return
			var n: Control = _node_views.get(id)
			if not (n and is_instance_valid(n)): return
			var mouse_canvas: Vector2 = _canvas.get_global_transform().affine_inverse() * mb.global_position
			_dragging = true
			_drag_id = id
			if mb.shift_pressed:
				# Shift+左键拖动 = 建边
				_drag_mode = "edge"
				_drag_kind = _data.key_to_kind(_pen_color_key)
				_drag_color_key = _pen_color_key
				_drag_dashed = _pen_dashed
				_drag_from = get_viewport().get_mouse_position()
			else:
				# 纯左键拖动 = 移动节点
				_drag_mode = "move"
				_drag_offset = mouse_canvas - n.position
				_drag_start = get_viewport().get_mouse_position()
				# 需求3：记录拖动起点与整棵子树（根节点无偏移机制→子树置空，由布局自动跟随）
			_drag_prestart_pos = _node_center.get(id, Vector2.ZERO)
			# 规则1/3：任意有后代的节点（人物/结论/推断）拖动时，其完整下游子树(经父→子有向边 BFS)
			# 一并随拖刚性平移；向上(父/人物)不动。根节点不再排除——人物拖拽也要带整棵星。
			_drag_subtree = _layout._descendants(id)
	else:
		# 释放：在 _input 里 commit（覆盖 gui_input 边界问题）
		pass
	# 右键菜单已整体移除（问题1）：打标签/标记状态/删除连线全部改由节点详情卡按钮提供


## 连线模式：处理单次节点点击（已被 _on_node_gui 路由过来）
## 第一次点击：选中该节点；第二次点击（不同节点）：建边；空地点击：取消选择
func _handle_connect_click(id: String, kind: String) -> bool:
	if not (kind in ["clue", "hypo", "conclusion", "person"]):
		return false
	if _connect_first_id == "":
		# 第一次选
		_connect_first_id = id
		_connect_first_kind = kind
		_toast_msg("已选中%s；再点一个目标即建边（空地右键连线模式退出）" %
			["线索", "线索", "推断", "结论", "人物"][(["clue", "hypo", "conclusion", "person", "?"].find(kind) if kind in ["clue", "hypo", "conclusion", "person"] else 0)])
		_redraw_all()
		return true
	# 第二次选
	if id == _connect_first_id:
		# 点同一个节点 → 取消
		_connect_first_id = ""
		_connect_first_kind = ""
		_toast_msg("已取消选择")
		_redraw_all()
		return true
	var first_kind: String = _connect_first_kind
	# 人物目标：仅线索 → 人物时建 tag，其他组合无意义则提示取消
	if kind == "person":
		if first_kind == "clue":
			_tag_person(_connect_first_id, id)
			_toast_msg("已为线索打上人物标签")
		elif first_kind in ["hypo", "conclusion", "chain"]:
			# 方案B：推断/结论/推理链 → 人物，建「归属」边（金色常显）
			_edge._add_edge(_connect_first_id, id, "target", "gold", false)
			_toast_msg("已建立%s→%s的归属关系" % [_node_short_label(_connect_first_id), _data._person_name(id)])
		else:
			_toast_msg("只有线索或推断/结论才能连到人物头像")
		_connect_first_id = ""
		_connect_first_kind = ""
		_redraw_all()
		return true
	if first_kind == "person":
		if kind == "clue":
			_tag_person(id, _connect_first_id)
			_toast_msg("已为线索打上人物标签")
		elif kind in ["hypo", "conclusion", "chain"]:
			# 方案B：人物作为源、推断/结论作为目标，方向仍是「节点→归属人物」
			_edge._add_edge(id, _connect_first_id, "target", "gold", false)
			_toast_msg("已建立%s→%s的归属关系" % [_node_short_label(id), _data._person_name(_connect_first_id)])
		else:
			_toast_msg("只有线索或推断/结论才能连到人物头像")
		_connect_first_id = ""
		_connect_first_kind = ""
		_redraw_all()
		return true
	# 节点 → 节点：建证据连线；若两节点间已有连线则反向删除（连线模式快捷取消，问题1 补充）
	var kind_str: String = _data.key_to_kind(_pen_color_key)
	var existing: Array = _edge._relations_between(_connect_first_id, id)
	if existing.is_empty():
		_edge._add_edge(_connect_first_id, id, kind_str, _pen_color_key, _pen_dashed)
	else:
		var total: int = existing.size()
		for r in existing:
			_edge._remove_edge(r.get("from", ""), r.get("to", ""), r.get("kind", "relate"))
		_toast_msg("已删除 %s ↔ %s 之间的 %d 条连线（已有连线时点两节点=取消连线）" %
			[_node_short_label(_connect_first_id), _node_short_label(id), total])
	_connect_first_id = ""
	_connect_first_kind = ""
	_redraw_all()
	return true


## 提交移动节点（含拖动语义，2026-08-19 重构）：
##   - 单击（位移 <8px）→ 弹详情
##   - 拖到另一节点上松开 → 建证据连线（线索↔推断/线索↔线索；线索→人物=打标签），用当前笔色/线型
##   - 拖到空地松开 → 移动节点位置（钳制到 kind 距离带）


func _on_node_clicked(id: String, kind: String) -> void:
	if kind == "chain":
		return
	_detail.show_detail(id, kind)


# ---- 打标签（拖线索到人物 / 详情卡按钮）----
## 打人物标签菜单（问题1：取消右键后，由节点详情卡「和谁有关 ▾」按钮调用）。
## 仅线索节点可用：列出其他人物，点选即打标签。
func _open_tag_menu(node_id: String, kind: String) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	if kind != "clue": return
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 28)
	var others := _persons.filter(func(p): return p.get("id", "") != _focus_person)
	if others.is_empty(): others = _persons
	for p in others:
		menu.add_item("和「%s」有关" % p.get("name", p.get("id", "?")))
		menu.set_item_metadata(menu.get_item_count() - 1, p.get("id", ""))
	menu.id_pressed.connect(func(idx: int):
		var pid: String = menu.get_item_metadata(idx)
		_tag_person(node_id, pid)
		menu.queue_free()
	)
	add_child(menu)
	menu.popup_centered()


## 标记状态菜单（问题1：取消右键后，由节点详情卡「标记状态 ▾」按钮调用）。
## 已排除（灰显）/ 待查（黄边）/ 恢复正常。
func _open_status_menu(clue_id: String) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 28)
	var cur := get_user_status(clue_id)
	var mark_label := ("当前：已排除" if cur == "excluded" else ("当前：待查" if cur == "pending" else "当前：正常"))
	menu.add_item(mark_label)
	menu.set_item_metadata(0, {"__status": "info"})
	menu.add_item("标为「已排除」（隐藏/灰显）")
	menu.set_item_metadata(1, {"__status": "excluded"})
	menu.add_item("标为「待查」（黄边高亮）")
	menu.set_item_metadata(2, {"__status": "pending"})
	if cur != "active":
		menu.add_item("恢复正常")
		menu.set_item_metadata(3, {"__status": "active"})
	menu.id_pressed.connect(func(idx: int):
		var md = menu.get_item_metadata(idx)
		if md is Dictionary and md.has("__status") and md["__status"] != "info":
			var st: String = md["__status"]
			mark_clue_status(clue_id, st)
			_toast_msg("已标记为「%s」" % {"excluded": "已排除", "pending": "待查", "active": "正常"}.get(st, st))
		menu.queue_free()
	)
	add_child(menu)
	menu.popup_centered()


## 节点短名（连线删除菜单用）：人物→中文名；推断→截断文本；线索→名称；其余→id
func _node_short_label(id: String) -> String:
	if _node_kind.get(id, "") == "person":
		return _data._person_name(id)
	var nd: Dictionary = _node_data.get(id, {})
	var lab: String = nd.get("label", "")
	if lab != "":
		return lab if lab.length() <= 8 else lab.substr(0, 8) + "…"
	return id


func _tag_person(clue_id: String, person_id: String) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	if clue_id == person_id:
		_toast_msg("线索不能指向自己")
		return
	var clue: Dictionary = _data._find_clue(clue_id)
	if clue.is_empty(): return
	var rns: Array = clue.get("related_npcs", [])
	if rns.has(person_id):
		_toast_msg("这条线索已和%s有关" % _data._person_name(person_id))
		return
	_undo.create_action("tag_person")
	_undo.add_do_method(_do_tag.bind(clue_id, person_id, true))
	_undo.add_undo_method(_do_tag.bind(clue_id, person_id, false))
	_undo.commit_action()
	if _cb_tag.is_valid():
		_cb_tag.call(clue_id, person_id)
	_persist_view()
	_rebuild_graph()
	_toast_msg("已为线索「%s」打上%s标签" % [clue.get("name", clue_id), _data._person_name(person_id)])


func _do_tag(clue_id: String, person_id: String, add: bool) -> void:
	var clue: Dictionary = _data._find_clue(clue_id)
	if clue.is_empty(): return
	var rns: Array = clue.get("related_npcs", [])
	if add and not rns.has(person_id):
		rns.append(person_id)
	elif not add:
		rns.erase(person_id)
	clue["related_npcs"] = rns


## 两节点间已存在的玩家连线（不分方向，同对节点可能有多条不同 kind，如 support+contradict）
## 线索是否参与了任意玩家连线（用于把被拖拽关联、但本身未挂焦点人物的线索也纳入星型视图）
## 左栏拖入图谱时的公开入口：把一条尚未放置的线索放入图谱。
## drop_at 为抬起落点的 viewport 坐标；若恰好命中图上一个节点（推断/结论/线索），
## 在放置该线索的同时自动与之建立绿实线 support 关系（对应需求「拖线索1到推理1默认建实线绿色关系」）。
func place_clue(cid: String, drop_at: Vector2 = Vector2(-1, -1)) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	if _data._clue_placed(cid):
		return
	if drop_at.x >= 0.0:
		var hit: String = _drag.drop_node_except(drop_at, cid)
		var hk: String = _node_kind.get(hit, "")
		if hit != "" and hk in ["hypo", "clue", "conclusion"]:
			_edge._add_edge(cid, hit, "support", "green", false)
			_persist_view()
			_rebuild_graph()
			_toast_msg("线索已放入图谱并与目标建立支持关系")
			return
	_data._mark_clue_placed(cid)
	if drop_at.x >= 0.0:
		var _cp: Vector2 = _canvas.get_global_transform().affine_inverse() * drop_at
		_node_center[cid] = _cp
		var _nps: Dictionary = _state_store.get("graph_node_positions", {})
		_nps[cid] = _cp
		_state_store["graph_node_positions"] = _nps
	_persist_view()
	_rebuild_graph()
	_toast_msg("线索已放入图谱（详情卡可移除归还）")



## 正向推导：拖线索入画布后弹「可推导推断」候选窗（wall_relations 拖入路径调用）
func open_derive_popup(cid: String) -> void:
	if _state != State.EDITABLE:
		return
	if _dockctl != null:
		_dockctl._open_derive_popup(cid)

func _unplace_clue_from_graph(cid: String, card: Control) -> void:
	if _state != State.EDITABLE:
		return
	var doomed: Array[Dictionary] = []
	for r in _relations:
		if r.get("from", "") == cid or r.get("to", "") == cid:
			doomed.append(r)
	_data._unmark_clue_placed(cid)
	_placed_clues.erase(cid)
	for r in doomed:
		_edge._remove_edge(r.get("from", ""), r.get("to", ""), r.get("kind", "relate"))
	if is_instance_valid(card):
		card.queue_free()
	if _state_store.has("graph_placed_clues"):
		_state_store["graph_placed_clues"] = _placed_clues.duplicate()
	_persist_view()
	_rebuild_graph()
	# 左栏「已收集线索」即时恢复：必须先 rebuild（画布节点视图更新）再通知左栏刷新，
	# 否则 visible_clue_ids() 仍含被删线索，左栏过滤掉它导致需手动切换页面才显示。
	if _cb_relations_changed.is_valid():
		_cb_relations_changed.call(_relations.duplicate())
	_toast_msg("已将该线索从图谱移除，归还到「已收集线索」")

## 同步线索 associated 标记：参与任意玩家连线 → 实线绿边（已关联视觉反馈）；无连线 → 复位
func _sync_clue_associated() -> void:
	for c in _clues:
		var cid: String = c.get("id", "")
		var has: bool = false
		for r in _relations:
			if r.get("from", "") == cid or r.get("to", "") == cid:
				has = true
				break
		c["associated"] = has


## 删除一条用户建立的连线（需求 2026-08-19：可取消误连；可撤销）
func _on_undo() -> void:
	if _state != State.EDITABLE: return
	if _undo.has_undo():
		_undo.undo()
		if _cb_relations_changed.is_valid():
			_cb_relations_changed.call(_relations.duplicate())
		_persist_view()
		_rebuild_graph()
		_toast_msg("已撤销")


func _on_redo() -> void:
	if _state != State.EDITABLE: return
	if _undo.has_redo():
		_undo.redo()
		if _cb_relations_changed.is_valid():
			_cb_relations_changed.call(_relations.duplicate())
		_persist_view()
		_rebuild_graph()
		_toast_msg("已重做")


# ===================== 顶部栏驱动接口（由推理墙统一顶栏调用）=====================
func set_pen(color_key: String, dashed: bool) -> void:
	_pen_color_key = color_key
	_pen_dashed = dashed
	_dockctl._emit_pen_changed()


## 取消选中当前连线（统一入口：清下标 + 关弹窗 + 通知顶栏还原画笔模式）。
func _deselect_edge() -> void:
	_selected_edge = -1
	_edge._close_edge_menu()
	if _cb_edge_selected.is_valid():
		_cb_edge_selected.call(-1)


## 顶栏线型按钮（实/虚）在「有选中连线」时改为直接编辑该线；公开方法供 WallRelations 调用。
func _edit_selected_edge_dashed(d: bool) -> void:
	if _selected_edge < 0 or _selected_edge >= _edge_list.size(): return
	_edge._set_edge_dashed(_edge_list[_selected_edge], d)


## 顶栏性质按钮（支持/矛盾/反对/弱关联）在「有选中连线」时改为直接编辑该线；公开方法供 WallRelations 调用。
func _edit_selected_edge_kind(kind: String) -> void:
	if _selected_edge < 0 or _selected_edge >= _edge_list.size(): return
	_edge._set_edge_kind(_edge_list[_selected_edge], kind)


func set_mode(m: int) -> void:
	_switch_mode(m)


func set_connect_mode(enabled: bool) -> void:
	_connect_mode = enabled
	_connect_first_id = ""
	_connect_first_kind = ""
	if not enabled:
		_toast_msg("已退连线模式")
	_redraw_all()


func get_connect_mode() -> bool:
	return _connect_mode


func set_focus(pid: String) -> void:
	if pid == "": return
	_focus_person = pid
	_persist_view()
	_rebuild_graph()


# === P0/P2 公共方法 ===
func set_search_query(q: String) -> void:
	_search_query = q.strip_edges()
	_recompute_search_matches()
	_rebuild_graph()
	# 飞达第一个匹配
	if not _search_match_ids.is_empty():
		_fly_to_node(_search_match_ids[0])


func set_status_filter(f: String) -> void:
	_status_filter = f
	_rebuild_graph()


## 折叠/展开某个节点（XMind 式通用入口）。id 为空或叶子（线索）返回 false。
## EDITABLE 态走 UndoRedo（与移动/连线同栈，支持 Ctrl+Z/Y）；LOCKED 态直接生效（浏览用）。
func toggle_fold(id: String) -> bool:
	if id == "": return false
	var label: String = _node_short_label(id)
	var will_fold := not _folded_nodes.has(id)
	if _state == State.EDITABLE:
		_undo.create_action("折叠 %s" % label)
		_undo.add_do_method(_fold._set_folded.bind(id, will_fold))
		_undo.add_undo_method(_fold._set_folded.bind(id, not will_fold))
		_undo.commit_action()
	else:
		_fold._set_folded(id, will_fold)
	_persist_view()
	if will_fold:
		if _fold._is_leaf(id):
			_toast_msg("已收起「%s」" % label)
		else:
			_toast_msg("已折叠「%s」的外层内容（%d 项）" % [label, _fold._fold_count(id)])
	else:
		_toast_msg("已展开「%s」" % label)
	return will_fold

## 顶部 🪗 按钮：折叠当前悬停/高亮节点（非叶子则优先），否则折叠焦点人物（保留旧行为）
func toggle_fold_focus() -> bool:
	if _focus_person == "": return false
	var id: String = _focus_person
	if _highlight_id != "" and not _fold._is_leaf(_highlight_id):
		id = _highlight_id
	return toggle_fold(id)


func mark_clue_status(clue_id: String, status: String) -> void:
	# status: "excluded" / "pending" / "active"
	_user_excluded.erase(clue_id)
	_user_pending.erase(clue_id)
	if status == "excluded":
		_user_excluded[clue_id] = true
	elif status == "pending":
		_user_pending[clue_id] = true
	_rebuild_graph()


func get_user_status(clue_id: String) -> String:
	if _user_excluded.has(clue_id): return "excluded"
	if _user_pending.has(clue_id): return "pending"
	return "active"


func _recompute_search_matches() -> void:
	_search_match_ids = []
	if _search_query == "": return
	var q: String = _search_query.to_lower()
	for nd in _node_list_all():
		var text: String = str(nd.get("label", "")) + " " + str(nd.get("sub", ""))
		if q in text:
			_search_match_ids.append(nd.id)


# 完整节点列表（不过滤，用于搜索匹配）
func _node_list_all() -> Array:
	# 复用 _node_list 的逻辑：复制它之前不做过滤的版本
	# 这里简化：直接调用 _node_list 内部 raw 重建
	return _node_list_raw() if _node_list_raw != null else []


# === 飞达节点（镜头平滑移动 + 缩放到合适尺寸）===
func _fly_to_node(node_id: String) -> void:
	var n: Control = _node_views.get(node_id)
	if not n or not is_instance_valid(n): return
	# 触发 SceneFramework 的 reset_camera 行为：传节点中心，让相机移到那里
	# 简化：直接调用 _show_detail 让节点入视口
	_toast_msg("已跳转：%s" % _node_short_label(node_id))
	_highlight_id = node_id
	_redraw_all()
	# 如果有 SceneFramework 暴露 fly_to API，调用之
	if get_parent() and get_parent().has_method("fly_to_world_point"):
		get_parent().call("fly_to_world_point", n.position + n.size * 0.5)


# === 节点列表原始版（不过滤）===
func _node_list_raw() -> Array:
	return _node_list()


# === P2 导出为 Markdown ===
func export_markdown() -> void:
	var md := "# 推理墙 — 案件进度\n\n"
	md += "- 焦点人物：%s\n" % _data._person_name(_focus_person)
	md += "- 已排除线索：%d\n" % _user_excluded.size()
	md += "- 待查线索：%d\n" % _user_pending.size()
	md += "- 玩家关系：%d\n\n" % _relations.size()
	md += "## 线索\n"
	for c in _clues:
		var st: String = get_user_status(str(c.get("id", "")))
		var st_str: String = {"excluded": "（已排除）", "pending": "（待查）", "active": ""}.get(st, "")
		md += "- **%s**%s — %s\n" % [c.get("name", ""), st_str, c.get("desc", "")]
	md += "\n## 推断\n"
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		md += "- %s\n" % h.get("text", h.get("id", ""))
	md += "\n## 关系\n"
	for r in _relations:
		md += "- %s → %s（%s）\n" % [r.get("from", ""), r.get("to", ""), r.get("kind", "")]
	_show_export_panel(md)


func _show_export_panel(text: String) -> void:
	if _export_panel and is_instance_valid(_export_panel):
		_export_panel.queue_free()
	var win := Window.new()
	win.title = "📤 导出（窗口可拖动 · 文本框内 Ctrl+A 全选复制）"
	win.size = Vector2(860, 580)
	win.always_on_top = true
	_export_panel = win
	add_child(win)
	win.popup_centered()
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 8)
	mc.add_theme_constant_override("margin_bottom", 12)
	win.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	mc.add_child(vb)
	var title := Label.new()
	title.text = "导出内容（自动下载文件 · 亦可复制下方文本）"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(title)
	var edit := TextEdit.new()
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.text = text
	edit.wrap_enabled = true
	edit.select_all()
	vb.add_child(edit)
	win.close_requested.connect(func():
		if _export_panel == win:
			_export_panel = null
		win.queue_free()
	)


func undo() -> void:
	_on_undo()


func redo() -> void:
	_on_redo()


# ===================== 浮层线索栏（左侧，可收缩）=====================
# ===================== 「推断/结论」建议弹窗 =====================
# ===================== 缩放/平移 =====================
func _on_canvas_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(get_viewport().get_mouse_position(), 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(get_viewport().get_mouse_position(), 0.9)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# 连线模式下：空白处左键点击 = 取消选中（不进入拖动）
			if event.pressed and _connect_mode and _connect_first_id != "":
				_connect_first_id = ""
				_connect_first_kind = ""
				_toast_msg("已取消选中")
				_redraw_all()
				return
			if event.pressed:
				_panning = true
				_press_pos = get_viewport().get_mouse_position()
				_pan_last = _press_pos
				_press_moved = false
			else:
				_panning = false
				if not _press_moved:
					_on_canvas_left_click(get_viewport().get_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 连线模式下：右键点击空白 = 退出连线模式
			if _connect_mode:
				set_connect_mode(false)
				return
	elif event is InputEventMouseMotion and _panning:
		var gp := get_viewport().get_mouse_position()
		if _press_pos.distance_to(gp) > 5.0:
			_press_moved = true
		_canvas.position += gp - _pan_last
		_pan_last = gp


func _on_canvas_left_click(viewport_pos: Vector2) -> void:
	if _connect_mode:
		return
	# 全局坐标 → 画布本地：必须用全局变换逆，不能用 _canvas.position（那是父级局部坐标，漏算 _clip 的 64px 偏移）
	var lp := _canvas.get_global_transform().affine_inverse() * viewport_pos
	var ei := _edge._edge_hit_test(lp)
	if ei >= 0:
		_edge._select_edge(ei, viewport_pos)
	else:
		_deselect_edge()
	_redraw_all()

func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var old_scale := _zoom
	var ns: float = clamp(old_scale * factor, 0.25, 2.5)
	# 全局坐标 → 画布本地（含 _clip 契入偏移），与 _on_canvas_left_click 一致
	var lp := _canvas.get_global_transform().affine_inverse() * mouse_pos
	_canvas.scale = Vector2(ns, ns)
	# _canvas.position 是相对 _clip(契入后左上=左栏右缘/顶栏底) 的局部坐标，转回视口坐标需扣 _clip 原点偏移
	_canvas.position = mouse_pos - lp * ns - _clip.get_global_transform().origin
	_zoom = ns
	

## 顶栏「自动排列」（思傅 2026-09-09 改定 · B1）：进入「左右平衡整洁树」并**定格**（不再切回纯右向）。
## 人物居画布中心，其直接子（结论）整棵子树按茂盛度平衡分派到左右两侧——
## 左侧呈「叶-枝-干-根」、右侧「根-干-枝-叶」（美学4 镜像对称）。
## 一键排列语义 = 整墙整洁复位：清空手动钉位/偏移（否则被钉节点与其后代不参与重排、看不出平衡效果），
## 但**保留玩家的手动换侧选择**（_subtree_sides）。仅在模式 C（图谱）可用。
## 旧 BFS 深度分列（_auto_rank_layout / _use_rank_layout）保留代码但不再由本按钮触发。
func auto_layout() -> void:
	if _mode != GraphViewController.ViewMode.MODE_C:
		return
	_balanced_layout = true
	_node_offsets = {}        # 清空手动相对偏移，重排即回到整洁层级（需求3/5 复位）
	_manual_nodes = []        # 清空钉位登记：整墙全部节点参与平衡重排
	_root_anchor_pos = {}
	_state_store["graph_root_anchors"] = {}
	_state_store["graph_manual_nodes"] = []
	_layout._relayout_on_edge = true   # 强制忽略拖前旧位，按新结构全量重排
	_rebuild_graph()
	_persist_view()
	fit_view()


## 自适应画布：缩放+居中至全部节点可见（内容少则放大，多则缩小）
func fit_view() -> void:
	var ids: Array = _node_center.keys()
	if ids.is_empty():
		_canvas.scale = Vector2.ONE
		_canvas.position = Vector2.ZERO
		_zoom = 1.0
		return
	var minp := Vector2.INF
	var maxp := Vector2(-INF, -INF)
	for id in ids:
		var c: Vector2 = _node_center[id]
		minp = Vector2(min(minp.x, c.x), min(minp.y, c.y))
		maxp = Vector2(max(maxp.x, c.x), max(maxp.y, c.y))
	var bbox := maxp - minp
	var margin := 90.0
	var vp: Vector2 = _clip.size if _clip != null and _clip.size.x > 0 else Vector2(1280, 760)
	var ns: float = min((vp.x - margin * 2.0) / max(bbox.x, 1.0), (vp.y - margin * 2.0) / max(bbox.y, 1.0))
	ns = clamp(ns, 0.25, 1.6)
	_canvas.scale = Vector2(ns, ns)
	var center_gl := _canvas.get_global_transform().affine_inverse() * (minp + bbox * 0.5)
	_canvas.position = -center_gl * ns + vp * 0.5
	_zoom = ns


## 进墙默认取景：把焦点人物定格在画布中心（思傅 2026-09-17）。
## 宽图下 fit_view 按整 bbox 居中会让空白区居中 → 进去看不到内容；人物居中后推理链自其向两侧辐射，
## 玩家以人物为锚点探索。z 取适中缩放（默认 1.0，封顶 1.6 防止小图过大），保证人物卡完整且邻侧结论可见。
func _center_on_person(z: float = 1.0) -> void:
	if _focus_person == "" or not _node_center.has(_focus_person):
		return
	var c: Vector2 = _node_center[_focus_person]
	var vp: Vector2 = _clip.size if (_clip != null and _clip.size.x > 0) else Vector2(1280, 760)
	z = clamp(z, 0.25, 1.6)
	_canvas.scale = Vector2(z, z)
	_zoom = z
	# 画布中心(_canvas.position 为 _clip 局部坐标)对齐人物：canvas.position + c*z = vp*0.5
	_canvas.position = vp * 0.5 - c * z


# ===================== 顶部栏动作 =====================
func _switch_mode(m: int) -> void:
	if m == ViewMode.MODE_A or m == ViewMode.MODE_D:
		return
	if m == _mode: return


func _on_greyed_tab(tab_name: String) -> void:
	_toast_msg("%s 将于 Phase D 开放" % tab_name)


func _on_focus_selected(idx: int) -> void:
	var pid: String = _focus_sel.get_item_metadata(idx)
	if pid == "": return
	_focus_person = pid
	_persist_view()
	_rebuild_graph()


func _on_close_pressed() -> void:
	# 关闭前先把最新的节点位置/模式/焦点写回共享 state_store，
	# 避免「关系存了、位置没存」的读数落差（Bug1 兜底）。
	_persist_view()
	if _cb_close.is_valid():
		_cb_close.call()
	else:
		queue_free()


# 详情标题的主体文本（去前缀），供「编辑内容」输入框作为初始值


# ===================== 首入引导 =====================
# 首入引导（_show_tutorial 等多步骤教程弹层）已拆至 scripts/clue/graph/graph_view_guide.gd（由 _guide 组件负责）
func _toast_msg(text: String) -> void:
	if not _toast: return
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var t := create_tween()
	t.tween_property(_toast, "modulate:a", 0.0, 1.5).set_delay(0.6)


# ===================== 视图记忆 =====================
func _persist_view() -> void:
	if _state_store.is_empty(): return
	_state_store["graph_placed_clues"] = _placed_clues.duplicate()
	_state_store["graph_focus"] = _focus_person
	_state_store["graph_seed"] = _layout_seed
	_state_store["graph_manual_nodes"] = _manual_nodes.duplicate()
	_state_store["graph_folded_nodes"] = _folded_nodes
	_state_store["graph_nodes"] = _graph_nodes.duplicate()
	_state_store["graph_derived_conclusions"] = _derived_conclusions.duplicate()
	_state_store["graph_edited_texts"] = _edited_texts.duplicate()
	_state_store["graph_deleted_target"] = _deleted_target_edges   # 需求1：持久化已删除的结论→人物边
	_state_store["graph_node_offsets"] = _node_offsets.duplicate()   # 需求3/5：非根节点相对偏移持久化
	_state_store["graph_balanced_layout"] = _balanced_layout          # 2026-09-09：左右平衡布局已定格
	_state_store["graph_subtree_sides"] = _subtree_sides.duplicate()  # 2026-09-09：玩家手动换侧结果
	_state_store["graph_deleted_nodes"] = _state_store.get("graph_deleted_nodes", [])
	_layout._persist_node_positions()


## 自动折叠到「每条推理链最上层节点」（跨场景带入·任务）：
## 对任意节点，若它【没有更高层父节点】且【有下层子节点】，则视为该链的根 → 折叠以隐藏其整棵子树；
## 孤立节点 / 叶子（无下层子节点，如未建立任何关系的独立线索）保持可见。
## 层级序：人物/事件=0 最顶 > 结论=1 > 推断=2 > 线索=3 最底（与 graph_view_fold._ring_depth 对齐）。
## 仅 case_wide 进入新场景时调用一次，不沿用上一场景折叠/展开态。
func _apply_fold_to_roots() -> void:
	# 只基于「玩家真实关系」(_relations) 判链：_edge_list 含 _derive_edges 自动生成的数据预设边
	# （线索→推断 support、推断→结论 imply always），若纳入会把 conclusion/推断误判为链根，
	# 折叠后 _compute_hidden 从根 BFS 把全部推断/线索收起（节点"不显示"真因）。
	var adj := {}
	var link := func(a: String, b: String) -> void:
		if a == "" or b == "":
			return
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		if not (b in adj[a]): adj[a].append(b)
		if not (a in adj[b]): adj[b].append(a)
	for r in _relations:
		link.call(r.get("from", ""), r.get("to", ""))
	var folded := {}
	# 收集所有已知节点 id（真实邻接 + 自定义文本框 + 结论 + 焦点人物 + 线索），统一用权威 _kind_of 解析层级
	var ids := {}
	for id in adj:
		ids[id] = true
	for gn in _graph_nodes:
		ids[gn.get("id", "")] = true
	if not _derived_conclusions.is_empty():
		for _dc in _derived_conclusions:
			var _dnid: String = _conclusion_node_id(str(_dc.get("id", "")))
			if _dnid != "" and not ids.has(_dnid):
				ids[_dnid] = true
	if _focus_person != "" and not ids.has(_focus_person):
		ids[_focus_person] = true
	for c in _clues:
		ids[c.get("id", "")] = true
	for id in ids:
		if id == "":
			continue
		var rd := _fold._ring_depth(_fold._kind_of(id))
		var has_parent := false
		var has_child := false
		for nb in adj.get(id, []):
			var nrd := _fold._ring_depth(_fold._kind_of(nb))
			if nrd < rd:
				has_parent = true
			elif nrd > rd:
				has_child = true
		# 链根 = 无更高层父节点 且 有下层子节点 → 折叠隐藏其子树（孤立/叶子不折叠，保持可见）
		# 人物/事件（rd=0 最顶）天然满足条件，作为每链的折叠根（收起其下整条玩家链，人物本身仍可见）
		if not has_parent and has_child:
			folded[id] = true
	_folded_nodes = folded
	_state_store["graph_folded_nodes"] = _folded_nodes
	_persist_view()


# 顶栏「添文本框」：向画布新增一个自定义文本节点（kind = clue/hypo/conclusion/person）
func add_text_node(kind: String) -> void:
	var nkid: String = kind if kind in ["clue", "hypo", "conclusion", "person"] else "hypo"
	var seq: int = 0
	var nid: String = ""
	while true:
		nid = "note_%s_%d" % [nkid, seq]
		if not _node_center.has(nid): break
		seq += 1
	var labels: Dictionary = {"clue": "线索", "hypo": "推断", "conclusion": "结论", "person": "人物"}
	var subs: Dictionary = {"clue": "线索", "hypo": "推断", "conclusion": "结论", "person": "人物"}
	var placed: Dictionary = {"id": nid, "kind": nkid, "label": "【%s】新文本" % labels.get(nkid, "文本"), "sub": subs.get(nkid, "自定义"), "data": {"correct": true, "player_made": true}}
	_graph_nodes.append(placed)
	# 在画布中部放置
	var base: Vector2 = _canvas.size * 0.5
	var jitter: Vector2 = Vector2((-60 + (seq % 5) * 30), (-40 + (seq % 4) * 25))
	var pos: Vector2 = _layout._clamp_to_canvas(base + jitter)
	_node_center[nid] = pos
	var nps: Dictionary = _state_store.get("graph_node_positions", {})
	nps[nid] = pos
	_state_store["graph_node_positions"] = nps
	_layout_seed = int(Time.get_ticks_msec()) + seq
	_persist_view()
	_rebuild_graph()


func _delete_text_node(id: String) -> void:
	if not id.begins_with("note_"): return
	var target: Array = _graph_nodes.filter(func(n): return n.get("id", "") == id)
	if target.is_empty(): return
	_graph_nodes = _graph_nodes.filter(func(n): return n.get("id", "") != id)
	_relations = _relations.filter(func(r): return r.get("from", "") != id and r.get("to", "") != id)
	var del_pool: Array = _state_store.get("graph_deleted_nodes", [])
	del_pool.append(target[0])
	_state_store["graph_deleted_nodes"] = del_pool
	_folded_nodes.erase(id)
	_node_center.erase(id)
	_persist_view()
	_rebuild_graph()




# ===================== 难度门控：预设假设可见性 =====================
## 决定 battlefield 假设是否作为【预设节点】自动渲染上墙（配合难度分支设计）：
##   HARD  —— 不预设任何推断，玩家自行添加；
##   EASY  —— 仅正确推断（无误导、无扣留项）；
##   NORMAL—— 正确(auto)+误导 均预设可见；pool=="manual" 的正确项被扣留，须玩家自建。
func _hypo_preset_visible(hd: Dictionary) -> bool:
	var kind: String = str(hd.get("kind", "true"))
	var pool: String = str(hd.get("pool", "auto"))
	if _difficulty == Diff.HARD:
		return false
	if _difficulty == Diff.EASY:
		return kind == "true"
	if kind == "true" and pool == "manual":
		return false
	return true


# ===================== 提交软比对：抽取玩家主张 =====================
## 返回图谱上所有推断/结论节点的玩家主张：{id,kind,text,support_clues,player_made,dir_derived}
func _player_claims() -> Array:
	var out := []
	for nid in _node_views.keys():
		var kind: String = _fold._kind_of(nid)
		if kind != "hypo" and kind != "conclusion":
			continue
		var support := []
		for r in _relations:
			if str(r.get("to", "")) == str(nid) and str(r.get("kind", "")) in ["support", "weak"]:
				support.append(str(r.get("from", "")))
		out.append({"id": str(nid), "kind": kind, "text": _node_label(nid),
			"support_clues": support, "player_made": _node_player_made(nid),
			"dir_derived": _derive_dir(_node_label(nid), support)})
	return out


## 玩家产物快照（供 WallBranchEvaluator 分枝计分）。
## ⚠️ 只吐「玩家真实产物」：_relations（玩家建的边）+ _graph_nodes（玩家采纳/自建的推断）
## + _derived_conclusions（玩家落盘的结论）。
## 绝不掺入 _derive_edges() 自动派生的数据预设边——否则玩家什么都不做也满分。
## 返回深拷贝，避免评分引擎改动污染视图状态。
func snapshot_player_work() -> Dictionary:
	var rels: Array = []
	for r in _relations:
		rels.append({
			"from": str(r.get("from", "")),
			"to": str(r.get("to", "")),
			"kind": str(r.get("kind", "relate")),
			"dashed": bool(r.get("dashed", false)),
		})
	var nodes: Array = []
	for gn in _graph_nodes:
		nodes.append({
			"id": str(gn.get("id", "")),
			"kind": str(gn.get("kind", "hypo")),
			"text": str(gn.get("label", "")),   # 困难模式评价需要玩家自由节点文本（标注器用）
			"data": gn.get("data", {}).duplicate(true),
		})
	var cons: Array = []
	for dc in _derived_conclusions:
		cons.append(dc.duplicate(true) if dc is Dictionary else {"id": str(dc)})

	# ── 困难模式自由文本结论别名 ──────────────────────────────────────
	# 玩家自定义结论（custom_N）在验证时与正确推理链的结论做方向性比对：命中则别名成
	# conclusion_X，使布局树/评分引擎/边判定全部复用现有逻辑（与预设结论零分叉）。
	# 判定规则：同 dir（affirm/negate）+ 文本/subject/object 命中（见 _match_conclusion）。
	var custom_alias: Dictionary = {}      # 别名键含两种形态：derived 记录的 "custom_N" 与节点 id "conclusion_custom_N"
	for dc in _derived_conclusions:
		var cid: String = str(dc.get("id", ""))
		if not cid.begins_with("custom"):
			continue
		var ctext: String = str(dc.get("text", ""))
		var cdir: String = str(dc.get("dir", _derive_dir(ctext, [])))
		var matched: String = _match_conclusion(ctext, cdir)
		# 统一成「节点 id 形态」，使 derived 记录 id 与关系 from/to 对齐（否则困难模式「证据支撑度」
		# 按 player_concl_id 反查支撑边时对不上 → 玩家自定义结论白写、拿不到证据分）：
		#   命中真相 → conclusion_<真相id>；未命中 → conclusion_<custom_N>（沿用自定义节点 id）。
		var target_id: String = ("conclusion_" + matched) if matched != "" else ("conclusion_" + cid)
		custom_alias[cid] = target_id
		custom_alias["conclusion_" + cid] = target_id
	if not custom_alias.is_empty():
		var cons2: Array = []
		for dc in cons:
			var cid2: String = str(dc.get("id", ""))
			if custom_alias.has(cid2):
				var e: Dictionary = dc.duplicate(true)
				e["id"] = custom_alias[cid2]
				e["matched_from"] = cid2
				cons2.append(e)
			else:
				cons2.append(dc)
		cons = cons2
		var rels2: Array = []
		for r in rels:
			var rf: String = str(r.get("from", ""))
			var rt: String = str(r.get("to", ""))
			if custom_alias.has(rf):
				rf = custom_alias[rf]
			if custom_alias.has(rt):
				rt = custom_alias[rt]
			var e2: Dictionary = r.duplicate(true)
			e2["from"] = rf
			e2["to"] = rt
			rels2.append(e2)
		rels = rels2

	return {"relations": rels, "graph_nodes": nodes, "derived_conclusions": cons}


## 困难模式自定义结论匹配：玩家自由文本 → 真相结论 id（方向性一致才判对）。
## 命中阈值 0.45；宽容口径（match_keys 字面 + 概念 F1 + 实词 Dice + subject/object 重叠）见 conclusion_matcher.gd。
const _CONCL_MATCH_THRESHOLD := ConclusionMatcher.MATCH_THRESHOLD
func _match_conclusion(text: String, dir_hint: String = "") -> String:
	var t: String = text.strip_edges().to_lower()
	if t == "":
		return ""
	var best := ""
	var best_score := 0.0
	for c in _hypo_current.get("conclusions", []):
		var cid: String = str(c.get("id", ""))
		if cid == "":
			continue
		var cdir: String = str(c.get("dir", "affirm"))
		if dir_hint != "" and dir_hint != cdir:
			continue
		var s: float = _conclusion_text_match(t, c)
		if s > best_score:
			best_score = s
			best = cid
	return best if best_score >= _CONCL_MATCH_THRESHOLD else ""


func _conclusion_text_match(t: String, c: Dictionary) -> float:
	# 宽容匹配口径统一在 conclusion_matcher.gd；此处仅转发（与 HardModeEvaluator 同源）。
	return ConclusionMatcher.score(t, c)


func _node_label(id: String) -> String:
	if id.begins_with("conclusion_"):
		return _conclusion_text(id.substr("conclusion_".length()))
	if id == "conclusion":
		return _conclusion_text(_chosen_conclusion) if _chosen_conclusion != "" else _data._verdict_text()
	if id.begins_with("chain:"):
		return id
	for gn in _graph_nodes:
		if str(gn.get("id", "")) == str(id):
			return str(gn.get("label", ""))
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		if str(h.get("id", "")) == str(id):
			return str(h.get("text", ""))
	for c in _clues:
		if str(c.get("id", "")) == str(id):
			return str(c.get("name", id))
	for p in _persons:
		if str(p.get("id", "")) == str(id):
			return str(p.get("name", id))
	return str(id)


func _node_player_made(id: String) -> bool:
	for gn in _graph_nodes:
		if str(gn.get("id", "")) == str(id):
			return bool(gn.get("data", {}).get("player_made", false))
	return false


## 派生节点（推断/结论）是否正确（kind=true；自定义结论/未知返回 true，不参与扣分）。
## 供推理墙判定/评分区分「正确 vs 误导」推导（修复：选错误导项也拉低评分）。
func _derived_node_correct(id: String) -> bool:
	if id.begins_with("conclusion_"):
		var cid: String = id.substr("conclusion_".length())
		var cd: Dictionary = _conclusion_def(cid)
		if not cd.is_empty():
			return str(cd.get("kind", "true")) == "true"
		return true   # 自定义结论 custom_N：玩家自述，默认正确
	# 推断：battlefield.hypotheses 的 kind 优先；玩家自建/采纳的推断在 _graph_nodes.data.correct
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		if str(h.get("id", "")) == id:
			return str(h.get("kind", "true")) == "true"
	for gn in _graph_nodes:
		if str(gn.get("id", "")) == id:
			return bool(gn.get("data", {}).get("correct", true))
	return true


## 玩家图谱上「已采纳/自建」的推断与结论节点正确性统计（供推理墙三星·推理星计入）。
## 仅统计玩家实际建立的节点（_graph_nodes 中采纳的推断 / _derived_conclusions 中推导的结论）；
## 场景预设自动渲染、但玩家未采纳的 hypo 不计入。返回 {correct, total}。
func _derived_claim_correctness() -> Dictionary:
	var correct := 0; var total := 0
	var seen := {}
	for _d in _derived_conclusions:
		var _cid: String = str(_d.get("id", ""))
		if _cid == "" or seen.has(_cid): continue
		seen[_cid] = true
		total += 1
		var cd: Dictionary = _conclusion_def(_cid)
		if cd.is_empty() or str(cd.get("kind", "true")) == "true":
			correct += 1
	for gn in _graph_nodes:
		var gid: String = str(gn.get("id", ""))
		var gk: String = str(gn.get("kind", "hypo"))
		if gk != "hypo" or seen.has(gid): continue
		seen[gid] = true
		total += 1
		if bool(gn.get("data", {}).get("correct", true)):
			correct += 1
	return {"correct": correct, "total": total}


## 从节点文本推导方向（启发式）：含否定词→negate，否则 affirm
func _derive_dir(text: String, support_clues: Array) -> String:
	var neg := ["不", "非", "否", "≠", "不是", "没有", "无", "未"]
	for n in neg:
		if text.find(n) >= 0:
			return "negate"
	return "affirm"



func restore_text_node(id: String) -> void:
	var del_pool: Array = _state_store.get("graph_deleted_nodes", [])
	var found: Array = del_pool.filter(func(n): return n.get("id", "") == id)
	if found.is_empty(): return
	_graph_nodes.append(found[0])
	_state_store["graph_deleted_nodes"] = del_pool.filter(func(n): return n.get("id", "") != id)
	var base: Vector2 = _canvas.size * 0.5
	_node_center[id] = _layout._clamp_to_canvas(base + Vector2(-30, -20))
	var nps: Dictionary = _state_store.get("graph_node_positions", {})
	nps[id] = _node_center[id]
	_state_store["graph_node_positions"] = nps
	_persist_view()
	_rebuild_graph()

func get_deleted_nodes() -> Array:
	return ([] if _state_store.is_empty() else _state_store.get("graph_deleted_nodes", [])) as Array

func update_node_label(id: String, text: String) -> void:
	if _state_store.is_empty(): return
	if not _graph_nodes.any(func(n): return n.get("id", "") == id): return
	for i in _graph_nodes.size():
		if _graph_nodes[i].get("id", "") == id:
			var ndc: Dictionary = _graph_nodes[i]
			ndc["label"] = text
			_graph_nodes[i] = ndc
			break
	_persist_view()
	_rebuild_graph()

## 任务7：返回当前画布上可见的「线索」节点 id 列表，供推理墙左栏做唯一性去重。
func visible_clue_ids() -> Array:
	var out := []
	for id in _node_views:
		if _node_kind.get(id, "") == "clue":
			out.append(id)
	return out

## 采纳一条候选推断：生成推断(hypo)节点并自动与支撑证据线索建绿实线(support)关系。
## cand 来自场景 battlefield.hypotheses：{id,text,kind:"true"/"mislead",gate_clue_ids:[...]}
## 支撑线索 = gate_clue_ids 中当前已收集(_clues 含该 id)的线索；未收集的跳过（收集后发布会重算）。
## 采纳一条候选推断（推理战场引导，2026-09）：
## 推断假设(battlefield.hypotheses)已自动渲染为图谱 hypo 节点，relation_tags 已自动连"线索→推断"support 边。
## 这里补齐两层增量：① 该候选 id 若尚未作为节点上墙（如困难模式玩家自行补录的候选），则建成 hypo 节点；
## ② 把 gate_clue_ids 中「已收集但尚未与其连边」的证据线索补连 support 边，并展示 adopt_desc 详细文案。
# ===================== 正向推导：线索→推断→结论 =====================
func _hypo_def(hid: String) -> Dictionary:
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		if str(h.get("id", "")) == hid:
			return h
	return {}


func _conclusion_def(cid: String) -> Dictionary:
	for c in _hypo.get("battlefield", {}).get("conclusions", []):
		if str(c.get("id", "")) == cid:
			return c
	return {}


func _conclusion_text(cid: String) -> String:
	# 跨场景携带：先查玩家已推导记录里携带的文本。场景N 推导的结论带入场景N+1 后，
	# 该 cid 不在场景N+1 的 battlefield 里，_conclusion_def 查不到 → 不能回退到 verdict 默认文案。
	for _d in _derived_conclusions:
		if str(_d.get("id", "")) == cid:
			var _t := str(_d.get("text", ""))
			if _t != "":
				return _t
	if cid.begins_with("custom"):
		return _data._verdict_text()
	var cd := _conclusion_def(cid)
	if not cd.is_empty():
		return str(cd.get("text", cid))
	return _data._verdict_text()


## 结论节点 id ↔ 结论 id 互转（多实例：节点 id = "conclusion_" + 结论 id）
func _conclusion_node_id(con_id: String) -> String:
	return "conclusion_" + str(con_id)


func _conclusion_con_id(nid: String) -> String:
	if nid.begins_with("conclusion_"):
		return nid.substr("conclusion_".length())
	return ""


## 方案B：同步所有「已推导结论」的 gate 推断→结论 support 边。
## 结论定义含 gate_hypo_ids（多个推断/结论共推）时，凡已上墙的 gate 节点都补一条 support 边，
## 使结论链随推断逐步到位自动闭合；结论尚未推导（节点未生成）或某 gate 尚未上墙时不补，待其到位后再次同步。
## 2026-09-05：改为 no-op —— 用户明确要求「推理墙上只能有玩家选择的连线」，
## 系统自动补的 gate→结论 support 绿边属于「系统擅自添加的连线」，一律不再自动生成；
## 玩家若想连，自行拖推断到结论即可（走正常建边路径）。
func _sync_conclusion_gate_edges() -> void:
	return


## 推断详情卡入口：打开结论候选窗（gate_hypo_ids 含该推断的结论）
func _open_conclusion_choice(hid: String) -> void:
	_close_detail_card()
	_dockctl._open_conclusion_popup(hid)


## 视图跟随：把画布平移使指定节点中心落在视口中心（推导生成节点后自动跟随，避免节点在视野外）
func _focus_on(id: String) -> void:
	if not _node_views.has(id) or not is_instance_valid(_node_views[id]):
		return
	if _clip == null or _canvas == null:
		return
	var target: Vector2 = _node_center.get(id, _node_views[id].position + _node_views[id].size * 0.5)
	var vp_size: Vector2 = get_viewport_rect().size
	var clip_origin: Vector2 = _clip.get_global_transform().origin
	_canvas.position = vp_size * 0.5 - clip_origin - target * _zoom
	_redraw_all()


func _close_detail_card() -> void:
	if _detail_card and is_instance_valid(_detail_card):
		_detail_card.queue_free()
		_detail_card = null


func adopt_candidate(cand: Dictionary, auto_link_gates: bool = true, anchor_id: String = "") -> void:
	if _state != State.EDITABLE:
		_ui_toast("推理墙已封存，仅可浏览")
		return
	var hid: String = cand.get("id", "")
	if hid == "":
		return
	var label: String = cand.get("text", "推断")
	# ① 节点缺失才补建（正常路径由 battlefield.hypotheses 自动渲染；困难模式补录会走这里）
	if not _node_center.has(hid):
		var placed: Dictionary = {"id": hid, "kind": "hypo", "label": label,
			"sub": "推断", "data": {"correct": cand.get("kind", "true") == "true", "candidate": true, "adopt_desc": cand.get("adopt_desc", "")}}
		_graph_nodes.append(placed)
		var base: Vector2 = _canvas.size * 0.5
		# 锚定到触发线索（前向推导由 _derive_hypo 传 cid），否则回退画布中心
		if anchor_id != "" and _node_center.has(anchor_id):
			base = _node_center[anchor_id]
		# 螺旋碰撞检测：避免与现有节点叠加（替代旧 5×4 抖动网格）；最终位置由星形布局在 _rebuild_graph 重排
		var pos: Vector2 = _layout._find_non_overlapping_position(base, hid, "hypo", _node_center)
		_node_center[hid] = pos
	# ② 补充连接缺失的支撑证据：默认开启（候选面板一键采纳）；正向推导 _derive_hypo 传 false，
	#    只连玩家实际拖入的线索，绝不自动连带其他 gate 线索上墙
	if auto_link_gates and not _data._id_is_clue(hid):
		for cid in cand.get("gate_clue_ids", []):
			var cs := str(cid)
			if not _data._id_is_clue(cs):
				continue
			var linked := _relations.any(func(r): return r.get("from", "") == cs and r.get("to", "") == hid)
			linked = linked or any_edge(cs, hid)
			if not linked:
				_edge._add_edge(cs, hid, "support", "green", false)
	_layout_seed = int(Time.get_ticks_msec()) + _graph_nodes.size()
	_persist_view()
	_rebuild_graph()
	var desc: String = cand.get("adopt_desc", "")
	if desc != "":
		_ui_toast(desc if desc.length() <= 120 else desc.substr(0, 117) + "…")


func any_edge(f: String, t: String) -> bool:
	for e in _edge_list:
		if e.get("from", "") == f and e.get("to", "") == t:
			return true
	return false


func _ui_toast(msg: String) -> void:
	_toast_msg(msg)


func _gn_color(kind: String) -> Color:
	match kind:
		"person": return Color(0.66, 0.20, 0.16, 0.97)
		"conclusion": return Color(0.84, 0.74, 0.56, 0.96)
		"clue": return COL_CLUE_BG
		_: return COL_HYPO_BG


func _clear_drag_preview() -> void:
	_dragging = false
	_drag_id = ""


func _input(event: InputEvent) -> void:
	# === 弹窗拖动（统一可拖拽窗口）— 优先于节点/连线拖动处理 ===
	if _popup_dragging and _popup_drag_panel and is_instance_valid(_popup_drag_panel):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_popup_dragging = false
			return
		if event is InputEventMouseMotion:
			_popup_drag_panel.global_position = get_viewport().get_mouse_position() - _popup_drag_offset
			get_viewport().set_input_as_handled()
			return
	# === 节点拖动（move / edge）— 必须在 dock 拖动前处理 ===
	if _dragging and _drag_id != "":
		if event is InputEventMouseMotion:
			if _drag_mode == "move":
				# 节点移动：实时更新位置，distance 钳制到 kind 距离带
				var n: Control = _node_views.get(_drag_id)
				if n and is_instance_valid(n):
					var mouse_canvas: Vector2 = _canvas.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
					var new_pos: Vector2 = mouse_canvas - _drag_offset
					var new_center: Vector2 = new_pos + n.size * 0.5
					var clamped: Vector2 = _layout._clamp_free(new_center)
					# 需求3：拖动中同步平移整个子树（分枝/叶子）随本节点一并移动
					var _delta: Vector2 = clamped - _node_center.get(_drag_id, clamped)
					n.position = clamped - n.size * 0.5
					_node_center[_drag_id] = clamped
					for _sd in _drag_subtree:
						var _sv: Variant = _node_views.get(_sd)
						if _sv != null and is_instance_valid(_sv):
							_node_center[_sd] = _node_center.get(_sd, Vector2.ZERO) + _delta
							_sv.position = _node_center[_sd] - _sv.size * 0.5
					# 拖拽命中提示：拖到其它节点范围时，把拖拽节点缩小并置顶，
					# 让玩家直观感知两者可建立联系
				# ⚠️ 修复（任务1）：_drop_node_except/_nearest_node_except 期望「视口全局坐标」
				# （内部会再做一次 affine_inverse 变换），此处必须传鼠标全局坐标而非画布本地
				# 坐标 clamped，否则双重变换导致命中恒空、缩小/置顶从不触发。
				var _gp: Vector2 = get_viewport().get_mouse_position()
				var _hit: String = _drag.drop_node_except(_gp, _drag_id) if _state == State.EDITABLE else ""
				if _hit == "":
					_hit = _drag.nearest_node_except(_gp, _drag_id, 48.0) if _state == State.EDITABLE else ""
					if _hit != "" and _node_kind.get(_hit, "") in ["hypo", "clue", "conclusion"]:
						n.modulate = Color(1, 1, 1, 0.55)
						n.scale = Vector2(0.9, 0.9)
						n.z_index = 900
						_drag_hover = _hit
					else:
						n.modulate = Color(1, 1, 1, 1)
						n.scale = Vector2.ONE
						n.z_index = 0
						_drag_hover = ""
					_fold._sync_fold_controls_positions()
					_redraw_all()
					get_viewport().set_input_as_handled()
			elif _drag_mode == "edge":
				# 建边：拖拽过程中画弧线预览
				if get_viewport().get_mouse_position().distance_to(_drag_from) > 6:
					_redraw_all()
			return
		elif event is InputEventMouseButton and not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and _drag_mode == "move":
				_drag.commit_move(_drag_id)
				return
			if event.button_index == MOUSE_BUTTON_LEFT and _drag_mode == "edge":
				_drag.commit_drag(_drag_id)
				return
			if event.button_index == MOUSE_BUTTON_RIGHT and _drag_mode == "edge":
				_drag.commit_drag(_drag_id)
				return
	# === dock 拖动（原有） ===
	if _dock_dragging and event is InputEventMouseMotion:
		var gp2: Vector2 = get_viewport().get_mouse_position()
		if gp2.distance_to(_dock_start) > 6:
			_dock_moved = true
		_dockctl._move_dock_preview(gp2)
		# 声明吃掉移动：避免 dock 的 ScrollContainer 在拖动过程中抢去事件去滚动列表
		get_viewport().set_input_as_handled()
		return
	if _dock_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dockctl._on_dock_drop()
		return
	# === 键 ===
	# ⚠️ 2026-08-19 修复：elif 分支曾无类型守卫直接访问 event.keycode，
	# 导致每一次鼠标/触摸事件都抛 "Invalid access to property 'keycode'" SCRIPT ERROR，
	# 并中断事件链 → 顶栏按钮/节点点击全部"无反应"。
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			_on_undo()
		elif event.keycode == KEY_Y and event.ctrl_pressed:
			_on_redo()
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			# 延迟到帧末，避免在 _input 内直接销毁节点导致卡死（Web导出易复现）
			call_deferred("_on_close_pressed")
