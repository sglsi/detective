extends Control

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

# === 入参数据（由推理墙传入，本控制器只读 + 通过回调回写）===
var _clues: Array = []
var _hypo: Dictionary = {}
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
var _manual_nodes: Array = []
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
var _clip: Control = null           # 裁剪视口
var _canvas: Control = null         # _world：节点与连线挂此
var _hint_layer: Control = null     # 难度提示圈（最底）
var _edge_layer: Control = null     # 连线绘制层（节点下）
var _toolbar: Control = null
var _toast: Label = null
var _detail_card: PanelContainer = null
var _tutorial: Control = null

# === 派生缓存 ===
var _node_views: Dictionary = {}    # id -> Control
var _node_center: Dictionary = {}   # id -> Vector2（画布本地中心）
var _node_kind: Dictionary = {}     # id -> String
var _node_data: Dictionary = {}     # id -> Dictionary（原始数据）
var _graph_nodes: Array = []        # 玩家顶栏「添文本框」新增的自定义节点 [{id,kind,label,sub}]（持久化于 state_store["graph_nodes"]）
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
var _drag_from := Vector2.ZERO
var _drag_kind := ""
var _drag_mode := ""              # "move" 或 "edge"（_drag_kind 是关系 kind support/oppose）
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
}

# === 身份揭示门控（需求2）：某些 NPC 在「揭示名字的证据」被收集前，不得作为已知人物
# 出现在推理墙人物中心，避免现场线索 related_npcs 提前把未揭示身份的嫌疑人名带上墙。
# > 霍普的名字只在收到从美国来的电报（C_SOTCB_501 马车公司信息 / C_SOTCB_502 霍普身份，
#   均为场景五之后）才揭晓；此前现场勘查（c203/204/205/206 等）虽真实关联他，但推理墙
#   人物中心不得提前显示「霍普」。
const _IDENTITY_REVEAL_GATES := {
	"NPC_HOP": ["C_SOTCB_501", "C_SOTCB_502"],
}

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
# 颜色键 → 颜色（绿=支持 / 橙=矛盾存疑 / 红=反对 / 灰=弱关联）
const _COLOR_KEYS := {
	"green": Color(0.4, 0.85, 0.4),
	"orange": Color(0.95, 0.55, 0.25),
	"red": Color(0.95, 0.3, 0.3),
	"grey": Color(0.55, 0.50, 0.42),
}
const _KEY_TO_KIND := {"green": "support", "orange": "contradict", "red": "oppose", "grey": "relate"}
const _KIND_TO_KEY := {"support": "green", "imply": "green", "contradict": "orange", "oppose": "red", "relate": "grey"}


static func kind_to_key(kind: String) -> String:
	return _KIND_TO_KEY.get(kind, "grey")


static func key_to_kind(key: String) -> String:
	return _KEY_TO_KIND.get(key, "relate")


static func color_from_key(key: String) -> Color:
	return _COLOR_KEYS.get(key, _COLOR_KEYS["grey"])


func _ready() -> void:
	pass


# === 当前笔（由推理墙顶部栏 / 图谱内弹窗共同驱动）===
var _pen_color_key: String = "green"
var _pen_dashed: bool = false
var _cb_pen_changed: Callable = Callable()
var _cb_relations_changed: Callable = Callable()
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

# === 图谱内拖拽笔（落点建关系时使用）===
var _drag_color_key: String = "green"
var _drag_dashed: bool = false

# === 连线选中/编辑（点击连线弹出右键菜单）===
var _selected_edge: int = -1      # _edge_list 中被点击选中的连线下标；-1 表示未选中
var _edge_menu: Control = null    # 连线右键浮动菜单
var _press_pos: Vector2 = Vector2.ZERO   # 画布左键按下时的视口坐标
var _press_moved: bool = false           # 按下后是否发生拖拽（用于区分点击与拖拽平移）

# === P0/P1/P2 新增状态（搜索/状态标记/折叠/导出）===
var _search_query: String = ""
var _status_filter: String = "all"   # all/excluded/pending/key
var _folded_nodes: Dictionary = {}       # node_id -> true：被折叠的"根"节点（XMind 式连线折叠）
var _all_positions: Dictionary = {}      # node_id -> Vector2：全部节点位置缓存（含隐藏者），持久化用
var _fold_controls: Dictionary = {}      # node_id -> Control：连线出口处的折叠点击控件（透明，只接 gui_input）
var _fold_layer: Control = null          # 折叠圆形绘制图层（统一在 draw 回调里画，规避"绘制时机"报错）
var _user_excluded := {}             # clue_id -> true（用户标"已排除"）
var _user_pending := {}              # clue_id -> true（用户标"待查"）
var _search_match_ids := []          # 当前搜索命中的节点 id 列表
var _export_panel: Control = null    # 导出结果面板


## 唯一入口：推理墙调用本方构建图谱视图。data 字段见文件头。
func build(data: Dictionary) -> void:
	_clues = data.get("clues", [])
	_hypo = data.get("hypo", {})
	_relations = data.get("relations", [])
	_persons = data.get("persons", [])
	_focus_person = data.get("focus_person", "")
	_difficulty = data.get("difficulty", Diff.NORMAL)
	_editable = data.get("editable", true)
	# 不再冻结墙侧 verdict 快照（问题3）：结论节点红/橙/黄/绿与文字始终按图内关系实时推算，
	# 「关联正确后即时变色」，无需退出重进。LOCKED 墙关系不可变，实时推算与已定 verdict 一致。
	_verdict = -1
	_state_store = data.get("state_store", {})
	_cb_tag = data.get("on_tag", Callable())
	_cb_add_edge = data.get("on_add_edge", Callable())
	_cb_remove_relation = data.get("on_remove_relation", Callable())
	_cb_close = data.get("on_close", Callable())
	_cb_verify = data.get("on_verify", Callable())
	_cb_pen_changed = data.get("on_pen_changed", Callable())
	_cb_relations_changed = data.get("on_relations_changed", Callable())
	_show_toolbar = data.get("show_toolbar", false)
	_auto_fold = data.get("auto_fold", false)
	_case_wide = data.get("case_wide", false)

	# 视图记忆恢复（09 R-3）：读 SaveGame/state_store
	_mode = _state_store.get("graph_view_mode", ViewMode.MODE_C)
	_placed_clues = (_state_store.get("graph_placed_clues", []) as Array).duplicate()
	_manual_nodes = (Array(_state_store.get("graph_manual_nodes", [])) as Array).duplicate()
	_graph_nodes = (Array(_state_store.get("graph_nodes", [])) as Array).duplicate()
	_edited_texts = (Dictionary(_state_store.get("graph_edited_texts", {})) as Dictionary).duplicate()

	# 兜底（修根因 2026-08-19 v4）：如果调用方给的 _persons 是空但 ClueSystem 实际有相关线索，
	# 实时从 Autoload 拉并组装一次（避免 reasoning_wall 提前 _derive 之后又被另一层兜底覆盖，
	# 此处是最后一道）。
	if _persons.is_empty() and ClueSystem and ClueSystem.has_method("get_collected"):
		var live: Array = ClueSystem.get_collected("")
		if not live.is_empty():
			var seen := {}
			var out := []
			for c in live:
				for p in c.get("related_npcs", []):
					if not seen.has(p):
						seen[p] = true
						# 身份揭示门控占位：未揭示身份的人物仍保留，但用「神秘嫌疑犯」占位居替（同 reasoning_wall._derive_persons）
						var npc_name: String = _NPC_DISPLAY_NAMES.get(p, p) if _identity_revealed(p, live) else "神秘嫌疑犯"
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
	# 需求2：进入新场景（案件级大墙 reuse）时若已建立关系，自动折叠内层已确立的推理主干，
	# 聚焦最新线索与推断。仅当玩家尚未主动折叠过（_folded_nodes 为空）才播种，玩家展开/折叠会覆盖。
	if _auto_fold and _folded_nodes.is_empty() and not _relations.is_empty():
		var _inner_roots: Array = []
		for _rf in _relations:
			for _eid in [_rf.get("from", ""), _rf.get("to", "")]:
				if _eid == "": continue
				if _ring_depth(_kind_of(_eid)) == 0 and not (_eid in _inner_roots):
					_inner_roots.append(_eid)
		for _eid in _inner_roots:
			_folded_nodes[_eid] = true
		_state_store["graph_folded_nodes"] = _folded_nodes
		_persist_view()
	_all_positions = {}

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
	# 已收集线索栏唯一入口：reasoning_wall 左栏（挂顶层 z=20，显示+选择+拖入放置+放置后消失）。
	# 这里不再创建图谱自带的第二套 dock（System B），避免"两套已收集线索"冗余。
	# _create_clue_dock()

	if not _state_store.get("graph_tutorial_seen", false):
		_show_tutorial()


## 身份揭示门控（需求2）：判定某 NPC 是否应以"已知人物"出现在人物中心。
## 仅当已收集线索中存在其"揭示名字的证据"时才揭示；收集线索集合由 live（已收集线索）承载。
func _identity_revealed(pid: String, live: Array) -> bool:
	var gates: Array = _IDENTITY_REVEAL_GATES.get(pid, [])
	if gates.is_empty():
		return true
	for g in gates:
		for c in live:
			if c.get("id", "") == g:
				return true
	return false


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

	# 裁剪视口（限制 _canvas 在屏幕内）
	_clip = Control.new()
	_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.offset_top = 64
	_clip.offset_bottom = -44
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	add_child(_clip)

	# _world 容器（缩放/平移等价 Camera2D）
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_gui)
	_clip.add_child(_canvas)

	_hint_layer = Control.new()
	_hint_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_layer.z_index = 0
	_hint_layer.draw.connect(_on_hint_draw)
	_canvas.add_child(_hint_layer)

	_edge_layer = Control.new()
	_edge_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_layer.z_index = 1
	_edge_layer.draw.connect(_on_edge_draw)
	_canvas.add_child(_edge_layer)

	_fold_layer = Control.new()
	_fold_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fold_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fold_layer.z_index = 3
	_fold_layer.draw.connect(_on_fold_draw)
	_canvas.add_child(_fold_layer)

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
	var tab_b := _mk_tab("推理链", false)
	tab_b.pressed.connect(_switch_mode.bind(ViewMode.MODE_B))
	row.add_child(tab_b)
	_tab_c_btn = tab_c; _tab_b_btn = tab_b
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

	_refresh_toolbar_state()
	return bar


var _focus_sel: OptionButton = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _verify_btn: Button = null
var _tab_c_btn: Button = null
var _tab_b_btn: Button = null


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
	if _tab_b_btn: _tab_b_btn.button_pressed = (_mode == ViewMode.MODE_B)
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
func _person_name(id: String) -> String:
	for p in _persons:
		if p.get("id", "") == id:
			var nm: String = p.get("name", "")
			if nm != "" and nm != id:
				return nm
	if _NPC_DISPLAY_NAMES.has(id):
		return _NPC_DISPLAY_NAMES[id]
	return id


func _find_clue(cid: String) -> Dictionary:
	for c in _clues:
		if c.get("id", "") == cid: return c
	return {}


func _clues_for_person(pid: String) -> Array:
	var out := []
	for c in _clues:
		if pid in c.get("related_npcs", []):
			out.append(c)
	return out


func _compute_common_clues() -> void:
	_common_clues = {}
	for c in _clues:
		var np := 0
		for _p in c.get("related_npcs", []):
			np += 1
		if np >= 2:
			_common_clues[c.get("id", "")] = true


## 证据连线（数据边）派生：玩家关系 + 自动推断（clue.relation_tags→推断 / 推断→结论）
func _derive_edges() -> void:
	_edge_list = []
	var seen := {}
	var add := func(f: String, t: String, kind: String, always: bool, color_key: String = "", dashed: bool = false) -> void:
		if f == "" or t == "": return
		var key = "%s|%s|%s" % [f, t, kind]
		if seen.has(key): return
		seen[key] = true
		var ck := color_key if color_key != "" else kind_to_key(kind)
		var col := color_from_key(ck)
		_edge_list.append({"from": f, "to": t, "kind": kind, "color": col, "color_key": ck, "dashed": dashed, "dotted": false, "always": always})

	for r in _relations:
		var k: String = r.get("kind", "relate")
		# 用户手动建立的关系常显（需求 2026-08-19：连线建立后一直显示，不依赖悬停/模式）
		add.call(r.get("from", ""), r.get("to", ""), k, true, r.get("color_key", ""), r.get("dashed", false))

	# 自动推断：线索 relation_tags 命中某推断节点 → 证据指向
	var hypo_ids := []
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		hypo_ids.append(h.get("id", ""))
	for c in _clues:
		for tag in c.get("relation_tags", []):
			if hypo_ids.has(tag):
				add.call(c.get("id", ""), tag, "support", false, "", false)

	# 自动推断：所有推断 → 结论（传导）— 这些结构性边始终显示（不依赖悬停）
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		add.call(h.get("id", ""), "conclusion", "imply", true, "", false)


func _rel_color(kind: String) -> Color:
	return color_from_key(kind_to_key(kind))


