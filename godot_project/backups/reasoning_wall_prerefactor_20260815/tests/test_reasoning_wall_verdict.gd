extends SceneTree
## P1-4 补充单测：推理墙判定逻辑（reasoning_wall.gd · get_verdict）
## 四级判定：CONTRADICTORY=0 / INSUFFICIENT=1 / SUPPORTED=2 / VERIFIED=3
## 运行：godot --headless --script res://tools/test_reasoning_wall_verdict.gd --path <godot_project>
## 注意：本文件未经 Godot 实跑验证（当前环境 shell 被沙箱拦截），请在本地运行确认。

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var rw = load("res://scripts/clue/reasoning_wall.gd").new()
	var ok := true
	var msg := ""

	# 无关联 → INSUFFICIENT(1)
	rw._associated = 0
	rw._contradicting = 0
	if rw.get_verdict() != 1:
		ok = false
		msg = "空关联应判 INSUFFICIENT(1)，实得 %d" % rw.get_verdict()

	# ≥1 条关联 → SUPPORTED(2)
	rw._associated = 1
	if rw.get_verdict() != 2:
		ok = false
		msg = "1 关联应判 SUPPORTED(2)，实得 %d" % rw.get_verdict()

	# ≥3 条关联 → VERIFIED(3)
	rw._associated = 3
	if rw.get_verdict() != 3:
		ok = false
		msg = "3 关联应判 VERIFIED(3)，实得 %d" % rw.get_verdict()

	# 存在矛盾证据 → CONTRADICTORY(0) 优先级最高
	rw._associated = 5
	rw._contradicting = 1
	if rw.get_verdict() != 0:
		ok = false
		msg = "有矛盾应判 CONTRADICTORY(0)，实得 %d" % rw.get_verdict()

	if ok:
		print("P1_RESULT: PASS — 推理墙判定逻辑 4 例全过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
