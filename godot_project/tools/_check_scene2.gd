extends SceneTree
func _initialize():
	var res = load("res://scripts/scene/scene2.gd")
	if res:
		print("SCENE2_LOAD_OK")
	else:
		print("SCENE2_LOAD_FAILED")
	quit()
