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
var _cb_tag: Callable = Callable()
var _cb_add_edge: Callable = Callable()
var _cb_remove_relation: Callable = Callable()
var _cb_close: Callable = Callable()

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
var _drag_preview: Control = null

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


## 唯一入口：推理墙调用本方构建图谱视图。data 字段见文件头。
func build(data: Dictionary) -> void:
	_clues = data.get("clues", [])
	_hypo = data.get("hypo", {})
	_relations = data.get("relations", [])
	_persons = data.get("persons", [])
	_focus_person = data.get("focus_person", "")
	_difficulty = data.get("difficulty", Diff.NORMAL)
	_editable = data.get("editable", true)
	_verdict = data.get("verdict", -1)
	_state_store = data.get("state_store", {})
	_cb_tag = data.get("on_tag", Callable())
	_cb_add_edge = data.get("on_add_edge", Callable())
	_cb_remove_relation = data.get("on_remove_relation", Callable())
	_cb_close = data.get("on_close", Callable())
	_cb_pen_changed = data.get("on_pen_changed", Callable())
	_cb_relations_changed = data.get("on_relations_changed", Callable())
	_show_toolbar = data.get("show_toolbar", false)

	# 视图记忆恢复（09 R-3）：读 SaveGame/state_store
	_mode = _state_store.get("graph_view_mode", ViewMode.MODE_C)
	_focus_person = _state_store.get("graph_focus", _focus_person)
	_layout_seed = _state_store.get("graph_seed", 1)

	# 焦点缺省：取第一人物；若无人则造一个「本案核心」中心
	if _focus_person == "" and not _persons.is_empty():
		_focus_person = _persons[0].get("id", "")
	if _focus_person == "":
		_focus_person = "__case__"
		if _persons.is_empty():
			_persons = [{"id": "__case__", "name": "本案核心"}]

	_state = State.LOCKED if not _editable else State.EDITABLE
	if _state == State.LOCKED:
		_undo.clear_history(true)

	_create_ui()
	_rebuild_graph()
	_create_clue_dock()

	if not _state_store.get("graph_tutorial_seen", false):
		_show_tutorial()


# ===================== UI 构建 =====================
func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

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

	if _show_toolbar:
		_toolbar = _create_toolbar()
		add_child(_toolbar)

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -40
	_toast.offset_left = 16; _toast.offset_right = -16
	_toast.add_theme_font_size_override("font_size", 15)
	_toast.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_toast.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate = Color(1, 1, 1, 0)
	add_child(_toast)


func _create_toolbar() -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 60
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.10, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12; row.offset_right = -12; row.offset_top = 10; row.offset_bottom = -10
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
	_focus_sel.add_theme_font_size_override("font_size", 14)
	_focus_sel.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_focus_sel.custom_minimum_size = Vector2(150, 34)
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
	crumb.add_theme_font_size_override("font_size", 14)
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

	var close := _mk_tool_btn("✕", "返回推理墙")
	close.pressed.connect(_on_close_pressed)
	row.add_child(close)

	_refresh_toolbar_state()
	return bar


var _focus_sel: OptionButton = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _tab_c_btn: Button = null
var _tab_b_btn: Button = null


