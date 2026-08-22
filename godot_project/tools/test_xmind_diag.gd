extends SceneTree
## 诊断：按关系驱动的横向阶梯树布局校验（对齐华生示范）。
## 断言：整链(person→conclusion→hypo→clue)沿树向外逐列推进(列x单调外扩)、
## 同列不重叠、树完整无遗漏、全在画布内、方向随人物位置自适应(不硬性统一)。

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
	g._relation_tree_layout(nodes, center, saved_pos, out)
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
	# 3) 沿树方向逐列外扩：dir 由布局实际方向反推（人物偏右→左生长、偏左→右生长，不硬性统一）
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
	# 4) 同列不重叠（同一列x上的节点 y 间隔不小于 30）
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
	return fail

func nd_kind(nodes: Array, id: String) -> String:
	for nd in nodes:
		if nd.id == id: return nd.kind
	return ""

func _initialize() -> void:
	await create_timer(0.1).timeout
	var gvc := load("res://scripts/clue/graph_view_controller.gd")
	var g: Control = gvc.new()
	g._focus_person = "NPC_HOLMES"
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080)
	g._canvas = canvas
	g._clues = []; g._edge_list = []
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
	# 两条完整推理链
	var relations := [
		{"from": "NPC_HOLMES", "to": "conclusion_A", "kind": "support"},
		{"from": "conclusion_A", "to": "h1", "kind": "support"},
		{"from": "conclusion_A", "to": "h2", "kind": "support"},
		{"from": "h1", "to": "c1", "kind": "support"},
		{"from": "h2", "to": "c2", "kind": "support"},
		{"from": "NPC_HOLMES", "to": "conclusion_B", "kind": "support"},
		{"from": "conclusion_B", "to": "h3", "kind": "support"},
		{"from": "h3", "to": "c3", "kind": "support"},
	]
	var fail := 0
	print("--- 默认(人物居中) ---")
	g._relations = relations
	fail += _check(g, nodes, {}, relations, "默认")
	print("--- 人物保存于右(1700,300) → 向左铺开 ---")
	fail += _check(g, nodes, {"NPC_HOLMES": Vector2(1700, 300)}, relations, "人物在右")
	print("--- 人物保存于左(200,800) → 向右铺开 ---")
	fail += _check(g, nodes, {"NPC_HOLMES": Vector2(200, 800)}, relations, "人物在左")
	print("XMIND_DIAG3: %s" % ("PASS" if fail == 0 else "FAIL (%d)" % fail))
	quit()