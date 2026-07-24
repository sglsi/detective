extends Control

func _ready() -> void:
	print("Sherlock Assets Demo ready")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
