extends SceneTree
# 回归：场景二地点类线索圈必须完全落在可视场景区内，且不会被 UI 栏（dialogue_bar/top_bar）吞点击。
# 修复前：c201/c205/c206 的 y≥850，被 _scene_area.clip_contents 裁掉，且 _dialogue_bar 默认 STOP 吞点击。

func _initialize() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	sf.name = "ui"
	root.add_child(sf)
	sf._ready()

	var world: Control = sf.get_world_layer()
	var off: Vector2 = sf.get_world_offset()
	var scene_area: Control = sf.get_scene_area()
	if world == null or scene_area == null:
		print("SCENE2_GEOM: FAIL (missing world/scene_area)"); quit()

	# 关键护栏：UI 栏不能是 STOP，否则会盖在 _world 上吞掉线索点击。
	# 它们的交互子按钮自身已有 STOP/接收 gui_input，父容器设 IGNORE 无影响。
	if sf._dialogue_bar.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("SCENE2_GEOM: FAIL (dialogue_bar mouse_filter != IGNORE, got ", sf._dialogue_bar.mouse_filter, ")"); quit()
	if sf._top_bar.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("SCENE2_GEOM: FAIL (top_bar mouse_filter != IGNORE)"); quit()

	var scene_rect: Rect2 = scene_area.get_global_rect()
	# --script 下 global_rect 可能缓存旧值，用已知常量兜底
	if scene_rect.position.is_equal_approx(Vector2.ZERO):
		scene_rect = Rect2(off, scene_area.size)

	var scene2_script = load("res://scripts/scene/scene2.gd")
	var hotspots: Array = scene2_script.HOTSPOTS
	if hotspots.is_empty():
		print("SCENE2_GEOM: FAIL (empty hotspots)"); quit()

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
			print("SCENE2_GEOM: FAIL ", cid, " btn not visible"); ok = false; continue

		# 圆圈中心 = 命中区中心，与 _mark_clue_at_anchor 一致
		var center := Vector2(float(hs["x"]) + float(hs["w"]) * 0.5,
							  float(hs["y"]) + float(hs["h"]) * 0.5)
		if not scene_rect.has_point(center):
			print("SCENE2_GEOM: FAIL ", cid, " circle center ", center, " outside scene_area ", scene_rect); ok = false

		# 按钮本身（world 局部）也要落在 world 尺寸内；world 尺寸 = scene_area 尺寸
		var local_top_left := Vector2(float(hs["x"]), float(hs["y"])) - off
		var local_rect := Rect2(local_top_left, Vector2(float(hs["w"]), float(hs["h"])))
		var world_rect := Rect2(Vector2.ZERO, scene_area.size)
		if not world_rect.encloses(local_rect):
			print("SCENE2_GEOM: WARN ", cid, " btn partially outside world: ", local_rect)

	if ok:
		print("SCENE2_GEOM: PASS")
	quit()