# ===================== 图重建 =====================
## 节点卡片真实高度：视图已测量用视图，否则回退字符估算
func _view_height(id: String) -> float:
	var v: Variant = _node_views.get(id)
	if v != null:
		var _sz: Vector2 = v.size
		if _sz.y > 1.0:
			return _sz.y
	return _est_node_h({})

## 同列纵向去重叠：同一列（x 相邻）节点按真实卡片高度，保证相邻卡片上下边距 ≥15px，并把整列回居中避免整体下沉堆出画布
func _apply_column_overlap_fix() -> void:
	var cols: Dictionary = {}
	for id in _node_center:
		var x: float = (round(_node_center[id].x / 8.0) * 8.0)
		if not cols.has(x):
			cols[x] = []
		cols[x].append(id)
	for x in cols:
		var arr: Array = cols[x]
		if arr.size() < 2:
			continue
		arr.sort_custom(func(a, b): return _node_center[a].y < _node_center[b].y)
		var _cy_before: float = 0.0
		for i in arr.size():
			_cy_before += _node_center[arr[i]].y
		_cy_before /= float(arr.size())
		for i in range(1, arr.size()):
			var _ha: float = _view_height(arr[i - 1])
			var _hb: float = _view_height(arr[i])
			var _min_cy: float = _node_center[arr[i - 1]].y + (_ha + _hb) * 0.5 + 15.0
			if _node_center[arr[i]].y < _min_cy:
				_node_center[arr[i]] = Vector2(_node_center[arr[i]].x, _min_cy)
		var _cy_after: float = 0.0
		for i in arr.size():
			_cy_after += _node_center[arr[i]].y
		_cy_after /= float(arr.size())
		var _shift: float = _cy_before - _cy_after
		for i in arr.size():
			var id2: String = arr[i]
			_node_center[id2] = Vector2(_node_center[id2].x, _node_center[id2].y + _shift)
			var vv: Variant = _node_views.get(id2)
			if vv != null:
				vv.position = _node_center[id2] - vv.size * 0.5
	return


func _rebuild_graph() -> void:
	_compute_common_clues()
	_derive_edges()
	# 清旧节点 + 旧折叠控件（扫画布清除历史残留图元，避免拖动中重建叠加出重复同名节点）
	for ch in _canvas.get_children():
		if ch is Control and ch.has_meta("graph_node"):
			ch.queue_free()
	for n in _node_views.values():
		if is_instance_valid(n): n.queue_free()
	for c in _fold_controls.values():
		if is_instance_valid(c): c.queue_free()
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
	var pos := _compute_layout(nodes)
	_node_center = pos
	# 合并可见节点位置进全局缓存（隐藏节点的位置由 _all_positions 保留）。
	# ⚠️ 仅模式 C 合并：模式 B 是垂直分层的临时聚焦视图，若写入会污染 _all_positions，
	# 导致切回星型/重进时个别节点位置错乱回初始（问题2）。
	if _mode == ViewMode.MODE_C:
		for id in pos:
			_all_positions[id] = pos[id]
	for nd in nodes:
		var v := _make_node(nd)
		v.set_meta("graph_node", true)
		_node_views[nd.id] = v
		_canvas.add_child(v)
		v.position = pos.get(nd.id, Vector2.ZERO) - v.size * 0.5
		_node_kind[nd.id] = nd.kind
		_node_data[nd.id] = nd.data
	# 同列纵向去重叠：按真实卡片高度硬保证相邻卡片上下边距 ≥15px（不依赖布局/估算，避免任何覆盖）
	_apply_column_overlap_fix()
	# 创建连线出口折叠控件（XMind 式 −/+N）
	for nd in nodes:
		if _is_leaf(nd.id): continue
		if _direct_outer_neighbors(nd.id).is_empty(): continue
		var fc := _make_fold_control(nd.id)
		fc.set_meta("graph_node", true)
		_fold_controls[nd.id] = fc
		_canvas.add_child(fc)
	_redraw_all()


func _node_list() -> Array:
	var list := []
	if _case_wide:
		var fp: String = _focus_person
		for p in _persons:
			var pid: String = str(p.get("id", "")) if p is Dictionary else ""
			if pid == "" or pid == "__case__":
				continue
			var is_focus := pid == fp
			list.append({"id": pid, "kind": "person",
				"label": _person_name(pid), "sub": "焦点" if is_focus else "角色",
				"color": COL_PERSON, "data": {"id": pid}})
	else:
		# 中心：焦点人物
		list.append({"id": _focus_person, "kind": "person",
			"label": _person_name(_focus_person), "sub": "焦点", "color": COL_PERSON,
			"data": {"id": _focus_person}})

	if _mode == ViewMode.MODE_C:
		# 第一圈：线索
		var clues := _clues if _case_wide else _clues_for_person(_focus_person)
		# P0-2 状态过滤
		if _status_filter != "all" and not clues.is_empty():
			var sf := _status_filter
			clues = clues.filter(func(c): return _clue_matches_filter(c, sf))
		if clues.is_empty():
			clues = _clues
			# 同样应用状态过滤
			if _status_filter != "all":
				var sf2 := _status_filter
				clues = clues.filter(func(c): return _clue_matches_filter(c, sf2))
		for c in clues:
			var cid: String = c.get("id", "")
			var common: bool = _common_clues.has(cid)
			list.append({"id": cid, "kind": "clue",
				"label": c.get("name", cid), "sub": _clue_sub(c),
				"color": _clue_color(c), "data": c, "common": common})
		# 关联线索：被拖拽连到推断/结论/人物但本身未挂焦点人物的线索，也纳入星型视图，
		# 使其显示为节点并把连线画出来（修复「拖线索后线索不显示、不知是否关联」）。
		var _in_list := {}
		for _n in list: _in_list[_n.id] = true
		# 关联线索：被拖到推断/结论/人物但未挂焦点的线索也纳入（修复拖线索不显示）
		for c2 in _clues:
			var _cid2: String = c2.get("id", "")
			if _in_list.has(_cid2): continue
			if _clue_has_relation(_cid2):
				list.append({"id": _cid2, "kind": "clue",
					"label": c2.get("name", _cid2), "sub": _clue_sub(c2),
					"color": _clue_color(c2), "data": c2, "common": _common_clues.has(_cid2)})
				_in_list[_cid2] = true
		# 已放置线索（可能为孤立，如删除关系后）：始终保留为图谱节点（独立循环，杜绝重复叠加）
		for _p_cid in _placed_clues:
			if _in_list.has(_p_cid): continue
			var _p_c: Dictionary = _clue_by_id(_p_cid)
			if _p_c.is_empty(): continue
			list.append({"id": _p_cid, "kind": "clue",
				"label": _p_c.get("name", _p_cid), "sub": _clue_sub(_p_c),
				"color": _clue_color(_p_c), "data": _p_c, "common": _common_clues.has(_p_cid)})
			_in_list[_p_cid] = true
		# 第二圈：推断
		var hypos: Array = _hypo.get("battlefield", {}).get("hypotheses", [])
		if hypos.is_empty():
			hypos = [{"id": "H_core", "text": _hypo.get("title", "核心推断"), "correct": true}]
		for h in hypos:
			list.append({"id": h.get("id", ""), "kind": "hypo",
				"label": h.get("text", ""), "sub": "推断", "color": COL_GOLD_LIGHT, "data": h})
		# 第三圈：推理链 + 结论（结论统一在函数末尾追加一次，避免 MODE_C 下出现两个结论文本框，问题4）
		var chain_id: String = _hypo.get("chain_id", "")
		if chain_id != "":
			list.append({"id": "chain:" + chain_id, "kind": "chain",
				"label": "#" + str(chain_id), "sub": "推理链", "color": COL_GOLD, "data": {}})
	else:
		# 模式 B：分层
		var clues := _clues.filter(func(c): return c.get("associated", false))
		if clues.is_empty():
			clues = _clues
		for c in clues:
			var cid: String = c.get("id", "")
			list.append({"id": cid, "kind": "clue",
				"label": c.get("name", cid), "sub": _clue_sub(c),
				"color": _clue_color(c), "data": c, "common": _common_clues.has(cid)})
		var hypos: Array = _hypo.get("battlefield", {}).get("hypotheses", [])
		if hypos.is_empty():
			hypos = [{"id": "H_core", "text": _hypo.get("title", "核心推断"), "correct": true}]
		for h in hypos:
			list.append({"id": h.get("id", ""), "kind": "hypo",
				"label": h.get("text", ""), "sub": "推断", "color": COL_GOLD_LIGHT, "data": h})
		var chain_id2: String = _hypo.get("chain_id", "")
		if chain_id2 != "":
			list.append({"id": "chain:" + chain_id2, "kind": "chain",
				"label": "#" + str(chain_id2), "sub": "推理链", "color": COL_GOLD, "data": {}})
	list.append({"id": "conclusion", "kind": "conclusion",
		"label": _verdict_text(), "sub": "结论", "color": _verdict_color(), "data": {}})

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
	var hidden := _compute_hidden()
	if not hidden.is_empty():
		var kept := []
		for nd in list:
			if hidden.has(nd.id): continue
			kept.append(nd)
		list = kept
	return list


# ===================== 图谱折叠（XMind 式连线折叠） =====================
## 圈层深度：结论/人物/链=0（最内，可折叠外层）；推断=1；线索=2（最外，叶子不可折叠）。
## 与布局 _RING_BANDS 解耦——仅用于折叠方向判定（设计 §1.1）。
func _ring_depth(kind: String) -> int:
	match kind:
		"conclusion": return 0
		"person":     return 0
		"chain":      return 0
		"hypo":       return 1
		"clue":       return 2
		_:            return 2

## 任意节点 id 的 kind（不依赖可见性——隐藏节点也需判定圈层）
func _kind_of(id: String) -> String:
	if id == _focus_person: return "person"
	if id == "conclusion": return "conclusion"
	if id.begins_with("chain:"): return "chain"
	if _node_kind.has(id): return _node_kind[id]
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		if h.get("id", "") == id: return "hypo"
	for c in _clues:
		if c.get("id", "") == id: return "clue"
	return "clue"

## 叶子节点（线索）不可折叠
func _is_leaf(id: String) -> bool:
	return _ring_depth(_kind_of(id)) >= 2

## 无向邻接表（折叠遍历用）：玩家关系 + 数据边 + 模式C人物↔线索元数据边
func _build_adjacency() -> Dictionary:
	var adj := {}
	var link := func(a: String, b: String) -> void:
		if a == "" or b == "": return
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		if not (b in adj[a]): adj[a].append(b)
		if not (a in adj[b]): adj[b].append(a)
	for e in _edge_list:
		link.call(e.from, e.to)
	for r in _relations:
		link.call(r.get("from", ""), r.get("to", ""))
	if _mode == ViewMode.MODE_C and _focus_person != "":
		# 结论节点 id 恒为 "conclusion"，直接锚定（避免在 _build_adjacency 内调 _node_list 造成递归）
		link.call(_focus_person, "conclusion")
	return adj

## 节点的直接外层邻居（圈层深度严格更大的相连节点）——用于折叠控件数量与朝向
func _direct_outer_neighbors(id: String) -> Array:
	var out := []
	var rd := _ring_depth(_kind_of(id))
	for nb in _build_adjacency().get(id, []):
		if _ring_depth(_kind_of(nb)) > rd:
			out.append(nb)
	return out

## 折叠隐藏集合：从各折叠根 BFS，收起所有圈层更深且可达的外层节点（设计 §4.1）
func _compute_hidden() -> Dictionary:
	var hidden := {}
	var adj := _build_adjacency()
	for root in _folded_nodes:
		var root_rd := _ring_depth(_kind_of(root))
		var stack := [root]
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			for nb in adj.get(cur, []):
				if hidden.has(nb): continue
				if _ring_depth(_kind_of(nb)) <= root_rd: continue
				hidden[nb] = true
				stack.append(nb)
	return hidden

## 折叠控件上的计数：直接外层邻居数（设计 §4.3 / §9.4）
func _fold_count(id: String) -> int:
	return _direct_outer_neighbors(id).size()

## 折叠控件上的字形：展开=−，折叠=+N
func _fold_glyph(id: String) -> String:
	if _folded_nodes.has(id):
		return "+%d" % _fold_count(id)
	return "-"

## 折叠控件位置：节点外缘、朝向外层邻居簇重心方向
func _fold_control_pos(id: String) -> Vector2:
	var center: Vector2 = _node_center.get(id, Vector2.ZERO)
	if center == Vector2.ZERO: return center
	var neighbors := _direct_outer_neighbors(id)
	if neighbors.is_empty(): return center
	var dir := Vector2.ZERO
	for nb in neighbors:
		var nc: Vector2 = _node_center.get(nb, center)
		if nc != center:
			dir += (nc - center).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var radius: float = _node_radius_for_kind(_kind_of(id))
	return center + dir * (radius + 14)

## 节点半径（用于控件外移距离）
func _node_radius_for_kind(kind: String) -> float:
	match kind:
		"person":     return 52.0
		"conclusion": return 46.0
		"chain":      return 36.0
		"hypo":       return 40.0
		"clue":       return 40.0
		_:            return 40.0

