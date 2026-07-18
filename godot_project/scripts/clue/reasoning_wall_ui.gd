extends Control
class_name ReasoningWallUI

## ReasoningWallUI - 推理墙界面（思维殿堂）
## P2 实装：真实线索状态机（4 态）+ 假设五态机（5 态）+ 红线推理链可视化。
##
## 线索库四态机（设计文档 §2.1）：
##   未发现 UNDISCOVERED → 已收集 COLLECTED → 已验证 VERIFIED →（可失效）已失效 EXPIRED
## 假设五态机（设计文档 §2.2，M2+ 完整 5 态）：
##   待建立 PENDING → 活跃中 ACTIVE → 领先中 LEADING → 已确认 CONFIRMED / 已排除 EXCLUDED
## 红线推理链可视化：
##   支持关系 = 绿色实线；矛盾/反对 = 红色虚线（红线）；弱关联 = 灰色虚线。
##
## 向后兼容：保留 VerifyResult 枚举与 ClueEventBus.verification_complete 信号，
##           场景 2-3 的 _on_verification_complete 逻辑无需改动。

# ============ 状态机枚举 ============

## 线索库四态机（WallClueState，独立于此项目全局生命周期枚举 ClueSystem.ClueState）
enum WallClueState {
	UNDISCOVERED,  # 未发现：场景中已存在，玩家尚未获取
	COLLECTED,     # 已收集：交互/对话/检验获取，纳入线索库
	VERIFIED,      # 已验证：双源印证/工具检验，确认可靠
	EXPIRED,       # 已失效：超出调查进度窗口或被新证据证伪
}

## 假设五态机（M2+ 完整状态）
enum HypothesisState {
	PENDING,   # 待建立：预设节点，尚未关联证据
	ACTIVE,    # 活跃中：关联≥1 有效证据
	LEADING,   # 领先中：支持度显著高于并行假设
	CONFIRMED, # 已确认：核心证据链闭合，升级为事实
	EXCLUDED,  # 已排除：被决定性证据证伪
}

## 四级验证（与场景 GameScene._on_verification_complete 对齐）
enum VerifyResult {
	VERIFIED,        # 已确认
	SUPPORTED,       # 证据基本支持
	INSUFFICIENT,    # 证据不足
	CONTRADICTORY,   # 矛盾
}

## 线索↔假设 关系类型
enum RelationType {
	SUPPORT,    # 支持（绿实线）
	CONTRADICT, # 矛盾/反对（红虚线）
	WEAK,       # 弱关联（灰虚线）
}

# ============ 数据模型 ============

class Clue:
	var id: String = ""
	var name: String = ""
	var state: int = WallClueState.COLLECTED
	var relation_tags: Array = []   # 指向其支持的假设 id
	var attribute_tags: Array = []   # 属性标签（直接物证/目击证词/干扰...）
	var card: Panel = null

class Hypothesis:
	var id: String = ""
	var title: String = ""
	var level: int = 1               # 0=核心问题 1=主假设 2=子假设
	var parent_id: String = ""
	var state: int = HypothesisState.PENDING
	var node: Panel = null
	var pos: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2(240, 70)
	var links: Array = []            # [{clue_id, relation}]

# ============ 运行时数据 ============

var _clues: Dictionary = {}        # id -> Clue
var _hypotheses: Dictionary = {}   # id -> Hypothesis
var _primary_hypo_id: String = ""  # 本案应确认的主假设
var _lines: Array = []             # [{from, to, color, dashed}] 供 _draw 渲染

# ============ 节点引用 ============

@onready var clue_panel: Control = $CluePanel
@onready var board_area: Control = $BoardArea
@onready var verify_button: Button = $VerifyButton
@onready var result_label: Label = $ResultLabel
@onready var milestone_popup: Control = $MilestonePopup

