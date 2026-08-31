extends SceneTree
## 问题2 行为单测：验证「正确/错误推导链」评分不同，且误导支撑边不计入判定信号。
## 用真实 ReasoningWall + 假 GraphView(extends Control 以匹配 _graph_view: Control) 驱动
## WallState._support_signals() 与 _update_star_rating()。
## 运行：godot --headless --script res://tools/test_p2_scoring_correctness.gd --path <godot_project>

var _done := false
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

# 假 GraphView：必须 extends Control 才能赋给 _graph_view: Control 类型字段
class FakeGraphView extends Control:
	var mislead_ids := {}        # 误导派生节点 id 集合（kind=false）
	var der := {"correct": 0, "total": 0}
	func _derived_node_correct(id: String) -> bool:
		return not mislead_ids.has(id)
	func _derived_claim_correctness() -> Dictionary:
		return der

func _run() -> void:
	var ok := true
	var msg := ""

	var rw = load("res://scripts/clue/reasoning_wall.gd").new()
	if rw == null:
		print("P2_RESULT: FAIL — 无法实例化 ReasoningWall")
		quit()
		return

	# 装配最小状态层
	var ws = load("res://scripts/clue/wall/wall_state.gd").new()
	ws.owner = rw
	rw._state_ctl = ws
	var gv = FakeGraphView.new()
	rw._graph_view = gv
	rw._star_lbl = Label.new()
	rw._local_clue_count = 4
	rw._expected_clues = 4
	rw._battle = {}
	rw._insight_bonus = 0
	rw._chain_id = ""

	# ===== 1) _support_signals：误导目标支撑边不计入 =====
	# 正确链：clueA→hypo_G(support) + hypo_G→conclusion_G(support)，目标均正确
	gv.mislead_ids = {}
	rw._associated = 0
	rw._relations = [
		{"from": "clueA", "to": "hypo_G", "kind": "support", "dashed": false},
		{"from": "hypo_G", "to": "conclusion_G", "kind": "support", "dashed": false},
	]
	if ws._support_signals() != 2:
		ok = false; msg = "正确链 support 信号应=2，实得 %d" % ws._support_signals()
	# 错误链：两条支撑边目标均为误导项
	gv.mislead_ids = {"hypo_BAD": true, "conclusion_BAD": true}
	rw._relations = [
		{"from": "clueA", "to": "hypo_BAD", "kind": "support", "dashed": false},
		{"from": "hypo_BAD", "to": "conclusion_BAD", "kind": "support", "dashed": false},
	]
	if ws._support_signals() != 0:
		ok = false; msg = "错误链 support 信号应=0，实得 %d" % ws._support_signals()
	# 混合链：一条正确 + 一条误导
	gv.mislead_ids = {"hypo_BAD": true, "conclusion_BAD": true}
	rw._relations = [
		{"from": "clueA", "to": "hypo_G", "kind": "support", "dashed": false},
		{"from": "hypo_BAD", "to": "conclusion_BAD", "kind": "support", "dashed": false},
	]
	if ws._support_signals() != 1:
		ok = false; msg = "混合链 support 信号应=1，实得 %d" % ws._support_signals()

	# ===== 2) _update_star_rating：推理星纳入派生推导正确性 =====
	# 正确推导：线索全对 + 派生结论正确（der={correct:1,total:1}）
	gv.mislead_ids = {}
	gv.der = {"correct": 1, "total": 1}
	rw._clues = [{"id": "c1", "associated": true, "correct": true},
	             {"id": "c2", "associated": true, "correct": true}]
	rw._associated = 2
	ws._update_star_rating()
	var rea_ok: int = int(rw._last_stars.get("reasoning", 0))
	if rea_ok != 3:
		ok = false; msg = "正确推导推理星应=3，实得 %d" % rea_ok
	# 错误推导：线索全对但派生结论误导（der={correct:0,total:1}）
	gv.mislead_ids = {"conclusion_BAD": true}
	gv.der = {"correct": 0, "total": 1}
	rw._clues = [{"id": "c1", "associated": true, "correct": true},
	             {"id": "c2", "associated": true, "correct": true}]
	rw._associated = 2
	ws._update_star_rating()
	var rea_bad: int = int(rw._last_stars.get("reasoning", 0))
	if rea_bad != 1:
		ok = false; msg = "错误推导推理星应=1，实得 %d" % rea_bad

	if ok:
		print("P2_RESULT: PASS — 问题2 修复：正确/错误推导评分已区分；误导支撑边不计入判定信号")
	else:
		print("P2_RESULT: FAIL — " + msg)
	quit()