## 创建连线出口折叠控件的「点击热区」（透明 Control，只接 gui_input；圆形由 _fold_layer 统一绘制）
func _make_fold_control(id: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(48, 48)
	c.size = Vector2(48, 48)
	c.position = _fold_control_pos(id) - Vector2(24, 24)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.z_index = 6
	c.tooltip_text = "点击折叠/展开外层内容"
	c.gui_input.connect(_on_fold_control_gui.bind(id))
	return c

## 折叠圆形统一绘制（_fold_layer 的 draw 回调，绘制时机合法，规避"Drawing only allowed inside _draw"）
func _on_fold_draw() -> void:
	for id in _fold_controls:
		var c: Control = _fold_controls.get(id)
		if c == null or not is_instance_valid(c): continue
		var center := _fold_control_pos(id)
		var folded := _folded_nodes.has(id)
		# 圆底
		_fold_layer.draw_circle(center, 22.0, Color(0.10, 0.08, 0.06, 0.96))
		_fold_layer.draw_arc(center, 22.0, 0, TAU, 28, COL_GOLD, 3.0)
		# 字形
		var f := ThemeDB.get_default_theme().default_font
		if f == null: continue
		var txt := _fold_glyph(id)
		var fs := 26
		var sz := f.get_string_size(txt, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var p := Vector2(center.x - sz.x * 0.5, center.y + sz.y * 0.5)
		_fold_layer.draw_string(f, p, txt, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
			COL_GOLD_LIGHT if not folded else COL_GOLD)

## 点击折叠控件：toggle（不触发节点拖动/连线）
func _on_fold_control_gui(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle_fold(id)
		get_viewport().set_input_as_handled()

## 拖动节点时同步所有折叠控件位置（点击热区 + 绘制图层都要刷新）
func _sync_fold_controls_positions() -> void:
	for id in _fold_controls:
		var c = _fold_controls[id]
		if not is_instance_valid(c): continue
		c.position = _fold_control_pos(id) - Vector2(12, 12)
	if _fold_layer and is_instance_valid(_fold_layer): _fold_layer.queue_redraw()

## 折叠根写回（供 UndoRedo 调用）
func _set_folded(id: String, v: bool) -> void:
	if v:
		_folded_nodes[id] = true
	else:
		_folded_nodes.erase(id)
	_rebuild_graph()


func _clue_sub(c: Dictionary) -> String:
	var correct: bool = c.get("correct", true)
	var st := "已关联" if c.get("associated", false) else "未关联"
	if not correct: st = "干扰项"
	# P0-2 用户标记状态覆盖
	var uid: String = c.get("id", "")
	if _user_excluded.has(uid): st = "已排除"
	elif _user_pending.has(uid): st = "待查"
	return st


# P0-2 状态过滤辅助：判断线索是否匹配当前过滤
func _clue_matches_filter(c: Dictionary, filter: String) -> bool:
	var uid: String = c.get("id", "")
	match filter:
		"excluded": return _user_excluded.has(uid)
		"pending": return _user_pending.has(uid)
		"key":
			# 关键：correct=true 且 importance >= 5（"重要"+"关键"）且未排除
			if _user_excluded.has(uid): return false
			return c.get("correct", true) and int(c.get("importance", 0)) >= 5
	return true


func _clue_color(c: Dictionary) -> Color:
	if not c.get("correct", true): return COL_RED
	if c.get("associated", false): return COL_GREEN
	return COL_GOLD_LIGHT


func _verdict_text() -> String:
	var v := _compute_verdict()
	return ["两种对不上", "证据不足", "有点道理", "说得通"][v]


func _verdict_color() -> Color:
	var v := _compute_verdict()
	return [COL_RED, COL_ORANGE, COL_YELLOW, COL_GREEN][v]


## 轻量结论推算（与 reasoning_wall.get_verdict 同规则，供结论节点着色；视图派生，不缓存）
func _compute_verdict() -> int:
	if _verdict >= 0:
		return _verdict
	var contra := 0
	for c in _clues:
		if c.get("associated", false) and not c.get("correct", true):
			contra += 1
	for r in _relations:
		if r.get("dashed", false): continue   # 虚线（存疑）只显示不计入判定，与 get_verdict 同规则
		if r.get("kind", "") in ["contradict", "oppose"]:
			contra += 1
	if contra > 0: return 0
	var support := 0
	for c in _clues:
		if c.get("associated", false) and c.get("correct", true):
			support += 1
	for r in _relations:
		if r.get("dashed", false): continue   # 同上：虚线支持连线不计入
		if r.get("kind", "") == "support":
			support += 1
	if support >= 3: return 3
	if support >= 1: return 2
	return 1


## 布局算法（按需求1/6）：
##   - 每节点按 kind 分配「距离带 [min, max]」（_RING_BANDS）：核心<结论<链<推断<线索
##   - 节点可在带内自由拖动，distance 钳制到带内 → 永远维持排序
##   - 自适应半径：节点多时往外推到 max，保证总弧长 ≥ 节点宽 × 节点数（消除初始重叠）
##   - 手动位置持久化到 state_store（graph_node_positions）
func _compute_layout(nodes: Array) -> Dictionary:
	var center := _canvas.size * 0.5
	if _canvas.size.x <= 0 or _canvas.size.y <= 0:
		# headless / 未布局时兜底（test_graph_view 会强制设 1280x720，但兜底仍必要）
		center = Vector2(960, 540)
	var out := {}

	# 加载已持久化位置
	var saved_pos: Dictionary = _state_store.get("graph_node_positions", {})

	if _mode == ViewMode.MODE_C:
		# 按关系驱动的横向阶梯树（华生示范对齐）：人物→结论→推断→线索 逐列向左/右阶梯铺开，
		# 人物偏左树向右、偏右树向左（方向不硬性统一）；多人物各成一棵独立子树水平错开不交叉。
		# 每次增删关系都会经 _rebuild_graph 重排本布局（玩家手动拖动仅即时生效、下次增删复位）。
		_relation_tree_layout(nodes, center, saved_pos, out)
	else:
		# 模式 B：推理链纵向自上而下（人物在最上，结论→推断/链→线索依次向下逐行排开）
		out[_focus_person] = center
		var rows := {}
		for nd in nodes:
			if nd.id == _focus_person: continue
			var d: int = 4
			match nd.kind:
				"conclusion": d = 1
				"hypo", "chain": d = 2
				"clue": d = 3
			if not rows.has(d): rows[d] = []
			rows[d].append(nd.id)
		var depth_keys := rows.keys()
		depth_keys.sort()
		var span2: float = _canvas.size.x - 200.0 if _canvas.size.x > 200 else 1080.0
		var y0: float = center.y - 100.0
		var row_gap2 := 130.0
		var rr := 0
		for d in depth_keys:
			var arr: Array = rows[d]
			var n2: int = arr.size()
			var y: float = y0 + float(rr) * row_gap2
			for i in n2:
				var x: float = 100.0 + (float(i) / maxi(n2, 1)) * span2
				if n2 == 1: x = _canvas.size.x * 0.5 if _canvas.size.x > 0 else 540.0
				out[arr[i]] = Vector2(x, y)
			rr += 1
	return out


## 按节点 kind 估算渲染宽度（用于自适应半径防重叠；与 _make_node 卡片尺寸×2 同步）
func _node_width_for_kind(kind: String) -> float:
	# 2026-08-21：宽度整体减半（配合文本框自适应窄化，环径估算同步收紧）
	match kind:
		"clue":       return 160.0
		"hypo":       return 140.0
		"conclusion": return 160.0
		"chain":      return 125.0
		_: return 150.0


## 把点钳制到对应 kind 的距离带内（保持「核心 < 结论 < 推断 < 线索」排序）
# XMind 式布局：以焦点人物为中心，主分支（推断/结论/推理链）扇出，
# 线索沿其佐证分支向外剖列、轻微横向扇出；无佐证线索在外围柔性散布。
# 不再按 kind 分层成同心圆；已保存位置直接采用（自由排布，不钳回 ring）。
func _xmind_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	# 人物锚点：沿用已保存位置（人物可自由拖动/画布可有多个人物）；
	# 无保存时默认放在水平约 72% 处，给推理树留出向左铺开的空间。
	var person_pos: Vector2 = center
	var sp: Variant = saved_pos.get(_focus_person, null)
	if sp is Vector2:
		person_pos = sp
	else:
		person_pos = _clamp_to_canvas(Vector2(_canvas.size.x * 0.72, _canvas.size.y * 0.5))
	out[_focus_person] = person_pos
	# 层深：结论离人物最近(1)，推断/推理链中层(2)，线索最外层(3)
	var layer_of := {}
	for nd in nodes:
		match nd.kind:
			"conclusion":
				layer_of[nd.id] = 1
			"chain":
				layer_of[nd.id] = 2
			"hypo":
				layer_of[nd.id] = 2
			"clue":
				layer_of[nd.id] = 3
			_:
				layer_of[nd.id] = 4
	# 生长方向：人物偏右则向左铺开，偏左则向右铺开，避免树伸出画布
	var dirv := 1.0
	if person_pos.x >= _canvas.size.x * 0.5:
		dirv = -1.0
	var col_gap: float = 250.0
	# 按层分列；已保存位置直接沿用（尊重玩家拖动）
	var by_layer := {}
	var max_layer := 0
	for nd in nodes:
		if nd.id == _focus_person:
			continue
		var saved_v: Variant = saved_pos.get(nd.id, null)
		if saved_v is Vector2:
			out[nd.id] = saved_v
		else:
			var lv: int = layer_of.get(nd.id, 4)
			if not by_layer.has(lv):
				by_layer[lv] = []
			by_layer[lv].append(nd.id)
			if lv > max_layer:
				max_layer = lv
	# 同层同列：列 x 随层距人物递增，列内按高度均匀堆叠（多结论/多推断同侧时整齐排列）
	for lv in by_layer.keys():
		var ids: Array = by_layer[lv]
		var col_x: float = person_pos.x + dirv * (float(lv) * col_gap)
		var n := ids.size()
		var step: float = 92.0
		var total_h: float = float(maxi(n - 1, 0)) * step
		var top: float = clampf(person_pos.y - total_h * 0.5, 60.0, _canvas.size.y - 60.0)
		for j in n:
			out[ids[j]] = _clamp_to_canvas(Vector2(col_x, top + float(j) * step))
	# 布局收尾：全部钳制到画布内，防止默认布局把文本节点挤出可视区
	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


# ===================== 按关系驱动的横向阶梯树（华生示范对齐） =====================
## 思想：不再按 kind 一次性横排，而是把「整条推理链」作为一棵以人物为根的关系树：
##   人物(col0) → 结论(col1) → 推断/推理链(col2) → 线索(col3) 逐列向右阶梯铺开。
##  - 排列起自人物为根的 BFS 树（邻居层更深者作子），同父子树归组、父居子带中央；
##  - 多结论/多推断/多线索同列垂直整齐堆叠，不出现跨侧分叉（避免连线交叉）；
##  - direction 不硬性统一：人物偏右则树向左生长、偏左则向右，人物可自由摆放（保存位优先）；
##  - 孤立（未接入树）线索在外围散布；多人物每人一棵独立子树、水平错开不交叉。
func _relation_tree_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	# 性质层：决定节点所在纵向阶梯列（人物最内、线索最外）
	var depth_of := {}
	for nd in nodes:
		match nd.get("kind", ""):
			"person": depth_of[nd.id] = 0
			"conclusion": depth_of[nd.id] = 1
			"hypo", "chain": depth_of[nd.id] = 2
			"clue": depth_of[nd.id] = 3
			_: depth_of[nd.id] = 4
	# 根集合 = 人物节点（当前单焦点人物；算法支持多人物各成一树）
	var roots: Array = []
	for nd in nodes:
		if nd.get("kind", "") == "person" and not (nd.id in roots):
			roots.append(nd.id)
	if roots.is_empty() and not nodes.is_empty():
		roots = [nodes[0].id]
	var adj := _build_adjacency()
	# 构建父子关系树：从根 BFS，邻居"性质层更深"者作子，每节点只承接一次（防环）
	var child_map := {}
	var assigned := {}
	var q: Array = []
	for r in roots:
		if assigned.has(r): continue
		assigned[r] = true
		q.append(r)
		child_map[r] = []
	while q.size() > 0:
		var rest: Array = []
		for u in q:
			for nb in adj.get(u, []):
				if assigned.has(nb): continue
				if not (depth_of.get(nb, 4) > depth_of.get(u, 4)):
					continue
				assigned[nb] = true
				if not child_map.has(u): child_map[u] = []
				child_map[u].append(nb)
				child_map[nb] = []
				rest.append(nb)
		q = rest
	# 子树叶子高：内部 = Σ 子叶子高，用于垂直带划分
	var high := {}
	for r in roots:
		high[r] = 1
	for u in assigned:
		high[u] = 1
	_collect_high(roots, child_map, high)
	# 节点估算高度（文字行数×行高 + 副标题 + 内边距），用于垂直带切分保证兄弟间 ≥15px
	var est_h := {}
	for nd in nodes:
		est_h[nd.id] = _est_node_h(nd)
	var memo := {}
	for _nd in nodes:
		_subtree_span_est(_nd.id, child_map, est_h, memo)
	# 人物定位：保存位优先（人物可自由拖动）；多人物水平错开
	var col_gap: float = 300.0
	var root_default_x: float = center.x
	var _rd: Variant = saved_pos.get(_focus_person, null) if _focus_person != "" else null
	if _rd is Vector2:
		root_default_x = _rd.x
	for r in roots:
		var _sv: Variant = saved_pos.get(r, null)
		var rx: float = _sv.x if (_sv is Vector2) else root_default_x
		var ry: float = _sv.y if (_sv is Vector2) else center.y
		out[r] = Vector2(rx, ry)
	# direction：人物偏右→向左生长，偏左→向右（方向不硬性统一）
	var dirv := 1.0
	if root_default_x >= _canvas.size.x * 0.5:
		dirv = -1.0
	for r in roots:
		var _sv2: Variant = saved_pos.get(r, null)
		var rx2: float = _sv2.x if (_sv2 is Vector2) else root_default_x
		var ry2: float = _sv2.y if (_sv2 is Vector2) else center.y
		var _half3: float = maxf(memo.get(r, 130.0) * 0.5, 60.0)
		var top2: float = ry2 - _half3
		var bot2: float = ry2 + _half3
		_assign_subtree(r, child_map, memo, est_h, out, top2, bot2, rx2, dirv, col_gap)
	# 孤立（未接入树）节点：外围散布（保存位优先），保持可见
	var spare_i := 0
	var out_keys := {}
	for k in out: out_keys[k] = true
	for nd in nodes:
		if out_keys.has(nd.id): continue
		var sv: Variant = saved_pos.get(nd.id, null)
		if sv is Vector2:
			out[nd.id] = sv
			continue
		out[nd.id] = Vector2(root_default_x + dirv * (5.0 + float(spare_i) * 0.6) * col_gap,
			center.y - 220.0 + float(spare_i) * 120.0)
		spare_i += 1
	# 手动拖动过的节点保持原位，不被自动布局覆盖（保证每个人物/结论/推断/线索都能自由移动）
	for mid2 in _manual_nodes:
		var _sv3: Variant = saved_pos.get(mid2, null)
		if _sv3 is Vector2 and out.has(mid2):
			out[mid2] = _sv3
	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


## 后续遍历收集拓扑序，据此自底向上算子树叶子高
func _collect_high(roots: Array, child_map: Dictionary, high: Dictionary) -> void:
	var order := []
	var stack: Array = []
	for r in roots:
		stack.append(Array([r, false]))
	while stack.size() > 0:
		var pair: Array = stack.pop_back()
		var u: String = pair[0]
		var visited: bool = pair[1]
		if visited:
			order.append(u)
		else:
			stack.append(Array([u, true]))
			var ch: Array = child_map.get(u, [])
			var closed := {}
			for c in ch:
				if closed.has(c): continue
				closed[c] = true
				stack.append(Array([c, false]))
	for u in order:
		var ch2: Array = child_map.get(u, [])
		if ch2.is_empty(): continue
		var s: int = 0
		for c in ch2:
			s += high.get(c, 1)
		high[u] = s


## 子树所需垂直带长（递归）：父带 ≥ max(自身估高, Σ子带长 + 兄弟间隙15)，保证后代不溢出、兄弟不交叠
func _subtree_span_est(u: String, child_map: Dictionary, est_h: Dictionary, memo: Dictionary) -> float:
	if memo.has(u):
		return memo[u]
	var ch: Array = child_map.get(u, [])
	var s: float = est_h.get(u, 130.0) as float
	if not ch.is_empty():
		var sub: float = 0.0
		for _c in ch:
			sub += _subtree_span_est(_c, child_map, est_h, memo)
		s = maxf(s, sub + 15.0 * (float(ch.size()) - 1.0))
	memo[u] = s
	return s


## 递归布点：父居其子带中央；子带按各自子树带长精确切分（不足则居中留白），兄弟带间保证 ≥15px，绝不溢出交叠
func _assign_subtree(u: String, child_map: Dictionary, sp: Dictionary, est_h: Dictionary, out: Dictionary, top: float, bot: float, pxx: float, dirv: float, col_gap: float) -> void:
	var mid_y: float = (top + bot) * 0.5
	if out.has(u):
		out[u] = Vector2(out[u].x, mid_y)
	else:
		out[u] = Vector2(pxx, mid_y)
	var ch: Array = child_map.get(u, [])
	if ch.is_empty():
		return
	var totalSpan: float = 0.0
	for _c in ch:
		totalSpan += sp.get(_c, 130.0) as float
	totalSpan += 15.0 * (float(ch.size()) - 1.0)
	var cur: float = top + maxf(0.0, ((bot - top) - totalSpan) * 0.5)
	for c in ch:
		var _h: float = sp.get(c, 130.0) as float
		_assign_subtree(c, child_map, sp, est_h, out, cur, cur + _h, pxx + dirv * col_gap, dirv, col_gap)
		cur += _h + 15.0


## 估算节点卡片高度（与 _make_node 尺寸逻辑一致）：行数=ceil(文本宽/420)，行数×行高＋副标题＋内边距
func _est_node_h(nd: Dictionary) -> float:
	var fs: float = 28.0
	var line_h: float = fs * 1.35
	var sub_h: float = 22.0 * 1.35
	var txt: String = str(nd.get("label", ""))
	var natural: float = maxf(float(txt.length()) * fs, 1.0)
	var nlines: float = maxf(1.0, ceil(natural / 420.0))
	return nlines * line_h + sub_h + 2.0 + 12.0


# 灵活布局辅助：仅把节点限制在画布内（XMind 式自由排布，允许任意位置）
func _clamp_to_canvas(p: Vector2) -> Vector2:
	var m: float = 60.0
	var cv: Vector2 = _canvas.size
	var ox: float = clampf(p.x, m, maxf(cv.x - m, m))
	var oy: float = clampf(p.y, m, maxf(cv.y - m, m))
	return Vector2(ox, oy)


# 拖动自由摆放：允许节点中心略超出画布（半张卡，约 120px），吃满可视区但不至于拖丢
func _clamp_free(p: Vector2) -> Vector2:
	var cv: Vector2 = _canvas.size
	var slack: float = 120.0
	return Vector2(clampf(p.x, -slack, maxf(cv.x + slack, slack)),
		clampf(p.y, -slack, maxf(cv.y + slack, slack)))

func _clamp_to_band(pos: Vector2, center: Vector2, kind: String) -> Vector2:
	var band: Dictionary = _RING_BANDS.get(kind, _RING_BANDS["clue"])
	var diff: Vector2 = pos - center
	var dist: float = diff.length()
	if dist < 0.01:
		# 落在中心点附近，给个默认方向（正上）以免角度无定义
		return center + Vector2(0.0, -band.default)
	if dist < band.min:
		return center + diff / dist * band.min
	if dist > band.max:
		return center + diff / dist * band.max
	return pos


## 把当前所有节点位置写入 state_store（持久化手动布局，含隐藏节点——见设计 §6）
## 先用当前可见位置刷新缓存，再写入；隐藏节点位置由 _all_positions 保留（避免展开错位）。
func _persist_node_positions() -> void:
	if _state_store.is_empty(): return
	# 仅模式 C 写盘：模式 B 布局（或用户在模式 B 的拖动）不持久化，
	# 否则会覆盖模式 C 的存档位置 → 重进/切回星型时位置错乱（问题2）。
	if _mode != ViewMode.MODE_C: return
	for id in _node_center:
		_all_positions[id] = _node_center[id]
	var pos: Dictionary = {}
	for id in _all_positions:
		var p = _all_positions[id]
		if id == _focus_person: continue   # 中心永远画布中央，不存
		if p is Vector2:
			pos[id] = p
	_state_store["graph_node_positions"] = pos


# ===================== 节点视图 =====================
## 节点配色规则（用户需求）：
##   - 线索：底=白；已关联=实线绿边；未关联=虚线暗金边；干扰项(correct=false)=实线红边 + 红字
##   - 推断：底=灰；有关联=实线暗边；无关联=虚线暗边；干扰项=实线红边 + 红字
##   - 推理链/结论：维持当前（结论按 verdict 红/橙/黄/绿，链=金边）
##   - 中心人物：金边 + 暖金底
func _make_node(nd: Dictionary) -> Control:
	var kind: String = nd.kind
	var is_person: bool = kind == "person"
	var is_concl: bool = kind == "conclusion"
	var is_chain: bool = kind == "chain"
	var is_hypo: bool = kind == "hypo"
	var is_clue: bool = kind == "clue"

	var card: PanelContainer
	var is_graph_card: bool = true
	var gc = GraphCard.new()
	card = gc
	# 大小按类型给（中文文本可能变宽，故预留；字号已×2，尺寸同步放大）
	# #1 自适应：卡片尺寸随姓名文字长度增长（约 28px/字，字号28），封顶 480 后自动换行扩高
	# 位置由调用方按 _node_center - size*0.5 重新居中，边/菜单以中心为锚，连线不受影响
	var _base_w: float = 180.0; var _base_h: float = 150.0
	if is_person: _base_w = 180.0; _base_h = 170.0
	elif is_concl: _base_w = 160.0; _base_h = 160.0
	elif is_chain: _base_w = 125.0; _base_h = 120.0
	elif is_hypo: _base_w = 140.0; _base_h = 130.0
	else: _base_w = 160.0; _base_h = 130.0
	# 卡片尺寸在标签建立后按真实文字测量（见文末 _size_card_to_text 调用）

	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	var default_border_w: int = 2
	style.border_width_left = default_border_w; style.border_width_right = default_border_w
	style.border_width_top = default_border_w; style.border_width_bottom = default_border_w
	style.set_corner_radius_all(8)

	var text_red := false
	var dashed: bool = false
	var dashed_col: Color = COL_CLUE_BORDER
	var dashed_w: float = 2.0
	var font_col: Color = COL_TEXT_DARK   # 默认深色字；人物红框改用浅色字
	var sub_col: Color = COL_GREY

	if is_clue:
		var c: Dictionary = nd.data
		var correct: bool = c.get("correct", true)
		var assoc: bool = c.get("associated", false)
		# P0-2 用户标记覆盖
		var cid: String = c.get("id", "")
		var excluded: bool = _user_excluded.has(cid)
		var pending: bool = _user_pending.has(cid)
		if excluded:
			# 已排除：灰底 + 暗边
			style.bg_color = Color(0.20, 0.18, 0.16, 0.85)
			style.border_color = Color(0.40, 0.38, 0.35)
			style.border_width_left = 1; style.border_width_right = 1
			style.border_width_top = 1; style.border_width_bottom = 1
			text_red = false
		elif not correct:
			# 干扰项：白底 + 实线红边 + 红字
			style.bg_color = COL_CLUE_BG_DIM
			style.border_color = COL_CLUE_BORDER_DISTRACT
			text_red = true
		else:
			style.bg_color = COL_CLUE_BG
			if assoc:
				style.border_color = COL_CLUE_BORDER_ASSOC
			else:
				# 未关联：虚线暗金边
				style.border_color = COL_CLUE_BG   # 把 stylebox 边框调成 bg 色，避免与手动虚线重影
				style.border_width_left = 0; style.border_width_right = 0
				style.border_width_top = 0; style.border_width_bottom = 0
				dashed = true
				dashed_col = COL_CLUE_BORDER
				dashed_w = 2.0
		# P0-2 待查标记：黄边覆盖
		if pending and not excluded:
			style.border_color = Color(0.95, 0.80, 0.25)
			style.border_width_left = 3; style.border_width_right = 3
			style.border_width_top = 3; style.border_width_bottom = 3
			dashed = false
		# 共同线索（关联≥2人物）金边覆盖
		if nd.get("common", false):
			style.border_color = COL_GOLD
			style.border_width_left = 3; style.border_width_right = 3
			style.border_width_top = 3; style.border_width_bottom = 3
			dashed = false
		# P0-3 搜索匹配高亮：金色加粗外框
		if not _search_query.is_empty() and _search_match_ids.has(cid):
			style.border_color = Color(1.0, 0.90, 0.30)
			style.border_width_left = 4; style.border_width_right = 4
			style.border_width_top = 4; style.border_width_bottom = 4
	elif is_hypo:
		var h: Dictionary = nd.data
		var correct: bool = h.get("correct", true)
		if not correct:
			style.bg_color = COL_HYPO_BG_DIM
			style.border_color = COL_CLUE_BORDER_DISTRACT
			text_red = true
		else:
			style.bg_color = COL_HYPO_BG
			if _node_has_user_relation(nd.id):
				style.border_color = COL_HYPO_BORDER
			else:
				# 未关联推断：虚线暗边
				style.border_color = COL_HYPO_BG   # 同上，把 stylebox 边框调成 bg 色
				style.border_width_left = 0; style.border_width_right = 0
				style.border_width_top = 0; style.border_width_bottom = 0
				dashed = true
				dashed_col = COL_HYPO_BORDER
				dashed_w = 2.0
	elif is_chain:
		style.bg_color = Color(0.16, 0.13, 0.08, 0.95)
		style.border_color = COL_GOLD
	elif is_concl:
		style.bg_color = Color(0.84, 0.74, 0.56, 0.96)   # 结论=浅棕（对照华生示范）
		style.border_color = Color(0.58, 0.44, 0.20)
		style.border_width_left = 3; style.border_width_right = 3
		style.border_width_top = 3; style.border_width_bottom = 3
	elif is_person:
		style.bg_color = Color(0.66, 0.20, 0.16, 0.97)   # 人物=红框（对照华生示范）
		style.border_color = Color(0.96, 0.44, 0.34)
		style.border_width_left = 3; style.border_width_right = 3
		style.border_width_top = 3; style.border_width_bottom = 3
		font_col = Color(0.99, 0.95, 0.92)
		sub_col = Color(0.92, 0.88, 0.85)

	card.add_theme_stylebox_override("panel", style)

	# 折叠根：暗金虚线描边（提示"此节点下有收起内容"，见设计 §2.3）
	if _folded_nodes.has(nd.id):
		(card as GraphCard).setup_dashed(true, COL_GOLD, 2)

	# 启用虚线（需要 GraphCard）
	if is_graph_card and dashed:
		(card as GraphCard).setup_dashed(true, dashed_col, dashed_w)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	var lab = Label.new()
	lab.text = nd.get("label", "")
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # #1 宽度封顶时换行，避免长文本截断
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", COL_TEXT_RED if text_red else font_col)
	lab.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lab)

	var sub = Label.new()
	sub.text = nd.get("sub", "")
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", sub_col)
	sub.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	# #1 真实自适应：宽度按文字自然宽度（上限 420=15 汉字×28 字号），高度按换行后真实行数；超过15字才换行
	var _MAX_W: float = 420.0
	# 自然宽度：autowrap 下 get_minimum_size 只返回换行约束宽（460→230），须临时关 autowrap 量单行真实宽
	var _prev_wrap: TextServer.AutowrapMode = lab.autowrap_mode
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	var _nat := lab.get_minimum_size()
	lab.autowrap_mode = _prev_wrap
	var _sm := sub.get_minimum_size()
	var _wrap_w := clampf(maxf(_nat.x, _sm.x), 0.0, _MAX_W)
	lab.custom_minimum_size = Vector2(_wrap_w, 0)   # 设定换行宽度，高度自适应
	var _lm := lab.get_minimum_size()
	var _inner_w: float
	var _inner_h: float
	if _lm.y > 1.0:
		_inner_w = maxf(_wrap_w, _sm.x)
		_inner_h = _lm.y + _sm.y + 2.0
	else:
		# 字体未就绪（极少见，如 headless 首帧）回退字符估算
		var _nl := float(str(nd.get("label", "")).length())
		_inner_w = clampf(maxf(_base_w, 30.0 + _nl * 28.0), _base_w, _MAX_W)
		_inner_h = _base_h
	var _nw := clampf(_inner_w + 18.0, _base_w, _MAX_W + 18.0)
	var _nh := _inner_h + 12.0
	card.custom_minimum_size = Vector2(_nw, _nh)
	card.size = Vector2(_nw, _nh)

	var id: String = nd.id
	var kind2: String = nd.kind
	card.gui_input.connect(_on_node_gui.bind(id, kind2))
	card.mouse_entered.connect(_on_node_hover.bind(id, true))
	card.mouse_exited.connect(_on_node_hover.bind(id, false))
	card.tooltip_text = _node_tooltip(nd)
	return card


## 节点是否有「玩家手动建立的关系」（仅玩家关系，不含自动推断边）
func _node_has_user_relation(id: String) -> bool:
	for r in _relations:
		if r.get("from", "") == id or r.get("to", "") == id:
			return true
	return false


func _node_tooltip(nd: Dictionary) -> String:
	match nd.kind:
		"clue":
			var c: Dictionary = nd.data
			var who := "未知"
			var rns: Array = c.get("related_npcs", [])
			if not rns.is_empty():
				who = "、".join(rns.map(func(p): return _person_name(p)))
			return "线索：%s\n%s\n和谁有关：%s" % [c.get("name", ""), c.get("desc", ""), who]
		"hypo":
			return "推断：%s" % [nd.data.get("text", "")]
		"person":
			return "焦点人物：%s" % [nd.label]
		"chain":
			return "推理链：%s" % [nd.label]
		"conclusion":
			return "当前结论：%s" % [nd.label]
	return ""


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
func _on_edge_draw() -> void:
	var _fh: Dictionary = _compute_hidden()
	for e in _edge_list:
		var a: Vector2 = _node_center.get(e.from, Vector2.ZERO)
		var b: Vector2 = _node_center.get(e.to, Vector2.ZERO)
		if a == Vector2.ZERO or b == Vector2.ZERO: continue
		if _fh.has(e.from) or _fh.has(e.to): continue
		var show := false
		if e.always:
			show = true
		elif _mode == ViewMode.MODE_B:
			show = true
		elif _highlight_id != "" and (e.from == _highlight_id or e.to == _highlight_id):
			show = true
		if not show:
			continue
		if e.kind in ["relate", "imply", "support", "oppose", "contradict"]:
			if e.dashed:
				_draw_arc_dashed(a, b, e.color, 2)
			else:
				_draw_arc_line(a, b, e.color, 3)

	# 拖拽预览线（弧线）
	if _dragging and _drag_id != "":
		var a3: Vector2 = _node_center.get(_drag_id, Vector2.ZERO)
		if a3 != Vector2.ZERO:
			if _drag_mode == "edge":
				_draw_arc_line(a3, _drag_preview_pos(), _rel_color(_drag_kind), 2, 40.0)
			elif _drag_mode == "move":
				# move 模式不画预览线
				pass

	# 选中边高亮（点击连线后明显的视觉反馈，覆盖在普通边之上）
	if _selected_edge >= 0 and _selected_edge < _edge_list.size():
		var se: Dictionary = _edge_list[_selected_edge]
		var sa: Vector2 = _node_center.get(se.get("from", ""), Vector2.ZERO)
		var sb: Vector2 = _node_center.get(se.get("to", ""), Vector2.ZERO)
		if sa != Vector2.ZERO and sb != Vector2.ZERO:
			_draw_arc_line(sa, sb, COL_GOLD, 7, 55.0)


## 沿 a→b 画一条二次贝塞尔弧线（控制点偏移中点垂直方向 curvature）
func _draw_arc_line(a: Vector2, b: Vector2, col: Color, w: float, curvature: float = 50.0, segments: int = 24) -> void:
	if (a - b).length() < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * curvature
	var ctrl: Vector2 = mid + perp
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		var p: Vector2 = a * omt * omt + ctrl * 2.0 * omt * t + b * t * t
		pts.append(p)
	_edge_layer.draw_polyline(pts, col, w, true)


## 沿 a→b 画虚线弧线（沿贝塞尔采样，按 dash 长度切段）
func _draw_arc_dashed(a: Vector2, b: Vector2, col: Color, w: float, curvature: float = 50.0, segments: int = 48, dash_len: float = 8.0, gap_len: float = 6.0) -> void:
	if (a - b).length() < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * curvature
	var ctrl: Vector2 = mid + perp
	# 先采样出所有曲线点
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		var p: Vector2 = a * omt * omt + ctrl * 2.0 * omt * t + b * t * t
		pts.append(p)
	# 沿线段累积长度，按 dash/gap 切段画
	var traveled: float = 0.0
	var next_break: float = dash_len
	var drawing := true
	for i in range(1, pts.size()):
		var p0: Vector2 = pts[i - 1]
		var p1: Vector2 = pts[i]
		var seg_len: float = p0.distance_to(p1)
		var t0: float = traveled
		var t1: float = traveled + seg_len
		while t1 >= next_break:
			if drawing:
				var k: float = (next_break - t0) / seg_len
				_edge_layer.draw_line(p0.lerp(p1, clamp(k, 0.0, 1.0)), p1, col, w)
				t0 = next_break
				drawing = false
				next_break += gap_len
			else:
				t0 = next_break
				drawing = true
				next_break += dash_len
		if drawing and i + 1 < pts.size():
			_edge_layer.draw_line(p0.lerp(p1, clamp((t1 - t0) / seg_len, 0.0, 1.0)), p0.lerp(p1, 1.0), col, w)
		traveled = t1


## 旧的直线虚线（保留兼容，未再使用）
func _draw_dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dist: float = a.distance_to(b)
	var dash: float = 10.0; var gap: float = 7.0; var seg: float = dash + gap
	if seg <= 0: return
	var steps: int = int(dist / seg)
	var dir: Vector2 = (b - a).normalized()
	var pos: Vector2 = a
	for i in steps:
		var p2: Vector2 = pos + dir * dash
		if p2.distance_to(a) > dist: p2 = b
		_edge_layer.draw_line(pos, p2, col, w)
		pos = p2 + dir * gap
	if pos.distance_to(b) > 1.0:
		_edge_layer.draw_line(pos, b, col, w)


## 沿 a→b 画虚线弧线（沿贝塞尔采样，按 dash 长度切段）


func _drag_preview_pos() -> Vector2:
	if _canvas and is_instance_valid(_canvas) and get_viewport():
		return _canvas.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	return Vector2.ZERO


## 拖动带子树的节点时先折叠子树（先折叠后移动）：移动只带该节点本身，避免整棵子树跟移。
func _fold_subtree_for_drag(id: String) -> void:
	if _state != State.EDITABLE: return
	var subs := _subtree_ids(id)
	if subs.is_empty() and not _folded_nodes.has(id):
		return
	call_deferred("_apply_fold_subtree", id, subs)


## BFS 沿连接收集本节点（kind 更深）的整棵子树 id（不含 id 自身），与 _relation_tree_layout 同款方向判据。
func _subtree_ids(id: String) -> Array:
	var res: Array = []
	var adj := _build_adjacency()
	var d0: int = _ring_depth(_kind_of(id))
	var q: Array = [id]
	var seen := {id: true}
	while q.size() > 0:
		var u: String = q.pop_front()
		for nb in adj.get(u, []):
			if seen.has(nb): continue
			var d1: int = _ring_depth(_kind_of(nb))
			if d1 <= d0: continue
			seen[nb] = true
			res.append(nb)
			q.append(nb)
	return res


## deferred：折叠子树（含本体），重排后拖动只体现该节点本身；可经节点折叠控件展开。
func _apply_fold_subtree(id: String, subs: Array) -> void:
	if not is_inside_tree(): return
	if not _folded_nodes.has(id): _folded_nodes[id] = true
	for s in subs:
		_folded_nodes[s] = true
	_state_store["graph_folded_nodes"] = _folded_nodes
	_persist_view()
	_rebuild_graph()


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
				_drag_kind = key_to_kind(_pen_color_key)
				_drag_color_key = _pen_color_key
				_drag_dashed = _pen_dashed
				_drag_from = get_viewport().get_mouse_position()
			else:
				# 纯左键拖动 = 移动节点
				_drag_mode = "move"
				_drag_offset = mouse_canvas - n.position
				_drag_start = get_viewport().get_mouse_position()
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
		else:
			_toast_msg("只能把线索拖到人物头像建关联")
		_connect_first_id = ""
		_connect_first_kind = ""
		_redraw_all()
		return true
	if first_kind == "person":
		if kind == "clue":
			_tag_person(id, _connect_first_id)
			_toast_msg("已为线索打上人物标签")
		else:
			_toast_msg("只能把线索拖到人物头像建关联")
		_connect_first_id = ""
		_connect_first_kind = ""
		_redraw_all()
		return true
	# 节点 → 节点：建证据连线；若两节点间已有连线则反向删除（连线模式快捷取消，问题1 补充）
	var kind_str: String = key_to_kind(_pen_color_key)
	var existing: Array = _relations_between(_connect_first_id, id)
	if existing.is_empty():
		_add_edge(_connect_first_id, id, kind_str, _pen_color_key, _pen_dashed)
	else:
		var total: int = existing.size()
		for r in existing:
			_remove_edge(r.get("from", ""), r.get("to", ""), r.get("kind", "relate"))
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
func _commit_move(id: String, at: Vector2 = Vector2.INF) -> void:
	var gp: Vector2 = get_viewport().get_mouse_position() if at == Vector2.INF else at
	var moved := gp.distance_to(_drag_start) > 8.0
	if moved and _state == State.EDITABLE:
		var drop: String = _drop_node_except(gp, id)
		if drop == "":
			# 容错：未精确落在目标框内时，找 48px 内最近的节点（差几个像素也要能建边）
			drop = _nearest_node_except(gp, id, 48.0)
		if drop != "":
			var drop_kind: String = _node_kind.get(drop, "")
			if drop_kind == "person":
				_tag_person(id, drop)
			elif drop_kind in ["hypo", "clue", "conclusion"]:
				_add_edge(id, drop, key_to_kind(_pen_color_key), _pen_color_key, _pen_dashed)
		if moved:
			if not _manual_nodes.has(id):
				_manual_nodes.append(id)
			_state_store["graph_manual_nodes"] = _manual_nodes
	elif not moved:
		_on_node_clicked(id, _node_kind.get(id, ""))
	_persist_node_positions()
	_dragging = false
	_drag_id = ""
	_drag_mode = ""
	_sync_fold_controls_positions()
	_redraw_all()


## 查找 gp 处命中的节点，排除 exclude_id（拖动中被拖节点自身可能压住目标）
func _drop_node_except(gp: Vector2, exclude_id: String) -> String:
	var local := _canvas.get_global_transform().affine_inverse() * gp
	for id in _node_views:
		if id == exclude_id: continue
		var n: Control = _node_views[id]
		if not is_instance_valid(n): continue
		if Rect2(n.position, n.size).has_point(local):
			return id
	return ""


## 找距离 gp 最近且不超过 max_dist 的节点（排除 exclude_id）
func _nearest_node_except(gp: Vector2, exclude_id: String, max_dist: float) -> String:
	var local := _canvas.get_global_transform().affine_inverse() * gp
	var best := ""
	var best_d := max_dist
	for id in _node_views:
		if id == exclude_id: continue
		var n: Control = _node_views[id]
		if not is_instance_valid(n): continue
		var c := n.position + n.size * 0.5
		var d := c.distance_to(local)
		if d < best_d:
			best_d = d
			best = id
	return best


## 提交建边（拖到另一节点上 = 加证据连线；落空 = 取消）
func _commit_drag(id: String) -> void:
	var gp: Vector2 = get_viewport().get_mouse_position()
	var drop: String = _node_at(gp)
	_dragging = false
	_drag_id = ""
	_drag_mode = ""
	_redraw_all()
	if drop == "" or drop == id:
		if drop == id:
			_on_node_clicked(id, _node_kind.get(id, ""))
		return
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	var drop_kind: String = _node_kind.get(drop, "")
	if drop_kind == "person":
		_tag_person(id, drop)
	elif drop_kind in ["hypo", "clue", "conclusion"]:
		_add_edge(id, drop, _drag_kind, _drag_color_key, _drag_dashed)
	else:
		_on_node_clicked(id, _node_kind.get(id, ""))


func _node_at(gp: Vector2) -> String:
	# 把全局坐标转画布本地，命中节点包围盒
	for id in _node_views:
		var n: Control = _node_views[id]
		if not is_instance_valid(n): continue
		var local := _canvas.get_global_transform().affine_inverse() * gp
		if Rect2(n.position, n.size).has_point(local):
			return id
	return ""


func _on_node_clicked(id: String, kind: String) -> void:
	if kind == "chain":
		_switch_mode(ViewMode.MODE_B)
		return
	_show_detail(id, kind)


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
		return _person_name(id)
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
	var clue: Dictionary = _find_clue(clue_id)
	if clue.is_empty(): return
	var rns: Array = clue.get("related_npcs", [])
	if rns.has(person_id):
		_toast_msg("这条线索已和%s有关" % _person_name(person_id))
		return
	_undo.create_action("tag_person")
	_undo.add_do_method(_do_tag.bind(clue_id, person_id, true))
	_undo.add_undo_method(_do_tag.bind(clue_id, person_id, false))
	_undo.commit_action()
	if _cb_tag.is_valid():
		_cb_tag.call(clue_id, person_id)
	_persist_view()
	_rebuild_graph()
	_toast_msg("已为线索「%s」打上%s标签" % [clue.get("name", clue_id), _person_name(person_id)])


func _do_tag(clue_id: String, person_id: String, add: bool) -> void:
	var clue: Dictionary = _find_clue(clue_id)
	if clue.is_empty(): return
	var rns: Array = clue.get("related_npcs", [])
	if add and not rns.has(person_id):
		rns.append(person_id)
	elif not add:
		rns.erase(person_id)
	clue["related_npcs"] = rns


func _add_edge(from: String, to: String, kind: String, color_key: String = "", dashed: bool = false) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	if from == to:
		_toast_msg("线索不能指向自己")
		return
	if color_key == "":
		color_key = kind_to_key(kind)
	for r in _relations:
		if r.from == from and r.to == to and r.kind == kind:
			_toast_msg("这条证据连线已存在")
			return
	_undo.create_action("add_edge")
	_undo.add_do_method(_do_edge.bind(from, to, kind, color_key, dashed, true))
	_undo.add_undo_method(_do_edge.bind(from, to, kind, color_key, dashed, false))
	_undo.commit_action()
	if _id_is_clue(from):
		_mark_clue_placed(from)
	if _id_is_clue(to):
		_mark_clue_placed(to)
	if _cb_relations_changed.is_valid():
		_cb_relations_changed.call(_relations.duplicate())
	_persist_view()
	_rebuild_graph()
	_toast_msg("建立了%s的证据连线" % _rel_verb(kind))


func _rel_verb(kind: String) -> String:
	match kind:
		"support": return VERB_SUPPORT
		"oppose": return VERB_OPPOSE
		"contradict": return VERB_CONTRADICT
		_: return VERB_RELATE


## 两节点间已存在的玩家连线（不分方向，同对节点可能有多条不同 kind，如 support+contradict）
func _relations_between(a: String, b: String) -> Array:
	var out := []
	for r in _relations:
		var f: String = r.get("from", "")
		var t: String = r.get("to", "")
		if (f == a and t == b) or (f == b and t == a):
			out.append(r)
	return out

## 线索是否参与了任意玩家连线（用于把被拖拽关联、但本身未挂焦点人物的线索也纳入星型视图）
func _clue_has_relation(cid: String) -> bool:
	for r in _relations:
		if r.get("from", "") == cid or r.get("to", "") == cid:
			return true
	return false


func _id_is_clue(cid: String) -> bool:
	for c in _clues:
		if c.get("id", "") == cid:
			return true
	return false


func _clue_by_id(cid: String) -> Dictionary:
	for c in _clues:
		if c.get("id", "") == cid:
			return c
	return {}


func _clue_placed(cid: String) -> bool:
	return cid in _placed_clues


func _mark_clue_placed(cid: String) -> void:
	if cid in _placed_clues:
		return
	_placed_clues.append(cid)
	if not _state_store.is_empty():
		_state_store["graph_placed_clues"] = _placed_clues.duplicate()


func _unmark_clue_placed(cid: String) -> void:
	if cid not in _placed_clues:
		return
	_placed_clues.erase(cid)
	if not _state_store.is_empty():
		_state_store["graph_placed_clues"] = _placed_clues.duplicate()

## 左栏拖入图谱时的公开入口：把一条尚未放置的线索放入图谱。
## drop_at 为抬起落点的 viewport 坐标；若恰好命中图上一个节点（推断/结论/线索），
## 在放置该线索的同时自动与之建立绿实线 support 关系（对应需求「拖线索1到推理1默认建实线绿色关系」）。
func place_clue(cid: String, drop_at: Vector2 = Vector2(-1, -1)) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	if _clue_placed(cid):
		return
	if drop_at.x >= 0.0:
		var hit: String = _drop_node_except(drop_at, cid)
		var hk: String = _node_kind.get(hit, "")
		if hit != "" and hk in ["hypo", "clue", "conclusion"]:
			_add_edge(cid, hit, "support", "green", false)
			_persist_view()
			_rebuild_graph()
			_toast_msg("线索已放入图谱并与目标建立支持关系")
			return
	_mark_clue_placed(cid)
	_persist_view()
	_rebuild_graph()
	_toast_msg("线索已放入图谱（详情卡可移除归还）")

func _unplace_clue_from_graph(cid: String, card: Control) -> void:
	if _state != State.EDITABLE:
		return
	var doomed: Array[Dictionary] = []
	for r in _relations:
		if r.get("from", "") == cid or r.get("to", "") == cid:
			doomed.append(r)
	_unmark_clue_placed(cid)
	for r in doomed:
		_remove_edge(r.get("from", ""), r.get("to", ""), r.get("kind", "relate"))
	if is_instance_valid(card):
		card.queue_free()
	if _state_store.has("graph_placed_clues"):
		_state_store["graph_placed_clues"] = _placed_clues.duplicate()
	# 让左栏「已收集线索」即时恢复该线索（孤立线索无关系边时也需刷新）
	if _cb_relations_changed.is_valid():
		_cb_relations_changed.call(_relations.duplicate())
	_persist_view()
	_rebuild_graph()
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
func _remove_edge(from: String, to: String, kind: String) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	var target := {}
	for r in _relations:
		if r.get("from", "") == from and r.get("to", "") == to and r.get("kind", "") == kind:
			target = r
			break
	if target.is_empty():
		_toast_msg("没有这条连线")
		return
	var ck: String = target.get("color_key", "")
	var ds: bool = target.get("dashed", false)
	_undo.create_action("remove_edge")
	_undo.add_do_method(_do_edge.bind(from, to, kind, ck, ds, false))
	_undo.add_undo_method(_do_edge.bind(from, to, kind, ck, ds, true))
	_undo.commit_action()
	if _cb_relations_changed.is_valid():
		_cb_relations_changed.call(_relations.duplicate())
	_persist_view()
	_rebuild_graph()
	_toast_msg("已删除%s的连线（Ctrl+Z 可恢复）" % _rel_verb(kind))


func _do_edge(from: String, to: String, kind: String, color_key: String, dashed: bool, add: bool) -> void:
	var kept := []
	for r in _relations:
		if not (r.from == from and r.to == to and r.kind == kind):
			kept.append(r)
	if add:
		kept.append({"from": from, "to": to, "kind": kind, "color_key": color_key, "dashed": dashed})
	_relations = kept
	# 同步线索 associated 标记 → 节点实线绿边（已关联视觉反馈），无连线则复位
	_sync_clue_associated()


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
	_emit_pen_changed()


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
	if id == "" or _is_leaf(id): return false
	var label: String = _node_short_label(id)
	var will_fold := not _folded_nodes.has(id)
	if _state == State.EDITABLE:
		_undo.create_action("折叠 %s" % label)
		_undo.add_do_method(_set_folded.bind(id, will_fold))
		_undo.add_undo_method(_set_folded.bind(id, not will_fold))
		_undo.commit_action()
	else:
		_set_folded(id, will_fold)
	_persist_view()
	if will_fold:
		_toast_msg("已折叠「%s」的外层内容（%d 项）" % [label, _fold_count(id)])
	else:
		_toast_msg("已展开「%s」" % label)
	return will_fold

## 顶部 🪗 按钮：折叠当前悬停/高亮节点（非叶子则优先），否则折叠焦点人物（保留旧行为）
func toggle_fold_focus() -> bool:
	if _focus_person == "": return false
	var id: String = _focus_person
	if _highlight_id != "" and not _is_leaf(_highlight_id):
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
	md += "- 焦点人物：%s\n" % _person_name(_focus_person)
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
	_export_panel = Panel.new()
	_export_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_export_panel.size = Vector2(800, 500)
	_export_panel.position = Vector2(240, 110)
	_export_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.10, 0.98)
	sb.border_color = COL_GOLD
	sb.border_width_left = 2; sb.border_width_right = 2; sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(8)
	_export_panel.add_theme_stylebox_override("panel", sb)
	add_child(_export_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12; vb.offset_right = -12; vb.offset_top = 12; vb.offset_bottom = -12
	_export_panel.add_child(vb)
	var title := Label.new()
	title.text = "📤 导出（可复制）"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(title)
	var edit := TextEdit.new()
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.text = text
	edit.wrap_enabled = true
	edit.select_all()
	vb.add_child(edit)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): _export_panel.queue_free(); _export_panel = null)
	vb.add_child(close_btn)


