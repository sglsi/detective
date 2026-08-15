extends SceneTree
# 回归：场景三地点类线索圈必须完全落在可视场景区内，且不会被 UI 栏吞点击。
# 修复前：c301-c305 位于 y=150（墙上/无内容区），c306-c310 位于 y=560 未对齐身体/物品，
# 现已按 sc_03_indoor_hd.jpg 尸体/物品/痕迹位置重新分布。

func _initialize() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	sf.name = "ui"
	root.add_child(sf)
	sf._ready()

	var world: Control = sf.get_world_layer()
	var off: Vector2 = sf.get_world_offset()
	var scene_area: Control = sf.get_scene_area()
	if world == null or scene_area == null:
		print("SCENE3_GEOM: FAIL (missing world/scene_area)"); quit()

	if sf._dialogue_bar.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("SCENE3_GEOM: FAIL (dialogue_bar mouse_filter != IGNORE, got ", sf._dialogue_bar.mouse_filter, ")"); quit()
	if sf._top_bar.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("SCENE3_GEOM: FAIL (top_bar mouse_filter != IGNORE)"); quit()

	var scene_rect: Rect2 = scene_area.get_global_rect()
	if scene_rect.position.is_equal_approx(Vector2.ZERO):
		scene_rect = Rect2(off, scene_area.size)

	var scene3_script = load("res://scripts/scene/scene3.gd")
	var hotspots: Array = scene3_script.HOTSPOTS
	if hotspots.is_empty():
		print("SCENE3_GEOM: FAIL (empty hotspots)"); quit()

	var txt := Label.new(); var spk := Label.new()
	var obs = load("res://scripts/clue/clue_observer.gd").new()
	obs.setup(sf, txt, spk, hotspots, null, null, "", world, off)
	obs.show()

	var ok := true
	for i in hotspots.size():
		var hs: Dictionary = hotspots[i]
		var cid: String = hs["id"]
		var btn = obs._btns[i]
		if not btn.visible:
			print("SCENE3_GEOM: FAIL ", cid, " btn not visible"); ok = false; continue

		var center := Vector2(float(hs["x"]) + float(hs["w"]) * 0.5,
							  float(hs["y"]) + float(hs["h"]) * 0.5)
		if not scene_rect.has_point(center):
			print("SCENE3_GEOM: FAIL ", cid, " circle center ", center, " outside scene_area ", scene_rect); ok = false

		var local_top_left := Vector2(float(hs["x"]), float(hs["y"])) - off
		var local_rect := Rect2(local_top_left, Vector2(float(hs["w"]), float(hs["h"])))
		var world_rect := Rect2(Vector2.ZERO, scene_area.size)
		if not world_rect.encloses(local_rect):
			print("SCENE3_GEOM: WARN ", cid, " btn partially outside world: ", local_rect)

	if ok:
		print("SCENE3_GEOM: PASS")
	quit()
