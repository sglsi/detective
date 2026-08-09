extends SceneTree

## Headless 实例化冒烟测试：逐一 load().instantiate() 各场景，
## 捕获 "Could not resolve super class" / "SCRIPT ERROR" / "Parse Error" 等致命解析错误。
## 用法：godot --headless --script tools/test_scene_instantiate.gd

const SCENES := [
	"res://scenes/main_menu.tscn",
	"res://scenes/scene1.tscn",
	"res://scenes/scene2.tscn",
	"res://scenes/scene3.tscn",
	"res://scenes/scene4.tscn",
	"res://scenes/scene5.tscn",
	"res://scenes/scene6.tscn",
	"res://scenes/scene7.tscn",
	"res://scenes/scene8.tscn",
	"res://scenes/prototype_procedural_bg.tscn",
]

var _fail := 0

func _initialize() -> void:
	# autoload 在 _initialize 调用前已注册，无需 await。
	for path in SCENES:
		_test_one(path)
	print("\n===== SCENE INSTANTIATE RESULT: %d/%d FAILED =====" % [_fail, SCENES.size()])
	quit(_fail if _fail > 0 else 0)

func _test_one(path: String) -> void:
	print("LOAD %s ..." % path)
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		print("  [FAIL] load() returned null"); _fail += 1; return
	if not (res is PackedScene):
		print("  [FAIL] not a PackedScene"); _fail += 1; return
	var inst = res.instantiate()
	if inst == null:
		print("  [FAIL] instantiate() returned null"); _fail += 1; return
	root.add_child(inst)            # 触发 _ready（同步）
	print("  [OK] instantiated class_name=%s" % inst.get_class())
	inst.queue_free()
