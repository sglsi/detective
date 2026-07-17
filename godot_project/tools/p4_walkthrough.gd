extends SceneTree
# P4 自动化可玩性预筛：逐幕实例化场景 2-8 并运行若干帧，捕获致命错误。
# 注意：这是 headless 自动化预筛，非人工肉眼走查。

const SCENES := [
	"res://scenes/scene_02.tscn",
	"res://scenes/scene_03.tscn",
	"res://scenes/scene_04.tscn",
	"res://scenes/scene_05.tscn",
	"res://scenes/scene_06.tscn",
	"res://scenes/scene_07.tscn",
	"res://scenes/scene_08.tscn",
]

var idx := 0
var step := 0
var frame_count := 0
var current_node: Node = null
var failed := false


func _process(_delta: float) -> bool:
	match step:
		0:
			if idx >= SCENES.size():
				if failed:
					print("WALK_RESULT: FAIL")
				else:
					print("WALK_RESULT: OK — 场景 2-8 全部实例化并运行 10 帧，无致命 SCRIPT ERROR")
				return true
			var path: String = SCENES[idx]
			var res: Resource = ResourceLoader.load(path)
			if res == null:
				print("WALK_FAIL: 无法加载 ", path)
				failed = true
				idx += 1
				return false
			var inst: Node = res.instantiate()
			if inst == null:
				print("WALK_FAIL: 无法实例化 ", path)
				failed = true
				idx += 1
				return false
			root.add_child(inst)
			current_node = inst
			frame_count = 0
			step = 1
			print("▶ 场景 ", path, " 已实例化，运行帧中…")
		1:
			frame_count += 1
			if frame_count >= 10:
				step = 2
		2:
			if is_instance_valid(current_node):
				current_node.queue_free()
			current_node = null
			idx += 1
			step = 0
	return false