func undo() -> void:
	_on_undo()


func redo() -> void:
	_on_redo()


# ===================== 浮层线索栏（左侧，可收缩）=====================
func _create_clue_dock() -> void:
	_dock = Control.new()
	_dock.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_dock.offset_top = 64
	_dock.offset_bottom = -44
	_dock.offset_right = 26 if _dock_collapsed else 340
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.z_index = 5
	add_child(_dock)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.06, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(bg)

	_dock_toggle_btn = Button.new()
	_dock_toggle_btn.text = "›" if _dock_collapsed else "‹"
	_dock_toggle_btn.add_theme_font_size_override("font_size", 30)
	_dock_toggle_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_dock_toggle_btn.custom_minimum_size = Vector2(44, 48)
	_dock_toggle_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_dock_toggle_btn.offset_right = -6; _dock_toggle_btn.offset_left = -52
	_dock_toggle_btn.offset_top = 4; _dock_toggle_btn.offset_bottom = 32
	_dock_toggle_btn.pressed.connect(_on_dock_toggle)
	_dock.add_child(_dock_toggle_btn)

	var title := Label.new()
	title.text = "已收集线索"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 10; title.offset_top = 8; title.offset_right = -44; title.offset_bottom = 58
	title.visible = not _dock_collapsed
	_dock.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 62; scroll.offset_bottom = -8; scroll.offset_left = 6; scroll.offset_right = -6
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.visible = not _dock_collapsed
	_dock.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	_dock_list = vb

	_refresh_dock()


