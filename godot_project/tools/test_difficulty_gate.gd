extends SceneTree
## 难度分支 · 预设假设可见性门控 + 方向推导 单测
## 验证 _hypo_preset_visible（HARD 全不预设 / EASY 仅正确 / NORMAL 扣留 manual 正确项）
## 与 _derive_dir（含否定词→negate）的纯逻辑。均为 GraphViewController 的无 UI 方法。
## 注：Diff 为 GraphViewController 类内 enum，本测试以整数 0/1/2 代表 EASY/NORMAL/HARD。

var res := {"p": 0, "f": 0}


func _chk(c: bool, m: String) -> void:
	if c:
		res.p += 1
	else:
		res.f += 1
	print("CHK", "PASS" if c else "FAIL", m)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()

	# ---- HARD(2)：不预设任何推断（玩家自行添加）----
	gv._difficulty = 2
	_chk(not gv._hypo_preset_visible({"kind": "true"}), "HARD 正确项不预设")
	_chk(not gv._hypo_preset_visible({"kind": "mislead"}), "HARD 误导项不预设")

	# ---- EASY(0)：仅正确推断（无误导、无扣留）----
	gv._difficulty = 0
	_chk(gv._hypo_preset_visible({"kind": "true"}), "EASY 正确项预设")
	_chk(not gv._hypo_preset_visible({"kind": "mislead"}), "拦截误导项")
	_chk(gv._hypo_preset_visible({"kind": "true", "pool": "manual"}), "EASY 扣留项仍预设(全给)")

	# ---- NORMAL(1)：正确(auto)+误导 预设；pool:manual 正确项被扣留 ----
	gv._difficulty = 1
	_chk(gv._hypo_preset_visible({"kind": "true", "pool": "auto"}), "NORMAL auto正确项预设")
	_chk(gv._hypo_preset_visible({"kind": "mislead"}), "NORMAL 误导项预设")
	_chk(not gv._hypo_preset_visible({"kind": "true", "pool": "manual"}), "NORMAL manual正确项扣留")

	# ---- 方向推导（启发式）----
	_chk(gv._derive_dir("凶手不是乘马车来的", []) == "negate", "_derive_dir 否定词→negate")
	_chk(gv._derive_dir("凶手未出现", []) == "negate", "_derive_dir 未→negate")
	_chk(gv._derive_dir("凶手乘出租马车", []) == "affirm", "_derive_dir 肯定→affirm")

	print("DIFF_GATE_RESULT PASS=%d FAIL=%d" % [res.p, res.f])
	quit()
