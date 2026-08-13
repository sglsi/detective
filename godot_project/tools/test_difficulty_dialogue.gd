extends SceneTree
## 回归测试：验证「不同难度不同台词」两条分支机制解析正确
##   机制A：start_node 分流（开场教程三难度各走独立链）
##   机制B：difficulty_filter 链式为 next（赫德森/m5 引导语），隐藏变体须被跳过而非误结束
## 不实例化 DialogueManager（--script 下其 autoload 引用无法编译），
## 改用真实的 DialogueResource/DialogueNodeResource 类 + 与引擎 _go_to_node 完全一致的跳过走查。

func _dn(id: String, sp: String, txt: String, tri: String, nxt: Array, mood: String = "n", df: int = 0):
	var n = DialogueNodeResource.new()
	n.node_id = id; n.speaker = sp; n.text = txt; n.trigger = tri
	var nn: Array[String] = []
	for s in nxt:
		if s is String: nn.append(s)
	n.next_nodes = nn; n.mood = mood; n.difficulty_filter = df
	return n

## 复刻 DialogueManager._go_to_node 的可见性跳过走查：从 start_id 走到第一个可见节点返回其文本
func _resolve(res: DialogueResource, start_id: String, diff: int) -> String:
	var visited: Array = []
	var id: String = start_id
	for _i in range(50):
		var node = res.find_node(id)
		if node == null:
			return "<<END>>"
		if not node.should_show(diff, ""):
			var nxt = node.get_available_next(diff, "")
			if nxt.is_empty() or nxt[0] == id:
				return "<<END>>"
			if id in visited:
				return "<<END>>"
			visited.append(id)
			id = nxt[0]
			continue
		return node.text
	return "<<LOOP>>"

func _run_case(desc: String, res: DialogueResource, expects: Array, advance_first: bool = false) -> bool:
	var ok := true
	for diff in [0, 1, 2]:
		var start: String = res.get_start_node(diff)
		var entry: String = start
		if advance_first:
			# 机制B：start 节点本身可见（共享父节点，如 h5），分支在「下一次推进」才解析，
			# 故从 start 的第一个可用 next 开始走查。
			var sn = res.find_node(start)
			var nx = sn.get_available_next(diff, "")
			if nx.is_empty():
				ok = false; printerr("  [%s] diff=%d start=%s 无 next" % [desc, diff, start]); continue
			entry = nx[0]
		var got: String = _resolve(res, entry, diff)
		var exp: String = expects[diff]
		if got != exp:
			ok = false
			printerr("  [%s] diff=%d start=%s 解析到「%s」 期望「%s」" % [desc, diff, start, got, exp])
	return ok

func _initialize() -> void:
	var passed := 0
	var failed := 0

	# —— 机制A：start_node 分流 ——
	var resA := DialogueResource.new(); resA.scene_id = "A"
	resA.nodes = [
		_dn("e0","福","EASY_OPEN","click",["e1"]),
		_dn("e1","系","EASY_TUT","click",["end"]),
		_dn("n0","福","NORMAL_OPEN","click",["n1"]),
		_dn("n1","系","NORMAL_TUT","click",["end"]),
		_dn("h0","福","HARD_OPEN","click",["h1"]),
		_dn("h1","系","HARD_TUT","click",["end"]),
	]
	resA.easy_start_node = "e0"; resA.normal_start_node = "n0"; resA.hard_start_node = "h0"
	if _run_case("start_node分流", resA, ["EASY_OPEN", "NORMAL_OPEN", "HARD_OPEN"]):
		passed += 1; print("✅ start_node 分流 OK")
	else:
		failed += 1

	# —— 机制B：difficulty_filter 链式为 next（h5/m5 同款）——
	var resB := DialogueResource.new(); resB.scene_id = "B"
	resB.nodes = [
		_dn("a","福","引导之前","click",["b_e","b_n","b_h"]),
		_dn("b_e","福","EASY_GUIDE","click",["b_n"],"n",1),
		_dn("b_n","福","NORMAL_GUIDE","click",["b_h"],"n",2),
		_dn("b_h","福","HARD_GUIDE","click",["end"],"n",3),
	]
	resB.easy_start_node = "a"; resB.normal_start_node = "a"; resB.hard_start_node = "a"
	if _run_case("filter链分流", resB, ["EASY_GUIDE", "NORMAL_GUIDE", "HARD_GUIDE"], true):
		passed += 1; print("✅ filter 链分流 OK")
	else:
		failed += 1

	print("DIFF_DIALOGUE_TEST passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