# 本案预设线索集（仅作关系判定参考；游戏中以真实发现为准）
const _CASE_CLUES := {
	"wheel_track": {"name": "车轮印", "rel": ["h_cabman"], "attr": ["直接物证"]},
	"hoof_print": {"name": "马蹄印", "rel": ["h_cabman"], "attr": ["直接物证"]},
	"footprint": {"name": "行人脚印", "rel": ["h_cabman"], "attr": ["直接物证"]},
	"grass_trample": {"name": "碾轧花草", "rel": ["h_cabman"], "attr": ["直接物证"]},
	"body": {"name": "尸体(被迫服毒)", "rel": ["h_cabman"], "attr": ["直接物证"]},
	"blood_word": {"name": "墙上血字 RACHE", "rel": ["h_revenge"], "attr": ["直接物证"]},
	"items": {"name": "随身物品(E.J.D.)", "rel": ["h_cabman"], "attr": ["直接物证"]},
	"ring": {"name": "女人戒指 L·F", "rel": ["h_cabman"], "attr": ["关键"]},
	"drunk_feature": {"name": "醉汉特征(红脸高个)", "rel": ["h_cabman"], "attr": ["目击证词"]},
	"disguise_flaw": {"name": "伪装破绽(步态)", "rel": ["h_cabman"], "attr": ["目击证词"]},
	"hat_photo": {"name": "卡彭蒂耶中尉照片", "rel": ["h_exclude"], "attr": ["直接物证"]},
	"harper_alibi": {"name": "哈珀不在场证词", "rel": ["h_exclude"], "attr": ["目击证词"]},
	"distractor_ring": {"name": "普通戒指(干扰)", "rel": [], "attr": ["干扰"]},
	"distractor_shoes": {"name": "普通皮鞋(干扰)", "rel": [], "attr": ["干扰"]},
}

func _get_event_bus():
	return get_node_or_null("/root/ClueEventBus")

func _ready() -> void:
	verify_button.pressed.connect(_on_verify_pressed)
	var bus = _get_event_bus()
	if bus:
		bus.connect("clue_discovered", _on_clue_discovered)
		bus.connect("clue_recorded", _on_clue_recorded)
	_build_hypothesis_tree()
	_layout_hypotheses()
	_refresh_lines()
	queue_redraw()
	hide()

# ============ 假设五态机：构建推理树 ============

func _build_hypothesis_tree() -> void:
	_add_hypothesis("h_core", "核心问题：凶手是谁？手法？", 0, "")
	_add_hypothesis("h_cabman", "主假设A：马车夫(杰弗森·霍普)作案", 1, "h_core")
	_add_hypothesis("h_robbery", "主假设B：入室抢劫伪装", 1, "h_core")
	_add_hypothesis("h_acquaintance", "主假设C：熟人仇杀", 1, "h_core")
	_add_hypothesis("h_cab", "子假设A1：出租马车", 2, "h_cabman")
	_add_hypothesis("h_return", "子假设A2：凶手返场找戒指", 2, "h_cabman")
	_add_hypothesis("h_revenge", "子假设A3：复仇动机", 2, "h_cabman")
	_add_hypothesis("h_exclude", "排除：卡彭蒂耶中尉嫌疑", 2, "h_core")
	_primary_hypo_id = "h_cabman"

func _add_hypothesis(id: String, title: String, level: int, parent_id: String) -> void:
	var h = Hypothesis.new()
	h.id = id
	h.title = title
	h.level = level
	h.parent_id = parent_id
	h.state = HypothesisState.PENDING
	_hypotheses[id] = h

func _layout_hypotheses() -> void:
	var layout := {
		"h_core": Vector2(480, 10),
		"h_cabman": Vector2(60, 170),
		"h_robbery": Vector2(480, 170),
		"h_acquaintance": Vector2(900, 170),
		"h_cab": Vector2(20, 360),
		"h_return": Vector2(200, 360),
		"h_revenge": Vector2(380, 360),
		"h_exclude": Vector2(820, 360),
	}
	for id in layout:
		var h = _hypotheses[id]
		h.pos = layout[id]
		if h.node == null:
			h.node = _create_hypothesis_node(h)
		h.node.position = h.pos
		h.node.size = h.size

