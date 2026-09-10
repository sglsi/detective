extends Control
## 验证「记录线索后镜头框选剩余待收集线索」逻辑（用户 2026-09-09 反馈）：
##   镜头必须始终聚焦到「仍需收集」的线索圆圈上、且任一待收集线索不得出界；
##   分布过广无法全纳入时自动回退统览（zoom=1 全可见）。
##
## 实测项：
##   T1 簇状剩余线索 → zoom>1 且全部落在场景区视野内（出界=FAIL）
##   T2 分布过广线索 → 自动回退统览（zoom=1, position=0）
##   T3 无剩余线索   → 回统览（zoom=1, position=0）
##
## 运行（沙箱外）：
##   godot --headless --path . "res://scenes/test_camera_frame_clues.tscn"
## 退出码 0=PASS，1=FAIL。

func _ready() -> void:
	await get_tree().process_frame

	var ui = load("res://scripts/ui/scene_framework.gd").new()
	get_tree().root.add_child(ui)          # _ready 同步构建 _world
	await get_tree().process_frame

	var world: Control = ui.get_world_layer()
	var area: Control = ui.get_scene_area()
	if world == null or area == null:
		printerr("RESULT: FAIL world/area 未构建"); get_tree().quit(2); return
	var view := area.size
	print("[SETUP] view=", view)

	# 把世界点 p 映射到「场景区局部屏幕坐标」：_world 是 _scene_area 子节点(偏移0)，
	# 故 screen_local = _world.position + p * _world.scale.x
	var in_view = func(p: Vector2) -> bool:
		var s := world.position + p * world.scale.x
		return s.x >= 0 and s.x <= view.x and s.y >= 0 and s.y <= view.y

	# T1：簇状剩余线索（约 200x200 包围盒）→ 应推近聚焦且全可见
	ui.frame_world_points([Vector2(100, 100), Vector2(300, 300)])
	await get_tree().create_timer(0.5).timeout
	var in_view1: bool = in_view.call(Vector2(100, 100)) and in_view.call(Vector2(300, 300))
	print("[T1] zoom=", snapped(world.scale.x, 0.01), " pos=", world.position, " in_view=", in_view1)
	if not in_view1 or world.scale.x <= 1.0:
		printerr("RESULT: FAIL T1 簇状线索未聚焦或出界 zoom=", world.scale.x, " in_view=", in_view1)
		get_tree().quit(1); return

	# T2：分布过广（占据几乎整个场景区）→ 必须回退统览，避免强行放大丢线索
	ui.frame_world_points([Vector2(10, 10), Vector2(view.x - 10, view.y - 10)])
	await get_tree().create_timer(0.5).timeout
	print("[T2] zoom=", snapped(world.scale.x, 0.01), " pos=", world.position)
	if abs(world.scale.x - 1.0) > 0.01 or world.position.distance_to(Vector2.ZERO) > 0.5:
		printerr("RESULT: FAIL T2 分布过广未回退统览 zoom=", world.scale.x, " pos=", world.position)
		get_tree().quit(1); return

	# T3：无剩余线索 → 回统览
	ui.frame_world_points([])
	await get_tree().create_timer(0.5).timeout
	print("[T3] zoom=", snapped(world.scale.x, 0.01), " pos=", world.position)
	if abs(world.scale.x - 1.0) > 0.01 or world.position.distance_to(Vector2.ZERO) > 0.5:
		printerr("RESULT: FAIL T3 无剩余线索未回统览 zoom=", world.scale.x)
		get_tree().quit(1); return

	print("RESULT: PASS 框选聚焦：簇状聚焦全可见 / 过广回退统览 / 清空回统览")
	get_tree().quit(0)
