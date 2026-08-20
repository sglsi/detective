extends Node

## 分水岭诊断：native headless 下 ClueSystem.catalog 到底加载出多少？
## 运行：godot --headless res://tools/test_catalog.tscn --quit
## 期望：size=28；若 size=0 说明 _load_catalog() 自身逻辑在 native 就坏（与 web export 无关）

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var cs = get_node_or_null("/root/ClueSystem")
	if cs == null:
		print("[TEST] ERROR: ClueSystem autoload not found")
		quit(1)
		return
	print("[TEST] catalog size = %d" % cs.clue_catalog.size())
	print("[TEST] get_total_clues = %d" % cs.get_total_clues())

	# 1) DirAccess 能否列出 data/clues/
	var dir = DirAccess.open("res://data/clues/")
	if dir == null:
		print("[TEST] DirAccess.open(res://data/clues/) = null !!!")
	else:
		dir.list_dir_begin()
		var names: Array = []
		var fname = dir.get_next()
		while fname != "":
			names.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
		print("[TEST] dir list size = %d" % names.size())
		for n in names:
			print("[TEST]   file: %s" % n)

	# 2) 手动 load 一个 .tres，看类型
	var p = "res://data/clues/clue_arm.tres"
	if ResourceLoader.exists(p):
		var res = load(p)
		print("[TEST] load(%s) -> %s (is ClueData=%s)" % [p, res, res is ClueData])
	else:
		print("[TEST] ResourceLoader.exists(%s) = false !!!" % p)

	# 3) 直接检查 ClueData 类是否可用
	var cd = ClueData.new()
	print("[TEST] ClueData.new() ok, id=%s" % cd.id)
	quit(0)

func quit(code: int) -> void:
	get_tree().quit(code)