func _create_hypothesis_node(h: Hypothesis) -> Panel:
	var panel = Panel.new()
	panel.name = "Hypo_%s" % h.id
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.22, 0.92)
	style.border_color = Color(0.5, 0.55, 0.65, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = h.title
	label.position = Vector2(8, 8)
	label.size = Vector2(224, 54)
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	panel.gui_input.connect(_on_hypo_input.bind(h.id))
	board_area.add_child(panel)
	return panel

func _on_hypo_input(event: InputEvent, hypo_id: String) -> void:
	# 仅用于高亮反馈；拖拽落点判定在 _on_card_drag 中完成
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[ReasoningWall] 选中假设: %s" % hypo_id)

# ============ 线索四态机 ============

func _on_clue_discovered(clue_id: String) -> void:
	if _clues.has(clue_id):
		return
	var c = Clue.new()
	c.id = clue_id
	c.name = _clue_display_name(clue_id)
	c.state = WallClueState.COLLECTED
	c.relation_tags = _CASE_CLUES.get(clue_id, {}).get("rel", [])
	c.attribute_tags = _CASE_CLUES.get(clue_id, {}).get("attr", [])
	c.card = _create_clue_card(c)
	_clues[clue_id] = c
	clue_panel.add_child(c.card)
	_reflow_clue_cards()
	_refresh_lines()
	queue_redraw()

func _on_clue_recorded(clue_id: String) -> void:
	if not _clues.has(clue_id):
		return
	# 记录：状态在 COLLECTED 之上维持；若已关联为支持证据则在验证时升级为 VERIFIED
	var c = _clues[clue_id]
	if c.card and c.card.has_node("StateLabel"):
		var lbl = c.card.get_node("StateLabel")
		lbl.text = "已记录"
		lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3, 1.0))

func _create_clue_card(c: Clue) -> Panel:
	var panel = Panel.new()
	panel.name = "Card_%s" % c.id
	panel.size = Vector2(230, 76)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.1, 0.9)
	style.border_color = _clue_border_color(c)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = c.name
	label.position = Vector2(10, 5)
	label.size = Vector2(210, 36)
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	var state_label = Label.new()
	state_label.name = "StateLabel"
	state_label.text = _clue_state_name(c.state)
	state_label.position = Vector2(10, 50)
	state_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(state_label)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_drag.bind(c.id))
	return panel

func _clue_border_color(c: Clue) -> Color:
	match c.state:
		WallClueState.VERIFIED: return Color(0.2, 0.9, 0.2, 1.0)
		WallClueState.EXPIRED: return Color(0.5, 0.5, 0.5, 1.0)
		_: return Color(0.6, 0.5, 0.3, 1.0)

func _clue_state_name(state: int) -> String:
	match state:
		WallClueState.UNDISCOVERED: return "未发现"
		WallClueState.COLLECTED: return "已收集"
		WallClueState.VERIFIED: return "已验证"
		WallClueState.EXPIRED: return "信息失效"
		_: return "已收集"

func _clue_display_name(clue_id: String) -> String:
	return _CASE_CLUES.get(clue_id, {}).get("name", clue_id)

func _reflow_clue_cards() -> void:
	var i = 0
	for cid in _clues:
		var card = _clues[cid].card
		if card and card.get_parent() == clue_panel:
			card.position = Vector2(10, 10 + i * 86)
			i += 1

# ============ 拖拽 + 关系建立（红线来源）============

var _dragging: String = ""
var _drag_offset: Vector2 = Vector2.ZERO