func _mk_tab(text: String, active: bool, greyed: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.disabled = greyed
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", COL_GOLD if active else COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(120, 38)
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
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(42, 38)
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


# ===================== 数据派生 =====================
func _person_name(id: String) -> String:
	for p in _persons:
		if p.get("id", "") == id: return p.get("name", id)
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
		add.call(r.get("from", ""), r.get("to", ""), k, false, r.get("color_key", ""), r.get("dashed", false))

	# 自动推断：线索 relation_tags 命中某推断节点 → 证据指向
	var hypo_ids := []
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		hypo_ids.append(h.get("id", ""))
	for c in _clues:
		for tag in c.get("relation_tags", []):
			if hypo_ids.has(tag):
				add.call(c.get("id", ""), tag, "support", false, "", false)

	# 自动推断：所有推断 → 结论（传导）
	for h in _hypo.get("battlefield", {}).get("hypotheses", []):
		add.call(h.get("id", ""), "conclusion", "imply", false, "", false)


func _rel_color(kind: String) -> Color:
	return color_from_key(kind_to_key(kind))


# ===================== 图重建 =====================
func _rebuild_graph() -> void:
	_compute_common_clues()
	_derive_edges()
	# 清旧节点
	for n in _node_views.values():
		if is_instance_valid(n): n.queue_free()
	_node_views = {}; _node_center = {}; _node_kind = {}; _node_data = {}
	_clear_drag_preview()

	var nodes := _node_list()
	var pos := _compute_layout(nodes)
	_node_center = pos
	for nd in nodes:
		var v := _make_node(nd)
		_node_views[nd.id] = v
		_canvas.add_child(v)
		v.position = pos.get(nd.id, Vector2.ZERO) - v.size * 0.5
		_node_kind[nd.id] = nd.kind
		_node_data[nd.id] = nd.data
	_redraw_all()


func _node_list() -> Array:
	var list := []
	# 中心：焦点人物
	list.append({"id": _focus_person, "kind": "person",
		"label": _person_name(_focus_person), "sub": "焦点", "color": COL_PERSON,
		"data": {"id": _focus_person}})

	if _mode == ViewMode.MODE_C:
		# 第一圈：线索
		var clues := _clues_for_person(_focus_person)
		if clues.is_empty():
			clues = _clues
		for c in clues:
			var cid: String = c.get("id", "")
			var common: bool = _common_clues.has(cid)
			list.append({"id": cid, "kind": "clue",
				"label": c.get("name", cid), "sub": _clue_sub(c),
				"color": _clue_color(c), "data": c, "common": common})
		# 第二圈：推断
		var hypos: Array = _hypo.get("battlefield", {}).get("hypotheses", [])
		if hypos.is_empty():
			hypos = [{"id": "H_core", "text": _hypo.get("title", "核心推断"), "correct": true}]
		for h in hypos:
			list.append({"id": h.get("id", ""), "kind": "hypo",
				"label": h.get("text", ""), "sub": "推断", "color": COL_GOLD_LIGHT, "data": h})
		# 第三圈：推理链 + 结论
		var chain_id: String = _hypo.get("chain_id", "")
		if chain_id != "":
			list.append({"id": "chain:" + chain_id, "kind": "chain",
				"label": "#" + str(chain_id), "sub": "推理链", "color": COL_GOLD, "data": {}})
		list.append({"id": "conclusion", "kind": "conclusion",
			"label": _verdict_text(), "sub": "结论", "color": _verdict_color(), "data": {}})
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
	return list


func _clue_sub(c: Dictionary) -> String:
	var correct: bool = c.get("correct", true)
	var st := "已关联" if c.get("associated", false) else "未关联"
	if not correct: st = "干扰项"
	return st


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
		if r.get("kind", "") in ["contradict", "oppose"]:
			contra += 1
	if contra > 0: return 0
	var support := 0
	for c in _clues:
		if c.get("associated", false) and c.get("correct", true):
			support += 1
	for r in _relations:
		if r.get("kind", "") == "support":
			support += 1
	if support >= 3: return 3
	if support >= 1: return 2
	return 1


func _compute_layout(nodes: Array) -> Dictionary:
	var center := _canvas.size * 0.5
	var out := {}
	if _mode == ViewMode.MODE_C:
		out[_focus_person] = center
		# 按圈分层
		var rings := {1: [], 2: [], 3: []}
		for nd in nodes:
			if nd.id == _focus_person: continue
			if nd.kind == "clue": rings[1].append(nd.id)
			elif nd.kind == "hypo": rings[2].append(nd.id)
			else: rings[3].append(nd.id)
		var radii := {1: 200.0, 2: 320.0, 3: 440.0}
		for ring in [1, 2, 3]:
			var ids: Array = rings[ring]
			var n := ids.size()
			for i in n:
				var ang := (float(i) / maxi(n, 1)) * TAU - PI * 0.5
				if n == 1: ang = -PI * 0.5
				out[ids[i]] = center + Vector2(cos(ang), sin(ang)) * radii[ring]
	else:
		# 模式 B：垂直三层
		var y_top := _clip.offset_top + 110.0
		var y_mid := _canvas.size.y * 0.5
		var y_bot := _canvas.size.y - 110.0
		var tops := []; var mids := []; var bots := []
		for nd in nodes:
			if nd.id == _focus_person: continue
			if nd.kind == "clue": tops.append(nd.id)
			elif nd.kind == "hypo": mids.append(nd.id)
			else: bots.append(nd.id)
		var place := func(arr: Array, y: float) -> void:
			var n := arr.size()
			var span := _canvas.size.x - 200.0
			for i in n:
				var x := 100.0 + (float(i) / maxi(n, 1)) * span
				if n == 1: x = _canvas.size.x * 0.5
				out[arr[i]] = Vector2(x, y)
		place.call(tops, y_top)
		place.call(mids, y_mid)
		place.call(bots, y_bot)
	return out


# ===================== 节点视图 =====================
func _make_node(nd: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 64)
	card.size = Vector2(120, 64)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	var col: Color = nd.get("color", COL_GOLD_LIGHT)
	style.bg_color = Color(col.r * 0.25 + 0.05, col.g * 0.25 + 0.04, col.b * 0.25 + 0.03, 0.96)
	style.border_color = col
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	if nd.get("common", false):
		style.border_color = COL_GOLD
		style.border_width_left = 3; style.border_width_right = 3; style.border_width_top = 3; style.border_width_bottom = 3
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	var lab := Label.new()
	lab.text = nd.get("label", "")
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	lab.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lab)

	var sub := Label.new()
	sub.text = nd.get("sub", "")
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COL_GREY)
	sub.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var id: String = nd.id
	var kind: String = nd.kind
	card.gui_input.connect(_on_node_gui.bind(id, kind))
	card.mouse_entered.connect(_on_node_hover.bind(id, true))
	card.mouse_exited.connect(_on_node_hover.bind(id, false))
	card.tooltip_text = _node_tooltip(nd)
	return card


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


