extends Node
func _ready() -> void:
	var errors: Array[String] = []
	for path in ["res://scenes/difficulty_select.tscn", "res://scripts/ui/auth_panel.gd", "res://scripts/ui/slot_dialog.gd", "res://scripts/clue/wall/wall_clue_library.gd"]:
		var res: Variant = load(path)
		if res == null:
			errors.append("LOAD_FAIL " + path)
			continue
		var inst: Variant = null
		if res is PackedScene:
			inst = res.instantiate()
		else:
			inst = res.new()
		if inst == null:
			errors.append("INST_FAIL " + path)
			continue
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		inst.queue_free()
		print("FLOW_OK ", path)
	if errors.size() > 0:
		for e in errors:
			print("FLOW_FAIL ", e)
	print("FLOW_DONE")
	get_tree().quit()
