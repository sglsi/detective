extends SceneTree

## 验证 Issue1（结论链折叠方向）与 Issue4（连边解除钉位/自动重排）
## 直接走真实 API：_add_edge 建结论→结论边（新方向 nid→hid），_node_list 折叠过滤，_root_anchor_pos 钉位解除。

func _initialize() -> void:
	var ok := 0
	var bad := 0

	var gv: GraphViewController = load("res://scripts/clue/graph_view_controller.gd").new()
	# headless new() 不跑 _ready，手动初始化 helper（避开 _dockctl 的额外依赖）
	gv._data = load("res://scripts/clue/graph/graph_view_data.gd").new()
	gv._data.owner = gv
	gv._layout = load("res://scripts/clue/graph/graph_view_layout.gd").new()
	gv._layout.owner = gv
	gv._fold = load("res://scripts/clue/graph/graph_view_fold.gd").new()
	gv._fold.owner = gv
	gv._edge = load("res://scripts/clue/graph/graph_view_edge.gd").new()
	gv._edge.owner = gv
	gv._focus_person = "person:NPC_WT"
	gv._case_wide = false
	gv._teaching = false
	gv._state = GraphViewController.State.EDITABLE
	gv._derived_conclusions = [
		{"id": "C1"}, {"id": "C2"}, {"id": "C3"}
	]
	gv._persons = [{"id": "person:NPC_WT", "name": "华生"}]
	gv._clues = []
	gv._relations = []
	# 让画布有尺寸，避免 _compute_layout 走虚拟中心兜底影响断言
	gv._canvas = Control.new()
	gv._canvas.size = Vector2(1920, 1080)
	gv.add_child(gv._canvas)

	# ── Issue1：构建 结论C1 →(父) 结论C2 →(父) 结论C3 的推导链（新方向 nid→hid）──
	gv._edge._add_edge("conclusion_C2", "conclusion_C1", "support", "green", false)
	gv._edge._add_edge("conclusion_C3", "conclusion_C2", "support", "green", false)

	# 1a) _descendants(C1) 应含 C2、C3（方向正确：C1 为父）
	var desc_c1 := gv._layout._descendants("conclusion_C1")
	if "conclusion_C2" in desc_c1 and "conclusion_C3" in desc_c1:
		ok += 1
		print("[PASS] Issue1 结论链方向正确：descendants(C1)=%s" % desc_c1)
	else:
		bad += 1
		print("[FAIL] Issue1 descendants(C1)=%s (期望含 C2,C3)" % desc_c1)

	# 1b) 折叠 C1 后，_node_list 应排除 C2、C3（XMind 式隐藏集生效）
	gv._folded_nodes = {"conclusion_C1": true}
	var nl := gv._node_list()
	var nl_ids: Array = []
	for _n in nl:
		nl_ids.append(_n.get("id", ""))
	if not ("conclusion_C2" in nl_ids) and not ("conclusion_C3" in nl_ids):
		ok += 1
		print("[PASS] Issue1 折叠C1后 _node_list 已排除 C2/C3 (保留 %d 节点)" % nl_ids.size())
	else:
		bad += 1
		print("[FAIL] Issue1 折叠C1后 _node_list 仍含 C2/C3：%s" % nl_ids)

	# 1c) 反向：折叠 C2 应只排除 C3（不误伤 C1）
	gv._folded_nodes = {"conclusion_C2": true}
	var nl2 := gv._node_list()
	var nl2_ids: Array = []
	for _n in nl2:
		nl2_ids.append(_n.get("id", ""))
	if "conclusion_C1" in nl2_ids and not ("conclusion_C3" in nl2_ids):
		ok += 1
		print("[PASS] Issue1 折叠C2只排除C3（C1保留）")
	else:
		bad += 1
		print("[FAIL] Issue1 折叠C2后 _node_list=%s" % nl2_ids)
	gv._folded_nodes = {}

	# ── Issue4：连边后解除被连子节点钉位 + 触发全量重排 ──
	# 先把某节点钉成手动根（模拟玩家拖过）
	gv._root_anchor_pos["conclusion_C3"] = Vector2(100, 100)
	gv._manual_nodes = ["conclusion_C3"]
	# 建一条把 C3 接入树的新边（C1→C3 也接上，模拟玩家补全关系）
	gv._edge._add_edge("conclusion_C3", "conclusion_C1", "support", "green", false)
	# 期望：C3 被解除钉位（否则重排推不动它）
	if not gv._root_anchor_pos.has("conclusion_C3"):
		ok += 1
		print("[PASS] Issue4 连边后 C3 已从 _root_anchor_pos 解除钉位（重排可生效）")
	else:
		bad += 1
		print("[FAIL] Issue4 C3 仍被钉在 _root_anchor_pos=%s" % gv._root_anchor_pos)
	# 期望：_relayout_on_edge 标志已被消费（重置为 false）
	if not gv._layout._relayout_on_edge:
		ok += 1
		print("[PASS] Issue4 _relayout_on_edge 已在 _compute_layout 内被消费归位")
	else:
		bad += 1
		print("[FAIL] Issue4 _relayout_on_edge 未被消费（仍 true）")

	print("RESULT ok=%d bad=%d" % [ok, bad])
	quit(0 if bad == 0 else 1)
