extends RefCounted
class_name GraphViewFold

## 图谱视图 · 折叠层（拆自 graph_view_controller.gd，Request C 后架构分层）
##
## 职责：XMind 式折叠（hidden 集 BFS 收起更深圈层 / 叶子=线索真折叠自身=任务3）、
## 折叠控件（点击热区 + 圆形绘制 + 字形计数）、邻接表（折叠遍历用）、
## 拖动前折叠子树。读取/回写 owner（GraphViewController）状态；常量归控制器经 owner. 引用。

var owner: GraphViewController

# ===================== 圈层判定 =====================
## 圈层判定（与布局 _relation_tree_layout 的 depth_of 对齐：人物/事件=0 最顶 > 结论=1 > 推断=2 > 线索=3 最底）。
## 折叠方向：折叠某节点 = 隐藏其「圈层更深（rd 更大）」的整棵子树。故人物(rd0)折叠会收起结论+推断+线索，
## 结论(rd1)折叠收起推断+线索，推断(rd2)折叠收起线索。叶子=线索(rd3)可折叠收起自身。
func _ring_depth(kind: String) -> int:
	match kind:
		"person":     return 0
		"event":      return 0
		"conclusion": return 1
		"hypo":       return 2
		"chain":      return 2
		"clue":       return 3
		_:            return 3


## 任意节点 id 的 kind（不依赖可见性——隐藏节点也需判定圈层）。
## ⚠️ 必须从「权威数据」直接解析，不能优先依赖 _node_kind：_rebuild_graph 在 line 609 清空 _node_kind，
## 而在 line 622 的 _node_list 内就会调用 _compute_hidden→_kind_of，此时 _node_kind 尚为空（要等 line 645
## 才回填）。若优先读 _node_kind，则「开墙即折叠」(_apply_fold_to_roots) 会因 kind 全退化成 clue(叶子)
## 而把折叠根自身也误收起。故这里优先从 _persons/_hypo/_clues/_graph_nodes 解析，_node_kind 仅作兜底。
func _kind_of(id: String) -> String:
	if id == owner._focus_person: return "person"
	if id.begins_with("conclusion_"): return "conclusion"
	if id == "conclusion": return "conclusion"
	if id.begins_with("chain:"): return "chain"
	for gn in owner._graph_nodes:
		if gn.get("id", "") == id: return gn.get("kind", "hypo")
	for h in owner._hypo.get("battlefield", {}).get("hypotheses", []):
		if h.get("id", "") == id: return "hypo"
	for p in owner._persons:
		var pid: String = p.get("id", "") if p is Dictionary else str(p)
		if pid == id: return "person"
	for c in owner._clues:
		if c.get("id", "") == id: return "clue"
	if owner._node_kind.has(id): return owner._node_kind[id]
	return "clue"


## 叶子节点（线索，rd=3）可折叠（折叠=收起自身，展开可恢复）
func _is_leaf(id: String) -> bool:
	return _ring_depth(_kind_of(id)) >= 3


## 无向邻接表（折叠遍历用）：玩家关系 + 数据边 + 模式C人物↔结论元数据边
func _build_adjacency() -> Dictionary:
	var adj := {}
	var link := func(a: String, b: String) -> void:
		if a == "" or b == "": return
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		if not (b in adj[a]): adj[a].append(b)
		if not (a in adj[b]): adj[b].append(a)
	for e in owner._edge_list:
		link.call(e.from, e.to)
	for r in owner._relations:
		link.call(r.get("from", ""), r.get("to", ""))
	if owner._mode == GraphViewController.ViewMode.MODE_C and owner._focus_person != "":
		# 多结论节点（id 形如 "conclusion_CL2-1"）逐一锚定到焦点人物（避免递归 _node_list）
		for _dc in owner._derived_conclusions:
			var _dnid: String = "conclusion_" + str(_dc.get("id", ""))
			if _dnid != "":
				link.call(owner._focus_person, _dnid)
	# 焦点人物 ↔ 其相关线索（related_npcs）：结构性元数据边，仅用于折叠层级组织，
	# 不进入 _edge_list（绘制层），故不会在画布产生多余连线（与「移除自动绘制边」不冲突）。
	for _c in owner._clues:
		var _rns: Array = _c.get("related_npcs", [])
		if owner._focus_person != "" and (owner._focus_person in _rns):
			link.call(owner._focus_person, str(_c.get("id", "")))
	return adj


## 节点的直接外层邻居（圈层深度严格更大的相连节点）——用于折叠控件数量与朝向
func _direct_outer_neighbors(id: String) -> Array:
	var out := []
	var rd := _ring_depth(_kind_of(id))
	for nb in _build_adjacency().get(id, []):
		if _ring_depth(_kind_of(nb)) > rd:
			out.append(nb)
	return out


# ===================== 折叠隐藏集（XMind 式） =====================
## 从各折叠根 BFS，收起整棵「玩家关系树」下游子树（设计 §4.1）。
## 遍历改用 _build_parent_of 同款有向父子边（_descendants），不再用圈层深度门控——
## 结论→结论同层边（rd 均为 1）原本会被 ring_depth<=root_rd 判定截断、收不起下游结论，
## 现改为沿玩家真实结构树收集，折叠 C-A1 也能收起 C-A2/C-MAIN 及其叶子（Issue 1）。
func _compute_hidden() -> Dictionary:
	var hidden := {}
	for root in owner._folded_nodes:
		# 叶子节点（如线索）折叠=收起自身（无更深子树可收），故把自身也计入隐藏集
		if _is_leaf(root):
			hidden[root] = true
			continue
		# 沿玩家关系树收起整棵下游子树：结论→结论同层边也能收起（Issue 1）
		for s in owner._layout._descendants(root):
			hidden[s] = true
	return hidden


