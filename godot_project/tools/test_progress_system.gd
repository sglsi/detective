extends SceneTree

## 单测：ProgressSystem 调查进度（节点计数 + 线索率）
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var ProgressSystem = root.get_node_or_null("/root/ProgressSystem")
	if not ProgressSystem:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	var ok := true
	var reason := ""

	ProgressSystem.register_case("case_p", 10)
	ProgressSystem.complete_node("case_p", "n1")
	ProgressSystem.complete_node("case_p", "n2")

	var p = ProgressSystem.get_progress("case_p")
	if p["current"] != 2:
		ok = false; reason = "current 应=2，实得 %d" % p["current"]
	if p["total"] != 10:
		ok = false; reason = "total 应=10，实得 %d" % p["total"]
	if p["node_ratio"] < 0.19 or p["node_ratio"] > 0.21:
		ok = false; reason = "node_ratio 应≈0.2，实得 %f" % p["node_ratio"]
	if p["ratio"] < 0.0 or p["ratio"] > 1.0:
		ok = false; reason = "ratio 应被钳制在[0,1]，实得 %f" % p["ratio"]

	# 完成所有节点后 node_ratio=1
	for i in range(3, 11):
		ProgressSystem.complete_node("case_p", "n%d" % i)
	var p2 = ProgressSystem.get_progress("case_p")
	if p2["node_ratio"] != 1.0:
		ok = false; reason = "满节点 node_ratio 应=1.0，实得 %f" % p2["node_ratio"]

	if not ProgressSystem.get_all_progress().has("case_p"):
		ok = false; reason = "get_all_progress 应包含 case_p"

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL - " + reason)
	quit()
