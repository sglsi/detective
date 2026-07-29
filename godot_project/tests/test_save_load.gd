extends SceneTree
## 存/读档端到端测试（headless）：
##   1. 槽位数 = 3
##   2. 自动分配：空槽位优先，满则覆盖最旧
##   3. 读档列表按时间倒序（最新在上）
##   4. 存档→读档后 scene_state 恢复到保存的阶段（Req 7 核心）
##   5. 跨场景读档时 current_scene_id 指向存档场景
## 运行: Godot --headless --path . --script res://tests/test_save_load.gd

var _fails := 0
var sm: Node   # SaveManager
var gm: Node   # GameManager
var sv: Node   # SaveSystem

func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		print("  PASS: ", name)
	else:
		_fails += 1
		print("  FAIL: ", name, "  ", detail)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	sm = root.get_node("/root/SaveManager")
	gm = root.get_node("/root/GameManager")
	sv = root.get_node("/root/SaveSystem")

	print("== 存/读档端到端测试 ==")

	for i in sm.SLOT_COUNT:
		sm.clear_slot(i)

	_check("槽位数为 3", sm.SLOT_COUNT == 3, "实际=" + str(sm.SLOT_COUNT))
	_check("初始无存档", not sm.has_any_save())
	_check("初始 sorted 列表为空", sm.get_slot_list_sorted().is_empty())

	# --- 第 1 次保存（模拟 scene1 华生观察阶段 phase=2）---
	gm.current_case_id = "case_blood_letter"
	await sv.request_save("scene1", 2, {"clue_ids": ["wrist", "arm"]})
	var s1: int = gm.current_slot
	_check("第1次自动分配到空槽位", FileAccess.file_exists(sm.slot_path(s1)), "slot=" + str(s1))

	await create_timer(1.1).timeout   # 拉开时间戳

	# --- 第 2 次保存（模拟 scene1 信使观察 phase=4）---
	await sv.request_save("scene1", 4, {"clue_ids": ["wrist", "arm", "face", "pose", "tattoo"]})
	var s2: int = gm.current_slot
	_check("第2次分配到不同槽位", s2 != s1, "s1=" + str(s1) + " s2=" + str(s2))

	await create_timer(1.1).timeout

	# --- 第 3 次保存（模拟 scene2 phase=1）---
	await sv.request_save("scene2", 1, {"clue_ids": []})
	var s3: int = gm.current_slot
	_check("第3次分配到第三个槽位", s3 != s1 and s3 != s2, "s3=" + str(s3))

	# --- 排序：最新在上 ---
	var sorted = sm.get_slot_list_sorted()
	_check("sorted 列表共 3 条", sorted.size() == 3, "实际=" + str(sorted.size()))
	if sorted.size() == 3:
		_check("最新在最上面 (scene2)", sorted[0].get("scene_id") == "scene2", "实际=" + str(sorted[0].get("scene_id")))
		var ts_ok = int(sorted[0].timestamp) >= int(sorted[1].timestamp) and int(sorted[1].timestamp) >= int(sorted[2].timestamp)
		_check("时间戳降序", ts_ok)

	await create_timer(1.1).timeout

	# --- 第 4 次保存：槽位已满，应覆盖最旧（s1）---
	await sv.request_save("scene1", 5, {"clue_ids": ["wrist"]})
	var s4: int = gm.current_slot
	_check("满员时覆盖最旧槽位", s4 == s1, "s4=" + str(s4) + " 期望=" + str(s1))

	# --- Req 7 核心：读档恢复到存入阶段 ---
	gm.scene_state = {}
	gm.current_scene_id = ""
	var ok: bool = await sv.load_game(s2)   # s2 = scene1 phase=4 的存档
	_check("读档成功", ok)
	_check("scene_id 恢复为 scene1", gm.current_scene_id == "scene1", "实际=" + gm.current_scene_id)
	_check("phase 恢复为 4", int(gm.scene_state.get("phase", -1)) == 4, "实际=" + str(gm.scene_state.get("phase")))
	_check("clue_ids 恢复 5 条", (gm.scene_state.get("clue_ids", []) as Array).size() == 5)

	# take_save_state 归属判定（场景 _restore_saved_state 依赖）
	var ss = sv.take_save_state("scene1")
	_check("take_save_state(scene1) 命中", not ss.is_empty() and int(ss.get("phase", -1)) == 4)

	# 跨场景归属：读 scene2 存档后 take_save_state("scene1") 应为空
	var ok2: bool = await sv.load_game(s3)
	_check("读 scene2 存档成功", ok2)
	var wrong = sv.take_save_state("scene1", false)
	_check("scene1 无法冒领 scene2 存档", wrong.is_empty())
	_check("current_scene_id=scene2（读档后跳转依据）", gm.current_scene_id == "scene2")

	for i in sm.SLOT_COUNT:
		sm.clear_slot(i)

	# --- 用户存档隔离（Req: 各用户存档相互独立）---
	print("== 用户存档隔离测试 ==")
	var am = root.get_node("/root/AuthManager")
	var logged_in: int = am.AuthState["LOGGED_IN"]
	var guest_state: int = am.AuthState["GUEST"]

	# 用户 A 登录并保存
	# 注意：gm.is_guest 保持 true，避免 save_to_slot 走云端镜像（假账号会挂死 await）。
	# 路径隔离只依赖 AuthManager 的登录态与 user_id，这里只设 AuthManager。
	am.user_data = {"id": "user_11111", "username": "11111"}
	am.current_auth_state = logged_in
	for i in sm.SLOT_COUNT: sm.clear_slot(i)
	await sv.request_save("scene1", 3, {"clue_ids": ["wrist"]})
	_check("用户A保存后可见自己的存档", sm.has_any_save())
	var a_path: String = sm.slot_path(gm.current_slot)
	_check("用户A存档路径含A的命名空间", a_path.contains("user_11111"), a_path)

	# 切换到用户 B：不应看到 A 的存档
	am.user_data = {"id": "user_222222", "username": "222222"}
	_check("用户B看不到用户A的存档", not sm.has_any_save())
	_check("用户B读档列表为空", sm.get_slot_list_sorted().is_empty())

	# 用户 B 自己保存，再切回 A，各自独立
	await sv.request_save("scene2", 1, {"clue_ids": []})
	_check("用户B保存后有自己的存档", sm.has_any_save())
	var b_sorted = sm.get_slot_list_sorted()
	_check("用户B只看到自己的1条存档", b_sorted.size() == 1 and b_sorted[0].get("scene_id") == "scene2")
	am.user_data = {"id": "user_11111", "username": "11111"}
	var a_sorted = sm.get_slot_list_sorted()
	_check("切回用户A仍是A的存档", a_sorted.size() == 1 and a_sorted[0].get("scene_id") == "scene1")

	# 清理两个用户的测试档，恢复游客态
	for uid in ["user_11111", "user_222222"]:
		am.user_data = {"id": uid, "username": uid}
		for i in sm.SLOT_COUNT: sm.clear_slot(i)
	am.user_data = {}
	am.current_auth_state = guest_state

	if _fails == 0:
		print("== 全部通过 ==")
	else:
		print("== 失败 ", _fails, " 项 ==")
	quit(1 if _fails > 0 else 0)
