extends SceneTree

## P2 轻量 class_name 校验（--script 模式，避免完整场景树实例化）
## godot --headless --path . --script tools/p2_classname_check.gd

func _fail(m: String) -> void:
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _init() -> void:
	print("=== P2 场景 class_name 校验（场景 4-8）===")
	var ok := true
	var cfg = [
		["res://scripts/scene/scene_04.gd", "Scene04Game"],
		["res://scripts/scene/scene_05.gd", "Scene05Game"],
		["res://scripts/scene/scene_06.gd", "Scene06Game"],
		["res://scripts/scene/scene_07.gd", "Scene07Game"],
		["res://scripts/scene/scene_08.gd", "Scene08Game"],
	]
	for c in cfg:
		var scr = load(c[0])
		if scr == null:
			_fail("无法加载脚本 %s" % c[0])
			ok = false
			continue
		var gname: String = scr.get_global_name() if scr != null else ""
		if gname == c[1]:
			_pass("class_name = %s  (%s)" % [gname, c[0]])
		else:
			_fail("class_name 期望 %s，实际 %s" % [c[1], gname])
			ok = false

	# 验证 .tscn 根脚本指向正确的 class_name（加载 PackedScene 取脚本全局名）
	var tscn = [
		["res://scenes/scene_04.tscn", "Scene04Game"],
		["res://scenes/scene_05.tscn", "Scene05Game"],
		["res://scenes/scene_06.tscn", "Scene06Game"],
		["res://scenes/scene_07.tscn", "Scene07Game"],
		["res://scenes/scene_08.tscn", "Scene08Game"],
	]
	for t in tscn:
		var ps = load(t[0])
		if ps == null or not (ps is PackedScene):
			_fail("无法加载场景 %s" % t[0])
			ok = false
			continue
		var inst = ps.instantiate()
		var gname: String = inst.get_script().get_global_name() if inst.get_script() != null else ""
		if gname == t[1]:
			_pass("场景 %s → class_name = %s" % [t[0], gname])
		else:
			_fail("场景 %s class_name 期望 %s，实际 %s" % [t[0], t[1], gname])
			ok = false
		inst.free()

	if ok:
		print("\n🎉 P2 场景 class_name 校验全部通过")
		quit(0)
	else:
		print("\n💥 P2 场景 class_name 校验失败")
		quit(1)
