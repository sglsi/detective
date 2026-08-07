extends SceneTree
## 推理墙「提交验证后关墙再重开」状态持久化 + 验证后关墙推进剧情（#场景二卡死修复）
## 运行：godot --headless --script res://tools/test_wall_persist.gd --path <godot_project>

# 模拟场景：持有 _wall_state 字典与 _enter_transition 推进标记
class FakeScene:
	var _wall_state: Dictionary = {}
	var advanced := false
	func _enter_transition() -> void:
		advanced = true

# 记录 on_verify 回调收到的判定
class Rec:
	var verdict := -1
	func on_verify(v: int) -> void:
		verdict = v

var _ran := false

func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _mk_clues() -> Array:
	var cs := []
	for i in range(6):
		cs.append({"id": "c%d" % i, "name": "线索%d" % i, "desc": "d", "correct": true, "associated": false})
	return cs

func _mk_hypo() -> Dictionary:
	return {
		"title": "测试假设",
		"description": "x",
		"battlefield": {
			"hypotheses": [{"id":"H1","text":"h1","correct":true}, {"id":"H2","text":"h2","correct":true}],
			"contradictions": [{"id":"C1","text":"c1","correct":true}]
		},
		"milestones": [{"id":"M1","text":"m1"}, {"id":"M2","text":"m2"}],
		"chain_id": "scene_test",
		"expected_clues": 6,
		"insight_bonus": 0
	}

func _run() -> void:
	var ok := true
	var msg := ""
	var wall_script = load("res://scripts/clue/reasoning_wall.gd")
	var hypo := _mk_hypo()
	var rec := Rec.new()
	var cb: Callable = Callable(rec, "on_verify")

	# ---- A. 持久化：提交验证后关墙，再重开应恢复到已提交状态 ----
	var fake = FakeScene.new()
	var w1 = wall_script.new()
	root.add_child(w1)
	w1.setup(_mk_clues(), hypo, cb, Callable(), 1, Callable(), fake._wall_state, Callable(fake, "_enter_transition"), true)
	w1.test_associate("c0"); w1.test_associate("c1"); w1.test_associate("c2")
	w1._on_verify_pressed()
	w1._on_verify_confirm(w1.get_verdict())
	if not fake._wall_state.get("verified", false): ok = false; msg = "A: 未持久化 verified"
	if fake._wall_state.get("associated", []).size() != 3: ok = false; msg = "A: 未持久化3条关联"
	if rec.verdict != 3: ok = false; msg = "A: 判定应为VERIFIED(3), 实得 %d" % rec.verdict
	var w2 = wall_script.new()
	root.add_child(w2)
	w2.setup(_mk_clues(), hypo, cb, Callable(), 1, Callable(), fake._wall_state, Callable(fake, "_enter_transition"), true)
	if w2._associated != 3: ok = false; msg = "A: 重开关联数应为3, 实得 %d" % w2._associated
	if not w2._verified: ok = false; msg = "A: 重开未恢复 verified"
	if w2.get_verdict() != 3: ok = false; msg = "A: 重开判定应为VERIFIED, 实得 %d" % w2.get_verdict()
	if w2._battle_hypo_states.get("H1", -1) != 0: ok = false; msg = "A: 战场状态未恢复默认 H1=%s bf=%s" % [w2._battle_hypo_states.get("H1", -1), fake._wall_state.get("battlefield", {})]

	# ---- B. 验证后关墙（返回/X）应推进剧情 ----
	var fake2 = FakeScene.new()
	var w3 = wall_script.new()
	w3.setup(_mk_clues(), hypo, cb, Callable(), 1, Callable(), fake2._wall_state, Callable(fake2, "_enter_transition"), true)
	w3.test_associate("c0"); w3.test_associate("c1"); w3.test_associate("c2")
	w3._verified = true
	w3._persist_state()
	w3._on_back_pressed()
	if not fake2.advanced: ok = false; msg = "B: 验证后关墙未推进剧情"

	# ---- C. 未验证关墙不应推进 ----
	var fake3 = FakeScene.new()
	var w4 = wall_script.new()
	w4.setup(_mk_clues(), hypo, cb, Callable(), 1, Callable(), fake3._wall_state, Callable(fake3, "_enter_transition"), true)
	w4.test_associate("c0"); w4.test_associate("c1"); w4.test_associate("c2")
	w4._on_back_pressed()
	if fake3.advanced: ok = false; msg = "C: 未验证关墙误推进剧情"

	if ok:
		print("P1_RESULT: PASS — 推理墙持久化+验证后关墙推进（场景二卡死修复）")
	else:
		print("P1_RESULT: FAIL — " + msg)
