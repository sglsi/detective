class_name GasLampGlow
extends Node2D

## Procedurally draws warm gas-lamp glows on top of the background.
## Lamp positions are defined in UV-normalized coordinates (0..1) and
## mapped to the current viewport size.

@export var lamp_positions: Array[Vector2] = [
    Vector2(0.265, 0.42),
    Vector2(0.78, 0.52),
]
@export var lamp_color: Color = Color(1.0, 0.72, 0.35, 0.55)
@export var lamp_radius: float = 90.0
@export var flicker_speed: float = 6.0

var _time: float = 0.0


func _ready() -> void:
    # 灯光层应位于背景之上、人物立绘与推理墙之下。
    z_index = -5


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    var vp_size: Vector2 = get_viewport_rect().size
    for pos in lamp_positions:
        var screen_pos: Vector2 = Vector2(pos.x * vp_size.x, pos.y * vp_size.y)
        var flicker: float = 0.92 + 0.08 * sin(_time * flicker_speed) * sin(_time * flicker_speed * 1.7)
        var radius: float = lamp_radius * flicker
        var color: Color = lamp_color
        color.a *= flicker
        draw_circle(screen_pos, radius, color)
