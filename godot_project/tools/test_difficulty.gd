extends SceneTree
## P1-4 补充单测：难度管理器（difficulty_manager.gd）
## EASY=0 引导式（显示提示）/ NORMAL=1 / HARD=2 硬核（不显示提示）。
## 运行：godot --headless --script res://tools/test_difficulty.gd --path <godot_project>
## 未经 Godot 实跑验证（环境 shell 被沙箱拦截），请本地运行确认。

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var d = load("res://autoload/difficulty_manager.gd").new()
	var ok := true
	var msg := ""

	# EASY(0)
	d.set_difficulty(0)
	if d.get_difficulty_name() != "简单":
		ok = false
		msg = "EASY 名称应为『简单』，实得 %s" % d.get_difficulty_name()
	if not d.should_show_hint():
		ok = false
		msg = "EASY 应显示提示（auto_fill_notebook）"

	# HARD(2)
	d.set_difficulty(2)
	if d.get_difficulty_name() != "困难":
		ok = false
		msg = "HARD 名称应为『困难』，实得 %s" % d.get_difficulty_name()
	if d.should_show_hint():
		ok = false
		msg = "HARD 不应显示提示（hardcore_manual）"

	# NORMAL(1) 名称
	d.set_difficulty(1)
	if d.get_difficulty_name() != "普通":
		ok = false
		msg = "NORMAL 名称应为『普通』，实得 %s" % d.get_difficulty_name()

	if ok:
		print("P1_RESULT: PASS — 难度管理器逻辑通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
