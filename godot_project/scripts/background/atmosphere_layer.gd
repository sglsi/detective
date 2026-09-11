class_name AtmosphereLayer
extends Control

## 场景氛围层（Tier 1 #4）：暗角 + 煤气灯暖光闪烁 + 雾气漂移 + 浮尘粒子。
## 复用 shaders/fog_atmosphere.gdshader 做屏幕合成（暗角/灯光/雾），
## 另叠加一层 GPUParticles2D 浮尘（世界坐标，随摄像机缩放/平移）。
## 挂载到 SceneFramework._world（z 介于背景 -10 与立绘 0 之间，本层内部 z=-5/-4）。

const FOG_SHADER := preload("res://shaders/fog_atmosphere.gdshader")

var _mat: ShaderMaterial = null

## cfg 字段（均可选，缺省用合理值）：
##   vignette: float        暗角强度（默认 1.0）
##   fog: float             雾气密度（默认 0.22）
##   fog_color: Color       雾色（默认冷灰蓝）
##   lamps: Array[Vector2]  灯光在「场景区域归一化 UV(0..1)」中的位置，最多 2 盏
##   lamp_intensity: float  灯光强度（默认 1.0）
##   lamp_radius: float     灯光半径（默认 0.12）
##   dust: bool             是否启用浮尘（默认 true）
## area_size: 世界层尺寸（用于浮尘发射范围与位置）
func configure(cfg: Dictionary, area_size: Vector2) -> void:
	if _mat != null:
		return
	_build_overlay(cfg, area_size)
	if cfg.get("dust", true):
		_build_dust(area_size)

func _build_overlay(cfg: Dictionary, area_size: Vector2) -> void:
	var cr := ColorRect.new()
	cr.name = "atmos_overlay"
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = -5
	_mat = ShaderMaterial.new()
	_mat.shader = FOG_SHADER
	_mat.set_shader_parameter("vignette_strength", cfg.get("vignette", 1.0))
	_mat.set_shader_parameter("fog_density", cfg.get("fog", 0.22))
	var fc: Color = cfg.get("fog_color", Color(0.22, 0.22, 0.28, 0.35))
	_mat.set_shader_parameter("fog_color", fc)
	var lamps: Array = cfg.get("lamps", [])
	if lamps.size() >= 1 and lamps[0] is Vector2:
		_mat.set_shader_parameter("lamp_1_uv", lamps[0])
	else:
		_mat.set_shader_parameter("lamp_1_uv", Vector2(-1.0, -1.0))
	if lamps.size() >= 2 and lamps[1] is Vector2:
		_mat.set_shader_parameter("lamp_2_uv", lamps[1])
	else:
		_mat.set_shader_parameter("lamp_2_uv", Vector2(-1.0, -1.0))
	_mat.set_shader_parameter("lamp_glow_intensity", cfg.get("lamp_intensity", 1.0))
	_mat.set_shader_parameter("lamp_glow_radius", cfg.get("lamp_radius", 0.12))
	cr.material = _mat
	add_child(cr)

func _build_dust(area_size: Vector2) -> void:
	var dust := GPUParticles2D.new()
	dust.name = "dust"
	dust.z_index = -4
	dust.position = area_size * 0.5
	dust.amount = 60
	dust.lifetime = 14.0
	dust.emitting = true
	dust.texture = _make_soft_dot(32)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(area_size.x * 0.5, area_size.y * 0.5, 0.0)
	# 2D 中 y 向下，direction(0,-1,0) = 向上飘升（贴近暖灯/热气感）
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 30.0
	pm.gravity = Vector3(0.0, -4.0, 0.0)
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 16.0
	pm.scale_min = 0.12
	pm.scale_max = 0.35
	pm.color = Color(1.0, 0.90, 0.72, 0.45)
	dust.process_material = pm
	add_child(dust)

## 生成柔边圆点纹理（白→透明），供浮尘粒子使用。
func _make_soft_dot(px: int = 32) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := float(px) * 0.5
	for y in range(px):
		for x in range(px):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var tex := ImageTexture.create_from_image(img)
	return tex
