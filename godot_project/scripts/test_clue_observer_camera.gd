extends Control
## 集成验证「观察器记录线索 → 镜头框选剩余待收集线索」整条链路（用户 2026-09-09）：
##   用真实 ClueObserver（地点类 world-layer 热点）+ 真实 SceneFramework，
##   记录 c0 后，get_remaining_clue_world_points 应返回 c1/c2/c3，
##   经 frame_world_points 框选后这 3 个待收集圆圈必须全部落在视野内、可点。
##
## 运行（沙箱外）：
##   godot --headless --path . "res://scenes/test_clue_observer_camera.tscn"
## 退出码 0=PASS，1=FAIL。

func _ready() -> void:
	await get_tree().process_frame

	var ui = load("res://scripts/ui/scene_framework.gd").new()
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	var world: Control = ui.get_world_layer()
	var area: Control = ui.get_scene_area()
	if world == null or area == null:
		printerr("RESULT: FAIL world/area 未构建"); get_tree().quit(2); return

	var ClueObserver = load("res://scripts/clue/clue_observer.gd")
	var obs = ClueObserver.new()
	add_child(obs)
	# 地点类热点：4 个簇状分布（world-layer 路径，走 get_clue_world_point 的 world 分支）
	var hotspots := [
		{"id":"c0","label":"A","x":100.0,"y":100.0,"w":40.0,"h":40.0,"desc":"a"},
		{"id":"c1","label":"B","x":200.0,"y":100.0,"w":40.0,"h":40.0,"desc":"b"},
		{"id":"c2","label":"C","x":100.0,"y":200.0,"w":40.0,"h":40.0,"desc":"c"},
		{"id":"c3","label":"D","x":200.0,"y":200.0,"w":40.0,"h":40.0,"desc":"d"},
	]
	obs.setup(self, Label.new(), Label.new(), hotspots, null, null, "",
		ui.get_world_layer(), ui.get_world_offset())

	# 记录 c0（标记为已收集）
	obs.mark_recorded("c0")

	var pts = obs.get_remaining_clue_world_points()
	print("[REMAINING] count=", pts.size(), " pts=", pts)
	if pts.size() != 3:
		printerr("RESULT: FAIL 剩余线索应为 3，实际 ", pts.size()); get_tree().quit(1); return

	# 关键链路：框选剩余线索
	ui.frame_world_points(pts)
	await get_tree().create_timer(0.5).timeout

	var view := area.size
	var all_visible := true
	for p in pts:
		var s: Vector2 = world.position + p * world.scale.x
		if s.x < 0 or s.x > view.x or s.y < 0 or s.y > view.y:
			all_visible = false
			print("[OUT] p=", p, " screen=", s)
	print("[AFTER_FRAME] zoom=", snapped(world.scale.x, 0.01), " pos=", world.position, " all_visible=", all_visible)
	if not all_visible or world.scale.x <= 1.0:
		printerr("RESULT: FAIL 记录后剩余待收集线索出界或未被聚焦 zoom=", world.scale.x, " all_visible=", all_visible)
		get_tree().quit(1); return

	print("RESULT: PASS 记录 c0 后，剩余 c1/c2/c3 框选聚焦且全部在视野内、可点")
	get_tree().quit(0)
