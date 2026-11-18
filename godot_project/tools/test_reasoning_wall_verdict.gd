extends SceneTree
## P1 补充单测：四级判定（VerdictRules 权威源，H12 裁定 3 落地）
## 无矛盾：0.90→3 VERIFIED / 0.60→2 SUPPORTED / 0.30→1 INSUFFICIENT / 0.10→1 INSUFFICIENT
## 有矛盾：0.90→2 SUPPORTED（不判 VERIFIED）/ 0.60→0 CONTRADICTORY / 0.30→0 CONTRADICTORY / 0.10→1 INSUFFICIENT
## 铁律（有矛盾时四档）：r<0.25→INSUFFICIENT(1)；0.25≤r<0.80→CONTRADICTORY(0)；r≥0.80→SUPPORTED(2)；永不判 VERIFIED(3)。
## 运行：godot --headless --script res://tools/test_reasoning_wall_verdict.gd --path <godot_project>
## 注意：2026-11-18 由「直实例化 reasoning_wall 测死字段 _associated/_contradicting」重写。
## 旧实现走 reasoning_wall.get_verdict() 的 null-state 兜底（恒 INSUFFICIENT），`_associated/_contradicting`
## 是「裁定 3」重构前的死字段（无人消费），且旧预期「有矛盾→0」与权威口径冲突。现直测 VerdictRules 单一事实源。

const VR := preload("res://scripts/clue/verdict_rules.gd")

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var cases := [
		[0.90, false, 3, "无矛盾 0.90→VERIFIED(3)"],
		[0.60, false, 2, "无矛盾 0.60→SUPPORTED(2)"],
		[0.30, false, 1, "无矛盾 0.30→INSUFFICIENT(1)"],
		[0.10, false, 1, "无矛盾 0.10→INSUFFICIENT(1)"],
		[0.90, true, 2, "有矛盾 0.90→SUPPORTED(2)"],
		[0.60, true, 0, "有矛盾 0.60→CONTRADICTORY(0)"],
		[0.30, true, 0, "有矛盾 0.30→CONTRADICTORY(0)"],
		[0.10, true, 1, "有矛盾 0.10→INSUFFICIENT(1)"],
	]
	var ok := true
	for row in cases:
		var got: int = VR.verdict_of(row[0], row[1])
		if got != row[2]:
			ok = false
			print("  ❌ %s 实得 %d" % [row[3], got])
	if VR.verdict_of(0.9, true) > 2:
		ok = false
		print("  ❌ 有矛盾 0.90 不应判 VERIFIED")

	if ok:
		print("P1_RESULT: PASS — VerdictRules 四级判定 %d 例全过 + 铁律" % cases.size())
	else:
		print("P1_RESULT: FAIL")
	quit()