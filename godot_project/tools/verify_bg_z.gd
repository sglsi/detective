extends SceneTree
func _initialize() -> void:
	await create_timer(0.2).timeout
	for sid in ["scene1", "scene2", "scene3"]:
		var ps = load("res://scenes/%s.tscn" % sid)
		var inst = ps.instantiate()
		root.add_child(inst)
		await create_timer(0.35).timeout
		var sa = inst.get_node_or_null("ui/scene_area")
		if sa == null:
			print("ZCHECK %s: NO scene_area" % sid); continue
		var parts = []
		for c in sa.get_children():
			if c.name in ["scene_bg", "default_bg"]:
				var tex = c.get("texture")
				parts.append("%s(z=%d,tex=%s)" % [c.name, c.z_index, (tex.resource_path if tex else "none")])
		print("ZCHECK %s: %s" % [sid, " | ".join(parts)])
		# 可见性判定：scene_bg 必须在 default_bg 之上(z 更大)才有机会被看到
		var sb = sa.get_node_or_null("scene_bg")
		var db = sa.get_node_or_null("default_bg")
		if sb != null and db != null:
			var visible_ok = sb.z_index > db.z_index
			print("ZCHECK %s: scene_bg ABOVE default_bg = %s" % [sid, "YES" if visible_ok else "NO(STILL HIDDEN)"])
		inst.queue_free()
		await create_timer(0.1).timeout
	quit()
