extends SceneTree

## 单测：ToolSystem 侦破工具（解锁 + 工具×物品组合发现）
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var ToolSystem = root.get_node_or_null("/root/ToolSystem")
	if not ToolSystem:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	var ok := true
	var reason := ""

	# 初始解锁状态
	if not ToolSystem.is_unlocked("magnifier"):
		ok = false; reason = "放大镜应初始解锁"
	if ToolSystem.is_unlocked("chemistry"):
		ok = false; reason = "化学试剂盒初始不应解锁"

	# 选择已解锁工具
	ToolSystem.select_tool("tape")
	if ToolSystem.selected_tool != "tape":
		ok = false; reason = "select_tool 后 selected_tool 应=tape"

	# 选择未解锁工具应被拒绝
	ToolSystem.select_tool("chemistry")
	if ToolSystem.selected_tool == "chemistry":
		ok = false; reason = "未解锁工具不应被选中"

	# 解锁后可选
	ToolSystem.unlock_tool("chemistry")
	if not ToolSystem.is_unlocked("chemistry"):
		ok = false; reason = "unlock_tool 后应解锁"

	# 组合发现（seed 规则）
	var res = ToolSystem.use_tool_on("magnifier", "blood")
	if res == "" or "血型" not in res:
		ok = false; reason = "放大镜+血迹 应发现血型，实得 '%s'" % res

	# 无对应组合返回空
	var none = ToolSystem.use_tool_on("magnifier", "desk")
	if none != "":
		ok = false; reason = "放大镜+desk 应无发现"

	# 持久化状态
	var st = ToolSystem.get_persistent_state()
	if not ("chemistry" in st["unlocked"]):
		ok = false; reason = "持久化状态应含已解锁的 chemistry"

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL - " + reason)
	quit()
