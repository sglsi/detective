extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var s = load("res://scripts/scene/scene1.gd")
	if s == null:
		print("SMOKE_FAIL: scene1.gd load null")
		quit(1)
		return
	print("SMOKE_OK: scene1.gd compiled")
	var scn: PackedScene = load("res://scenes/scene1.tscn")
	if scn == null:
		print("E2E_FAIL: scene1.tscn load null")
		quit(1)
		return
	var sc = scn.instantiate()
	root.add_child(sc)
	await process_frame
	await process_frame
	if sc.has_method("_open_letter_view"):
		sc._open_letter_view()
		await process_frame
		var lv = sc.get("_letter_view")
		if lv == null:
			print("E2E_FAIL: _letter_view not created")
			quit(1)
			return
		var tex = lv.get_child(1)
		if tex == null or tex.texture == null:
			print("E2E_FAIL: letter texture missing")
			quit(1)
			return
		print("E2E_OK: letter_view created, texture=", tex.texture.get_size())
		sc._close_letter_view()
		await process_frame
		if sc.get("_letter_view") != null:
			print("E2E_FAIL: letter_view not closed")
			quit(1)
			return
		var dm = sc.get("_dm")
		if dm == null:
			print("E2E_FAIL: rest dialogue not started")
			quit(1)
			return
		print("E2E_OK: letter closed, rest dialogue started")
	else:
		print("E2E_SKIP: _open_letter_view not found")
	quit(0)
