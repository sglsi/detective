extends SceneTree
func _initialize() -> void:
	await create_timer(0.1).timeout
	var scene2 = load("res://scripts/scene/scene2.gd")
	if scene2 == null:
		print("SCENE2_BG_TEST: FAIL - cannot load scene2.gd")
		quit(1)
		return
	var inst = scene2.new()
	var tex: Texture2D = inst.scene_background()
	if tex == null:
		print("SCENE2_BG_TEST: FAIL - scene_background returned null")
		inst.free()
		quit(1)
		return
	var img: Image = tex.get_image()
	print("SCENE2_BG_TEST: size=%dx%d format=%s path=%s / PASS" % [img.get_width(), img.get_height(), img.get_format(), tex.resource_path])
	inst.free()
	quit(0)
