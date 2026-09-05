extends SceneTree
## 最小验证：显式类型 GraphViewController，测 Issue1 折叠结论链 + Issue4 重排标志。
## 运行：godot --headless --path . --script res://tools/test_issue_min.gd
func _initialize() -> void:
	await process_frame
	var ok := 0
	var bad := 0

	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd"); quit(); return
	var gv: GraphViewController = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	if gv._canvas != null:
		gv._canvas.size = Vector2(1280, 720)

	# Issue1：结论→结论链（C3→C2→C1，C1 为根），折叠根结论须隐藏整条下游
	gv._relations = [
		{"from": "conclusion_C3", "to": "conclusion_C2", "kind": "support"},
		{"from": "conclusion_C2", "to": "conclusion_C1", "kind": "support"},
	]
	var desc_c1 := gv._layout._descendants("conclusion_C1")
	if "conclusion_C2" in desc_c1 and "conclusion_C3" in desc_c1:
		ok += 1; print("[PASS] Issue1 descendants(C1根) 含下游 C2/C3  (desc=%s)" % desc_c1)
	else:
		bad += 1; print("[FAIL] Issue1 descendants(C1)=%s  _relations.size=%d" % [desc_c1, gv._relations.size()])
	gv._folded_nodes = {"conclusion_C1": true}
	var hidden := gv._fold._compute_hidden()
	if hidden.has("conclusion_C2") and hidden.has("conclusion_C3"):
		ok += 1; print("[PASS] Issue1 折叠根C1后 hidden 含下游 C2/C3  (hidden=%s)" % hidden.keys())
	else:
		bad += 1; print("[FAIL] Issue1 hidden=%s" % hidden.keys())

	# Issue4：_relayout_on_edge 标志在 _compute_layout 内被消费归位
	if gv._canvas == null:
		gv._canvas = Control.new()
	gv._canvas.size = Vector2(1280, 720)
	gv._layout._relayout_on_edge = true
	var _out := gv._layout._compute_layout([], {})
	if gv._layout._relayout_on_edge == false:
		ok += 1; print("[PASS] Issue4 _compute_layout 消费后标志复位 false")
	else:
		bad += 1; print("[FAIL] Issue4 标志未复位")
	if typeof(_out) == TYPE_DICTIONARY:
		ok += 1; print("[PASS] Issue4 _compute_layout 正常返回 Dictionary")
	else:
		bad += 1; print("[FAIL] Issue4 返回类型=%s" % typeof(_out))

	print("MIN_RESULT: %s PASS=%d FAIL=%d" % ["PASS" if bad == 0 else "FAIL", ok, bad])
	quit()