func _on_edge_draw() -> void:
	for e in _edge_list:
		var a: Vector2 = _node_center.get(e.from, Vector2.ZERO)
		var b: Vector2 = _node_center.get(e.to, Vector2.ZERO)
		if a == Vector2.ZERO or b == Vector2.ZERO: continue
		var show := false
		if e.always:
			show = true
		elif _mode == ViewMode.MODE_B:
			show = true
		elif _highlight_id != "" and (e.from == _highlight_id or e.to == _highlight_id):
			show = true
		if not show:
			continue
		var col: Color = e.color
		# 高亮态强调，非高亮态在模式 C 默认下不绘制（仅人物元数据连线单独画）
		if e.kind == "relate" or e.kind == "imply" or e.kind == "support" or e.kind == "oppose" or e.kind == "contradict":
			if e.dashed:
				_draw_dashed(a, b, col, 2)
			else:
				_edge_layer.draw_line(a, b, col, 3)

	# 人物元数据连线（仅模式 C，常显，灰，实线）
	if _mode == ViewMode.MODE_C:
		for c in _clues:
			var cid: String = c.get("id", "")
			if _focus_person in c.get("related_npcs", []):
				var a: Vector2 = _node_center.get(cid, Vector2.ZERO)
				var b: Vector2 = _node_center.get(_focus_person, Vector2.ZERO)
				if a != Vector2.ZERO and b != Vector2.ZERO:
					_edge_layer.draw_line(a, b, COL_GREY, 1.5)

	# 拖拽预览线
	if _dragging and _drag_id != "":
		var a: Vector2 = _node_center.get(_drag_id, Vector2.ZERO)
		if a != Vector2.ZERO:
			_edge_layer.draw_line(a, _drag_preview_pos(), _rel_color(_drag_kind), 2)


func _draw_dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dist := a.distance_to(b)
	var dash := 10.0; var gap := 7.0; var seg := dash + gap
	if seg <= 0: return
	var steps := int(dist / seg)
	var dir := (b - a).normalized()
	var pos := a
	for i in steps:
		var p2 := pos + dir * dash
		if p2.distance_to(a) > dist: p2 = b
		_edge_layer.draw_line(pos, p2, col, w)
		pos = p2 + dir * gap
	if pos.distance_to(b) > 1.0:
		_edge_layer.draw_line(pos, b, col, w)


