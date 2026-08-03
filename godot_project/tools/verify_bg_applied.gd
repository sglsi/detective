extends SceneTree
func _initialize() -> void:
	await create_timer(0.2).timeout
	for sid in ["scene1","scene2","scene3","scene4","scene5","scene6","scene7","scene8"]:
		var ps = load("res://scenes/%s.tscn" % sid)
		if ps == null:
			print("VERIFY %s: tscn MISSING" % sid); continue
		var inst = ps.instantiate()
		root.add_child(inst)
		await create_timer(0.35).timeout
		var bg = inst.get_node_or_null("ui/scene_area/scene_bg")
		if bg != null and bg is TextureRect and bg.texture != null:
			print("VERIFY %s: scene_bg OK  tex=%s" % [sid, bg.texture.resource_path])
		else:
			print("VERIFY %s: scene_bg MISSING/empty" % sid)
		inst.queue_free()
		await create_timer(0.1).timeout
	quit()
