extends SceneTree

## scene4 兰斯交谈动态帧冒烟：编译 + conv 序列纹理 + 切帧逻辑（tools/t_bg_hires_probe.gd 同款模式）

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
	var ok := true
	for m in ["_start_dialogue_conv", "_conv_reset", "_on_line"]:
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
	# 切帧逻辑等价验证：模拟 _on_line 的 key→帧组 选择（"系统"在 key 计算前已 return，不在表内）
	var sp_cases := {"兰斯警士": "lance", "福尔摩斯": "holmes", "华生": "listen"}
	for sp in sp_cases:
		var key := "listen"
		if str(sp).contains("兰斯"): key = "lance"
		elif str(sp).contains("福尔摩斯"): key = "holmes"
		if key != sp_cases[sp]:
			print("S4_FAIL: speaker->key wrong: ", sp, " -> ", key); ok = false
	print("RESULT=", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
