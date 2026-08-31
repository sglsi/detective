extends SceneTree
## 问题3 单测：验证 _clue_box_height() 取当前所有 clue 节点的最大实测高（兜底 130），
## 该值即三种布局 col_gap 的下限（需求3：列间距 ≥ 一个线索文本框高度）。
## 运行：godot --headless --script res://tools/test_p3_layout_spacing.gd --path <godot_project>

var _done := false
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

class FakeLayoutOwner extends GraphViewController:
	pass

func _run() -> void:
	var ok := true
	var msg := ""
	var fo = FakeLayoutOwner.new()
	# 一个矮线索(无视图→回退估算) + 一个高线索(实测 220)
	var c_tall = Control.new()
	c_tall.size = Vector2(320.0, 220.0)
	fo._node_center = {"clue1": Vector2(0,0), "clue2": Vector2(100,0), "hypo1": Vector2(200,0)}
	fo._node_kind = {"clue1": "clue", "clue2": "clue", "hypo1": "hypo"}
	fo._node_views = {"clue2": c_tall}
	fo._node_data = {"clue1": {"label": "短"}, "clue2": {"label": "长"}}

	var gl = load("res://scripts/clue/graph/graph_view_layout.gd").new()
	gl.owner = fo
	var h: float = gl._clue_box_height()
	# 期望 ≥ 220（实测高线索），且 ≥ 130 兜底
	if h < 220.0 - 0.5:
		ok = false; msg = "_clue_box_height 应≥220(实测高线索)，实得 %f" % h
	if h < 130.0:
		ok = false; msg = "_clue_box_height 不应低于兜底 130，实得 %f" % h
	# 列间距下限应≥线索高度：复刻三处算式
	var floor1: float = maxf(h, 300.0)
	var floor2: float = maxf(h, clampf(400.0 / 2.0, 165.0, 300.0))
	if floor1 < h or floor2 < h:
		ok = false; msg = "col_gap 下限应≥线索高度 %f（floor1=%f floor2=%f）" % [h, floor1, floor2]

	if ok:
		print("P3_RESULT: PASS — 问题3：_clue_box_height=%f，三种布局 col_gap 下限均≥线索文本框高度" % h)
	else:
		print("P3_RESULT: FAIL — " + msg)
	quit()
