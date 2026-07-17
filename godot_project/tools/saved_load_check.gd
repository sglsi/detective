extends SceneTree

# 验证编辑器实际写回的 scene_04（serializeTres 产物）可被 Godot 加载。
var files: Array[String] = [
	"res://resources/dialogues/scene_04_police.tres",
]
var idx: int = 0
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	if idx >= files.size():
		if failures.is_empty():
			print("SAVED_LOAD_OK")
		else:
			print("SAVED_LOAD_FAIL: " + str(failures))
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
