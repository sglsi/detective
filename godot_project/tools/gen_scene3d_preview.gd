extends SceneTree

const OUT := "D:/AI/workbuddy/Claw/outputs/gen_scene3d_preview.png"

func _initialize() -> void:
	await create_timer(0.3).timeout
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1440)          # 更高分辨率，出图更锐利
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.set("msaa", 2)                        # Viewport.MSAA_4X（绕过枚举静态类型检查）
	root.add_child(vp)

	var scene := build_scene()
	vp.add_child(scene)

	# 留足 CSG 布尔烘焙时间
	await create_timer(1.8).timeout
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

func mat_tex(tex: Texture2D, base := Color(1, 1, 1), rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = base
	m.roughness = rough
	m.metallic = 0.0
	return m

func add_box(p: Node3D, pos: Vector3, size: Vector3, col: Color, rough := 0.85, cast := true,
		m: StandardMaterial3D = null) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m if m else mat(col, rough)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

func add_plane(p: Node3D, pos: Vector3, rot: Vector3, size: Vector2, col: Color, rough := 0.9,
		cast := true, m: StandardMaterial3D = null) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m if m else mat(col, rough)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

# ---------- 程序化纹理 ----------
func make_carpet_texture() -> ImageTexture:
	var w := 256; var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color(0.45, 0.11, 0.11)
			var dx := absi((x % 64) - 32)
			var dy := absi((y % 64) - 32)
			if dx + dy < 5:
				c = Color(0.80, 0.64, 0.26)        # 金色菱形线
			elif (x % 32 == 0) or (y % 32 == 0):
				c = c * 0.82
			if y < 12 or y > h - 12 or x < 12 or x > w - 12:
				c = Color(0.80, 0.64, 0.26)        # 金边
			var n := (sin(x * 0.7) + cos(y * 0.9)) * 0.02
			c = c + Color(n, n, n)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_local_to_scene = true
	return tex

func make_curtain_texture() -> ImageTexture:
	var w := 128; var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color(0.58, 0.28, 0.28)
	for y in h:
		for x in w:
			var fold := sin(x * PI * 6.0 / float(w))
			var c := base + Color(fold * 0.12, fold * 0.08, fold * 0.09)
			var n := sin(y * 0.6) * 0.02
			c = c + Color(n, n, n)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_local_to_scene = true
	return tex

func make_wood_texture() -> ImageTexture:
	var w := 256; var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var plank := y / 32
		for x in w:
			var c := Color(0.40, 0.28, 0.16)
			var v := sin(float(plank) * 12.9898) * 0.5      # 每块板轻微色差
			c = c + Color(v * 0.05, v * 0.04, v * 0.03)
			var grain := sin(float(x) * 0.35 + float(plank) * 3.0) * 0.03  # 木纹
			c = c + Color(grain, grain * 0.8, grain * 0.6)
			if (y % 32) < 2:                                # 板缝暗线
				c = c * 0.55
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_local_to_scene = true
	return tex

func make_wallpaper_texture() -> ImageTexture:
	var w := 128; var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color(0.36, 0.50, 0.33)
			if (x % 16) < 3:                                # 竖条纹
				c = Color(0.43, 0.57, 0.39)
			var n := sin(float(x) * 1.7) * 0.015 + sin(float(y) * 0.9) * 0.015
			c = c + Color(n, n, n)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_local_to_scene = true
	return tex

func make_canvas_texture() -> ImageTexture:
	var w := 128; var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h)
		for x in w:
			var c := Color(0.58, 0.72, 0.86).lerp(Color(0.34, 0.48, 0.30), t)
			if t > 0.55 and t < 0.62:                       # 地平线压暗
				c = c * 0.78
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_local_to_scene = true
	return tex