func _draw_dotted(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dist := a.distance_to(b)
	var dot := 3.0; var gap := 6.0; var seg := dot + gap
	if seg <= 0: return
	var steps := int(dist / seg)
	var dir := (b - a).normalized()
	var pos := a
	for i in steps:
		var p2 := pos + dir * dot
		_edge_layer.draw_line(pos, p2, col, w)
		pos = p2 + dir * gap


func _drag_preview_pos() -> Vector2:
	if _canvas and is_instance_valid(_canvas) and get_viewport():
		return _canvas.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	return Vector2.ZERO


# ===================== 交互 =====================
func _on_node_hover(id: String, entered: bool) -> void:
	if entered:
		_highlight_id = id
	else:
		if _highlight_id == id: _highlight_id = ""
	_redraw_all()


func _on_node_gui(event: InputEvent, id: String, kind: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _state == State.EDITABLE and kind in ["clue", "hypo", "conclusion"]:
					_dragging = true
					_drag_id = id
					_drag_from = get_viewport().get_mouse_position()
					_drag_kind = key_to_kind(_pen_color_key)
					_drag_color_key = _pen_color_key
					_drag_dashed = _pen_dashed
			else:
				if _dragging and _drag_id == id:
					_commit_drag(id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if kind == "clue":
				_open_tag_menu(id)
	elif event is InputEventMouseMotion and _dragging and _drag_id == id:
		if get_viewport().get_mouse_position().distance_to(_drag_from) > 6:
			_redraw_all()


func _commit_drag(id: String) -> void:
	var gp := get_viewport().get_mouse_position()
	var drop := _node_at(gp)
	_dragging = false
	_drag_id = ""
	_redraw_all()
	if drop == "" or drop == id:
		# 落在自己 → 视为点选（非自环）
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


# ---- 打标签（拖线索到人物 / 右键菜单）----
func _open_tag_menu(clue_id: String) -> void:
	if _state != State.EDITABLE:
		_toast_msg("已封存，仅可浏览")
		return
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 15)
	var others := _persons.filter(func(p): return p.get("id", "") != _focus_person)
	if others.is_empty(): others = _persons
	for p in others:
		menu.add_item("和「%s」有关" % p.get("name", p.get("id", "?")))
		menu.set_item_metadata(menu.get_item_count() - 1, p.get("id", ""))
	menu.id_pressed.connect(func(idx: int):
		var pid: String = menu.get_item_metadata(idx)
		_tag_person(clue_id, pid)
		menu.queue_free()
	)
	add_child(menu)
	menu.popup_centered()


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


func _do_edge(from: String, to: String, kind: String, color_key: String, dashed: bool, add: bool) -> void:
	var kept := []
	for r in _relations:
		if not (r.from == from and r.to == to and r.kind == kind):
			kept.append(r)
	if add:
		kept.append({"from": from, "to": to, "kind": kind, "color_key": color_key, "dashed": dashed})
	_relations = kept


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


func set_focus(pid: String) -> void:
	if pid == "": return
	_focus_person = pid
	_persist_view()
	_rebuild_graph()


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
	_dock.offset_right = 26 if _dock_collapsed else 180
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
	_dock_toggle_btn.add_theme_font_size_override("font_size", 16)
	_dock_toggle_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_dock_toggle_btn.custom_minimum_size = Vector2(24, 28)
	_dock_toggle_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_dock_toggle_btn.offset_right = -4; _dock_toggle_btn.offset_left = -28
	_dock_toggle_btn.offset_top = 4; _dock_toggle_btn.offset_bottom = 32
	_dock_toggle_btn.pressed.connect(_on_dock_toggle)
	_dock.add_child(_dock_toggle_btn)

	var title := Label.new()
	title.text = "已收集线索"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 10; title.offset_top = 8; title.offset_right = -34; title.offset_bottom = 36
	title.visible = not _dock_collapsed
	_dock.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 40; scroll.offset_bottom = -8; scroll.offset_left = 6; scroll.offset_right = -6
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
	card.custom_minimum_size = Vector2(160, 56)
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
	name.add_theme_font_size_override("font_size", 13)
	name.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name)
	var sub := Label.new()
	sub.text = "拖入图谱建立关系"
	sub.add_theme_font_size_override("font_size", 10)
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
	prev.custom_minimum_size = Vector2(160, 56)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.30, 0.10, 0.95)
	s.border_color = COL_GOLD
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	prev.add_theme_stylebox_override("panel", s)
	var lab := Label.new()
	lab.text = clue.get("name", cid)
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	prev.add_child(lab)
	prev.z_index = 40
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
		_dock.offset_right = 26 if _dock_collapsed else 180
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
	panel.custom_minimum_size = Vector2(440, 380)
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
	t.add_theme_font_size_override("font_size", 17)
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
	hint.add_theme_font_size_override("font_size", 13)
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
	cancel.add_theme_font_size_override("font_size", 14)
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
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COL_GREY)
	l.custom_minimum_size = Vector2(40, 30)
	return l


