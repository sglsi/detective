extends SceneTree
## 离屏渲染推理墙，验证统一三段式卡片（人物圆形头像/未知剪影/线索图/推断/结论）。
## 运行（窗口模式，必须非 headless，否则 SubViewport 无渲染设备）：
##   Godot.exe --path godot_project --script res://tools/shot_reasoning_wall.gd

func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 900)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)

	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	sv.add_child(gv)
	await process_frame   # 等 _ready 初始化 _data 等内部依赖
	gv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var data := {
		"clues": [
			{"id":"c201","name":"碾轧的花草","image":"res://assets/scenes/sc02_street.png","anchor":"c201",
			 "correct":true,"associated":true,"related_npcs":["霍普"]},
			{"id":"c202","name":"平行车轮印","image":"res://assets/scenes/sc02_street.png","anchor":"c202",
			 "correct":true,"associated":false,"related_npcs":["霍普"]},
			{"id":"c3","name":"可疑证词","correct":false,"associated":false,"related_npcs":[]},
		],
		"hypo": {"title":"x","case_name":"血字的研究","chain_id":"1",
			"battlefield":{"hypotheses":[],"contradictions":[]}},
		"relations": [],
		"persons": [{"id":"霍普","name":"霍普"}, {"id":"神秘嫌疑犯","name":"神秘嫌疑犯"}],
		"focus_person": "霍普",
		"difficulty": 1,
		"editable": true,
		"verdict": -1,
		"case_wide": true,
		"state_store": {
			"graph_tutorial_seen": true,
			"graph_placed_clues": ["c201","c202","c3"],
			"graph_derived_conclusions": [{"id":"dc1","text":"凶手是出租马车夫"}],
			"graph_nodes": [{"id":"g1","kind":"hypo","label":"马车夫作案","sub":"自定义"}],
		},
	}
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gv._canvas.size = sv.size
	gv._rebuild_graph()
	for i in 4:
		await process_frame
	# 手动取景：以 _clip 交互区（clip_contents=true，卡片被它裁剪）为目标窗口，
	# 按节点实际视图包围盒缩放居中；迭代补偿收敛（canvas 位置可能被布局改写）。
	var clip_rect: Rect2 = gv._clip.get_global_rect()
	var vp := clip_rect.size
	var target := clip_rect.position + clip_rect.size * 0.5
	var xform: Transform2D = gv._canvas.get_global_transform()
	var minp := Vector2(1e18, 1e18)
	var maxp := Vector2(-1e18, -1e18)
	for id in gv._node_views:
		var v: Control = gv._node_views[id]
		var tl: Vector2 = xform * (v.position)
		var br: Vector2 = xform * (v.position + v.size)
		minp = Vector2(minf(minp.x, tl.x), minf(minp.y, tl.y))
		maxp = Vector2(maxf(maxp.x, br.x), maxf(maxp.y, br.y))
	var bbox := maxp - minp
	var mg := 30.0
	var ns: float = clampf(minf((vp.x - mg * 2.0) / maxf(bbox.x, 1.0), (vp.y - mg * 2.0) / maxf(bbox.y, 1.0)), 0.05, 1.0)
	var content_c := (minp + maxp) * 0.5
	gv._canvas.scale = gv._canvas.scale * ns
	for it in 3:
		await process_frame
		var gl_c: Vector2 = gv._canvas.get_global_transform() * content_c
		var diff: Vector2 = target - gl_c
		if diff.length() < 1.0:
			break
		gv._canvas.position += diff
	for i in 10:
		await process_frame

	var img := sv.get_texture().get_image()
	var out := "D:/AI/workbuddy/Claw/reasoning_wall_cards.png"
	img.save_png(out)
	print("SAVED ", out, " ", img.get_width(), "x", img.get_height(), " nodes=", gv._node_views.size())

	# —— 自动断言：装饰层不拦鼠标 / 图钉存在 / 线索图锚点裁剪 ——
	var fails := 0
	for id in gv._node_views:
		var v: Control = gv._node_views[id]
		if v.get_child_count() == 0: continue
		var root_c: Control = v.get_child(0)
		if root_c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("[FAIL] ", id, " root mouse_filter 非 IGNORE"); fails += 1
		var has_pin := false
		for ch in root_c.get_children():
			if ch is PanelContainer and ch.custom_minimum_size == Vector2(22, 22):
				has_pin = true
		if not has_pin:
			print("[FAIL] ", id, " 缺顶部图钉"); fails += 1
	# 线索图裁剪断言：c201/c202 应为 AtlasTexture 且区域不同
	var regions := {}
	for id in ["c201", "c202"]:
		var v2: Control = gv._node_views.get(id)
		if v2 == null: continue
		regions[id] = _find_atlas_region(v2.get_child(0))
		if regions[id] == Rect2():
			print("[FAIL] ", id, " 线索图未锚点裁剪"); fails += 1
	if regions.get("c201", Rect2()) != Rect2() and regions.get("c201") == regions.get("c202"):
		print("[FAIL] c201/c202 裁剪区域相同"); fails += 1

	# —— 交互回归：模拟真实点击线索卡 → 应弹出详情卡（推导/打标签入口） ——
	var vc: Control = gv._node_views.get("c201")
	if vc != null:
		var cc: Vector2 = vc.get_global_rect().get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = cc
		press.global_position = cc
		sv.push_input(press)
		await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = cc
		release.global_position = cc
		sv.push_input(release)
		await process_frame
		await process_frame
		if gv._detail_card != null and is_instance_valid(gv._detail_card):
			print("[PASS] 点击线索卡 → 详情弹窗已打开（推导/打标签入口恢复）")
		else:
			print("[FAIL] 点击线索卡无详情弹窗"); fails += 1
	else:
		print("[FAIL] 找不到 c201 节点视图"); fails += 1

	print("ASSERT_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit()


func _find_atlas_region(n: Node) -> Rect2:
	if n is TextureRect and n.texture is AtlasTexture:
		return (n.texture as AtlasTexture).region
	for ch in n.get_children():
		var r: Rect2 = _find_atlas_region(ch)
		if r != Rect2():
			return r
	return Rect2()
