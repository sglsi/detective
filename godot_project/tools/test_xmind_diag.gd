extends SceneTree
## 诊断：人物锚定分层树布局校验——人物不强制居中、结论最近/推断中层/线索最外层、
## 同层同列整齐堆叠、全在画布内、方向随人物位置自适应。

func _check(g, nodes, saved_pos, want_dir: String) -> int:
	var fail := 0
	var out := {}
	var canvas: Control = g._canvas
	var center := canvas.size * 0.5
	g._xmind_layout(nodes, center, saved_pos, out)
	var person: Vector2 = out.get("NPC_HOLMES", Vector2(-9,-9))
	print("DBG person=", person, " out=", out)

	var layer_kind := {}
	for nd in nodes:
		layer_kind[nd.id] = nd.kind
	var x_of := {}
	for id in out:
		x_of[id] = out[id].x
	# 人物可移动：若给了保存位置则沿用
	if saved_pos.has("NPC_HOLMES"):
		if person.distance_to(saved_pos["NPC_HOLMES"]) > 1.0:
			print("FAIL 人物未沿用保存位置 pos=%s saved=%s" % [person, saved_pos["NPC_HOLMES"]]); fail += 1
	# 画布内
	for id in out:
		var p: Vector2 = out[id]
		if p.x < 0 or p.y < 0 or p.x > canvas.size.x or p.y > canvas.size.y:
			print("FAIL 出画布 %s %s" % [id, p]); fail += 1
	# 结论离人物最近、线索离最远
	var dist := {}
	for id in out:
		if id != "NPC_HOLMES":
			dist[id] = out[id].distance_to(person)
	var concl := -1.0; var infer := -1.0; var clue := -1.0
	for id in dist:
		match layer_kind[id]:
			"conclusion": concl = maxf(concl, dist[id])
			"hypo": infer = maxf(infer, dist[id])
			"clue": clue = maxf(clue, dist[id])
	if not (concl < infer and infer < clue):
		print("FAIL 层级距离错  concl(max)=%f infer(max)=%f clue(max)=%f" % [concl, infer, clue]); fail += 1
	# 同层同列（x 一致）
	var x_by_layer := {}
	for id in dist:
		var layer: int = 1 if layer_kind[id] == "conclusion" else (2 if layer_kind[id] == "hypo" else 3)
		if not x_by_layer.has(layer): x_by_layer[layer] = {}
		if not x_by_layer[layer].has(x_of[id]): x_by_layer[layer][x_of[id]] = 0
		x_by_layer[layer][x_of[id]] += 1
	for layer in x_by_layer:
		if x_by_layer[layer].size() != 1:
			print("FAIL 层%d 未同列 x=%s" % [layer, x_by_layer[layer]]); fail += 1
	# 方向自适应
	var expected_sign := 1.0
	for id in dist:
		if (out[id].x - person.x) * expected_sign < 0:
			expected_sign = -1.0
	if want_dir == "left" and expected_sign != -1.0:
		print("WARN 期望向左, 实际 sign=%f" % expected_sign)
	if want_dir == "right" and expected_sign != 1.0:
		print("WARN 期望向右, 实际 sign=%f" % expected_sign)
	return fail

func _initialize() -> void:
	await create_timer(0.1).timeout
	var gvc := load("res://scripts/clue/graph_view_controller.gd")
	var g: Control = gvc.new()
	# g.set("_focus_person", "NPC_HOLMES")
	g._focus_person = "NPC_HOLMES"
	print("DBG focus=", g._focus_person, "has_person_var=", "NPC_HOLMES" in str(g.get_property_list()))

	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	g._canvas = canvas
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
	var fail := 0
	print("--- 默认（人物无保存，向右半）→ 树应向左铺开 ---")
	fail += _check(g, nodes, {}, "left")
	var saved_right := {"NPC_HOLMES": Vector2(1700, 300)}
	print("--- 人物保存于右(1700) → 向左铺开 ---")
	fail += _check(g, nodes, saved_right, "left")
	var saved_left := {"NPC_HOLMES": Vector2(200, 800)}
	print("--- 人物保存于左(200) → 向右铺开 ---")
	fail += _check(g, nodes, saved_left, "right")
	print("XMIND_DIAG2: %s" % ("PASS" if fail == 0 else "FAIL (%d)" % fail))
	quit()
