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
			{"id":"c1","name":"车轮印迹","image":"res://assets/characters/watson/watson_teaching.png",
			 "correct":true,"associated":true,"related_npcs":["霍普"]},
			{"id":"c2","name":"花园车轮痕迹","image":"res://assets/scenes/sc_02_garden.png",
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
			"graph_placed_clues": ["c1","c2","c3"],
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
	# 手动取景（fit_view 依赖 _clip.size，SubViewport 下不可靠）：按节点实际视图包围盒缩放居中
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
	var vp := Vector2(sv.size.x, sv.size.y)
	var mg := 60.0
	var ns: float = clampf(minf((vp.x - mg * 2.0) / maxf(bbox.x, 1.0), (vp.y - mg * 2.0) / maxf(bbox.y, 1.0)), 0.05, 1.0)
	var content_c := (minp + maxp) * 0.5
	gv._canvas.scale = gv._canvas.scale * ns
	await process_frame
	# 用全局变换补偿嵌套偏移：把内容中心平移到视口中心
	var gl_c: Vector2 = gv._canvas.get_global_transform() * content_c
	gv._canvas.position += vp * 0.5 - gl_c
	for i in 10:
		await process_frame

	var img := sv.get_texture().get_image()
	var out := "D:/AI/workbuddy/Claw/reasoning_wall_cards.png"
	img.save_png(out)
	print("SAVED ", out, " ", img.get_width(), "x", img.get_height(), " nodes=", gv._node_views.size())
	quit()
