shader_type canvas_item;

// Simple sky gradient used behind the buildings if the background is cropped.
// Can also be applied to a ColorRect placed under the Sprite2D.

uniform vec4 top_color : source_color = vec4(0.35, 0.42, 0.55, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.92, 0.88, 0.80, 1.0);
uniform float horizon_position : hint_range(0.0, 1.0) = 0.45;
uniform float softening : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    float t = smoothstep(horizon_position - softening, horizon_position + softening, UV.y);
    COLOR = mix(top_color, bottom_color, t);
}
