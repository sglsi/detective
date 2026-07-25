class_name LondonBackground
extends Node2D

## Controls the London background drawing:
## - Slow cinematic camera pan across the scene.
## - Day / dusk / night atmosphere presets.
## - Toggles atmospheric fog overlay and gas-lamp glow.

@export_group("Camera")
@export var pan_speed: float = 8.0
@export var pan_range: float = 120.0
@export var auto_pan: bool = true

@export_group("Atmosphere")
@export var fog_overlay: ColorRect
@export var fog_material: ShaderMaterial
@export_enum("Day", "Dusk", "Night", "Foggy") var atmosphere_preset: String = "Dusk"

@export_group("Lamps")
@export var draw_lamp_glow: bool = true

@onready var camera: Camera2D = $Camera2D
@onready var lamps: Node2D = $GasLamps

var _pan_direction: int = 1


func _ready() -> void:
    if not fog_material:
        var atmosphere: CanvasLayer = $Atmosphere
        if atmosphere:
            var overlay: ColorRect = atmosphere.get_node("FogOverlay")
            if overlay and overlay.material is ShaderMaterial:
                fog_material = overlay.material as ShaderMaterial
    _apply_atmosphere_preset(atmosphere_preset)
    if camera and auto_pan:
        camera.position.x = 960.0 - pan_range


func _process(delta: float) -> void:
    if camera and auto_pan:
        camera.position.x += pan_speed * _pan_direction * delta
        if camera.position.x >= 960.0 + pan_range:
            _pan_direction = -1
        elif camera.position.x <= 960.0 - pan_range:
            _pan_direction = 1

    if lamps:
        lamps.visible = draw_lamp_glow


func _apply_atmosphere_preset(preset: String) -> void:
    if not fog_material:
        push_warning("Fog material not assigned; atmosphere preset skipped.")
        return

    match preset:
        "Day":
            fog_material.set_shader_parameter("fog_color", Color(0.65, 0.70, 0.78, 0.12))
            fog_material.set_shader_parameter("fog_density", 0.15)
            fog_material.set_shader_parameter("vignette_strength", 0.6)
            fog_material.set_shader_parameter("lamp_glow_intensity", 0.0)
        "Dusk":
            fog_material.set_shader_parameter("fog_color", Color(0.25, 0.22, 0.30, 0.35))
            fog_material.set_shader_parameter("fog_density", 0.35)
            fog_material.set_shader_parameter("vignette_strength", 1.1)
            fog_material.set_shader_parameter("lamp_glow_intensity", 0.9)
        "Night":
            fog_material.set_shader_parameter("fog_color", Color(0.08, 0.09, 0.14, 0.55))
            fog_material.set_shader_parameter("fog_density", 0.55)
            fog_material.set_shader_parameter("vignette_strength", 1.6)
            fog_material.set_shader_parameter("lamp_glow_intensity", 1.4)
        "Foggy":
            fog_material.set_shader_parameter("fog_color", Color(0.30, 0.30, 0.33, 0.60))
            fog_material.set_shader_parameter("fog_density", 0.65)
            fog_material.set_shader_parameter("vignette_strength", 1.0)
            fog_material.set_shader_parameter("lamp_glow_intensity", 1.1)


func set_atmosphere(preset: String) -> void:
    atmosphere_preset = preset
    _apply_atmosphere_preset(preset)


func set_camera_position(x: float) -> void:
    if camera:
        camera.position.x = clamp(x, 960.0 - pan_range, 960.0 + pan_range)
        auto_pan = false
