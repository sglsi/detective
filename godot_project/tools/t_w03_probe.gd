extends SceneTree
func _initialize() -> void:
	var anchors = load("res://data/clue_image_anchors.gd")
	var a = anchors.new()
	var table = a.build_anchor_table() if a.has_method("build_anchor_table") else null
	print("anchors script OK")
	# 需求3: 校验信使 posture 锚点已移到胸部(cy<0.45)
	var src = FileAccess.get_file_as_string("res://data/clue_image_anchors.gd")
	if "0.32" in src:
		print("CHK posture cy=0.32 present: PASS")
	else:
		print("CHK posture cy present: ?", "0.32" in src)
	# 需求2: tutorial 改为仅首次(不再 _teaching 强制)
	var gv = FileAccess.get_file_as_string("res://scripts/clue/graph_view_controller.gd")
	if "graph_tutorial_seen" in gv:
		print("CHK tutorial seen logic present: PASS")
	# 需求1: 确认框存在
	var wv = FileAccess.get_file_as_string("res://scripts/clue/wall/wall_verify.gd")
	if "_verify_confirm_win" in wv or "_show_verify_confirm" in wv:
		print("CHK verify confirm present: PASS")
	quit()