func _refresh_dock() -> void:
	if not _dock_list: return
	for c in _dock_list.get_children(): c.queue_free()
	_dock_cards = {}
	for c in _clues:
		var card := _make_dock_clue_card(c)
		_dock_list.add_child(card)
		_dock_cards[c.get("id", "")] = card


func _make_dock_clue_card(clue: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.28, 0.08, 0.95)
	s.border_color = Color(0.2, 0.8, 0.2)
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", s)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	var name := Label.new()
	name.text = clue.get("name", clue.get("id", "?"))
	name.add_theme_font_size_override("font_size", 40)
	name.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name)
	var sub := Label.new()
	sub.text = "拖入图谱建立关系"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", COL_GREY)
	vb.add_child(sub)
	var cid: String = clue.get("id", "")
	card.gui_input.connect(_on_dock_card_gui.bind(cid))
	card.tooltip_text = clue.get("desc", "")
	return card


func _on_dock_card_gui(event: InputEvent, cid: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _state != State.EDITABLE:
			_toast_msg("已封存，仅可浏览")
			return
		_dock_dragging = true
		_dock_clue_id = cid
		_dock_moved = false
		_dock_start = get_viewport().get_mouse_position()
		_make_dock_preview(cid)
		# 声明吃掉这次按下：防止 dock 所在 ScrollContainer 把按下当成滚动起点而抢走后续拖动，
		# 否则「左侧线索拖不进图谱」（Bug3）。
		get_viewport().set_input_as_handled()


func _on_dock_drop() -> void:
	_dock_dragging = false
	var cid := _dock_clue_id
	_dock_clue_id = ""
	_clear_dock_preview()
	if not _dock_moved:
		return
	var gp := get_viewport().get_mouse_position()
	if _dock and is_instance_valid(_dock) and _dock.get_global_rect().has_point(gp):
		return   # 落回线索栏内，视为取消
	_open_link_suggestions(cid)


func _make_dock_preview(cid: String) -> void:
	_clear_dock_preview()
	var clue: Dictionary = _find_clue(cid)
	var prev := PanelContainer.new()
	prev.custom_minimum_size = Vector2(300, 100)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.30, 0.10, 0.95)
	s.border_color = COL_GOLD
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	prev.add_theme_stylebox_override("panel", s)
	var lab := Label.new()
	lab.text = clue.get("name", cid)
	lab.add_theme_font_size_override("font_size", 40)
	lab.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	prev.add_child(lab)
	prev.z_index = 40
	# 纯视觉预览：设为 IGNORE，绝不作为命中控件拦截松开事件（否则拖到图谱上松手可能被预览本身吃掉）
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prev)
	_dock_preview = prev
	_move_dock_preview(get_viewport().get_mouse_position())