func _mk_pen_btn(t: String, active: bool, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.button_pressed = active
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", col if active else COL_GOLD_LIGHT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.20, 0.12, 0.95) if active else Color(0.14, 0.12, 0.08, 0.95)
	s.border_color = col if active else Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", s)
	b.custom_minimum_size = Vector2(78, 30)
	return b


func _mk_link_target(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(400, 34)
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
			if event.pressed:
				_panning = true
				_pan_last = get_viewport().get_mouse_position()
			else:
				_panning = false
	elif event is InputEventMouseMotion and _panning:
		var gp := get_viewport().get_mouse_position()
		_canvas.position += gp - _pan_last
		_pan_last = gp


func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var old_scale := _zoom
	var ns: float = clamp(old_scale * factor, 0.4, 2.5)
	var lp := (mouse_pos - _canvas.position) / old_scale
	_canvas.scale = Vector2(ns, ns)
	_canvas.position = mouse_pos - lp * ns
	_zoom = ns


# ===================== 顶部栏动作 =====================
func _switch_mode(m: int) -> void:
	if m == ViewMode.MODE_A or m == ViewMode.MODE_D:
		return
	_mode = m
	_persist_view()
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
	if _cb_close.is_valid():
		_cb_close.call()
	else:
		queue_free()


# ===================== 详情卡 =====================
func _show_detail(id: String, kind: String) -> void:
	if _detail_card and is_instance_valid(_detail_card):
		_detail_card.queue_free()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 220)
	card.z_index = 12
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
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(320, 80)
	body.add_theme_font_size_override("font_size", 14)
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
				tag_btn.add_theme_font_size_override("font_size", 14)
				tag_btn.pressed.connect(func(): _open_tag_menu(id))
				vb.add_child(tag_btn)
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

	var close := Button.new()
	close.text = "关闭"
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(func(): card.queue_free())
	vb.add_child(close)

	card.position = Vector2(40, 80)
	add_child(card)
	_detail_card = card


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
	panel.custom_minimum_size = Vector2(560, 320)
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
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(t)
	var lines := [
		"· 中心头像 = 当前焦点人物（认知锚点）",
		"· 圈层由近及远：线索 → 推断 → 推理链 → 结论",
		"· 把线索拖到人物头像 = 标注它和谁有关",
		"· 把线索拖到推断/线索 = 建立证据连线",
		"· 顶部可切换「人物星型 / 推理链」两种视图",
		"· 所有操作都可一键撤销，放心试",
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_size_override("font_size", 15)
		lb.add_theme_color_override("font_color", COL_GOLD_LIGHT)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(lb)
	var ok := Button.new()
	ok.text = "明白了"
	ok.add_theme_font_size_override("font_size", 16)
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
	_state_store["graph_focus"] = _focus_person
	_state_store["graph_seed"] = _layout_seed


func _clear_drag_preview() -> void:
	_dragging = false
	_drag_id = ""


func _input(event: InputEvent) -> void:
	if _dock_dragging and event is InputEventMouseMotion:
		var gp := get_viewport().get_mouse_position()
		if gp.distance_to(_dock_start) > 6:
			_dock_moved = true
		_move_dock_preview(gp)
		return
	if _dock_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_on_dock_drop()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			_on_undo()
		elif event.keycode == KEY_Y and event.ctrl_pressed:
			_on_redo()
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_close_pressed()
