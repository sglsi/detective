extends Node2D

## 活场景层 demo（场景一会客厅）——独立演示场景，不接主游戏。
## 分层视差 + 体积光尘粒子 + 壁炉余烬 + 窗外云 + 鼠标视差 + 相机漂移。
## URL 带 #alive 时由 main_menu 切入。

const BG_PATH := "res://assets/backgrounds/screen01-sofa01.jpg"
const FG_PATH := "res://assets/backgrounds/alive/fg_silhouette.png"

# sofa01 实测归一化坐标（多模态读图定标）
const WIN_MIN := Vector2(0.030, 0.005)
const WIN_MAX := Vector2(0.125, 0.500)
const HEARTH_UV := Vector2(0.89, 0.72)
const CORE_UV := Vector2(0.87, 0.78)
const DUST_RECT := Rect2(0.76, 330.0, 830.0, 570.0)  # 光束带（px, 1920x1080 视口）

const BG_SCALE := 0.52
const FG_SCALE := 0.575
const PARALLAX_BG := 16.0
const PARALLAX_FG := 38.0
const DRIFT_AMP := 7.0

var _t := 0.0
var _bg: Sprite2D
var _fg: Sprite2D
var _mouse_smooth := Vector2.ZERO

func _ready() -> void:
	var vp := Vector2(1920, 1080)

	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.z_index = -9
	add_child(copy)

	_bg = _mk_sprite(BG_PATH, BG_SCALE, vp)
	_bg.z_index = -10
	add_child(_bg)

	add_child(_mk_cloud_layer(vp, -8))
	add_child(_mk_fire_layer(vp, -7))
	add_child(_mk_dust(vp, -5))

	_fg = _mk_sprite(FG_PATH, FG_SCALE, vp)
	_fg.z_index = 0
	_fg.modulate = Color(0.82, 0.80, 0.78)
	add_child(_fg)

func _mk_sprite(path: String, sc: float, vp: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.centered = false
	sp.scale = Vector2(sc, sc)
	sp.position = (vp - sp.texture.get_size() * sc) * 0.5
	return sp

func _mk_layer_rect(vp: Vector2, z: int, shader_path: String, params: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.size = vp
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	r.material = m
	return r

func _mk_cloud_layer(vp: Vector2, z: int) -> ColorRect:
	return _mk_layer_rect(vp, z, "res://shaders/window_clouds.gdshader", {
		"win_min": WIN_MIN,
		"win_max": WIN_MAX,
		"edge_soft": 0.014,
		"cloud_speed": 0.005,
		"cloud_density": 0.45,
	})

func _mk_fire_layer(vp: Vector2, z: int) -> ColorRect:
	return _mk_layer_rect(vp, z, "res://shaders/fire_flicker.gdshader", {
		"hearth_uv": HEARTH_UV,
		"core_uv": CORE_UV,
		"hearth_radius": 0.17,
		"core_radius": 0.055,
		"intensity": 0.72,
	})

func _mk_dust(vp: Vector2, z: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.z_index = z
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = DUST_RECT.position + DUST_RECT.size * 0.5
	p.texture = _mk_dust_texture()

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(DUST_RECT.size.x * 0.5, DUST_RECT.size.y * 0.5, 0.0)
	pm.direction = Vector3(0.25, -1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -1.5, 0)
	pm.angular_velocity_min = -8.0
	pm.angular_velocity_max = 8.0
	pm.scale_min = 0.35
	pm.scale_max = 1.25
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.86, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.96, 0.82, 0.5))
	ramp.add_point(0.75, Color(1.0, 0.94, 0.78, 0.4))
	ramp.set_color(1, Color(1.0, 0.94, 0.8, 0.0))
	pm.color_ramp = _mk_ramp(ramp)
	p.process_material = pm
	return p

func _mk_ramp(g: Gradient) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _mk_dust_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 16
	t.height = 16
	return t

func _process(delta: float) -> void:
	_t += delta
	var drift := Vector2(sin(_t * 0.11) * DRIFT_AMP, cos(_t * 0.07) * DRIFT_AMP * 0.6)
	var m := _mouse_norm()
	_mouse_smooth = _mouse_smooth.lerp(m, minf(delta * 2.2, 1.0))
	var par := _mouse_smooth
	_bg.position += (drift * 0.4 + Vector2(-par.x * PARALLAX_BG, -par.y * PARALLAX_BG * 0.5)) * delta * 12.0
	_fg.position += (drift + Vector2(-par.x * PARALLAX_FG, -par.y * PARALLAX_FG * 0.5)) * delta * 12.0

func _mouse_norm() -> Vector2:
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return Vector2.ZERO
	return (Vector2(clampf(mp.x / vs.x, 0.0, 1.0), clampf(mp.y / vs.y, 0.0, 1.0)) - Vector2(0.5, 0.5)) * 2.0
