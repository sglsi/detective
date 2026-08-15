extends SceneTree
# 回归：仅实例化 scene3.tscn，检查无 class/依赖解析错误（不跑 _ready，避免 autoload 缺失影响）。

func _initialize() -> void:
	var path := "res://scenes/scene3.tscn"
	if not ResourceLoader.exists(path):
		print("SCENE3_INST: FAIL (packed scene not found: ", path, ")"); quit()
	var packed: PackedScene = load(path)
	if packed == null:
		print("SCENE3_INST: FAIL (load returned null)"); quit()
	var inst = packed.instantiate()
	if inst == null:
		print("SCENE3_INST: FAIL (instantiate returned null)"); quit()
	print("SCENE3_INST: PASS (scene3.tscn instantiated, class resolved)")
	quit()
