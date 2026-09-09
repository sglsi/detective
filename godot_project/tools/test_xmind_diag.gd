extends SceneTree
## 诊断：按关系驱动的横向阶梯树布局校验（对齐华生示范）。
## 校验对象：当前主布局 _logic_tree_layout（旧 _relation_tree_layout 已废弃，仅保留作参考）。
## 断言：整链(person→conclusion→hypo→clue)沿树向外逐列推进(列x单调外扩)、
## 同列不重叠、树完整无遗漏、全在画布内、人物锚定画布中心、子树向右展开。

func _ring(kind: String) -> int:
	match kind:
		"person": return 0
		"conclusion": return 1
		"hypo", "chain": return 2
		"clue": return 3
	return 4

func _check(g, nodes, saved_pos, relations, label: String) -> int:
	var fail := 0
	var out := {}
	var center: Vector2 = g._canvas.size * 0.5
	# 准备 _logic_tree_layout / _fold._kind_of 所需的权威数据
	g._graph_nodes = nodes
	g._relations = relations
	g._node_kind = {}
	for nd in nodes:
		g._node_kind[nd.id] = nd.kind
	g._layout._logic_tree_layout(nodes, center, saved_pos, out)
	# 应用真实同列去重叠（保证卡片垂直边缘间距 ≥24px）
	g._node_center = out.duplicate()
	g._node_views = {}
	g._layout._apply_column_overlap_fix()
	out = g._node_center.duplicate()
	var person: Vector2 = out.get("NPC_HOLMES", Vector2(-9999, -9999))
	print(label, " person=", person, " 可布局=", out.size(), " 节点=", nodes.size())
	# 1) 树完整：每个节点都有布局
	for nd in nodes:
		if not out.has(nd.id):
			print("FAIL 未布局 ", nd.id); fail += 1
	# 2) 画布内
	for id in out:
		var p: Vector2 = out[id]
		if p.x < 0 or p.y < 0 or p.x > g._canvas.size.x or p.y > g._canvas.size.y:
			print("FAIL 出画布 ", id, " ", p); fail += 1
	# 3) 沿树方向逐列外扩：人物锚定画布中心、子树向右展开（dir 由实际布局反推）
	var dir := 1.0
	for nd in nodes:
		if nd.id != "NPC_HOLMES" and out.has(nd.id):
			dir = 1.0 if out[nd.id].x >= person.x else -1.0
			break
	for nd in nodes:
		if nd.id == "NPC_HOLMES": continue
		var d: float = (out[nd.id].x - person.x) * dir
		if d <= 0:
			print("FAIL 方向异常 %s d=%f dir=%f person=%s" % [nd.id, d, dir, person]); fail += 1
	for r in relations:
		var a: String = r.get("from", ""); var b: String = r.get("to", "")
		if (not out.has(a)) or (not out.has(b)): continue
		if _ring(nd_kind(nodes, a)) == _ring(nd_kind(nodes, b)): continue
		var deeper := b if _ring(nd_kind(nodes, b)) > _ring(nd_kind(nodes, a)) else a
		var shallower := (a if deeper == b else b)
		var da: float = (out[deeper].x - person.x) * dir
		var ds: float = (out[shallower].x - person.x) * dir
		if da < ds - 1.0:
			print("FAIL 链未向外 %s(depth=%s) 应大于 %s(depth=%s)  da=%f ds=%f dir=%f" % [deeper, _ring(nd_kind(nodes, deeper)), shallower, _ring(nd_kind(nodes, shallower)), da, ds, dir]); fail += 1
	# 4) 同列不重叠（同一列x上的节点 中心 y 间隔不小于 30）
	var col_rows := {}
	for id in out:
		var kx: int = int(round(out[id].x))
		if not col_rows.has(kx): col_rows[kx] = []
		col_rows[kx].append(out[id].y)
	for kx in col_rows:
		if col_rows[kx].size() < 2: continue
		var ys: Array = col_rows[kx]; ys.sort()
		for i in range(1, ys.size()):
			if ys[i] - ys[i-1] < 30.0:
				print("FAIL 同列重叠 x=%d y=%s" % [kx, ys]); fail += 1; break
	# 4') 同列卡片垂直边缘间距 ≥15（避免相互覆盖，真实需求）
	var edge_rows := {}
	for id in out:
		var kx2: int = int(round(out[id].x))
		if not edge_rows.has(kx2): edge_rows[kx2] = []
		edge_rows[kx2].append({"id": id, "y": out[id].y})
	for kx2 in edge_rows:
		if edge_rows[kx2].size() < 2: continue
		var ew: Array = edge_rows[kx2]
		ew.sort_custom(func(a, b): return a.y < b.y)
		for i in range(1, ew.size()):
			var ndA = _find_nd(nodes, ew[i-1].id)
			var ndB = _find_nd(nodes, ew[i].id)
			if ndA == null or ndB == null: continue
			var hp: float = g._layout._real_node_height(ndA.id, ndA)
			var hc: float = g._layout._real_node_height(ndB.id, ndB)
			var edge: float = (ew[i].y - ew[i-1].y) - (hp + hc) * 0.5
			if edge < 14.99:
				print("FAIL 同列卡片间距<15 x=%d %s↔%s edge=%.1f y=[%s,%s]" % [kx2, ew[i-1].id, ew[i].id, edge, ew[i-1].y, ew[i].y]); fail += 1
	return fail


