extends SceneTree

func _run() -> void:
	var fails := 0
	var ps: PackedScene = load("res://scenes/test_alive.tscn")
	var root: Node = ps.instantiate()
	get_root().add_child(root)
	await process_frame
	var bg: Sprite2D = root.get_node_or_null("@Sprite2D@0") if root.get_node_or_null("@Sprite2D@0") else null
	# 按类型找
	var sprites: Array = []
	var rects: Array = []
	var parts: Array = []
	var copies: Array = []
	for c in root.get_children():
		if c is Sprite2D: sprites.append(c)
		elif c is ColorRect: rects.append(c)
		elif c is GPUParticles2D: parts.append(c)
		elif c is BackBufferCopy: copies.append(c)
	if sprites.size() != 2: fails += 1
	print("ALIVE sprites=", sprites.size(), " rects=", rects.size(), " parts=", parts.size(), " copies=", copies.size())
	if sprites.size() == 2:
		var bgsp: Sprite2D = sprites[0]
		var fgsp: Sprite2D = sprites[1]
		if bgsp.texture == null or fgsp.texture == null: fails += 1
		print("ALIVE bg_tex=", bgsp.texture != null, " fg_tex=", fgsp.texture != null, " fg_z=", fgsp.z_index, " bg_z=", bgsp.z_index)
		print("ALIVE fg_modulate=", fgsp.modulate)
	if rects.size() != 2: fails += 1
	else:
		for r in rects:
			var m: ShaderMaterial = r.material
			if m == null or m.shader == null: fails += 1
			else:
				print("ALIVE shader=", m.shader.resource_path.get_file(), " params=", m.shader.get_shader_uniform_list().size())
	if parts.size() != 1: fails += 1
	else:
		var p: GPUParticles2D = parts[0]
		print("ALIVE dust amount=", p.amount, " tex=", p.texture != null, " emitting=", p.emitting)
	if copies.size() != 1: fails += 1
	print("ALIVE DONE fails=", fails)
	quit(1 if fails > 0 else 0)

func _initialize() -> void:
	call_deferred("_run")
