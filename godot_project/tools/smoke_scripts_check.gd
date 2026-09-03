extends SceneTree

# 编译冒烟：逐个 load + reload 本轮改动的脚本，抓 SCRIPT ERROR（项目把 GDScript 警告当错误）。
var scripts: Array[String] = [
	"res://scripts/ui/side_panel.gd",
	"res://scripts/clue/wall_branch_evaluator.gd",
	"res://scripts/clue/wall/wall_verify.gd",
	"res://scripts/clue/wall/wall_state.gd",
]
var idx: int = 0
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	if idx >= scripts.size():
		if failures.is_empty():
			print("SCRIPT_SMOKE_OK")
		else:
			print("SCRIPT_SMOKE_FAIL: " + str(failures))
		quit()
		return true
	var p: String = scripts[idx]
	idx += 1
	var s: Variant = load(p)
	if s == null:
		failures.append(p + " -> load null")
		return false
	if s is GDScript:
		var err: int = (s as GDScript).reload()
		if err != OK:
			failures.append(p + " -> reload err " + str(err))
	return false
