extends SceneTree
## 几何探测：关联多条线索后，实测推理墙各子控件全局矩形，
## 定位「中间核心问题栏」是否向右溢出、盖住右侧「推理战场」栏。
## godot --headless --script res://tools/test_wall_layout.gd --path <godot_project>

class FakeScene:
	var _wall_state: Dictionary = {}
	func _enter_transition() -> void: pass

func _initialize() -> void:
	await create_timer(0.1).timeout
	var root := get_root()

	var rw_script := load("res://scripts/clue/reasoning_wall.gd")
	var w = rw_script.new()
	var hypos := []
	for i in range(4):
		hypos.append({"id": "H%d" % i, "text": "假设节点%d：凶手在案发时不在现场" % i})
	var hypo := {
		"title": "凶手究竟是谁？",
		"description": "根据现场线索推理出真凶。",
		"hypotheses": hypos,
		"chain_id": "scene3",
		"expected_clues": 12,
		"insight_bonus": 0,
	}
	var clues := []
	for i in range(12):
		clues.append({"id": "S3-%d" % i, "name": "线索%d（一条较长的线索名称用于测试溢出效果）" % i, "desc": "d", "correct": true, "associated": false})
	var fake := FakeScene.new()
	var cb := Callable()
	var on_cont := Callable()
	w.setup(clues, hypo, cb, Callable(), 1, on_cont, fake._wall_state, Callable(), true)
	root.add_child(w)
	await create_timer(0.15).timeout

	# 关联所有线索（模拟点击左侧线索）
	for c in clues:
		w.test_associate(c["id"])
	await create_timer(0.2).timeout

	var cp: Control = w._center_panel
	var rp: Control = w._right_panel
	var cp_rect: Rect2 = cp.get_global_rect()
	var rp_rect: Rect2 = rp.get_global_rect()
	print("WALL size=%s" % w.size)
	print("center_panel global_rect=%s" % cp_rect)
	print("right_panel  global_rect=%s" % rp_rect)
	print("center.right=%f  right.left=%f" % [cp_rect.end.x, rp_rect.position.x])

	var overlap := []
	_overlap_recursive(w, rp_rect.position.x, overlap)
	print("OVERLAP count=%d" % overlap.size())
	for o in overlap:
		print("  OVERLAP: %s  right_edge=%f (超出右栏左界 %f)" % [o[0], o[1], rp_rect.position.x])

	print("=== assoc_list children (count=%d) ===" % w._assoc_list.get_child_count())
	var max_right := 0.0
	for ch in w._assoc_list.get_children():
		var r: Rect2 = ch.get_global_rect()
		print("  %s rect=%s" % [ch.get_class(), r])
		if r.end.x > max_right: max_right = r.end.x
	print("assoc max_right=%f  center.right=%f" % [max_right, cp_rect.end.x])

	var ok := (max_right <= cp_rect.end.x + 1.0)   # 关联按钮必须全部落在中心面板内，不溢出到右栏
	print("LAYOUT_RESULT: %s" % ("PASS" if ok else "FAIL"))
	if not ok:
		print("  (关联区溢出中心面板，会盖住右侧「推理战场」栏)")
	quit()

func _overlap_recursive(node: Node, right_left: float, out: Array) -> void:
	if node is Control:
		var c := node as Control
		if c.visible and c.get_global_rect().end.x > right_left + 1.0:
			out.append([c.get_path(), c.get_global_rect().end.x])
	for ch in node.get_children():
		_overlap_recursive(ch, right_left, out)
