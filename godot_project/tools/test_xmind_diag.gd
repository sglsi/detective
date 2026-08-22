extends SceneTree
## 诊断：构造「华生」人物星型数据，调用 graph_view_controller._xmind_layout，
## 校验 XMind 结构：人物居中、主分支扇出、线索随主分支向外、全部在画布内。
## godot --headless --script res://tools/test_xmind_diag.gd --path <godot_project>

func _initialize() -> void:
	await create_timer(0.1).timeout
	var gvc_script := load("res://scripts/clue/graph_view_controller.gd")
	var g: Control = gvc_script.new()
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	g.set("_focus_person", "NPC_HOLMES")
	g._canvas = canvas

	var persons := ["NPC_HOLMES"]
	var nodes := []
	nodes.append({"id": "NPC_HOLMES", "kind": "person", "label": "华生", "data": {}})
	nodes.append({"id": "conclusion", "kind": "conclusion", "label": "说得通", "data": {}})
	var hypos := ["H_anchor", "H_beard", "H_stance", "H_order"]
	for h in hypos:
		nodes.append({"id": h, "kind": "hypo", "label": "推断:" + h, "data": {}})
	var clue_defs := {
		"c_tattoo": {"label": "信使手背锚形文身", "tags": ["H_anchor"]},
		"c_beard": {"label": "络腮胡须".replace(".", "."), "tags": ["H_beard"]},
		"c_stance": {"label": "挺拔站姿", "tags": ["H_stance"]},
		"c_order": {"label": "发号施令", "tags": ["H_anchor"]},
		"c_silent": {"label": "静", "tags": []},
	}
	for cid in clue_defs:
		var d: Dictionary = clue_defs[cid]
		nodes.append({"id": cid, "kind": "clue", "label": d["label"], "data": {"relation_tags": d["tags"]}})

	var out := {}
	var center := canvas.size * 0.5
	g._xmind_layout(nodes, center, {}, out)

	var fail := 0
	var person_pos: Vector2 = out.get("NPC_HOLMES", Vector2.INF)
	if person_pos.distance_to(center) > 1.0:
		print("FAIL 人物未居中  pos=%s center=%s" % [person_pos, center]); fail += 1
	var r_main: float = clampf(min(canvas.size.x, canvas.size.y), 360.0, 900.0) * 0.2
	if r_main < 150.0:
		r_main = 150.0
	var n_ranks := {}
	for nd in nodes:
		var id: String = nd.id
		if id == "NPC_HOLMES":
			continue
		var pos: Vector2 = out.get(id, Vector2.INF)
		if pos == Vector2.INF:
			print("FAIL 缺位置 %s" % id); fail += 1; continue
		var dist: float = pos.distance_to(center)
		# 画布内检查
		if pos.x < 0 or pos.y < 0 or pos.x > canvas.size.x or pos.y > canvas.size.y:
			print("FAIL 出画布 %s pos=%s" % [id, pos]); fail += 1
		# 半径层级：主分支 < 挂靠线索
		if nd.kind in ["hypo", "conclusion", "chain"]:
			if dist < r_main * 0.7:
				print("FAIL 主分支过近 %s dist=%f r_main=%f" % [id, dist, r_main]); fail += 1
		if nd.kind == "clue" and not (out[id] == center):
			var tags: Array = nd.data.get("relation_tags", [])
			if tags.size() > 0 and dist < r_main + 60.0:
				print("FAIL 挂靠线索未外展 %s dist=%f" % [id, dist]); fail += 1
		if nd.kind == "conclusion":
			# 结论应固定正上方（y 更小、x≈center.x）
			if not (pos.y < center.y and abs(pos.x - center.x) < 200.0):
				print("WARN 结论未在正上方 pos=%s" % pos)
	print("XMIND_DIAG: %s" % ("PASS" if fail == 0 else "FAIL"))
	print("  person=%s" % out.get("NPC_HOLMES"))
	for id in out:
		print("  %-12s @ %s" % [id, out[id]])
	quit()
