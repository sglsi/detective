extends Node
# 附加到 autoload 中作为环境验证器
# 在 _ready() 中检查 Godot 版本和渲染器兼容性

func _ready() -> void:
	_check_version()
	_check_renderer()
	_check_directory_structure()

func _check_version() -> void:
	var version = Engine.get_version_info()
	var major = version.major
	var minor = version.minor
	var expected_major = 4
	var expected_minor = 7
	
	if major != expected_major or minor != expected_minor:
		push_warning("Godot 版本不匹配！当前: %d.%d, 期望: %d.%d" % [major, minor, expected_major, expected_minor])
	else:
		print("[EnvCheck] Godot 版本: %d.%d ✅" % [major, minor])

func _check_renderer() -> void:
	var renderer = OS.get_current_rendering_method()
	if renderer != "gl_compatibility":
		push_warning("渲染器不是 Compatibility/GLES3！当前: %s" % renderer)
	else:
		print("[EnvCheck] 渲染器: %s ✅" % renderer)

func _check_directory_structure() -> void:
	var dirs = [
		"res://autoload/",
		"res://scenes/",
		"res://scripts/",
		"res://data/",
		"res://assets/",
		"res://addons/",
	]
	for dir in dirs:
		if DirAccess.dir_exists_absolute(dir):
			print("[EnvCheck] 目录存在: %s ✅" % dir)
		else:
			push_warning("目录缺失: %s" % dir)
	
	print("[EnvCheck] 环境检查完成")
