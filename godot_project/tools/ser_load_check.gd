extends SceneTree

# 加载所有 _ser_*.tres，验证 Godot 能成功加载并拿到 nodes 数组。
# 用法（在 godot_project 目录下）：
#   godot --headless --script res://tools/ser_load_check.gd

var files: Array[String] = [
	"res://resources/dialogues/_ser_scene_01_phase1_tutorial.tres",
	"res://resources/dialogues/_ser_scene_02_garden.tres",
	"res://resources/dialogues/_ser_scene_03_indoor.tres",
	"res://resources/dialogues/_ser_scene_04_police.tres",
	"res://resources/dialogues/_ser_scene_05_parlor.tres",
	"res://resources/dialogues/_ser_scene_06_apartment.tres",
	"res://resources/dialogues/_ser_scene_07_hotel.tres",
	"res://resources/dialogues/_ser_scene_08_finale.tres"
]
var idx: int = 0
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	if idx >= files.size():
		if failures.is_empty():
			print("GODOT_LOAD_ALL_OK")
		else:
			print("GODOT_LOAD_FAIL: " + str(failures))
		quit()
	var p: String = files[idx]
	idx += 1
	var res: Resource = load(p)
	if res == null:
		failures.append(p + " -> null")
		return false
	if res.get_script() == null:
		failures.append(p + " -> no script")
		return false
	var n: int = 0
	if res.get("nodes") != null:
		n = (res.get("nodes") as Array).size()
	var sid: String = ""
	if res.get("scene_id") != null:
		sid = res.get("scene_id")
	print(p.get_file() + " OK nodes=" + str(n) + " scene_id=" + sid)
	return false
