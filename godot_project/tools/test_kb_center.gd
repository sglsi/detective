extends SceneTree
## 验证推理知识库面板是否真正居中
## 运行：godot --headless --script res://tools/test_kb_center.gd

func _initialize() -> void:
	await create_timer(0.1).timeout
	root.size = Vector2i(1920, 1080)
	await create_timer(0.05).timeout
	var kb = load("res://scripts/knowledge/knowledge_base_panel.gd").new()
	root.add_child(kb)
	await create_timer(0.1).timeout

	var vp := root.size
	var main = kb.get_node_or_null("MainPanel")
	if main == null:
		print("[FAIL] 找不到 MainPanel")
		print("KB_CENTER_RESULT: FAIL")
		quit()

	var r: Rect2 = main.get_global_rect()
	var cx: float = r.position.x + r.size.x / 2.0
	var cy: float = r.position.y + r.size.y / 2.0
	var expected_cx: float = vp.x / 2.0
	var expected_cy: float = vp.y / 2.0
	var dx: float = abs(cx - expected_cx)
	var dy: float = abs(cy - expected_cy)
	print("viewport        = %s" % [vp])
	print("main global rect = %s" % [r])
	print("panel center     = (%s, %s)" % [cx, cy])
	print("expected center  = (%s, %s)" % [expected_cx, expected_cy])
	print("offset(px)       = (%s, %s)" % [dx, dy])
	print("anchors          = %s" % [main.anchors_preset])  # 仅供观察
	if dx < 2.0 and dy < 2.0:
		print("[PASS] 知识库面板已居中")
		print("KB_CENTER_RESULT: PASS")
	else:
		print("[FAIL] 知识库面板未居中，偏差 (%s, %s)px" % [dx, dy])
		print("KB_CENTER_RESULT: FAIL")
	quit()