func _on_card_drag(event: InputEvent, clue_id: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = clue_id
				var card = _clues[clue_id].card
				_drag_offset = card.get_local_mouse_position()
			else:
				if _dragging != "":
					_drop_card(_dragging, get_global_mouse_position())
					_dragging = ""
	elif event is InputEventMouseMotion and _dragging == clue_id:
		var card = _clues[clue_id].card
		card.global_position = get_global_mouse_position() - _drag_offset

func _drop_card(clue_id: String, global_pos: Vector2) -> void:
	var card = _clues[clue_id].card
	var target_hypo: Hypothesis = null
	for hid in _hypotheses:
		var h = _hypotheses[hid]
		if h.node and h.node.get_global_rect().has_point(global_pos):
			target_hypo = h
			break
	if target_hypo == null:
		# 未落到假设节点：回到线索库
		if card.get_parent() != clue_panel:
			var gp = card.global_position
			card.reparent(clue_panel)
			card.global_position = gp
		_reflow_clue_cards()
		return
	# 落到假设节点：建立关系
	if card.get_parent() != board_area:
		var gp = card.global_position
		card.reparent(board_area)
		card.global_position = gp
	_link_clue_to_hypothesis(clue_id, target_hypo.id)

func _link_clue_to_hypothesis(clue_id: String, hypo_id: String) -> void:
	var c = _clues.get(clue_id)
	var h = _hypotheses.get(hypo_id)
	if c == null or h == null:
		return
	# 去重
	for link in h.links:
		if link["clue_id"] == clue_id:
			h.links.erase(link)
			break
	var rel = _decide_relation(c, h)
	h.links.append({"clue_id": clue_id, "relation": rel})
	# 假设进入活跃中
	if h.state == HypothesisState.PENDING:
		h.state = HypothesisState.ACTIVE
		_paint_hypothesis(h)
	# 线索若作为支持证据关联，则视为已验证
	if rel == RelationType.SUPPORT:
		_set_clue_state(c, WallClueState.VERIFIED)
	print("[ReasoningWall] 关联 %s → %s (%s)" % [c.name, h.title, _relation_name(rel)])
	_refresh_lines()
	queue_redraw()

func _decide_relation(c: Clue, h: Hypothesis) -> int:
	if c.relation_tags.has(h.id):
		return RelationType.SUPPORT
	# 干扰线索落在「应确认」的正确假设上 → 视为矛盾（红线）
	if c.attribute_tags.has("干扰") and h.id == _primary_hypo_id:
		return RelationType.CONTRADICT
	# 干扰线索落在排除假设上 → 支持排除
	if c.attribute_tags.has("干扰") and h.id == "h_exclude":
		return RelationType.SUPPORT
	return RelationType.WEAK

func _relation_name(rel: int) -> String:
	match rel:
		RelationType.SUPPORT: return "支持"
		RelationType.CONTRADICT: return "矛盾"
		_: return "弱关联"

func _set_clue_state(c: Clue, state: int) -> void:
	c.state = state
	if c.card and c.card.has_node("StateLabel"):
		var lbl = c.card.get_node("StateLabel")
		lbl.text = _clue_state_name(state)
	var style = c.card.get_theme_stylebox("panel") if c.card else null
	if style:
		style.border_color = _clue_border_color(c)

func _paint_hypothesis(h: Hypothesis) -> void:
	if h.node == null:
		return
	var style = h.node.get_theme_stylebox("panel")
	if style == null:
		style = StyleBoxFlat.new()
		h.node.add_theme_stylebox_override("panel", style)
	match h.state:
		HypothesisState.PENDING: style.border_color = Color(0.5, 0.55, 0.65, 1.0)
		HypothesisState.ACTIVE: style.border_color = Color(0.4, 0.7, 0.9, 1.0)
		HypothesisState.LEADING: style.border_color = Color(0.9, 0.8, 0.3, 1.0)
		HypothesisState.CONFIRMED: style.border_color = Color(0.2, 0.9, 0.2, 1.0)
		HypothesisState.EXCLUDED: style.border_color = Color(0.7, 0.3, 0.3, 1.0)

# ============ 四级验证 + 五态机推进 ============

func _on_verify_pressed() -> void:
	var result = _verify_all()
	_show_result(result)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("verification_complete", result)

func _verify_all() -> int:
	var overall = VerifyResult.INSUFFICIENT
	for hid in _hypotheses:
		var h = _hypotheses[hid]
		if h.level == 0:
			continue
		var r = _compute_hypothesis_result(h)
		_update_hypothesis_state(h, r)
		if hid == _primary_hypo_id:
			overall = r
	_refresh_lines()
	queue_redraw()
	return overall

func _compute_hypothesis_result(h: Hypothesis) -> int:
	var support = 0
	var contradict = 0
	for link in h.links:
		match link["relation"]:
			RelationType.SUPPORT: support += 1
			RelationType.CONTRADICT: contradict += 1
	if contradict > 0:
		return VerifyResult.CONTRADICTORY
	if support >= 3:
		return VerifyResult.VERIFIED
	if support >= 1:
		return VerifyResult.SUPPORTED
	return VerifyResult.INSUFFICIENT

func _update_hypothesis_state(h: Hypothesis, result: int) -> void:
	match result:
		VerifyResult.CONTRADICTORY:
			if h.id != _primary_hypo_id:
				h.state = HypothesisState.EXCLUDED
			else:
				h.state = HypothesisState.ACTIVE
		VerifyResult.INSUFFICIENT:
			h.state = HypothesisState.ACTIVE
		VerifyResult.SUPPORTED:
			h.state = HypothesisState.LEADING
		VerifyResult.VERIFIED:
			h.state = HypothesisState.CONFIRMED
			_unlock_milestone("first_reasoning")
	_paint_hypothesis(h)

func _show_result(result: int) -> void:
	var msg := ""
	var col := Color(0.9, 0.9, 0.9, 1.0)
	match result:
		VerifyResult.VERIFIED:
			msg = "证据充分 · 已确认 ✓\n核心证据链闭合：马车夫即凶手杰弗森·霍普。"
			col = Color(0.2, 0.9, 0.2, 1.0)
		VerifyResult.SUPPORTED:
			msg = "证据基本支持\n方向正确，但证据链还不够完整。"
			col = Color(0.8, 0.8, 0.2, 1.0)
		VerifyResult.INSUFFICIENT:
			msg = "证据不足\n需要更多线索来支撑结论。"
			col = Color(0.9, 0.5, 0.2, 1.0)
		VerifyResult.CONTRADICTORY:
			msg = "证据矛盾（红线）\n部分线索之间存在矛盾，请重新审视。"
			col = Color(0.95, 0.2, 0.2, 1.0)
	result_label.text = msg
	result_label.add_theme_color_override("font_color", col)
	result_label.show()

func _unlock_milestone(milestone_id: String) -> void:
	_show_milestone_popup("推理链完成")

func _show_milestone_popup(name: String) -> void:
	if milestone_popup == null or not milestone_popup.has_node("Label"):
		return
	milestone_popup.get_node("Label").text = "【里程碑解锁】%s" % name
	milestone_popup.show()
	# 不使用 await（避免成为协程被无 await 调用导致编译错误）；改用一次性计时器收起弹窗
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(milestone_popup):
			milestone_popup.hide()
	, Object.CONNECT_ONE_SHOT)

