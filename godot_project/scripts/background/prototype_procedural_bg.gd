extends Control

## 独立原型预览场景：挂载 ProceduralBackground，并提供 4 个预设切换按钮。
## 在 Godot 编辑器按 F6，或 Web 版打开此场景即可对比程序化氛围背景效果。
const PB = preload("res://scripts/background/procedural_background.gd")

var _bg

func _ready() -> void:
	_bg = PB.new()
	_bg.name = "ProceduralBG"
	add_child(_bg)

	var bar := HBoxContainer.new()
	bar.position = Vector2(20, 20)
	add_child(bar)

	var label := Label.new()
	label.text = "氛围预设："
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	bar.add_child(label)

	for p in ["Day", "Dusk", "Night", "Foggy"]:
		var b := Button.new()
		b.text = p
		b.pressed.connect(_on_preset.bind(p))
		bar.add_child(b)

func _on_preset(p: String) -> void:
	_bg.apply_preset(p)
