extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn: PackedScene = load("res://scenes/scene1.tscn")
	if scn == null:
		print("BG_FAIL: scene1.tscn load null")
		quit(1)
		return
	var sc = scn.instantiate()
	root.add_child(sc)
	await process_frame
	if not sc.has_method("scene_background"):
		print("BG_FAIL: scene_background not found (compile fail?)")
		quit(1)
		return
	var sofa: Texture2D = sc.scene_background()
	var door: Texture2D = sc._opendoor_bg()
	var ok := true
	if sofa == null:
		print("BG_FAIL: sofa null"); ok = false
	else:
		print("BG_OK: sofa01 %dx%d" % [sofa.get_width(), sofa.get_height()])
	if door == null:
		print("BG_FAIL: opendoor null"); ok = false
	else:
		print("BG_OK: opendoor %dx%d" % [door.get_width(), door.get_height()])
	print("RESULT=", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
