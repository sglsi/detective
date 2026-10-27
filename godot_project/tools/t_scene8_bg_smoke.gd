extends SceneTree

## 场景八背景冒烟：实例化 scene8，断言背景为写实风专属图 scene8_parlor_dawn
## （与场景一/五同一间 221B 起居室），尺寸 4096x2262，且场景脚本无加载错误。

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn: PackedScene = load("res://scenes/scene8.tscn")
	if scn == null:
		print("S8_FAIL: scene8.tscn load null")
		quit(1)
		return
	var sc = scn.instantiate()
	root.add_child(sc)
	await process_frame
	await process_frame

	var ok := true
	var bg_node = sc.find_child("scene_bg", true, false)
	if bg_node == null:
		ok = false
		print("S8_FAIL: no scene_bg node")
	else:
		var tex = bg_node.texture
		var bg_path = tex.resource_path if tex != null else "<null>"
		var w = tex.get_width() if tex != null else 0
		var h = tex.get_height() if tex != null else 0
		print("S8_BG:", bg_path, " size=", w, "x", h)
		if bg_path.find("scene8_parlor_dawn") < 0:
			ok = false
			print("S8_FAIL: scene8 background not switched to dedicated 221B image")
		if w != 4096 or h != 2262:
			ok = false
			print("S8_FAIL: unexpected background resolution")

	print("S8_OK" if ok else "S8_DONE_WITH_FAIL")
	quit(0 if ok else 1)