func _find_nd(nodes: Array, id: String):
	for nd in nodes:
		if nd.id == id: return nd
	return null

func nd_kind(nodes: Array, id: String) -> String:
	for nd in nodes:
		if nd.id == id: return nd.kind
	return ""

func _initialize() -> void:
	await create_timer(0.1).timeout
	var gvc := load("res://scripts/clue/graph_view_controller.gd")
	var g: Control = gvc.new()
	g._focus_person = "NPC_HOLMES"
	# 布局所需的 helper 层（正常由 _ready 初始化，headless 单测手动补）
	g._layout = load("res://scripts/clue/graph/graph_view_layout.gd").new()
	g._fold = load("res://scripts/clue/graph/graph_view_fold.gd").new()
	g._layout.owner = g
	g._fold.owner = g
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080)
	g._canvas = canvas
	# 布局/折叠消费的状态（与 GraphViewController 默认对齐）
	g._node_views = {}
	g._node_kind = {}
	g._graph_nodes = []
	g._manual_nodes = []
	g._root_anchor_pos = {}
	g._persons = []
	g._hypo = {"battlefield": {"hypotheses": []}}
	g._clues = []
	g._derived_conclusions = []
	g._edge_list = []
	var nodes := [
		{"id": "NPC_HOLMES", "kind": "person", "label": "华生", "data": {}},
		{"id": "conclusion_A", "kind": "conclusion", "label": "在阿富汗服役过", "data": {}},
		{"id": "conclusion_B", "kind": "conclusion", "label": "曾行医", "data": {}},
		{"id": "h1", "kind": "hypo", "label": "是名军医", "data": {}},
		{"id": "h2", "kind": "hypo", "label": "经历过热带", "data": {}},
		{"id": "h3", "kind": "hypo", "label": "参加过战争", "data": {}},
		{"id": "c1", "kind": "clue", "label": "军人气质", "data": {"relation_tags": ["h1"]}},
		{"id": "c2", "kind": "clue", "label": "脸色黝黑", "data": {"relation_tags": ["h2"]}},
		{"id": "c3", "kind": "clue", "label": "左臂僵硬", "data": {"relation_tags": ["h3"]}},
	]
	# 两条完整推理链。关系约定与 _build_parent_of 一致：from=子(前提), to=父(综合)
	# —— 即「结论挂人物」「推断挂结论」「线索挂推断」。
	var relations := [
		{"from": "conclusion_A", "to": "NPC_HOLMES", "kind": "support"},
		{"from": "h1", "to": "conclusion_A", "kind": "support"},
		{"from": "h2", "to": "conclusion_A", "kind": "support"},
		{"from": "c1", "to": "h1", "kind": "support"},
		{"from": "c2", "to": "h2", "kind": "support"},
		{"from": "conclusion_B", "to": "NPC_HOLMES", "kind": "support"},
		{"from": "h3", "to": "conclusion_B", "kind": "support"},
		{"from": "c3", "to": "h3", "kind": "support"},
	]
	var fail := 0
	print("--- 默认(人物居中,向右展开) ---")
	fail += _check(g, nodes, {}, relations, "默认")
	print("--- 人物保存于右(1700,300) → 仍锚定画布中心向右(_logic_tree_layout 忽略 saved_pos 的人物列) ---")
	fail += _check(g, nodes, {"NPC_HOLMES": Vector2(1700, 300)}, relations, "人物在右")
	print("--- 人物保存于左(200,800) → 同上 ---")
	fail += _check(g, nodes, {"NPC_HOLMES": Vector2(200, 800)}, relations, "人物在左")
	print("XMIND_DIAG3: %s" % ("PASS" if fail == 0 else "FAIL (%d)" % fail))
	quit()