func _move_dock_preview(gp: Vector2) -> void:
	if _dock_preview and is_instance_valid(_dock_preview):
		_dock_preview.position = gp - _dock_preview.size * 0.5


func _clear_dock_preview() -> void:
	if _dock_preview and is_instance_valid(_dock_preview):
		_dock_preview.queue_free()
	_dock_preview = null


func _on_dock_toggle() -> void:
	_dock_collapsed = not _dock_collapsed
	if _dock and is_instance_valid(_dock):
		_dock.offset_right = 26 if _dock_collapsed else 340
	if _dock_toggle_btn and is_instance_valid(_dock_toggle_btn):
		_dock_toggle_btn.text = "›" if _dock_collapsed else "‹"
	var title_child: Array = _dock.get_children().filter(func(c): return c is Label)
	for t in title_child: t.visible = not _dock_collapsed
	if _dock_list and is_instance_valid(_dock_list):
		# 滚动容器是 _dock_list 的父节点
		var sc := _dock_list.get_parent()
		if sc and is_instance_valid(sc): sc.visible = not _dock_collapsed


# ===================== 「推断/结论」建议弹窗 =====================
func _open_link_suggestions(cid: String) -> void:
	_close_link_popup()
	_link_popup_clue_id = cid
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 25
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 560)
	panel.position = (get_viewport_rect().size - Vector2(440, 380)) * 0.5
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = COL_GOLD
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	var t := Label.new()
	t.text = "把线索「%s」连到：" % _find_clue(cid).get("name", cid)
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(t)

	var pen_row := HBoxContainer.new()
	vb.add_child(pen_row)
	pen_row.add_child(_mk_pen_label("线型"))
	var solid := _mk_pen_btn("实线", not _pen_dashed, Color(0.8, 0.8, 0.8))
	solid.pressed.connect(func(): _set_pen_dashed(false))
	pen_row.add_child(solid)
	var dashed := _mk_pen_btn("虚线", _pen_dashed, COL_GREY)
	dashed.pressed.connect(func(): _set_pen_dashed(true))
	pen_row.add_child(dashed)

	var col_row := HBoxContainer.new()
	vb.add_child(col_row)
	col_row.add_child(_mk_pen_label("性质"))
	var keys := ["green", "orange", "red", "grey"]
	var labels := ["支持", "矛盾存疑", "反对", "弱关联"]
	for i in keys.size():
		var b := _mk_pen_btn(labels[i], _pen_color_key == keys[i], color_from_key(keys[i]))
		var k: String = keys[i]
		b.pressed.connect(func(): _set_pen_color(k))
		col_row.add_child(b)

	var sep := HSeparator.new()
	vb.add_child(sep)
	var hint := Label.new()
	hint.text = "选择要连接的目标："
	hint.add_theme_font_size_override("font_size", 40)
	hint.add_theme_color_override("font_color", COL_GREY)
	vb.add_child(hint)

	var pname: String = _person_name(_focus_person)
	var pb := _mk_link_target("★ %s（星型归属）" % pname)
	pb.pressed.connect(func(): _confirm_link(cid, _focus_person, "person"))
	vb.add_child(pb)
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		var hb := _mk_link_target("推断：%s" % h.get("text", h.get("id", "?")))
		var hid: String = h.get("id", "")
		hb.pressed.connect(func(): _confirm_link(cid, hid, "hypo"))
		vb.add_child(hb)
	var cb := _mk_link_target("结论：%s" % _verdict_text())
	cb.pressed.connect(func(): _confirm_link(cid, "conclusion", "conclusion"))
	vb.add_child(cb)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(_close_link_popup)
	vb.add_child(cancel)

	add_child(popup)
	_link_popup = popup


