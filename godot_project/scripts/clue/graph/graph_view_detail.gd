extends RefCounted
class_name GraphViewDetail

## 图谱视图 · 节点详情卡层（拆自 graph_view_controller.gd）
##
## 职责：点节点弹出的详情卡（统一 DetailCard 框架，屏幕居中 + ✕ + 拖拽）、标题文案、
## 卡片删除（线索归还线索栏 / 其余移除节点与关系并重排）、删除连线回调。
## _detail_card 状态与 _close_detail_card 留在主控制器（被 _open_conclusion_choice 等外部调用）。

var owner: GraphViewController

const DETAIL_CARD = preload("res://scripts/ui/detail_card.gd")

## 详情卡标题文案（编辑态优先取玩家已编辑文本）
func detail_title_text(id: String, kind: String) -> String:
	if owner._edited_texts.has(id):
		return str(owner._edited_texts[id])
	if kind == "clue":
		return str(owner._node_data.get(id, {}).get("name", id))
	if kind == "hypo":
		return str(owner._node_data.get(id, {}).get("text", ""))
	if kind == "person":
		return owner._data._person_name(id)
	if kind == "chain":
		return str(owner._node_data.get(id, {}).get("label", id))
	if kind == "conclusion":
		# 结论详情默认文本取结论实际内容（跨场景携带后仍是场景二所选内容），
		# 不再回退到实时判定文案「说得通」（问题3）。
		return owner._conclusion_text(owner._conclusion_con_id(id))
	return owner._data._verdict_text()


## 统一删除：从详情卡删除该卡片（clue=归还线索栏；其余=从图谱移除节点与关系）
func delete_card_node(id: String, kind: String, card: Control) -> void:
	if owner._state != owner.State.EDITABLE: return
	if is_instance_valid(card): card.queue_free()
	if kind == "clue":
		owner._unplace_clue_from_graph(id, null)
	else:
		delete_node(id, kind)


## 通用节点删除：从 _graph_nodes/关系/已折叠/位置 中移除并重排（覆盖 note_/hypo/conclusion/chain/person）
func delete_node(id: String, kind: String) -> void:
	if owner._state != owner.State.EDITABLE: return
	var target: Array = owner._graph_nodes.filter(func(n): return n.get("id", "") == id)
	owner._graph_nodes = owner._graph_nodes.filter(func(n): return n.get("id", "") != id)
	owner._relations = owner._relations.filter(func(r): return r.get("from", "") != id and r.get("to", "") != id)
	var del_pool: Array = owner._state_store.get("graph_deleted_nodes", [])
	for t in target:
		del_pool.append(t)
	owner._state_store["graph_deleted_nodes"] = del_pool
	owner._folded_nodes.erase(id)
	owner._node_center.erase(id)
	if id == owner._focus_person:
		owner._focus_person = owner._persons[0].get("id", "") if not owner._persons.is_empty() else ""
	owner._persist_view()
	owner._rebuild_graph()
	if owner._cb_relations_changed.is_valid():
		owner._cb_relations_changed.call(owner._relations.duplicate())


