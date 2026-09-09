extends SceneTree
func _initialize() -> void:
	var inst := load("res://scripts/clue/wall/wall_verify.gd")
	print("wall_verify load -> ", typeof(inst))
	var r := load("res://scripts/clue/reasoning_wall.gd")
	print("reasoning_wall load -> ", typeof(r))
	var g := load("res://scripts/clue/graph_view_controller.gd")
	print("graph_view load -> ", typeof(g))
	var a := load("res://data/clue_image_anchors.gd")
	if a and a.new():
		print("anchors OK")
	quit()
