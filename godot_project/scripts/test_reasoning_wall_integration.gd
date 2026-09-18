extends Control
## 推理墙 × 场景 集成验证（06_推理墙运行机制 MVP 对齐）
## 在 Control 场景 _ready 内运行：autoload(ClueSystem/DifficultyManager) 已注册，
## 模拟「场景收集线索 → 打开推理墙 → 关联线索 → 验证」的完整链路，断言：
##   1) verdict 双口径：主口径（wall_branch_evaluator 按场景真值链逐项比对）在无真值
##      合成场景下安全返回 INSUFFICIENT（不崩溃、不误判）；兜底口径（快照不可用时的
##      关联计数：矛盾>0→0 / 支持≥3→3 / 支持≥1→2 / 否则 1）正确分级。
##   2) 结论里程碑：VERIFIED 时点亮事实节点
##   3) 结构化验证报告非空且含等级（_compute_report 纯函数文案）
##   4) 难度适配：HARD 模式报告仅含等级（不泄露支持/矛盾明细）
## 运行：godot --headless "res://scenes/test_reasoning_wall_integration.tscn"

var _pass := 0
var _fail := 0

func _ready() -> void:
	await _run()
	queue_free()

func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)

func _make_wall(clues: Array, hypo: Dictionary, difficulty: int) -> Control:
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW_%d" % difficulty
	add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), difficulty)
	return wall

func _run() -> void:
	# 准备线索（模拟场景通过 ClueSystem 收集）
	var clues: Array = []
	if ClueSystem:
		ClueSystem.clear_source("wall_test")
		ClueSystem.collect_clue_from_catalog("c1", "车轮印", "窄轮距马车", true, "wall_test", -1)
		ClueSystem.collect_clue_from_catalog("c2", "身高特征", "凶手身材高大", true, "wall_test", -1)
		ClueSystem.collect_clue_from_catalog("c3", "毒药", "生物碱毒药", true, "wall_test", -1)
		ClueSystem.collect_clue_from_catalog("c4", "假证词", "当事人说谎", false, "wall_test", -1)
		clues = ClueSystem.get_collected("wall_test")
	else:
		clues = [
			{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true},
			{"id":"c2","name":"身高特征","desc":"凶手高大","correct":true},
			{"id":"c3","name":"毒药","desc":"生物碱","correct":true},
			{"id":"c4","name":"假证词","desc":"说谎","correct":false},
		]

	var hypo := {
		"title": "马车夫作案",
		"description": "凶手是出租马车夫",
		"milestones": [
			{"id":"m1","text":"作案手法：毒杀"},
			{"id":"m2","text":"凶手身份：马车夫"},
		],
	}

	# ⚠️ 口径说明（2026-09-18 预期值修正）：
	# verdict 主口径 = wall_branch_evaluator 按场景真值链逐项比对（需真实场景 battlefield）。
	# 本 fixture 为合成线索 + scene_id="wall_test"（无真值链注册），主口径按 0 正确率
	# 判 INSUFFICIENT——这正是要守卫的行为：无真值数据时不得崩溃、不得误判 VERIFIED。
	# 「关联计数」旧口径保留为快照不可用（_graph_view 置空）时的兜底路径，用例 A~D 对
	# 兜底口径断言原分级语义。

	# ---- 用例 A：关联 3 条正确 → 兜底口径 VERIFIED + 验证后里程碑点亮 + 报告 ----
	var wallA = _make_wall(clues, hypo, 1)
	wallA.test_associate("c1")
	wallA.test_associate("c2")
	wallA.test_associate("c3")
	_chk(wallA.get_verdict() == 1, "A: 无真值场景主口径 → INSUFFICIENT(1)（不误判 VERIFIED）")
	wallA._graph_view = null   # 模拟快照不可用 → 走兜底计数口径
	_chk(wallA.get_verdict() == 3, "A: 兜底口径 关联3正确线索 → VERIFIED(3)")
	# 走真实验证路径（确认提交 → 生成报告 + 点亮里程碑；_on_verify_pressed 现会先弹确认窗，
	# 无头环境直接调确认后的 _open_verify_result）
	wallA._verify_ctl._open_verify_result()
	await get_tree().create_timer(0.1).timeout
	var msA = wallA.get_milestone_state()
	_chk(msA["confirmed"] == 2 and msA["total"] == 2, "A: 验证后点亮全部里程碑 (2/2)")
	_chk(not wallA.get_last_report().is_empty(), "A: 验证后结构化报告非空")
	var rep_a: String = wallA._verify_ctl._compute_report(3)
	_chk("已获证实" in rep_a, "A: 报告含验证等级")
	_chk("证据链完整闭合" in rep_a, "A: 报告含支持依据")
	wallA.queue_free()

	# ---- 用例 B：关联含 1 条误导 → 兜底口径 CONTRADICTORY ----
	var wallB = _make_wall(clues, hypo, 1)
	wallB.test_associate("c1")
	wallB.test_associate("c4")
	_chk(wallB.get_verdict() == 1, "B: 无真值场景主口径 → INSUFFICIENT(1)")
	wallB._graph_view = null
	_chk(wallB.get_verdict() == 0, "B: 兜底口径 含误导项 → CONTRADICTORY(0)")
	_chk(wallB.get_milestone_state()["confirmed"] == 0, "B: 矛盾时不点亮里程碑")
	wallB.queue_free()

	# ---- 用例 C：仅 1 条 → 兜底口径 SUPPORTED ----
	var wallC = _make_wall(clues, hypo, 1)
	wallC.test_associate("c1")
	wallC._graph_view = null
	_chk(wallC.get_verdict() == 2, "C: 兜底口径 关联1条 → SUPPORTED(2)")
	wallC.queue_free()

	# ---- 用例 D：0 条 → INSUFFICIENT（主口径与兜底口径一致）----
	var wallD = _make_wall(clues, hypo, 1)
	_chk(wallD.get_verdict() == 1, "D: 0关联 主口径 → INSUFFICIENT(1)")
	wallD._graph_view = null
	_chk(wallD.get_verdict() == 1, "D: 0关联 兜底口径 → INSUFFICIENT(1)")
	wallD.queue_free()

	# ---- 用例 E：HARD 难度报告仅含等级（不泄露支持/矛盾明细）----
	var wallE = _make_wall(clues, hypo, 2)
	_chk(wallE.get_difficulty() == 2, "E: 难度透传 HARD(2)")
	var hard_rep = wallE._verify_ctl._compute_report(3)
	_chk("支持依据" not in hard_rep, "E: HARD 报告不泄露支持依据明细")
	_chk("验证等级" in hard_rep, "E: HARD 报告含等级")
	wallE.queue_free()

	print("=== 结果: PASS=%d  FAIL=%d ===" % [_pass, _fail])
	if _fail > 0:
		print("INTEGRATION_RESULT: FAIL")
	else:
		print("INTEGRATION_RESULT: PASS")
