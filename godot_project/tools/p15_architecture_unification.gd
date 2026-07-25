extends SceneTree
## 架构一致性回归测试（用户核心需求：所有场景共享同一框架；场景二/三完全一致；
## 场景一略有不同但遵循同一骨架；后续新增场景只继承一个基类，改一处即反映到全部场景）
##
## 断言：
##  1) scene1 / scene2 / scene3 均 extends DetectiveScene（单一基类、单一真相源）
##  2) scene2 与 scene3 的 Phase 枚举完全同构（结构一致，仅内容不同）
##  3) scene2 / scene3 不重复定义基类已封装的通用机制（_open_wall / _do_save /
##     _restore_saved_state / _on_clue_recorded / _on_nav / _on_action / _popup / _sb …），
##     从而确保「改基类一处 → 所有场景生效」
##  4) 上述通用机制在运行时确实可用（来自基类继承），证明「机制」与「内容」已分离

func _initialize() -> void:
	await process_frame
	await process_frame
	var ok := true
	var log := []

	# ---- 1) 单一基类继承（用运行时反射，避免把 DetectiveScene 拖进编译期依赖）----
	for sid in ["scene1", "scene2", "scene3"]:
		var p = load("res://scenes/%s.tscn" % sid).instantiate()
		if _extends_base(p):
			log.append("✓ %s extends DetectiveScene（单一基类）" % sid)
		else:
			ok = false
			log.append("✗ %s 未 extends DetectiveScene — 架构被打破" % sid)
		p.queue_free()
		await process_frame

	# ---- 2) scene2 / scene3 的 Phase 枚举同构 ----
	var s2 = load("res://scenes/scene2.tscn").instantiate()
	var s3 = load("res://scenes/scene3.tscn").instantiate()
	var keys2: Array = s2.Phase.keys()
	var keys3: Array = s3.Phase.keys()
	var vals2: Array = s2.Phase.values()
	var vals3: Array = s3.Phase.values()
	if keys2 == keys3 and vals2 == vals3:
		log.append("✓ scene2/scene3 Phase 枚举同构: %s" % str(keys2))
	else:
		ok = false
		log.append("✗ scene2/scene3 Phase 枚举不一致: %s vs %s" % [str(keys2), str(keys3)])
	# 关键共享阶段名必须存在（这些阶段驱动统一的机制流转）
	for name in ["ARRIVAL", "DETECTIVE_DIALOGUE", "OBSERVE", "REASONING", "TRANSITION"]:
		if not (keys2.has(name) and keys3.has(name)):
			ok = false
			log.append("✗ 缺少共享阶段 %s（机制流转可能错位）" % name)

	# ---- 3) 通用机制由基类提供，scene2/scene3 不得重复定义 ----
	var base_methods: Array[String] = [
		"_open_wall", "_do_save", "_do_load", "_restore_saved_state",
		"_on_clue_recorded", "_on_nav", "_on_action", "_popup", "_sb",
		"_on_hotspot_seen", "_show_map_panel", "_show_casebook_panel",
		"_show_inventory_panel", "_show_options_panel", "_show_journal",
		"_toggle_observe", "_npc_talk", "_use_magnifier", "_open_evidence",
		"_start_dialogue", "_on_line", "_make_nodes", "_make_dialogue_resource",
	]
	var src2 := _read("res://scripts/scene/scene2.gd")
	var src3 := _read("res://scripts/scene/scene3.gd")
	for m in base_methods:
		var pat := "func " + m + "("
		if src2.contains(pat):
			ok = false; log.append("✗ scene2 重复定义基类机制 %s（改基类不会反映到它）" % m)
		if src3.contains(pat):
			ok = false; log.append("✗ scene3 重复定义基类机制 %s（改基类不会反映到它）" % m)
	# 但运行时必须可用（确实继承自基类）
	if not (s2.has_method("_open_wall") and s2.has_method("_do_save") and s2.has_method("_restore_saved_state")):
		ok = false; log.append("✗ scene2 缺失基类继承的通用方法")
	if not (s3.has_method("_open_wall") and s3.has_method("_do_save") and s3.has_method("_restore_saved_state")):
		ok = false; log.append("✗ scene3 缺失基类继承的通用方法")
	if ok:
		log.append("✓ scene2/scene3 通用机制均来自 DetectiveScene（单一来源，无重复定义）")

	# ---- 4) 内容钩子由子类提供（证明「内容」与「机制」已分离）----
	for m in ["scene_id", "clue_source", "hotspots", "reasoning_hypothesis", "_apply_restored_phase", "_enter_arrival"]:
		if not (s2.has_method(m) and s3.has_method(m)):
			ok = false; log.append("✗ 内容钩子缺失 %s" % m)
	log.append("✓ 内容钩子 scene2/scene3 均实现（机制/内容分离）")

	for l in log:
		print("[P15]", l)

	if ok:
		print("P15_STRUCT_OK 三场景架构统一：均 extends DetectiveScene，场景二/三同构，通用机制单一来源")
	else:
		print("P15_STRUCT_FAIL 架构不一致：发现重复定义或缺少共享机制")
	quit()

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

## 运行时反射：判断实例脚本是否直接继承 DetectiveScene（不引入编译期类型依赖，
## 以免引擎在编译期重编译 detective_scene.gd 时因 autoload 全局尚未就绪而误报未定义）。
func _extends_base(p: Node) -> bool:
	var s = p.get_script()
	if s == null:
		return false
	var base = s.get_base_script()
	if base == null:
		return false
	return str(base.resource_path).ends_with("detective_scene.gd")