func _close_link_popup() -> void:
	if _link_popup and is_instance_valid(_link_popup):
		_link_popup.queue_free()
		_link_popup = null


func _confirm_link(cid: String, target_id: String, kind_hint: String) -> void:
	_close_link_popup()
	if target_id == "" or target_id == cid: return
	if kind_hint == "person":
		_tag_person(cid, target_id)
	else:
		var kind: String = key_to_kind(_pen_color_key)
		_add_edge(cid, target_id, kind, _pen_color_key, _pen_dashed)


func _mk_pen_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", COL_GREY)
	l.custom_minimum_size = Vector2(60, 44)
	return l


func _mk_pen_btn(t: String, active: bool, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.button_pressed = active
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", col if active else COL_GOLD_LIGHT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.20, 0.12, 0.95) if active else Color(0.14, 0.12, 0.08, 0.95)
	s.border_color = col if active else Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", s)
	b.custom_minimum_size = Vector2(110, 44)
	return b


func _mk_link_target(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(560, 52)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.13, 0.08, 0.95)
	s.border_color = Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", s)
	return b


func _set_pen_color(key: String) -> void:
	_pen_color_key = key
	_emit_pen_changed()
	_refresh_link_popup_pen()


func _set_pen_dashed(d: bool) -> void:
	_pen_dashed = d
	_emit_pen_changed()
	_refresh_link_popup_pen()


func _emit_pen_changed() -> void:
	if _cb_pen_changed.is_valid():
		_cb_pen_changed.call(_pen_color_key, _pen_dashed)


func _refresh_link_popup_pen() -> void:
	if _link_popup and is_instance_valid(_link_popup):
		var cid := _link_popup_clue_id
		_close_link_popup()
		_open_link_suggestions(cid)


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
	var ei := _edge_hit_test(lp)
	if ei >= 0:
		_select_edge(ei, viewport_pos)
	else:
		_selected_edge = -1
		_close_edge_menu()
	_redraw_all()

func _bezier(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + ctrl * 2.0 * u * t + b * t * t

func _edge_hit_test(lp: Vector2) -> int:
	var best := -1
	var best_d := 16.0
	for ei in _edge_list.size():
		var e: Dictionary = _edge_list[ei]
		var a: Vector2 = _node_center.get(e.get("from", ""), Vector2(-1e6, -1e6))
		var b: Vector2 = _node_center.get(e.get("to", ""), Vector2(-1e6, -1e6))
		if a.x < -1e5 or b.x < -1e5:
			continue
		var mid := (a + b) / 2.0
		var delta := b - a
		var perp := Vector2(-delta.y, delta.x).normalized() * 50.0
		var ctrl := mid + perp
		var dmin := 1e9
		var t := 0.0
		while t <= 1.0:
			var p := _bezier(a, ctrl, b, t)
			var d := lp.distance_to(p)
			if d < dmin:
				dmin = d
			t += 0.01
		if dmin < best_d:
			best_d = dmin
			best = ei
	return best

func _select_edge(ei: int, viewport_pos: Vector2) -> void:
	_selected_edge = ei
	_show_edge_menu(viewport_pos, _edge_list[ei])
	_toast_msg("已选中连线")

func _show_edge_menu(viewport_pos: Vector2, e: Dictionary) -> void:
	_close_edge_menu()
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var lab := Label.new()
	lab.text = "连线：%s → %s（%s）" % [e.get("from", ""), e.get("to", ""), _rel_verb(e.get("kind", ""))]
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lab)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var b_del := _mk_menu_btn("✕  删除连线")
	b_del.pressed.connect(func() -> void: _edge_delete(e))
	vbox.add_child(b_del)
	var b_dash := _mk_menu_btn("⊸  线型切换")
	b_dash.pressed.connect(func() -> void: _edge_toggle_dashed(e))
	vbox.add_child(b_dash)
	var b_kind := _mk_menu_btn("↻  性质切换")
	b_kind.pressed.connect(func() -> void: _edge_cycle_kind(e))
	vbox.add_child(b_kind)
	panel.add_child(vbox)
	panel.position = viewport_pos + Vector2(8, 8)
	add_child(panel)
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var lp := (get_global_mouse_position() - _canvas.position) / _canvas.scale
			if _edge_hit_test(lp) != _selected_edge:
				_selected_edge = -1
				_close_edge_menu()
			_redraw_all()
	)
	_edge_menu = panel

func _mk_menu_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(180, 30)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func _close_edge_menu() -> void:
	if _edge_menu and is_instance_valid(_edge_menu):
		_edge_menu.queue_free()
	_edge_menu = null

func _edge_delete(e: Dictionary) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	_remove_edge(e.get("from", ""), e.get("to", ""), e.get("kind", ""))
	_close_edge_menu()
	_selected_edge = -1
	_toast_msg("连线已删除")

func _edge_toggle_dashed(e: Dictionary) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	var from: String = e.get("from", "")
	var to: String = e.get("to", "")
	var kind: String = e.get("kind", "")
	var new_dash: bool = not bool(e.get("dashed", false))
	_undo.create_action("toggle_edge_dashed")
	_undo.add_do_method(_do_set_dashed.bind(from, to, kind, new_dash))
	_undo.add_undo_method(_do_set_dashed.bind(from, to, kind, not new_dash))
	_undo.commit_action()
	_close_edge_menu()
	if _cb_relations_changed.is_valid():
		_cb_relations_changed.call(_relations.duplicate())
	_persist_view()
	_rebuild_graph()
	_toast_msg("线型已切换")

func _do_set_dashed(from: String, to: String, kind: String, dashed: bool) -> void:
	for r in _relations:
		if r.from == from and r.to == to and r.kind == kind:
			r["dashed"] = dashed
			break

func _edge_cycle_kind(e: Dictionary) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	var KINDS: Array[String] = ["relate", "support", "oppose", "contradict"]
	var from: String = e.get("from", "")
	var to: String = e.get("to", "")
	var old_kind: String = e.get("kind", "relate")
	var idx: int = KINDS.find(old_kind)
	var new_kind: String = KINDS[(idx + 1) % KINDS.size()]
	var dashed: bool = e.get("dashed", false)
	_undo.create_action("change_edge_kind")
	_undo.add_do_method(_do_change_edge_kind.bind(from, to, old_kind, dashed, new_kind))
	_undo.add_undo_method(_do_change_edge_kind.bind(from, to, new_kind, dashed, old_kind))
	_undo.commit_action()
	_close_edge_menu()
	if _cb_relations_changed.is_valid():
		_cb_relations_changed.call(_relations.duplicate())
	_persist_view()
	_rebuild_graph()
	_toast_msg("连线性质已切换为 %s" % _rel_verb(new_kind))

func _do_change_edge_kind(from: String, to: String, old_kind: String, dashed: bool, new_kind: String) -> void:
	var changed := false
	for r in _relations:
		if r.from == from and r.to == to and r.kind == old_kind:
			r["kind"] = new_kind
			r["dashed"] = dashed
			r["color_key"] = kind_to_key(new_kind)
			changed = true
			break
	if not changed:
		_relations.append({"from": from, "to": to, "kind": new_kind, "color_key": kind_to_key(new_kind), "dashed": dashed})