# ---------- CSG 圆润沙发（UNION：盒体 + 圆柱扶手/坐垫/靠垫） ----------
func make_sofa() -> CSGCombiner3D:
	var comb := CSGCombiner3D.new()
	comb.operation = CSGCombiner3D.OPERATION_UNION
	var m := mat(Color(0.50, 0.32, 0.18))
	var seat := CSGBox3D.new(); seat.size = Vector3(2.6, 0.45, 1.0); seat.position = Vector3(0, 0.225, 0)
	var back := CSGBox3D.new(); back.size = Vector3(2.6, 0.7, 0.35); back.position = Vector3(0, 0.8, -0.32)
	var larm := CSGCylinder3D.new(); larm.radius = 0.2; larm.height = 1.0; larm.rotation = Vector3(PI/2, 0, 0)
	larm.position = Vector3(-1.3, 0.55, 0)
	var rarm := CSGCylinder3D.new(); rarm.radius = 0.2; rarm.height = 1.0; rarm.rotation = Vector3(PI/2, 0, 0)
	rarm.position = Vector3(1.3, 0.55, 0)
	var cush := CSGCylinder3D.new(); cush.radius = 0.17; cush.height = 1.15; cush.rotation = Vector3(0, 0, PI/2)
	cush.position = Vector3(-0.62, 0.5, 0.06)
	var cush2 := CSGCylinder3D.new(); cush2.radius = 0.17; cush2.height = 1.15; cush2.rotation = Vector3(0, 0, PI/2)
	cush2.position = Vector3(0.62, 0.5, 0.06)
	var bcush := CSGCylinder3D.new(); bcush.radius = 0.13; bcush.height = 1.05; bcush.rotation = Vector3(0, 0, PI/2)
	bcush.position = Vector3(-0.6, 0.82, -0.16)
	var bcush2 := CSGCylinder3D.new(); bcush2.radius = 0.13; bcush2.height = 1.05; bcush2.rotation = Vector3(0, 0, PI/2)
	bcush2.position = Vector3(0.6, 0.82, -0.16)
	for c in [seat, back, larm, rarm, cush, cush2, bcush, bcush2]:
		c.material = m
		comb.add_child(c)
	comb.position = Vector3(-1.0, 0.0, -3.0)
	return comb

# ---------- CSG 布尔壁炉（SUBTRACTION：盒体 - 拱形炉膛 - 顶角圆化） ----------
func make_fireplace() -> CSGCombiner3D:
	var comb := CSGCombiner3D.new()
	comb.operation = CSGCombiner3D.OPERATION_SUBTRACTION
	var marble := mat(Color(0.82, 0.80, 0.76))
	var body := CSGBox3D.new(); body.size = Vector3(0.9, 1.7, 2.0); body.position = Vector3(0, 0.85, 0)
	body.material = marble
	comb.add_child(body)
	# 拱形炉膛开口：方块（上部）+ 半球（下部）做并集后从正面挖穿
	var hole := CSGCombiner3D.new(); hole.operation = CSGCombiner3D.OPERATION_UNION
	var hb := CSGBox3D.new(); hb.size = Vector3(0.5, 0.5, 1.8); hb.position = Vector3(0, 0.45, 0)
	var hs := CSGSphere3D.new(); hs.radius = 0.25; hs.position = Vector3(0, 0.20, 0)
	hole.add_child(hb); hole.add_child(hs)
	hole.position = Vector3(0, 0.0, 0.1)
	comb.add_child(hole)
	# 顶部两前角削圆
	var cL := CSGSphere3D.new(); cL.radius = 0.16; cL.position = Vector3(-0.45, 1.62, -1.0)
	var cR := CSGSphere3D.new(); cR.radius = 0.16; cR.position = Vector3(0.45, 1.62, -1.0)
	comb.add_child(cL); comb.add_child(cR)
	comb.position = Vector3(5.0, 0.0, -3.0)
	return comb

