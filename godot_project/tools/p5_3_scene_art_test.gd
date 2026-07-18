extends SceneTree

# P5-3 场景美术端到端验证
# 验证 scene_controller.gd 已将占位 ColorRect 替换为 TextureRect + 真实 .png 资源，
# 且 8 个场景背景图均能被 Godot 加载。

var failures: Array[String] = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		print("OK   " + name)
	else:
		print("FAIL " + name + ((" — " + msg) if msg else ""))
		failures.append(name)

func _process(_delta: float) -> bool:
	var sc = FileAccess.get_file_as_string("res://scripts/scene/scene_controller.gd")
	
	# 1. 代码层：映射表存在、TextureRect 接入、占位方法已移除
	_check("SCENE_ART 映射表存在", "SCENE_ART :=" in sc)
	_check("TextureRect 接入", "TextureRect.new()" in sc)
	_check("_draw_placeholder 已移除", not ("_draw_placeholder" in sc))
	_check("SCENE_ART 覆盖 8 场景", sc.count("sc_0") >= 8)
	
	# 2. 资源层：8 张场景背景图均存在且可加载
	var scene_ids = [
		"sc_01_lab", "sc_02_garden", "sc_03_indoor", "sc_04_police",
		"sc_05_parlor", "sc_06_apartment", "sc_07_hotel", "sc_08_finale",
	]
	for sid in scene_ids:
		var path = "res://assets/scenes/" + sid + ".png"
		_check("scene_exists:" + sid, FileAccess.file_exists(path))
		if ResourceLoader.exists(path):
			var tex = load(path)
			_check("scene_load:" + sid, tex != null and tex is Texture2D)
		else:
			_check("scene_load:" + sid, false, "ResourceLoader.exists false")
	
	if failures.is_empty():
		print("SCENE_ART_OK")
	else:
		print("SCENE_ART_FAIL: " + str(failures))
	quit()
	return false
