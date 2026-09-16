extends Control

## 回归测试：推理墙「提交验证 → 存档 → 读档」回到验证前状态
##
## 用户报告（2026-09-16）：在推理墙提交验证、给出本次推理结论后存档，
## 下次读该档位时回到「提交验证前」的状态，须重新提交验证、再次给出结论。
##
## 根因：`detective_scene._open_wall()` 对全案大墙**每次开墙**都执行
##     _wall_state["verified"] = false / ["verdict"] = -1
## 而 `_wall_state` 就是 `ClueSystem.case_wall_state`（同一份引用），也正是存档所存的对象。
## 于是只要在「提交验证之后、存档之前」重开过一次墙（读档后阶段入口自动开墙同理），
## 刚写入的 verified/verdict 就被抹成未验证 → 存档记下的是验证前状态。
##
## 该重置本身是为修复 1857cde「跨场景验证状态泄漏导致场景三墙被封存」而加的，
## 所以正确修法是：**按「验证归属场景」判断**——只有存储的归属场景 ≠ 当前场景时才清除
## （跨场景带入），同场景重开必须保留。
##
## 运行（须沙箱外）：
##   godot --headless --path godot_project res://scenes/test_wall_verify_scene_scope.tscn
## 退出码 0=PASS，1=FAIL。

var _pass := 0
var _fail := 0


func _chk(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] ", label)
	else:
		_fail += 1
		print("[FAIL] ", label)


func _ready() -> void:
	_run.call_deferred()


## 确保没有墙处于打开状态（有则用 toggle 关掉并等它真正销毁）
func _ensure_closed(s) -> void:
	if s.get("_wall_instance") != null:
		s._open_wall()                       # toggle：已开则关闭
		await get_tree().process_frame
		await get_tree().process_frame


## 真正开一次墙，并返回是否确实打开了。
## ⚠️ 两个坑：① `_open_wall()` 是 toggle，若已有墙会被「关闭」而非打开；
##    ② 没有任何已收集线索时它会**提前 return**（连状态重置都不会执行），
##    测试若不断言「墙真的开了」，就会静默空转、把用例变成假通过。
func _real_open(s) -> bool:
	await _ensure_closed(s)
	if s.get("_wall_instance") != null:
		return false
	s._open_wall()
	await get_tree().process_frame
	return s.get("_wall_instance") != null


func _mk_state(owner: String, verified: bool, verdict: int) -> Dictionary:
	return {
		"owner_scene": owner,
		"verified": verified,
		"verdict": verdict,
		"relations": [{"from": "c201", "to": "H1", "kind": "support", "color_key": "green", "dashed": false}],
		"associated": ["c201"],
		"battlefield": {},
		"milestones_lit": [],
		"doubt_book": [],
	}


