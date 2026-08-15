extends SceneTree
# 回归：仅实例化 scene2.tscn，检查无 class/依赖解析错误（不跑 _ready，避免 autoload 缺失影响）。

func _initialize() -> void:
	var path := "res://scenes/scene2.tscn"
	if not ResourceLoader.exists(path):
		print("SCENE2_INST: FAIL (packed scene not found: ", path, ")"); quit()
	var packed: PackedScene = load(path)
	if packed == null:
		print("SCENE2_INST: FAIL (load returned null)"); quit()
	var inst = packed.instantiate()
	if inst == null:
		print("SCENE2_INST: FAIL (instantiate returned null)"); quit()
	print("SCENE2_INST: PASS (scene2.tscn instantiated, class resolved)")
	quit()