func add_curtain(p: Node3D, pos: Vector3, size: Vector2, m: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = size
	mi.mesh = pm; mi.material_override = m; mi.position = pos
	# 默认 PlaneMesh 水平朝上；旋转使其竖直并朝向房间 (+Z)
	mi.rotation = Vector3(PI/2, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

func build_scene() -> Node3D:
	var r := Node3D.new()
	r.name = "Scene3D"

	# ---------- 环境与后期（Forward+ 下生效；Compatibility 自动忽略 SSAO/SSIL） ----------
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_color = Color(0.48, 0.46, 0.42)
	e.ambient_light_energy = 0.85
	e.set("tonemap_mode", 2)      # FILMIC 色调映射
	e.tonemap_exposure = 1.12
	e.ssao_enabled = true         # 环境光遮蔽（缝隙/墙角变暗，体积感提升）
	e.ssao_radius = 0.6
	e.ssao_intensity = 1.5
	e.ssil_enabled = true         # 间接光
	e.ssil_radius = 2.5
	e.ssil_intensity = 1.2
	e.glow_enabled = true         # Bloom，火光/灯泡溢出
	e.glow_intensity = 0.55
	e.glow_bloom = 0.30
	e.glow_hdr_threshold = 1.0
	env.environment = e
	r.add_child(env)

	# ---------- 灯光 ----------
	# 窗光：方向光（主光，投影）
	var sun := DirectionalLight3D.new()
	sun.position = Vector3(-6, 7, 6)
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_color = Color(1.0, 0.96, 0.82)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 22.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 0.10
	r.add_child(sun)

	# 补光：从右后方来的柔和方向光，不投影，抬亮暗部
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(-125), 0)
	fill.light_color = Color(0.58, 0.64, 0.74)
	fill.light_energy = 0.55
	r.add_child(fill)

	# 壁炉暖光（投影）
	var fire := OmniLight3D.new()
	fire.position = Vector3(3.2, 0.9, -3.2)
	fire.light_color = Color(1.0, 0.55, 0.22)
	fire.light_energy = 3.0
	fire.omni_range = 6.5
	fire.shadow_enabled = true
	fire.shadow_bias = 0.04
	r.add_child(fire)

	# ---------- 材质（程序化纹理） ----------
	var wood_mat := mat_tex(make_wood_texture(), Color(1, 1, 1), 0.85)
	wood_mat.uv1_scale = Vector3(4, 3, 1)
	var wall_mat := mat_tex(make_wallpaper_texture(), Color(1, 1, 1), 0.92)
	wall_mat.uv1_scale = Vector3(8, 2, 1)

	# ---------- 外壳：地板/墙/天花板 ----------
	add_plane(r, Vector3(0, 0, 0), Vector3(0, 0, 0), Vector2(12, 9), Color(1, 1, 1), 0.85, false, wood_mat)     # 木地板
	add_plane(r, Vector3(0, 1.5, -4.5), Vector3(PI/2, 0, 0), Vector2(12, 3), Color(1, 1, 1), 0.92, false, wall_mat) # 后墙
	add_plane(r, Vector3(-6, 1.5, 0), Vector3(0, 0, -PI/2), Vector2(9, 3), Color(1, 1, 1), 0.92, false, wall_mat)  # 左墙
	add_plane(r, Vector3(6, 1.5, 0), Vector3(0, 0, PI/2), Vector2(9, 3), Color(1, 1, 1), 0.92, false, wall_mat)   # 右墙
	add_plane(r, Vector3(0, 3, 0), Vector3(PI, 0, 0), Vector2(12, 9), Color(0.62, 0.60, 0.57), 0.95, false)       # 天花板

	# 踢脚线（细节，增加完成度）
	add_box(r, Vector3(0, 0.07, -4.44), Vector3(12, 0.14, 0.06), Color(0.72, 0.68, 0.60), 0.8, false)
	add_box(r, Vector3(-5.94, 0.07, 0), Vector3(0.06, 0.14, 9), Color(0.72, 0.68, 0.60), 0.8, false)
	add_box(r, Vector3(5.94, 0.07, 0), Vector3(0.06, 0.14, 9), Color(0.72, 0.68, 0.60), 0.8, false)

	# 窗（后墙，浅蓝）
	add_plane(r, Vector3(-3.5, 1.7, -4.49), Vector3(PI/2, 0, 0), Vector2(2.2, 1.6), Color(0.62, 0.77, 0.92), 0.35, false)

	# 画：金色外框 + 风景画布
	var canvas_mat := mat_tex(make_canvas_texture(), Color(1, 1, 1), 0.85)
	add_plane(r, Vector3(2.5, 1.8, -4.48), Vector3(PI/2, 0, 0), Vector2(1.75, 1.35), Color(0.72, 0.58, 0.24), 0.5, false)
	add_plane(r, Vector3(2.5, 1.8, -4.46), Vector3(PI/2, 0, 0), Vector2(1.5, 1.1), Color(1, 1, 1), 0.85, false, canvas_mat)

	# ---------- 地毯（程序化纹理） ----------
	var carpet_mat := mat_tex(make_carpet_texture(), Color(1, 1, 1), 0.95)
	carpet_mat.uv1_scale = Vector3(3, 2, 1)
	add_box(r, Vector3(-0.5, 0.03, 0.5), Vector3(5.0, 0.06, 3.6), Color(1, 1, 1), 0.95, false, carpet_mat)

	# ---------- 家具 ----------
	var sofa := make_sofa()
	sofa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	r.add_child(sofa)

	# 书柜 + 彩色书脊
	add_box(r, Vector3(-5.2, 1.2, 1.0), Vector3(0.6, 2.4, 3.0), Color(0.40, 0.27, 0.15))
	for i in 5:
		add_box(r, Vector3(-4.85, 0.6 + i * 0.4, 0.2), Vector3(0.3, 0.3, 0.5),
			Color(randf_range(0.4, 0.8), randf_range(0.2, 0.5), randf_range(0.2, 0.5)))

	# 壁炉（CSG 布尔拱形）+ 壁炉台 + 花瓶 + 炉膛火光
	var fp := make_fireplace()
	fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	r.add_child(fp)
	add_box(r, Vector3(5.0, 1.78, -3.0), Vector3(1.15, 0.10, 2.25), Color(0.84, 0.82, 0.78), 0.7)  # 壁炉台
	var vase := MeshInstance3D.new(); var vm := CylinderMesh.new()
	vm.top_radius = 0.07; vm.bottom_radius = 0.10; vm.height = 0.26
	vase.mesh = vm; vase.material_override = mat(Color(0.30, 0.42, 0.55), 0.35)
	vase.position = Vector3(5.0, 1.96, -2.7); r.add_child(vase)
	var fb := MeshInstance3D.new(); var fbm := BoxMesh.new(); fbm.size = Vector3(0.4, 0.12, 0.4)
	var fmat := StandardMaterial3D.new()
	fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.45, 0.12); fmat.emission_energy = 2.4
	fmat.albedo_color = Color(0.2, 0.1, 0.05)
	fb.mesh = fbm; fb.material_override = fmat
	fb.position = Vector3(5.0, 0.28, -2.55)
	fb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(fb)

	# 圆桌 + 椅
	var tmi := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = 0.7; cm.bottom_radius = 0.7; cm.height = 0.1
	tmi.mesh = cm; tmi.material_override = mat(Color(0.55, 0.38, 0.20)); tmi.position = Vector3(-2.5, 0.75, -0.5)
	r.add_child(tmi)
	add_box(r, Vector3(-2.5, 0.37, -0.5), Vector3(0.15, 0.7, 0.15), Color(0.40, 0.27, 0.15))
	add_box(r, Vector3(-2.5, 0.45, -1.8), Vector3(0.7, 0.1, 0.7), Color(0.45, 0.30, 0.17))
	add_box(r, Vector3(-2.5, 0.75, -2.1), Vector3(0.7, 0.7, 0.1), Color(0.45, 0.30, 0.17))
	add_box(r, Vector3(-2.5, 0.22, -1.8), Vector3(0.1, 0.45, 0.1), Color(0.40, 0.27, 0.15))

	# ---------- 吊灯（灯罩 + 发光灯泡 + 点光源 + 吊线） ----------
	add_box(r, Vector3(0, 2.86, -1.0), Vector3(0.02, 0.52, 0.02), Color(0.25, 0.20, 0.15), 0.7, false)
	var shade := MeshInstance3D.new(); var sm := CylinderMesh.new()
	sm.top_radius = 0.20; sm.bottom_radius = 0.34; sm.height = 0.30
	shade.mesh = sm; shade.material_override = mat(Color(0.86, 0.80, 0.68), 0.55)
	shade.position = Vector3(0, 2.50, -1.0); r.add_child(shade)
	var bulb := MeshInstance3D.new(); var bsm := SphereMesh.new()
	bsm.radius = 0.10; bsm.height = 0.20
	var bmat := StandardMaterial3D.new()
	bmat.emission_enabled = true; bmat.emission = Color(1.0, 0.86, 0.62); bmat.emission_energy = 3.0
	bmat.albedo_color = Color(1, 1, 1)
	bulb.mesh = bsm; bulb.material_override = bmat
	bulb.position = Vector3(0, 2.33, -1.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(bulb)
	var pl := OmniLight3D.new(); pl.position = Vector3(0, 2.28, -1.0)
	pl.light_color = Color(1.0, 0.86, 0.66); pl.light_energy = 2.2; pl.omni_range = 7.5
	pl.shadow_enabled = true; pl.shadow_bias = 0.04
	r.add_child(pl)

	# ---------- 窗帘（程序化纹理，位于窗前） ----------
	var cur_mat := mat_tex(make_curtain_texture(), Color(1, 1, 1), 0.9)
	cur_mat.uv1_scale = Vector3(1, 3, 1)
	add_curtain(r, Vector3(-4.55, 1.55, -4.44), Vector2(0.5, 2.0), cur_mat)
	add_curtain(r, Vector3(-2.45, 1.55, -4.44), Vector2(0.5, 2.0), cur_mat)
	add_curtain(r, Vector3(-3.5, 2.45, -4.44), Vector2(2.6, 0.5), cur_mat)

	# ---------- 相机 ----------
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 62.0
	r.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.55, 4.3), Vector3(0, 0.75, -2.5), Vector3.UP)

	return r
