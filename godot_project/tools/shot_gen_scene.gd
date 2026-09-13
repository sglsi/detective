extends SceneTree
## 用 SubViewport（固定 1280×960）渲染程序化场景并截图，与窗口 stretch 解耦。

func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 960)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)
	var scene: Control = load("res://tools/gen_scene_preview.gd").new()
	sv.add_child(scene)
	for i in 8:
		await process_frame
	var img := sv.get_texture().get_image()
	var out := "D:/AI/workbuddy/Claw/outputs/gen_scene_preview.png"
	img.save_png(out)
	print("SAVED ", out, " ", img.get_width(), "x", img.get_height())
	quit()
