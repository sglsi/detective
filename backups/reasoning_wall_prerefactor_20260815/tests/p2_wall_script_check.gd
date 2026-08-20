extends SceneTree

# P1-4 重建：推理墙机制校验（替代已删除的 reasoning_wall_ui.gd 检查）
# 校验对象：scripts/clue/reasoning_wall.gd
#   - Verdict 四态枚举值：CONTRADICTORY=0 / INSUFFICIENT=1 / SUPPORTED=2 / VERIFIED=3
#   - get_verdict() 判定逻辑：矛盾红线优先级最高；关联数驱动 SUPPORTED/VERIFIED
# 通过哨兵：打印 "推理墙校验通过"（run_ci.sh 以此判定）
# 注：本文件未经 Godot 实跑验证（当前环境 shell 被沙箱拦截），请在本地运行确认。

var failures: Array[String] = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		print("OK   " + name)
	else:
		print("FAIL " + name + ((" — " + msg) if msg else ""))
		failures.append(name)

func _process(_delta: float) -> bool:
	var WallScript = load("res://scripts/clue/reasoning_wall.gd")
	_check("推理墙脚本可加载", WallScript != null)
	if WallScript == null:
		print("推理墙校验失败: 脚本缺失")
		quit()
		return false

	var rw = WallScript.new()
	_check("get_verdict 方法存在", rw.has_method("get_verdict"))

	# 1. Verdict 四态枚举值
	var V = rw.Verdict
	_check("Verdict.CONTRADICTORY=0", V.CONTRADICTORY == 0)
	_check("Verdict.INSUFFICIENT=1", V.INSUFFICIENT == 1)
	_check("Verdict.SUPPORTED=2", V.SUPPORTED == 2)
	_check("Verdict.VERIFIED=3", V.VERIFIED == 3)

	# 2. 判定逻辑：无关联 → INSUFFICIENT
	rw._associated = 0
	rw._contradicting = 0
	_check("无关联→INSUFFICIENT", rw.get_verdict() == V.INSUFFICIENT, "实得 %d" % rw.get_verdict())

	# 3. ≥1 关联 → SUPPORTED
	rw._associated = 1
	_check("1关联→SUPPORTED", rw.get_verdict() == V.SUPPORTED, "实得 %d" % rw.get_verdict())

	# 4. ≥3 关联 → VERIFIED
	rw._associated = 3
	_check("3关联→VERIFIED", rw.get_verdict() == V.VERIFIED, "实得 %d" % rw.get_verdict())

	# 5. 矛盾红线优先级最高（即便关联满也判 CONTRADICTORY）
	rw._associated = 5
	rw._contradicting = 1
	_check("矛盾优先→CONTRADICTORY", rw.get_verdict() == V.CONTRADICTORY, "实得 %d" % rw.get_verdict())

	if failures.is_empty():
		print("推理墙校验通过")
	else:
		print("推理墙校验失败: " + str(failures))
	quit()
	return false