# ============ 红线推理链可视化（_draw）============

func _refresh_lines() -> void:
	_lines.clear()
	# 1) 结构连线：核心→主假设→子假设（灰，弱关联）
	for hid in _hypotheses:
		var h = _hypotheses[hid]
		if h.parent_id != "":
			var parent = _hypotheses.get(h.parent_id)
			if parent and parent.node and h.node:
				_lines.append({
					"from": _node_center(parent.node),
					"to": _node_center(h.node),
					"color": Color(0.55, 0.6, 0.7, 0.8),
					"dashed": false,
				})
	# 2) 关系连线：线索卡→假设节点（支持=绿实线 / 矛盾=红虚线 / 弱=灰虚线）
	for hid in _hypotheses:
		var h = _hypotheses[hid]
		if h.node == null:
			continue
		for link in h.links:
			var c = _clues.get(link["clue_id"])
			if c == null or c.card == null:
				continue
			var col := Color(0.6, 0.6, 0.6, 1.0)
			var dashed := true
			match link["relation"]:
				RelationType.SUPPORT:
					col = Color(0.2, 0.9, 0.2, 1.0)
					dashed = false
				RelationType.CONTRADICT:
					col = Color(0.95, 0.2, 0.2, 1.0)   # 红线
					dashed = true
				RelationType.WEAK:
					col = Color(0.6, 0.6, 0.6, 1.0)
					dashed = true
			_lines.append({
				"from": _node_center(c.card),
				"to": _node_center(h.node),
				"color": col,
				"dashed": dashed,
			})