func show_detail(id: String, kind: String) -> void:
	if owner._detail_card and is_instance_valid(owner._detail_card):
		owner._detail_card.queue_free()
	# 统一详情卡框架（暗棕底+金边圆角，顶栏含 ✕ 与拖拽手柄），与线索库详情弹窗视觉一致
	var d: Dictionary = DETAIL_CARD.build(detail_title_text(id, kind), func(): owner._close_detail_card())
	var card: PanelContainer = d.card
	var vb: VBoxContainer = d.body

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 120)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.91, 0.866, 0.784))
	vb.add_child(body)

	match kind:
		"clue":
			var c: Dictionary = owner._node_data.get(id, {})
			var who := "未知"
			var rns: Array = c.get("related_npcs", [])
			if not rns.is_empty():
				who = "、".join(rns.map(func(p): return owner._data._person_name(p)))
			var attr := "其他"
			var at: Array = c.get("attribute_tags", [])
			if not at.is_empty(): attr = at[0]
			body.text = "%s\n和谁有关：%s\n证据属性：%s\n状态：%s" % [
				c.get("desc", ""), who, attr, owner._data._clue_sub(c)]
			if owner._difficulty == owner.Diff.EASY:
				body.text += "\n（福尔摩斯旁白：这条线索值得和%s对一对。）" % who
			if owner._state == owner.State.EDITABLE:
				var tag_btn := Button.new()
				tag_btn.text = "和谁有关 ▾"
				tag_btn.add_theme_font_size_override("font_size", 15)
				tag_btn.pressed.connect(func(): owner._open_tag_menu(id, "clue"))
				vb.add_child(tag_btn)
				var status_btn := Button.new()
				status_btn.text = "标记状态 ▾"
				status_btn.add_theme_font_size_override("font_size", 15)
				status_btn.pressed.connect(func(): owner._open_status_menu(id))
				vb.add_child(status_btn)
		"hypo":
			var h: Dictionary = owner._node_data.get(id, {})
			body.text = "这是你正在考虑的其中一种可能性。"
			if owner._state == owner.State.EDITABLE:
				var chain_btn := Button.new()
				chain_btn.text = "推导下一层推断 ▾"
				chain_btn.add_theme_font_size_override("font_size", 15)
				chain_btn.pressed.connect(func(): owner._dockctl._open_hypo_derive_popup(id))
				vb.add_child(chain_btn)
				var concl_btn := Button.new()
				concl_btn.text = "推导结论 ▾"
				concl_btn.add_theme_font_size_override("font_size", 15)
				concl_btn.pressed.connect(func(): owner._dockctl._open_conclusion_popup(id))
				vb.add_child(concl_btn)
		"person":
			body.text = "星型中心。把线索拖到此处即可标注它和这个人的关系。"
		"conclusion":
			body.text = "根据你关联的证据与连线实时推算。点「提交验证」可正式结案。"
			if owner._state == owner.State.EDITABLE:
				# 通用推导入口：从结论再推下一层结论（启用 N 段推理链，解场景一阶段2/3不可达）。
				# EASY/NORMAL 候选窗列出可见预设结论；HARD 候选窗为空、仅留「✍ 自定义结论」由玩家自写。
				var nxt_btn := Button.new()
				nxt_btn.text = "推导下一层结论 ▾"
				nxt_btn.add_theme_font_size_override("font_size", 15)
				nxt_btn.pressed.connect(func(): owner._open_conclusion_choice(id))
				vb.add_child(nxt_btn)
		"chain":
			body.text = "点此切换到推理链聚焦视图。"

	# —— 编辑内容（问题2：允许玩家编辑文本框内容）——
	if owner._state == owner.State.EDITABLE and kind in ["clue", "hypo", "conclusion", "person", "chain"]:
		var edit_lbl := Label.new()
		edit_lbl.text = "编辑内容"
		edit_lbl.add_theme_font_size_override("font_size", 16)
		edit_lbl.add_theme_color_override("font_color", owner.COL_GOLD)
		vb.add_child(edit_lbl)
		var edit_box := TextEdit.new()
		edit_box.custom_minimum_size = Vector2(420, 72)
		edit_box.add_theme_font_size_override("font_size", 15)
		edit_box.text = str(owner._edited_texts.get(id, detail_title_text(id, kind)))
		vb.add_child(edit_box)
		var save_btn := Button.new()
		save_btn.text = "保存修改"
		save_btn.add_theme_font_size_override("font_size", 15)
		save_btn.pressed.connect(func():
			var new_text: String = edit_box.text.strip_edges()
			if new_text.is_empty(): return
			owner._edited_texts[id] = new_text
			owner._persist_view()
			owner._rebuild_graph()
			if is_instance_valid(card): card.queue_free())
		vb.add_child(save_btn)

	if owner._state == owner.State.EDITABLE:
		var del_btn := Button.new()
		del_btn.text = "🗑 删除此卡片"
		del_btn.add_theme_font_size_override("font_size", 15)
		del_btn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))
		del_btn.pressed.connect(func(): delete_card_node(id, kind, card))
		vb.add_child(del_btn)

	# —— 连线管理（问题1：取消右键后，删除连线改由此处）：列出本节点参与的全部关系，逐个可删 ——
	var rels := []
	for r in owner._relations:
		if r.get("from", "") == id or r.get("to", "") == id:
			rels.append(r)
	if owner._state == owner.State.EDITABLE and not rels.is_empty():
		var sep := HSeparator.new()
		vb.add_child(sep)
		var rel_lbl := Label.new()
		rel_lbl.text = "删除连线（本节点参与）"
		rel_lbl.add_theme_font_size_override("font_size", 16)
		rel_lbl.add_theme_color_override("font_color", owner.COL_GOLD)
		vb.add_child(rel_lbl)
		for r in rels:
			var other: String = r.get("to", "") if r.get("from", "") == id else r.get("from", "")
			var del_btn := Button.new()
			del_btn.text = "✕ 删除：↔ %s（%s）" % [owner._node_short_label(other), owner._edge._rel_verb(r.get("kind", "relate"))]
			del_btn.add_theme_font_size_override("font_size", 15)
			del_btn.pressed.connect(on_detail_delete.bind(
				r.get("from", ""), r.get("to", ""), r.get("kind", "relate"), card))
			vb.add_child(del_btn)

	# 拖拽：顶栏作为手柄（✕ 排除），复用通用 WindowDrag
	WindowDrag.make_draggable(card, d.title_bar, [d.close_btn])

	# 需求2（2026-09-19）：统一屏幕居中（不再贴节点、也不固定到某特定角），钳制在视口内、避开顶部功能栏
	var card_size: Vector2 = card.custom_minimum_size
	var view_rect := owner.get_viewport().get_visible_rect()
	var parent_node: Node = owner.get_parent()
	if parent_node and is_instance_valid(parent_node) and parent_node is Control:
		parent_node.add_child(card)
	else:
		parent_node = owner
		owner.add_child(card)
	var cx := view_rect.position.x + view_rect.size.x * 0.5
	var cy := view_rect.position.y + view_rect.size.y * 0.5
	var x: float = clamp(cx - card_size.x * 0.5, view_rect.position.x + 8.0,
		max(view_rect.position.x + 8.0, view_rect.position.x + view_rect.size.x - card_size.x - 8.0))
	var y: float = clamp(cy - card_size.y * 0.5, view_rect.position.y + 118.0,
		max(view_rect.position.y + 118.0, view_rect.position.y + view_rect.size.y - card_size.y - 8.0))
	card.position = Vector2(x, y)
	owner._detail_card = card


## 详情卡「删除连线」按钮回调（bind 传参，避免循环变量闭包歧义）
func on_detail_delete(from_id: String, to_id: String, rkind: String, card: Control) -> void:
	owner._edge._remove_edge(from_id, to_id, rkind)
	if is_instance_valid(card): card.queue_free()
