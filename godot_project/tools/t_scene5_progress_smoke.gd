extends SceneTree

## 场景五推进链冒烟：A/B/C 三路线逐节点推进，验证「a5 看你怎么盘问她」之后不再卡死
## 回归背景：scene5.gd `_enter_step1` 曾用 `var nodes := [...]`（无类型 Array）传给
## `_start_dialogue(nodes: Array[Resource], ...)`（类型化参数）→ Invalid type → 对话链断在 a5。

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn: PackedScene = load("res://scenes/scene5.tscn")
	if scn == null:
		print("S5_FAIL: scene5.tscn load null")
		quit(1)
		return
	var sc = scn.instantiate()
	root.add_child(sc)
	await process_frame
	await process_frame

	var gm = root.get_node_or_null("/root/GameManager")
	if gm != null:
		gm.scene_state["scene4_route"] = "A"

	var ok := true
	# ---- A 路线：a0..a5 → Step1 对话 s0.. → 追问面板 ----
	sc._enter_arrival()
	await process_frame
	var path_a := await _advance_until_stop(sc, 60)
	# 背景断言：场景五必须是夜晚专属图，不得复用场景八的 baker_street_parlor
	var bg_node = sc.find_child("scene_bg", true, false)
	if bg_node == null:
		ok = false
		print("S5_FAIL: no scene_bg node")
	else:
		var tex = bg_node.texture
		var bg_path = tex.resource_path if tex != null else "<null>"
		print("S5_BG:", bg_path, " size=", tex.get_width() if tex != null else 0, "x", tex.get_height() if tex != null else 0)
		if bg_path.find("scene5_parlor_night") < 0:
			ok = false
			print("S5_FAIL: scene5 background not switched")
	print("S5_PATH_A: ", path_a)
	if not path_a.has("a5") or not path_a.has("s0"):
		print("S5_FAIL: A route did not reach a5/s0")
		ok = false
	if sc._modal_panel == null or not is_instance_valid(sc._modal_panel):
		print("S5_FAIL: investigate panel not rendered after Step1")
		ok = false
	else:
		print("S5_OK: A route reached investigate panel (a5 → s0.. → panel)")

	# ---- B 路线：b0..b7 → Step4 知识检索 → 推理墙 ----
	if gm != null:
		gm.scene_state["scene4_route"] = "B"
	sc._enter_arrival()
	await process_frame
	var path_b := await _advance_until_stop(sc, 60)
	print("S5_PATH_B: ", path_b)
	if not path_b.has("b7") or not path_b.has("k0"):
		print("S5_FAIL: B route did not reach b7/k0")
		ok = false
	if sc._phase != 1:  # Phase.REASONING = 1（ARRIVAL/REASONING/TRANSITION 顺序）
		print("S5_FAIL: B route did not enter REASONING phase, phase=", sc._phase)
		ok = false
	else:
		print("S5_OK: B route reached reasoning wall")

	# ---- C 路线：c0..c2 → Step4 → 推理墙 ----
	if gm != null:
		gm.scene_state["scene4_route"] = "C"
	sc._enter_arrival()
	await process_frame
	var path_c := await _advance_until_stop(sc, 60)
	print("S5_PATH_C: ", path_c)
	if not path_c.has("c2") or not path_c.has("k0"):
		print("S5_FAIL: C route did not reach c2/k0")
		ok = false
	else:
		print("S5_OK: C route reached reasoning wall")

	print("RESULT=", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

## 连续推进对话直到对话结束（current_node 为空）为止，返回经过的节点 id 列表
func _advance_until_stop(sc, max_steps: int) -> Array:
	var seen: Array = []
	var guard := 0
	while guard < max_steps:
		guard += 1
		var d = sc._dm
		if d == null:
			break
		if d.current_node == null:
			break
		var id: String = d.current_node.node_id
		if seen.is_empty() or seen[seen.size() - 1] != id:
			seen.append(id)
		d.advance()
		await process_frame
	return seen