func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var old_scale := _zoom
	var ns: float = clamp(old_scale * factor, 0.4, 2.5)
	# 全局坐标 → 画布本地（含 _clip 偏移），与 _on_canvas_left_click 一致
	var lp := _canvas.get_global_transform().affine_inverse() * mouse_pos
	_canvas.scale = Vector2(ns, ns)
	_canvas.position = mouse_pos - lp * ns
	_zoom = ns

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
	ns = clamp(ns, 0.35, 1.6)
	_canvas.scale = Vector2(ns, ns)
	var center_gl := _canvas.get_global_transform().affine_inverse() * (minp + bbox * 0.5)
	_canvas.position = -center_gl * ns + _clip.get_global_transform().origin + vp * 0.5
	_zoom = ns


# ===================== 顶部栏动作 =====================
func _switch_mode(m: int) -> void:
	if m == ViewMode.MODE_A or m == ViewMode.MODE_D:
		return
	if m == _mode: return
	# 先落盘「旧模式」状态再切换：_persist_node_positions 按旧 _mode 判定（仅 MODE_C 写盘），
	# 避免把 MODE_B 的临时分层坐标覆盖进星型存档 → 切回/重进位置错乱（问题2）。
	_persist_view()
	_mode = m
	_rebuild_graph()
	_refresh_toolbar_state()


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
func _detail_title_text(id: String, kind: String) -> String:
	if _edited_texts.has(id):
		return str(_edited_texts[id])
	if kind == "clue":
		return str(_node_data.get(id, {}).get("name", id))
	if kind == "hypo":
		return str(_node_data.get(id, {}).get("text", ""))
	if kind == "person":
		return _person_name(id)
	if kind == "chain":
		return str(_node_data.get(id, {}).get("label", id))
	return _verdict_text()


# ===================== 详情卡 =====================
func _show_detail(id: String, kind: String) -> void:
	if _detail_card and is_instance_valid(_detail_card):
		_detail_card.queue_free()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 360)
	# 需求1：详情弹窗必须盖过左侧「已收集线索」栏（reasoning_wall 顶层 z=20）。
	# graph_view 整树 z=5，任何子节点都无法超过左栏；故把卡挂到 graph_view 的父
	# （reasoning_wall 顶层），并设 z=30（低于顶栏 100，顶栏仍可点）。
	card.z_index = 30
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	s.border_color = COL_GOLD
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", s)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 150)
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	vb.add_child(body)

	match kind:
		"clue":
			var c: Dictionary = _node_data.get(id, {})
			title.text = "线索：" + c.get("name", id)
			var who := "未知"
			var rns: Array = c.get("related_npcs", [])
			if not rns.is_empty():
				who = "、".join(rns.map(func(p): return _person_name(p)))
			var attr := "其他"
			var at: Array = c.get("attribute_tags", [])
			if not at.is_empty(): attr = at[0]
			body.text = "%s\n和谁有关：%s\n证据属性：%s\n状态：%s" % [
				c.get("desc", ""), who, attr, _clue_sub(c)]
			if _difficulty == Diff.EASY:
				body.text += "\n（福尔摩斯旁白：这条线索值得和%s对一对。）" % who
			if _state == State.EDITABLE:
				var tag_btn := Button.new()
				tag_btn.text = "和谁有关 ▾"
				tag_btn.add_theme_font_size_override("font_size", 26)
				tag_btn.pressed.connect(func(): _open_tag_menu(id, "clue"))
				vb.add_child(tag_btn)
				var status_btn := Button.new()
				status_btn.text = "标记状态 ▾"
				status_btn.add_theme_font_size_override("font_size", 26)
				status_btn.pressed.connect(func(): _open_status_menu(id))
				vb.add_child(status_btn)
				if _clue_placed(id):
					var rmv_btn := Button.new()
					rmv_btn.text = "从图谱移除（归还线索）"
					rmv_btn.add_theme_font_size_override("font_size", 26)
					rmv_btn.pressed.connect(_unplace_clue_from_graph.bind(id, card))
					vb.add_child(rmv_btn)
		"hypo":
			var h: Dictionary = _node_data.get(id, {})
			title.text = "推断：" + h.get("text", id)
			body.text = "这是你正在考虑的其中一种可能性。"
		"person":
			title.text = "焦点人物：" + _person_name(id)
			body.text = "星型中心。把线索拖到此处即可标注它和这个人的关系。"
		"conclusion":
			title.text = "当前结论：" + _verdict_text()
			body.text = "根据你关联的证据与连线实时推算。点「提交验证」可正式结案。"
		"chain":
			title.text = "推理链：" + _node_data.get(id, {}).get("label", id)
			body.text = "点此切换到推理链聚焦视图。"

	# —— 编辑内容（问题2：允许玩家编辑文本框内容）——
	if _state == State.EDITABLE and kind in ["clue", "hypo", "conclusion", "person", "chain"]:
		var edit_lbl := Label.new()
		edit_lbl.text = "编辑内容"
		edit_lbl.add_theme_font_size_override("font_size", 28)
		edit_lbl.add_theme_color_override("font_color", COL_GOLD)
		vb.add_child(edit_lbl)
		var edit_box := TextEdit.new()
		edit_box.custom_minimum_size = Vector2(440, 96)
		edit_box.add_theme_font_size_override("font_size", 24)
		edit_box.text = str(_edited_texts.get(id, _detail_title_text(id, kind)))
		vb.add_child(edit_box)
		var save_btn := Button.new()
		save_btn.text = "保存修改"
		save_btn.add_theme_font_size_override("font_size", 26)
		save_btn.pressed.connect(func():
			var new_text: String = edit_box.text.strip_edges()
			if new_text.is_empty(): return
			_edited_texts[id] = new_text
			_persist_view()
			_rebuild_graph()
			if is_instance_valid(card): card.queue_free())
		vb.add_child(save_btn)

	# —— 连线管理（问题1：取消右键后，删除连线改由此处）：列出本节点参与的全部关系，逐个可删 ——
	var rels := []
	for r in _relations:
		if r.get("from", "") == id or r.get("to", "") == id:
			rels.append(r)
	if _state == State.EDITABLE and not rels.is_empty():
		var sep := HSeparator.new()
		vb.add_child(sep)
		var rel_lbl := Label.new()
		rel_lbl.text = "删除连线（本节点参与）"
		rel_lbl.add_theme_font_size_override("font_size", 40)
		rel_lbl.add_theme_color_override("font_color", COL_GOLD)
		vb.add_child(rel_lbl)
		for r in rels:
			var other: String = r.get("to", "") if r.get("from", "") == id else r.get("from", "")
			var del_btn := Button.new()
			del_btn.text = "✕ 删除：↔ %s（%s）" % [_node_short_label(other), _rel_verb(r.get("kind", "relate"))]
			del_btn.add_theme_font_size_override("font_size", 40)
			del_btn.pressed.connect(_on_detail_delete.bind(
				r.get("from", ""), r.get("to", ""), r.get("kind", "relate"), card))
			vb.add_child(del_btn)

	var close := Button.new()
	close.text = "关闭"
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func(): card.queue_free())
	vb.add_child(close)

	# 需求：详情窗摆到界面「中部偏左 1/4」处，避开顶部功能栏（z=100，高约110px）。
	# 用视口可见矩形定位（卡片挂到 host 后以绝对坐标摆放），不足时回退到固定坐标。
	var view_rect := get_viewport().get_visible_rect()
	if view_rect.size.x > 100.0 and view_rect.size.y > 100.0:
		card.position = Vector2(view_rect.position.x + view_rect.size.x * 0.23,
			view_rect.position.y + view_rect.size.y * 0.5 - card.custom_minimum_size.y * 0.5)
	else:
		card.position = Vector2(40, 160)
	# 需求1：挂载到 graph_view 的父（reasoning_wall 顶层），脱离 graph_view z=5 的层级锁，
	# 否则卡内任何子节点都盖不过左栏（z=20）。父容器让卡与左栏成为兄弟，凭 z=30 盖左栏。
	var host: Node = get_parent()
	if host and is_instance_valid(host) and host is Control:
		host.add_child(card)
	else:
		add_child(card)
	_detail_card = card


## 详情卡「删除连线」按钮回调（bind 传参，避免循环变量闭包歧义）
func _on_detail_delete(from_id: String, to_id: String, rkind: String, card: Control) -> void:
	_remove_edge(from_id, to_id, rkind)
	if is_instance_valid(card): card.queue_free()


# ===================== 首入引导 =====================
func _show_tutorial() -> void:
	_tutorial = Control.new()
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.z_index = 30
	_tutorial.mouse_filter = Control.MOUSE_FILTER_STOP
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 520)
	panel.position = (get_viewport_rect().size - Vector2(560, 320)) / 2
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = COL_GOLD
	ps.border_width_left = 3; ps.border_width_right = 3; ps.border_width_top = 3; ps.border_width_bottom = 3
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	_tutorial.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var t := Label.new()
	t.text = "推理墙 · 图谱视图"
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(t)
	var lines := [
		"· 中心头像 = 当前焦点人物（认知锚点）",
		"· 距离核心由近及远：结论 → 推理链 → 推断 → 线索",
		"· 拖动节点 = 自由调整位置（距离自动维持排序）",
		"· 按住 Shift + 拖到另一节点 = 建立证据连线",
		"· 把线索拖到人物头像（或右键线索）= 标注它和谁有关",
		"· 顶部可切换「人物星型 / 推理链」两种视图",
		"· 所有操作都可一键撤销，放心试",
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_size_override("font_size", 28)
		lb.add_theme_color_override("font_color", COL_GOLD_LIGHT)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(lb)
	var ok := Button.new()
	ok.text = "明白了"
	ok.add_theme_font_size_override("font_size", 30)
	ok.add_theme_color_override("font_color", COL_GOLD)
	ok.pressed.connect(_close_tutorial)
	vb.add_child(ok)
	add_child(_tutorial)


func _close_tutorial() -> void:
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.queue_free()
		_tutorial = null
	_state_store["graph_tutorial_seen"] = true
	_persist_view()


# ===================== 提示 =====================
func _toast_msg(text: String) -> void:
	if not _toast: return
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var t := create_tween()
	t.tween_property(_toast, "modulate:a", 0.0, 1.5).set_delay(0.6)


# ===================== 视图记忆 =====================
func _persist_view() -> void:
	if _state_store.is_empty(): return
	_state_store["graph_view_mode"] = _mode
	_state_store["graph_placed_clues"] = _placed_clues.duplicate()
	_state_store["graph_focus"] = _focus_person
	_state_store["graph_seed"] = _layout_seed
	_state_store["graph_manual_nodes"] = _manual_nodes.duplicate()
	_state_store["graph_folded_nodes"] = _folded_nodes
	_state_store["graph_nodes"] = _graph_nodes.duplicate()
	_state_store["graph_edited_texts"] = _edited_texts.duplicate()
	_persist_node_positions()


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
	var placed: Dictionary = {"id": nid, "kind": nkid, "label": "【%s】新文本" % labels.get(nkid, "文本"), "sub": subs.get(nkid, "自定义"), "data": {"correct": true}}
	_graph_nodes.append(placed)
	# 在画布中部放置
	var base: Vector2 = _canvas.size * 0.5
	var jitter: Vector2 = Vector2((-60 + (seq % 5) * 30), (-40 + (seq % 4) * 25))
	var pos: Vector2 = _clamp_to_canvas(base + jitter)
	_node_center[nid] = pos
	var nps: Dictionary = _state_store.get("graph_node_positions", {})
	nps[nid] = pos
	_state_store["graph_node_positions"] = nps
	_layout_seed = int(Time.get_ticks_msec()) + seq
	_persist_view()
	_rebuild_graph()


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
					var clamped: Vector2 = _clamp_free(new_center)
					n.position = clamped - n.size * 0.5
					_node_center[_drag_id] = clamped
					_sync_fold_controls_positions()
					_redraw_all()
					get_viewport().set_input_as_handled()
			elif _drag_mode == "edge":
				# 建边：拖拽过程中画弧线预览
				if get_viewport().get_mouse_position().distance_to(_drag_from) > 6:
					_redraw_all()
			return
		elif event is InputEventMouseButton and not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and _drag_mode == "move":
				_commit_move(_drag_id)
				return
			if event.button_index == MOUSE_BUTTON_LEFT and _drag_mode == "edge":
				_commit_drag(_drag_id)
				return
			if event.button_index == MOUSE_BUTTON_RIGHT and _drag_mode == "edge":
				_commit_drag(_drag_id)
				return
	# === dock 拖动（原有） ===
	if _dock_dragging and event is InputEventMouseMotion:
		var gp2: Vector2 = get_viewport().get_mouse_position()
		if gp2.distance_to(_dock_start) > 6:
			_dock_moved = true
		_move_dock_preview(gp2)
		# 声明吃掉移动：避免 dock 的 ScrollContainer 在拖动过程中抢去事件去滚动列表
		get_viewport().set_input_as_handled()
		return
	if _dock_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_on_dock_drop()
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
