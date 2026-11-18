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

	# 2. 判定逻辑：收敛到 VerdictRules 单一事实源（H12 裁定 3）
	#    旧实现 set _associated/_contradicting 后调 get_verdict()。这两字段是「裁定 3」重构前的
	#    死字段，无人消费；直实例化(_state_ctl==null)时 get_verdict() 命中 null 兜底恒返回
	#    INSUFFICIENT → 无关联(期望1)假绿、其余假红，皆不可信。改为直测 VerdictRules.verdict_of。
	var VR = load("res://scripts/clue/verdict_rules.gd")
	# 无矛盾：3 / 2 / 1 / 1
	_check("无矛盾 0.90→VERIFIED", VR.verdict_of(0.90, false) == V.VERIFIED, "实得 %d" % VR.verdict_of(0.90, false))
	_check("无矛盾 0.60→SUPPORTED", VR.verdict_of(0.60, false) == V.SUPPORTED, "实得 %d" % VR.verdict_of(0.60, false))
	_check("无矛盾 0.30→INSUFFICIENT", VR.verdict_of(0.30, false) == V.INSUFFICIENT, "实得 %d" % VR.verdict_of(0.30, false))
	_check("无矛盾 0.10→INSUFFICIENT", VR.verdict_of(0.10, false) == V.INSUFFICIENT, "实得 %d" % VR.verdict_of(0.10, false))
	# 有矛盾：铁律——0.25≤r<0.80→CONTRADICTORY(0)、r≥0.80→SUPPORTED(2)、r<0.25→INSUFFICIENT(1)，永不判 VERIFIED
	_check("有矛盾 0.90→SUPPORTED(不判VERIFIED)", VR.verdict_of(0.90, true) == V.SUPPORTED, "实得 %d" % VR.verdict_of(0.90, true))
	_check("有矛盾 0.60→CONTRADICTORY", VR.verdict_of(0.60, true) == V.CONTRADICTORY, "实得 %d" % VR.verdict_of(0.60, true))
	_check("有矛盾 0.30→CONTRADICTORY", VR.verdict_of(0.30, true) == V.CONTRADICTORY, "实得 %d" % VR.verdict_of(0.30, true))
	_check("有矛盾 0.10→INSUFFICIENT", VR.verdict_of(0.10, true) == V.INSUFFICIENT, "实得 %d" % VR.verdict_of(0.10, true))

	if failures.is_empty():
		print("推理墙校验通过")
	else:
		print("推理墙校验失败: " + str(failures))
	quit()
	return false