func _run() -> void:
	await get_tree().process_frame
	if GameManager == null or ClueSystem == null:
		printerr("FATAL: 自动加载单例未就绪")
		get_tree().quit(2)
		return
	# 关闭游客/存档提示干扰；场景二为全案大墙（use_case_wide）
	GameManager.is_guest = false
	# ⚠️ 必须先有已收集线索，否则 _open_wall() 直接 return（连重置都不执行）→ 测试空转
	ClueSystem.collect_clue("c201", "碾轧的花草", "车轮碾过的凹痕", true, "garden", 10)
	_chk(ClueSystem.count_collected("") > 0, "前置：已注入一条可开墙的线索")

	var s2 = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2)
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(s2.scene_id() == "scene2", "前置：已实例化真实 scene2（scene_id=scene2）")

	# ---------- A. 同场景重开墙：不得抹掉已验证状态 ----------
	print("=== A. 同场景重开墙 ===")
	ClueSystem.case_wall_state = _mk_state("scene2", true, 3)
	var opened_a: bool = await _real_open(s2)
	_chk(opened_a, "A0 墙确实被打开（否则后续断言为空转）")
	var st_a: Dictionary = ClueSystem.case_wall_state
	_chk(bool(st_a.get("verified", false)),
		"A1 同场景重开墙后 verified 仍为 true（旧代码每次开墙都清 → 存档记成验证前）")
	_chk(int(st_a.get("verdict", -1)) == 3,
		"A2 同场景重开墙后 verdict 仍为 3（实=%d）" % int(st_a.get("verdict", -1)))
	var w = s2.get("_wall_instance")
	# 注意：`w` 是 Variant（Control），`.get("x")` 会命中 Node.get(path) 而非 Object.get(property)
	# → 必须用动态属性访问读脚本私有变量。
	_chk(w != null and bool(w._verified),
		"A3 墙实例自身也处于已提交验证状态（顶栏验证按钮应禁用）")

	# ---------- B. 跨场景带入：必须清除（保留 1857cde 的修复） ----------
	print("=== B. 跨场景带入清除验证锁 ===")
	ClueSystem.case_wall_state = _mk_state("scene3", true, 3)   # 归属场景三
	var opened_b: bool = await _real_open(s2)
	_chk(opened_b, "B0 墙确实被打开")
	var st_b: Dictionary = ClueSystem.case_wall_state
	_chk(not bool(st_b.get("verified", true)),
		"B1 从其它场景带入的已验证状态被清除（否则新场景墙被整体锁死）")
	_chk(int(st_b.get("verdict", 0)) == -1, "B2 verdict 同时复位为 -1")
	_chk(str(st_b.get("owner_scene", "")) == "scene2",
		"B3 归属场景改写为当前场景 scene2（实=%s）" % str(st_b.get("owner_scene", "")))
	_chk(ClueSystem.case_wall_state.get("relations", []).size() == 1,
		"B4 图谱关系等跨场景内容**不受影响**（只清验证锁）")

	# ---------- C. 存档往返：验证结果必须进快照并能恢复 ----------
	print("=== C. 存档往返 ===")
	ClueSystem.case_wall_state = _mk_state("scene2", true, 3)
	var opened_c: bool = await _real_open(s2)   # 模拟用户验证后开墙查看再存档
	_chk(opened_c, "C0 墙确实被打开")
	SaveManager._build_save_data()          # void：结果写入 SaveManager.save_data
	var snap: Dictionary = SaveManager.save_data.duplicate(true)
	var snap_wall: Dictionary = snap.get("case_wall_state", {})
	_chk(bool(snap_wall.get("verified", false)),
		"C1 存档快照中 case_wall_state.verified == true（旧代码此处为 false → 读档回验证前）")
	_chk(int(snap_wall.get("verdict", -1)) == 3, "C2 快照中 verdict == 3")

	# 模拟读档：清空内存态后用快照恢复
	ClueSystem.case_wall_state = {}
	SaveManager._restore_from_dict(snap)
	await get_tree().process_frame
	_chk(bool(ClueSystem.case_wall_state.get("verified", false)),
		"C3 读档恢复后 verified 仍为 true（不再要求玩家重新提交验证）")
	_chk(int(ClueSystem.case_wall_state.get("verdict", -1)) == 3, "C4 读档恢复后 verdict == 3")
	_chk(ClueSystem.case_wall_state.get("relations", []).size() == 1, "C5 读档恢复后关系仍在")

	# ---------- D. 读档后再开墙（用户报告的关键一步）：状态保持 ----------
	print("=== D. 读档后再开墙 ===")
	var opened_d: bool = await _real_open(s2)
	_chk(opened_d, "D0 墙确实被打开")
	_chk(bool(ClueSystem.case_wall_state.get("verified", false)),
		"D1 读档后开墙，verified 仍为 true（用户报告的复现路径）")
	var w2 = s2.get("_wall_instance")
	_chk(w2 != null and bool(w2._verified),
		"D2 墙实例恢复为已验证态（玩家无需重新提交验证）")

	print("=== WALL_VERIFY_SCENE_SCOPE: %s (pass=%d fail=%d) ===" % [
		"PASS" if _fail == 0 else "FAIL", _pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
