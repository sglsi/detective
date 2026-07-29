class_name ProceduralBackground
extends Control

## 纯程序化维多利亚夜景氛围背景节点。
## 不依赖任何位图：底层 ColorRect 套 ShaderMaterial，由 procedural_background.gdshader 实时绘制
## （fbm 天际线 + 雾 + 暗角 + 煤气灯辉光 + 慢摇）。体积仅几 KB。

@export_group("Atmosphere")
@export_enum("Day", "Dusk", "Night", "Foggy") var preset: String = "Night"
@export var auto_pan: bool = true
@export var pan_speed: float = 0.006
@export var pan_range: float = 0.02

var _mat: ShaderMaterial
var _pan_dir := 1.0
var _pan := 0.0

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/procedural_background.gdshader")
	var cr := ColorRect.new()
	cr.material = _mat
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = -10
	add_child(cr)
	apply_preset(preset)

func _process(delta: float) -> void:
	if auto_pan and _mat:
		_pan += pan_speed * _pan_dir * delta
		if _pan >= pan_range:
			_pan_dir = -1.0
		elif _pan <= -pan_range:
			_pan_dir = 1.0
		_mat.set_shader_parameter("pan_offset", _pan)

func apply_preset(p: String) -> void:
	preset = p
	if not _mat:
		return
	match p:
		"Day":
			_mat.set_shader_parameter("sky_top", Color(0.45, 0.55, 0.72))
			_mat.set_shader_parameter("sky_bottom", Color(0.85, 0.82, 0.78))
			_mat.set_shader_parameter("fog_color", Color(0.70, 0.74, 0.80, 0.30))
			_mat.set_shader_parameter("fog_density", 0.18)
			_mat.set_shader_parameter("vignette_strength", 0.6)
			_mat.set_shader_parameter("lamp_glow_intensity", 0.0)
			_mat.set_shader_parameter("window_glow", 0.5)
		"Dusk":
			_mat.set_shader_parameter("sky_top", Color(0.18, 0.16, 0.28))
			_mat.set_shader_parameter("sky_bottom", Color(0.55, 0.35, 0.25))
			_mat.set_shader_parameter("fog_color", Color(0.30, 0.25, 0.30, 0.40))
			_mat.set_shader_parameter("fog_density", 0.35)
			_mat.set_shader_parameter("vignette_strength", 1.1)
			_mat.set_shader_parameter("lamp_glow_intensity", 0.9)
			_mat.set_shader_parameter("window_glow", 0.6)
		"Night":
			_mat.set_shader_parameter("sky_top", Color(0.04, 0.05, 0.11))
			_mat.set_shader_parameter("sky_bottom", Color(0.20, 0.15, 0.17))
			_mat.set_shader_parameter("fog_color", Color(0.20, 0.22, 0.28, 0.55))
			_mat.set_shader_parameter("fog_density", 0.40)
			_mat.set_shader_parameter("vignette_strength", 1.25)
			_mat.set_shader_parameter("lamp_glow_intensity", 1.3)
			_mat.set_shader_parameter("window_glow", 0.6)
		"Foggy":
			_mat.set_shader_parameter("sky_top", Color(0.10, 0.11, 0.14))
			_mat.set_shader_parameter("sky_bottom", Color(0.30, 0.30, 0.33))
			_mat.set_shader_parameter("fog_color", Color(0.32, 0.33, 0.36, 0.65))
			_mat.set_shader_parameter("fog_density", 0.65)
			_mat.set_shader_parameter("vignette_strength", 1.0)
			_mat.set_shader_parameter("lamp_glow_intensity", 1.1)
			_mat.set_shader_parameter("window_glow", 0.4)