func _node_center(node: CanvasItem) -> Vector2:
	return node.global_position + node.size / 2.0

func _to_local(pos: Vector2) -> Vector2:
	return pos - global_position

func _draw() -> void:
	for line in _lines:
		if line["dashed"]:
			_draw_dashed_line(line["from"], line["to"], line["color"])
		else:
			draw_line(_to_local(line["from"]), _to_local(line["to"]), line["color"], 3.0, true)

func _draw_dashed_line(from_global: Vector2, to_global: Vector2, color: Color) -> void:
	var a = _to_local(from_global)
	var b = _to_local(to_global)
	var dist = a.distance_to(b)
	var dash = 14.0
	var gap = 8.0
	var step = dash + gap
	if step <= 0:
		return
	var n = int(dist / step)
	var dir = (b - a) / dist if dist > 0 else Vector2.ZERO
	var pos = a
	for i in range(n):
		var seg_end = pos + dir * dash
		if seg_end.distance_to(a) > dist:
			seg_end = b
		draw_line(pos, seg_end, color, 3.0, true)
		pos = pos + dir * step

# ============ 公开 API ============

func open() -> void:
	show()
	_refresh_lines()
	queue_redraw()
	var ui = get_node_or_null("/root/UIManager")
	if ui:
		ui.open_screen(ui.UIScreen.REASONING_WALL)

func close() -> void:
	hide()
	var ui = get_node_or_null("/root/UIManager")
	if ui:
		ui.close_screen(ui.UIScreen.REASONING_WALL)

# ============ 调试/自检入口（供 p2 验证脚本调用）============

func debug_exercise() -> Dictionary:
	# 发现并关联本案关键线索到正确假设，验证五态机 + 红线逻辑
	for cid in ["wheel_track", "hoof_print", "footprint", "body", "items", "distractor_ring"]:
		if not _clues.has(cid):
			_on_clue_discovered(cid)
	# Phase 1: 把支持线索拖到正确假设（应得 SUPPORT 绿实线）
	for cid in ["wheel_track", "hoof_print", "footprint", "body", "items"]:
		_link_clue_to_hypothesis(cid, _primary_hypo_id)
	var result1 = _verify_all()
	var state1 = _hypotheses[_primary_hypo_id].state
	# Phase 2: 把干扰线索错置到正确假设（应得 CONTRADICT 红线）
	_link_clue_to_hypothesis("distractor_ring", _primary_hypo_id)
	_verify_all()  # 红线已生成，矛盾状态在二次验证中体现
	return {
		"primary_result": result1,
		"primary_state": state1,
		"line_count": _lines.size(),
		"red_lines": _count_red_lines(),
		"clue_states": _clue_states_snapshot(),
	}

func _count_red_lines() -> int:
	var n = 0
	for line in _lines:
		if line["color"] == Color(0.95, 0.2, 0.2, 1.0):
			n += 1
	return n

func _clue_states_snapshot() -> Dictionary:
	var snap := {}
	for cid in _clues:
		snap[cid] = _clues[cid].state
	return snap
