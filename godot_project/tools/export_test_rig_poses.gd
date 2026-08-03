extends SceneTree
const SkeletonCharacter2D = preload("res://scripts/characters/skeleton_character.gd")
const TestRigCharacter = preload("res://scripts/rig/test_rig_character.gd")

func _initialize() -> void:
	await create_timer(0.1).timeout
	var scene = load("res://scenes/test_skeleton_character.tscn").instantiate()
	root.add_child(scene)
	var hero: SkeletonCharacter2D = scene.get_node("View/Hero")
	hero.build_from_def(TestRigCharacter.rig_def())
	hero._playing = false
	var origin: Vector2 = hero.position
	var specs: Array = [
		{"anim": "walk", "times": [0.0, 0.125, 0.25, 0.375]},
		{"anim": "idle", "times": [0.0, 0.25, 0.5, 0.75]},
		{"anim": "wave", "times": [0.0, 0.125, 0.25, 0.375]},
		{"anim": "talk", "times": [0.0, 0.083, 0.166, 0.25]},
	]
	var frames: Array = []
	for spec in specs:
		for t in spec["times"]:
			hero.apply_pose(spec["anim"], float(t))
			frames.append({"anim": spec["anim"], "t": float(t), "bones": hero.get_pose_data(origin)})
	print("POSEJSON " + JSON.stringify(frames))
	quit()
