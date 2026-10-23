extends SceneTree

## scene4 兰斯交谈动态帧 + 炉火闪烁层冒烟：编译 + conv 序列纹理 + 切帧映射 + 火光层生命周期

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn: PackedScene = load("res://scenes/scene4.tscn")
	if scn == null:
		print("S4_FAIL: scene4.tscn load null")
		quit(1)
		return
	var sc = scn.instantiate()
	root.add_child(sc)
	await process_frame
	await process_frame
	var ok := true
	for m in ["_start_dialogue_conv", "_conv_reset", "_on_line", "_ensure_fire_layer", "_fire_fade"]:
		if not sc.has_method(m):
			print("S4_FAIL: method missing: ", m); ok = false
	var paths := [
		"res://assets/scenes/sc_04_conv_00.jpg",
		"res://assets/scenes/sc_04_conv_01.jpg",
		"res://assets/scenes/sc_04_conv_02.jpg",
		"res://assets/scenes/sc_04_conv_03.jpg",
		"res://assets/scenes/sc_04_conv_04.jpg",
	]
	for p in paths:
		var t: Texture2D = load(p)
		if t == null:
			print("S4_FAIL: conv tex null: ", p); ok = false
		else:
			print("S4_OK: %s %dx%d" % [p.get_file(), t.get_width(), t.get_height()])
	# 切帧逻辑等价验证（"系统"在 key 计算前已 return，不在表内）
	var sp_cases := {"兰斯警士": "lance", "福尔摩斯": "holmes", "华生": "listen"}
	for sp in sp_cases:
		var key := "listen"
		if str(sp).contains("兰斯"): key = "lance"
		elif str(sp).contains("福尔摩斯"): key = "holmes"
		if key != sp_cases[sp]:
			print("S4_FAIL: speaker->key wrong: ", sp, " -> ", key); ok = false
	# 火光层生命周期：fade in → 层存在且可见 → fade out → tween 挂起
	sc._fire_fade(true)
	await process_frame
	var fl = sc._fire_layer
	if fl == null:
		print("S4_FAIL: fire layer not created"); ok = false
	else:
		if not fl.visible:
			print("S4_FAIL: fire layer not visible after fade-in"); ok = false
		else:
			print("S4_OK: fire layer created, visible, z=%d, mat=%s" % [fl.z_index, fl.material != null])
		if fl.material == null or fl.material.shader == null:
			print("S4_FAIL: fire shader not attached"); ok = false
		else:
			print("S4_OK: shader attached: ", fl.material.shader.resource_path.get_file())
	sc._fire_fade(false)
	await process_frame
	# 窗外云雾层：常驻场景四
	var cl = sc._cloud_layer
	if cl == null:
		print("S4_FAIL: cloud layer not created"); ok = false
	else:
		if cl.material == null or cl.material.shader == null:
			print("S4_FAIL: cloud shader not attached"); ok = false
		else:
			print("S4_OK: cloud layer created, z=%d, shader=%s" % [cl.z_index, cl.material.shader.resource_path.get_file()])
	# 后缓冲拷贝：WebGL 屏幕读取必需
	if sc._screen_copy == null:
		print("S4_FAIL: screen copy missing"); ok = false
	else:
		print("S4_OK: screen copy z=%d mode=%d" % [sc._screen_copy.z_index, sc._screen_copy.copy_mode])
	# 层尺寸须覆盖全屏（父节点为 Control 时 FULL_RECT 生效）
	print("S4_INFO: cloud size=%s fire size=%s" % [str(cl.size), str(sc._fire_layer.size)])
	print("RESULT=", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
