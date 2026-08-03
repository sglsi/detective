extends SceneTree
func _initialize() -> void:
	await create_timer(0.2).timeout
	var paths = [
		"res://assets/scenes/crime_scene_1920x1080.jpg",
		"res://assets/scenes/sc_03_indoor_hd.jpg",
		"res://assets/scenes/victorian_building_exterior.jpg",
		"res://assets/scenes/victorian_room.jpg",
		"res://assets/scenes/crime_scene_user.jpg",
		"res://assets/scenes/sc_01_lab.jpg",
		"res://assets/scenes/sc_02_garden.jpg",
		"res://assets/scenes/sc_08_finale.jpg",
		"res://assets/backgrounds/bg_london_1920x1080.jpg",
	]
	for p in paths:
		var ok = ResourceLoader.exists(p)
		print("BGCHECK %s -> %s" % [p, "OK" if ok else "MISSING"])
	quit()
