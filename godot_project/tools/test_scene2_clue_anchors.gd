extends SceneTree
## 验证场景二线索已与背景图 res://assets/scenes/sc_02_garden.png 通过 anchor 绑定
## 跑法：godot --headless --script res://tools/test_scene2_clue_anchors.gd --path <godot_project>

func _initialize() -> void:
	await create_timer(0.1).timeout

	const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")
	var scene2_script := load("res://scripts/scene/scene2.gd")
	if scene2_script == null:
		print("SCENE2_ANCHOR_TEST: FAIL - cannot load scene2.gd")
		quit(1); return

	var inst = scene2_script.new()
	var hotspots: Array = inst.hotspots()
	var all_ok := true
	var checked := 0

	for hs in hotspots:
		var id: String = hs.get("id", "")
		var img_path: String = hs.get("image", "")
		var anchor_name: String = hs.get("anchor", "")
		if img_path == "" or anchor_name == "":
			print("SCENE2_ANCHOR_TEST: FAIL [%s] missing image/anchor" % id)
			all_ok = false
			continue

		if not ResourceLoader.exists(img_path):
			print("SCENE2_ANCHOR_TEST: FAIL [%s] image not exists: %s" % [id, img_path])
			all_ok = false
			continue

		var tex: Texture2D = load(img_path)
		if tex == null:
			print("SCENE2_ANCHOR_TEST: FAIL [%s] cannot load texture: %s" % [id, img_path])
			all_ok = false
			continue

		var a: Dictionary = ClueImageAnchors.get_anchor(img_path, anchor_name)
		if a.is_empty():
			print("SCENE2_ANCHOR_TEST: FAIL [%s] anchor '%s' not found for %s" % [id, anchor_name, img_path])
			all_ok = false
			continue

		var tw := float(tex.get_width()); var th := float(tex.get_height())
		var x0 := (float(a["cx"]) - float(a["w"]) / 2.0) * tw
		var y0 := (float(a["cy"]) - float(a["h"]) / 2.0) * th
		var x1 := x0 + float(a["w"]) * tw
		var y1 := y0 + float(a["h"]) * th

		if x0 < 0 or y0 < 0 or x1 > tw or y1 > th:
			print("SCENE2_ANCHOR_TEST: FAIL [%s] crop out of bounds: %.1f,%.1f -> %.1f,%.1f (img %dx%d)" % [id, x0, y0, x1, y1, int(tw), int(th)])
			all_ok = false
			continue

		print("SCENE2_ANCHOR_TEST: OK  [%s] %s/%s crop=[%.1f,%.1f %.1fx%.1f]" % [id, img_path, anchor_name, x0, y0, x1 - x0, y1 - y0])
		checked += 1

	inst.free()
	if all_ok and checked == hotspots.size() and hotspots.size() > 0:
		print("SCENE2_ANCHOR_TEST: PASS (%d anchors verified)" % checked)
		quit(0)
	else:
		print("SCENE2_ANCHOR_TEST: FAIL (checked=%d, total=%d, all_ok=%s)" % [checked, hotspots.size(), all_ok])
		quit(1)