## 折叠控件上的计数：直接外层邻居数（设计 §4.3 / §9.4）
func _fold_count(id: String) -> int:
	return _direct_outer_neighbors(id).size()


## 折叠控件上的字形：展开=−，折叠=+N
func _fold_glyph(id: String) -> String:
	if owner._folded_nodes.has(id):
		if _is_leaf(id): return "+"
		return "+%d" % _fold_count(id)
	return "-"


## 折叠控件位置：节点外缘、朝向外层邻居簇重心方向
func _fold_control_pos(id: String) -> Vector2:
	# 折叠后节点 view 被移除、_node_center 不再含其位置，凭 _all_positions（持久位置缓存）兜底定位
	var center: Vector2 = owner._node_center.get(id, owner._all_positions.get(id, Vector2.ZERO))
	if center == Vector2.ZERO: return center
	var neighbors := _direct_outer_neighbors(id)
	if neighbors.is_empty():
		# 叶子（如线索）：控件置于节点右上角外缘，点击=收起/展开自身
		var r: float = _node_radius_for_kind(_kind_of(id))
		return center + Vector2(r * 0.7 + 6.0, -(r * 0.7 + 6.0))
	var dir := Vector2.ZERO
	for nb in neighbors:
		var nc: Vector2 = owner._node_center.get(nb, center)
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


# ===================== 折叠控件（点击热区 + 圆形绘制） =====================
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
	for id in owner._fold_controls:
		var c: Control = owner._fold_controls.get(id)
		if c == null or not is_instance_valid(c): continue
		var center := _fold_control_pos(id)
		var folded := owner._folded_nodes.has(id)
		# 圆底
		owner._fold_layer.draw_circle(center, 22.0, Color(0.10, 0.08, 0.06, 0.96))
		owner._fold_layer.draw_arc(center, 22.0, 0, TAU, 28, owner.COL_GOLD, 3.0)
		# 字形
		var f := ThemeDB.get_default_theme().default_font
		if f == null: continue
		var txt := _fold_glyph(id)
		var fs := 26
		var sz := f.get_string_size(txt, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var p := Vector2(center.x - sz.x * 0.5, center.y + sz.y * 0.5)
		owner._fold_layer.draw_string(f, p, txt, HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
			owner.COL_GOLD_LIGHT if not folded else owner.COL_GOLD)


## 点击折叠控件：toggle（不触发节点拖动/连线）
func _on_fold_control_gui(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		owner.toggle_fold(id)
		owner.get_viewport().set_input_as_handled()


## 拖动节点时同步所有折叠控件位置（点击热区 + 绘制图层都要刷新）
func _sync_fold_controls_positions() -> void:
	for id in owner._fold_controls:
		var c = owner._fold_controls[id]
		if not is_instance_valid(c): continue
		c.position = _fold_control_pos(id) - Vector2(12, 12)
	if owner._fold_layer and is_instance_valid(owner._fold_layer): owner._fold_layer.queue_redraw()


## 折叠根写回（供 UndoRedo / toggle_fold 调用）
func _set_folded(id: String, v: bool) -> void:
	if v:
		owner._folded_nodes[id] = true
		# 折叠本体时一并折叠其下层子树（推断→线索等），避免只藏连线而节点仍平铺
		for s in _subtree_ids(id):
			owner._folded_nodes[s] = true
			if owner._node_center.has(s):
				owner._all_positions[s] = owner._node_center[s]
		if owner._node_center.has(id):
			owner._all_positions[id] = owner._node_center[id]
	else:
		owner._folded_nodes.erase(id)
		# 展开需一并清掉下层的子树折叠，否则线索保持隐藏无法正确显示
		for s in _subtree_ids(id):
			owner._folded_nodes.erase(s)
			if owner._node_center.has(s):
				owner._all_positions[s] = owner._node_center[s]
		if owner._node_center.has(id):
			owner._all_positions[id] = owner._node_center[id]
	# 第8节改造（A①+B①）：折叠/展开后按星形重新自动排布（不保留折叠前的零散位置）
	owner._fold_keep_layout = false
	owner._rebuild_graph()


# ===================== 拖动前折叠子树 =====================
func _fold_subtree_for_drag(id: String) -> void:
	if owner._state != GraphViewController.State.EDITABLE: return
	var subs := _subtree_ids(id)
	if subs.is_empty() and not owner._folded_nodes.has(id):
		return
	call_deferred("_apply_fold_subtree", id, subs)


## 沿玩家关系树（_build_parent_of 子图）收集本节点的整棵下游子树 id（不含 id 自身）。
## 改用布局/拖拽共用的有向父子边遍历，不再用圈层深度门控——结论→结论同层边（rd 均为 1）
## 也能被折叠收起其下游结论与叶子（Issue 1）。
func _subtree_ids(id: String) -> Array:
	return owner._layout._descendants(id)


## deferred：折叠子树（含本体），重排后拖动只体现该节点本身；可经节点折叠控件展开。
func _apply_fold_subtree(id: String, subs: Array) -> void:
	if not owner.is_inside_tree(): return
	if not owner._folded_nodes.has(id): owner._folded_nodes[id] = true
	for s in subs:
		owner._folded_nodes[s] = true
	owner._state_store["graph_folded_nodes"] = owner._folded_nodes
	owner._persist_view()
	# 第8节改造（A①+B①）：折叠/展开后按星形重新自动排布（不保留折叠前的零散位置）
	owner._fold_keep_layout = false
	owner._rebuild_graph()
