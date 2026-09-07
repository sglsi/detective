extends SceneTree
func _init() -> void:
	var cls := load("res://scripts/clue/clue_observer.gd")
	var inst = cls.new()
	var has_pick: bool = inst.has_method("_pick_nearest_hotspot")
	var has_install: bool = inst.has_method("_install_portrait_hit_layer")
	print("PCK_PROBE pick_nearest=", has_pick, " install_layer=", has_install)
	print("VERSION=", "OLD(点击层)" if has_pick else "NEW(64px按钮)")
	quit(0)
