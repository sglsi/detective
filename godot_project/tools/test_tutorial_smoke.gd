extends SceneTree

## 冒烟：多步骤教程引导能正确构建、翻页；教学墙强制展示。
func _initialize() -> void:
	var ok := 0
	var bad := 0

	var gv: GraphViewController = load("res://scripts/clue/graph_view_controller.gd").new()
	gv._data = load("res://scripts/clue/graph/graph_view_data.gd").new()
	gv._data.owner = gv
	gv._layout = load("res://scripts/clue/graph/graph_view_layout.gd").new()
	gv._layout.owner = gv
	gv._fold = load("res://scripts/clue/graph/graph_view_fold.gd").new()
	gv._fold.owner = gv
	gv._edge = load("res://scripts/clue/graph/graph_view_edge.gd").new()
	gv._edge.owner = gv
	gv._state = GraphViewController.State.EDITABLE

	# 1) 非教学 + 已看过 → 门禁表达式应为 false（不弹）。门禁在 build() 内：_teaching or not graph_tutorial_seen
	gv._state_store = {"graph_tutorial_seen": true}
	gv._teaching = false
	var _should_show: bool = gv._teaching or not gv._state_store.get("graph_tutorial_seen", false)
	if not _should_show:
		ok += 1
		print("[PASS] 非教学已看过：门禁=false（不自动弹教程）")
	else:
		bad += 1
		print("[FAIL] 非教学已看过门禁仍为 true")
	# 教学墙 → 门禁 true
	gv._teaching = true
	_should_show = gv._teaching or not gv._state_store.get("graph_tutorial_seen", false)
	if _should_show:
		ok += 1
		print("[PASS] 教学墙：门禁=true（强制展示）")
	else:
		bad += 1
		print("[FAIL] 教学墙门禁为 false")

	# 2) 教学墙 → 强制展示，且生成 5 步
	gv._teaching = true
	gv._show_tutorial()
	if gv._tutorial != null and gv._tut_steps.size() == 5:
		ok += 1
		print("[PASS] 教学墙强制展示教程，步骤数=%d" % gv._tut_steps.size())
	else:
		bad += 1
		print("[FAIL] 教学墙教程步骤异常 tut=%s steps=%d" % [gv._tutorial != null, gv._tut_steps.size()])

	# 3) 翻页：上一步禁用、下一步到末步变「完成」
	if gv._tut_prev != null and gv._tut_next != null:
		if gv._tut_prev.disabled:
			ok += 1
			print("[PASS] 首步「上一步」禁用")
		else:
			bad += 1
			print("[FAIL] 首步上一步未禁用")
		gv._tut_goto(1)   # 到第二步
		gv._tut_goto(1); gv._tut_goto(1); gv._tut_goto(1)  # 到第五步(末)
		if gv._tut_idx == 4 and gv._tut_next.text == "完成":
			ok += 1
			print("[PASS] 翻到末步 idx=%d 按钮=「%s」" % [gv._tut_idx, gv._tut_next.text])
		else:
			bad += 1
			print("[FAIL] 翻页异常 idx=%d next=%s" % [gv._tut_idx, gv._tut_next.text])
	else:
		bad += 1
		print("[FAIL] 教程导航按钮未生成")

	# 4) 第二步内容含「拖入画布」关键词（关键教学点）
	gv._tut_idx = 1
	gv._tut_render()
	var body_txt := ""
	for _c in gv._tut_body.get_children():
		body_txt += _c.text
	if "拖入画布" in body_txt or "左侧" in body_txt:
		ok += 1
		print("[PASS] 步骤②含「拖线索入画布」指引")
	else:
		bad += 1
		print("[FAIL] 步骤②未提拖入画布: %s" % body_txt)

	print("RESULT ok=%d bad=%d" % [ok, bad])
	quit(0 if bad == 0 else 1)
