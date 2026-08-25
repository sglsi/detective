extends SceneTree

# 守卫探针：验证 Godot 输入派发是否严格按 z_index。
# 两个全屏 STOP 控件重叠：A(z=100 先 add), B(z=5 后 add)。
# 若 hover/click 命中 A → z 可靠，全屏图谱 + 高 z 浮层可行；
# 若命中 B（后 add 的反而优先）→ 命中按树序，全屏会被后挂载的图谱盖住。

var hits := {}

func _on_gui(event: InputEvent, who: Node) -> void:
	hits[who] = hits.get(who, 0) + 1

func _init() -> void:
	var win := get_root()
	var root_c := Control.new()
	root_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_c.name = "ROOT"
	win.add_child(root_c)

	var A := Control.new()
	A.name = "A_HIGHZ"
	A.mouse_filter = Control.MOUSE_FILTER_STOP
	A.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	A.z_index = 100
	root_c.add_child(A)
	A.gui_input.connect(_on_gui.bind(A.name))

	var B := Control.new()
	B.name = "B_LOWZ"
	B.mouse_filter = Control.MOUSE_FILTER_STOP
	B.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	B.z_index = 5
	root_c.add_child(B)
	B.gui_input.connect(_on_gui.bind(B.name))

	await process_frame
	await process_frame

	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(200, 200)
	Input.parse_input_event(mv)
	await process_frame
	var hovered := win.gui_get_hovered_control()
	print("HOVERED=", hovered.name if hovered else "null")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(200, 200)
	click.global_position = Vector2(200, 200)
	Input.parse_input_event(click)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(200, 200)
	release.global_position = Vector2(200, 200)
	Input.parse_input_event(release)
	await process_frame

	print("A_HIGHZ hits=", hits.get("A_HIGHZ", 0), " B_LOWZ hits=", hits.get("B_LOWZ", 0))
	quit()