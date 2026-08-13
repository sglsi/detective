extends SceneTree
## M1 摄像机/观察层冒烟测试：在场景树中实例化 SceneFramework，
## 强制 _ready 构建世界子树，验证 _world 创建、缩放/平移/推近 API 不抛错且数值正确。
## （--script 模式无帧推进，故不依赖 tween 完成，仅验证直接生效的 API 与标志位。）

func _initialize() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	root.add_child(sf)
	sf._ready()   # --script 下无帧推进，_ready 不会自动跑，手动强制同步构建

	var ok := true
	var msg := ""

	if sf._world == null:
		ok = false; msg = "_world 未创建"
	elif not sf._scene_area.clip_contents:
		ok = false; msg = "scene_area.clip_contents 未开启"
	else:
		var bg = load("res://assets/backgrounds/baker_street_parlor.jpg")
		var tex = load("res://assets/characters/watson/watson_teaching.png")
		sf.setup("贝克街221B", "DAY 1", bg)
		sf.add_portrait(tex, "华生", Vector2(160, 350), Vector2(280, 360))
		sf.set_camera_enabled(true)

		# 1) 推近：应创建 tween（缩放/位移由 tween 驱动）
		sf.focus_world_point(Vector2(400, 300), 2.0)
		if sf._camera_tween == null:
			ok = false; msg = "focus_world_point 未创建 tween"

		# 2) 直接缩放 API（_zoom_at 立即生效，不依赖 tween）
		var z0: float = sf._world.scale.x
		sf._zoom_at(Vector2(50, 50), 1.5)
		if sf._world.scale.x <= z0 or abs(sf._world.scale.x - clamp(z0*1.5, 1.0, 3.0)) > 0.001:
			ok = false; msg = "_zoom_at 缩放异常"

		# 3) 拖拽平移：position 应偏移
		var p0: Vector2 = sf._world.position
		sf._world.position += Vector2(30, -20)
		if not sf._world.position.is_equal_approx(p0 + Vector2(30, -20)):
			ok = false; msg = "平移未生效"

		# 4) 复位 tween 应被创建
		sf.reset_camera()
		if sf._camera_tween == null:
			ok = false; msg = "reset_camera 未创建 tween"

		# 5) 禁用标志
		sf.set_camera_enabled(false)
		if sf._camera_enabled:
			ok = false; msg = "set_camera_enabled(false) 未生效"

	if ok:
		print("CAMERA_RIG: PASS")
	else:
		print("CAMERA_RIG: FAIL - " + msg)
	quit()
