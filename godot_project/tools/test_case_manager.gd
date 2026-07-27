extends SceneTree
## P1-4 补充单测：案件管理器（case_manager.gd）
## 案件 .tres 位于 res://data/cases/，已知 id="blood_study"。
## 运行：godot --headless --script res://tools/test_case_manager.gd --path <godot_project>
## 未经 Godot 实跑验证（环境 shell 被沙箱拦截），请本地运行确认。

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var cm = load("res://autoload/case_manager.gd").new()
	var ok := true
	var msg := ""

	# 已知案件应返回非空字典且含 id
	var c = cm.load_case("blood_study")
	if c.is_empty() or not c.has("id"):
		ok = false
		msg = "load_case('blood_study') 应返回非空案件字典"

	# 不存在的案件应返回空字典
	var none = cm.load_case("__no_such_case__")
	if not none.is_empty():
		ok = false
		msg = "load_case 不存在案件应返回空字典"

	# 案件列表应为 Array
	var lst = cm.get_case_list()
	if not (lst is Array):
		ok = false
		msg = "get_case_list 应返回 Array"

	if ok:
		print("P1_RESULT: PASS — 案件管理器逻辑通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
