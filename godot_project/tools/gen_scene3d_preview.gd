extends SceneTree

const OUT := "D:/AI/workbuddy/Claw/outputs/gen_scene3d_preview.png"

func _initialize() -> void:
	await create_timer(0.2).timeout
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 960)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	var scene := build_scene()
	vp.add_child(scene)

	await create_timer(0.9).timeout
	var tex := vp.get_texture()
	var img := tex.get_image()
	if img:
		img.save_png(OUT)
		print("SAVED ", OUT, " ", img.get_size())
	else:
		print("NO IMAGE (render not ready)")
	quit()

func mat(col: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	return m

func add_box(p: Node3D, pos: Vector3, size: Vector3, col: Color, rough := 0.85) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(col, rough)
	mi.position = pos
	p.add_child(mi)

func add_plane(p: Node3D, pos: Vector3, rot: Vector3, size: Vector2, col: Color, rough := 0.9) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat(col, rough)
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)

func build_scene() -> Node3D:
	var r := Node3D.new()
	r.name = "Scene3D"

	# 环境光（避免暗部死黑）
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.04, 0.06)
	e.ambient_light_color = Color(0.45, 0.42, 0.38)
	e.ambient_light_energy = 0.80
	env.environment = e
	r.add_child(env)

	# 窗光：方向光从左前窗外打入
	var sun := DirectionalLight3D.new()
	sun.position = Vector3(-6, 7, 6)
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_color = Color(1.0, 0.96, 0.82)
	sun.light_energy = 1.7
	r.add_child(sun)

	# 壁炉暖光
	var fire := OmniLight3D.new()
	fire.position = Vector3(3.2, 0.9, -3.2)
	fire.light_color = Color(1.0, 0.55, 0.22)
	fire.light_energy = 3.0
	fire.omni_range = 6.5
	r.add_child(fire)

	# 地板（木，棕）— PlaneMesh 默认法线 +Y，无需旋转即为水平朝上
	add_plane(r, Vector3(0, 0, 0), Vector3(0, 0, 0), Vector2(12, 9), Color(0.42, 0.30, 0.17))
	# 地毯（红，略高于地板）
	add_box(r, Vector3(-0.5, 0.02, 0.5), Vector3(5.0, 0.04, 3.6), Color(0.5, 0.12, 0.12))
	# 后墙（绿）— 法线朝 +Z
	add_plane(r, Vector3(0, 1.5, -4.5), Vector3(PI/2, 0, 0), Vector2(12, 3), Color(0.38, 0.52, 0.34))
	# 左墙（绿）— 法线朝 +X
	add_plane(r, Vector3(-6, 1.5, 0), Vector3(0, 0, -PI/2), Vector2(9, 3), Color(0.35, 0.48, 0.31))
	# 右墙（绿）— 法线朝 -X
	add_plane(r, Vector3(6, 1.5, 0), Vector3(0, 0, PI/2), Vector2(9, 3), Color(0.35, 0.48, 0.31))
	# 天花板— 法线朝下
	add_plane(r, Vector3(0, 3, 0), Vector3(PI, 0, 0), Vector2(12, 9), Color(0.55, 0.53, 0.50))
	# 窗（后墙上的浅蓝）— 法线朝 +Z
	add_plane(r, Vector3(-3.5, 1.7, -4.49), Vector3(PI/2, 0, 0), Vector2(2.2, 1.6), Color(0.6, 0.75, 0.9), 0.4)
	# 画框（后墙，金边浅画）— 法线朝 +Z
	add_plane(r, Vector3(2.5, 1.8, -4.49), Vector3(PI/2, 0, 0), Vector2(1.6, 1.2), Color(0.8, 0.7, 0.5), 0.6)

	# 沙发（棕，靠后墙前）
	add_box(r, Vector3(-1.0, 0.35, -3.0), Vector3(2.6, 0.5, 1.0), Color(0.52, 0.34, 0.20))  # 座
	add_box(r, Vector3(-1.0, 0.85, -3.4), Vector3(2.6, 0.6, 0.4), Color(0.48, 0.30, 0.18))  # 靠背
	add_box(r, Vector3(-2.3, 0.55, -3.0), Vector3(0.4, 0.7, 1.0), Color(0.48, 0.30, 0.18))  # 左扶手
	add_box(r, Vector3(0.3, 0.55, -3.0), Vector3(0.4, 0.7, 1.0), Color(0.48, 0.30, 0.18))   # 右扶手
	add_box(r, Vector3(-2.0, 0.12, -3.4), Vector3(0.2, 0.24, 0.2), Color(0.25, 0.16, 0.08))
	add_box(r, Vector3(0.0, 0.12, -3.4), Vector3(0.2, 0.24, 0.2), Color(0.25, 0.16, 0.08))

	# 书柜（左墙边）
	add_box(r, Vector3(-5.2, 1.2, 1.0), Vector3(0.6, 2.4, 3.0), Color(0.40, 0.27, 0.15))
	for i in 5:
		add_box(r, Vector3(-4.85, 0.6 + i * 0.4, 0.2), Vector3(0.3, 0.3, 0.5),
			Color(randf_range(0.4, 0.8), randf_range(0.2, 0.5), randf_range(0.2, 0.5)))

	# 壁炉（右墙边，大理石白）
	add_box(r, Vector3(5.0, 0.8, -3.0), Vector3(0.8, 1.6, 2.0), Color(0.80, 0.78, 0.74))
	add_box(r, Vector3(5.0, 0.5, -3.0), Vector3(0.6, 0.8, 1.6), Color(0.20, 0.10, 0.05))

	# 圆桌（Cylinder 桌面）+ 桌腿
	var tmi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7; cm.bottom_radius = 0.7; cm.height = 0.1
	tmi.mesh = cm
	tmi.material_override = mat(Color(0.55, 0.38, 0.20))
	tmi.position = Vector3(-2.5, 0.75, -0.5)
	r.add_child(tmi)
	add_box(r, Vector3(-2.5, 0.37, -0.5), Vector3(0.15, 0.7, 0.15), Color(0.40, 0.27, 0.15))
	# 椅
	add_box(r, Vector3(-2.5, 0.45, -1.8), Vector3(0.7, 0.1, 0.7), Color(0.45, 0.30, 0.17))
	add_box(r, Vector3(-2.5, 0.75, -2.1), Vector3(0.7, 0.7, 0.1), Color(0.45, 0.30, 0.17))
	add_box(r, Vector3(-2.5, 0.22, -1.8), Vector3(0.1, 0.45, 0.1), Color(0.40, 0.27, 0.15))

	# 相机：房间内第一人称视角，面向沙发与壁炉
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 65.0
	r.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.55, 4.3), Vector3(0, 0.6, -2.5), Vector3.UP)

	return r
