extends Control
class_name DetectiveScene
## DetectiveScene — 统一侦探场景框架（按场景二结构提炼）
##
## 设计目标（用户需求）：游戏中所有场景共享同一套架构；场景二/三应完全一致，
## 场景一略有不同但遵循同一骨架；后续新增场景只需继承本类并填入内容，
## 修改布局/机制只需改这一处即可反映到全部场景。
##
## 本类封装「通用机制」（单一真相源、对话引擎、推理墙、存读档、导航/动作分发、
## 弹窗等）；子类只负责「内容」（HOTSPOTS、对话文本、推理假设、面板文案、流程分支）。
##
## 注意：本类刻意不定义 Phase 枚举（phase 以 int 表示），所有阶段相关判断/分支
## 都通过 virtual 钩子（_in_observe_phase / _apply_restored_phase / _enter_arrival …）
## 交给子类，从而允许场景一保留自己的一套 Phase 枚举而不冲突。

# ===== 共享状态 =====
var _phase := 0                       # 当前阶段（int；具体枚举由子类定义）
var _dm: DialogueManager
var _ui: SceneFramework
var _difficulty := 1
var _obs: ClueObserver                 # 单组观察器（场景二/三使用；场景一覆盖为两组）
var _clues: Array = []                 # 本场景已收集线索（本地权威，不读全局 ClueSystem）
var _wall_auto := false                # 推理墙验证后是否自动推进过渡
var _obs_text_lbl: Label               # ClueObserver 文本标签（场景二/三用占位标签）
var _obs_speaker_lbl: Label

# ===================== 生命周期骨架（子类通过 virtual 钩子定制） =====================
func _ready() -> void:
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
	_init_game_state()
	_build_ui()
	_create_dummy_labels()
	_create_observers()        # virtual：场景二/三建单组；场景一建两组
	_connect_ui_signals()      # virtual（默认导航/动作分发对所有场景通用）
	if _restore_saved_state(): return
	_enter_arrival()

# ===== 子类需实现的配置钩子（提供合理默认值，缺省也不崩） =====
func scene_id() -> String: return "sceneX"
func clue_source() -> String: return "default"      # ClueSystem 来源名（garden/indoor/watson/messenger）
func hotspots() -> Array: return []
func scene_title() -> String: return ""
func scene_time_text() -> String: return "DAY 1"
func scene_background() -> Texture2D: return null

# ===== 构建 =====
func _init_game_state() -> void:
	if GameManager:
		GameManager.current_case_id = "case_blood_letter"
		GameManager.current_scene_id = scene_id()
		if AuthManager: GameManager.is_guest = AuthManager.is_guest()

func _build_ui() -> void:
	_ui = SceneFramework.new(); _ui.name = "ui"; add_child(_ui)
	_ui.setup(scene_title(), scene_time_text(), scene_background())

func _create_dummy_labels() -> void:
	_obs_text_lbl = Label.new(); _obs_text_lbl.visible = false; add_child(_obs_text_lbl)
	_obs_speaker_lbl = Label.new(); _obs_speaker_lbl.visible = false; add_child(_obs_speaker_lbl)

## 默认：创建单组观察器并连线到本类通用处理器。
## 场景一覆盖为创建 watson/messenger 两组。
func _create_observers() -> void:
	_obs = ClueObserver.new()
	_obs.setup(self, _obs_text_lbl, _obs_speaker_lbl, hotspots(), null)
	_obs.hotspot_clicked.connect(_on_hotspot_seen)
	_obs.clue_recorded.connect(_on_clue_recorded)
	_obs.all_recorded.connect(_on_all_done)

func _connect_ui_signals() -> void:
	_ui.nav_clicked.connect(_on_nav)
	_ui.action_clicked.connect(_on_action)

# ===================== 观察器（通用） =====================
func _on_hotspot_seen(clue_id: String) -> void:
	var h = _get_hotspot(clue_id)
	if not h: return
	var tip := _hotspot_tip(h.get("tool", ""))
	_ui.set_dialogue("发现：" + str(h.get("label", "")), str(h.get("desc", "")) + tip)

## 记录一条线索：追加到本地数组并同步到 ClueSystem（推理墙单一真相源）。
## 与场景二/三历史行为完全一致：name 取线索 label。
func _on_clue_recorded(_clue_id: String, _clue_data: Dictionary) -> void:
	_clues.append(_clue_data)
	if ClueSystem:
		ClueSystem.collect_clue(
			_clue_data.get("id", _clue_id),
			_clue_data.get("name", ""),
			_clue_data.get("desc", ""),
			_clue_data.get("correct", true),
			clue_source()
		)
	var total := hotspots().size()
	_ui.show_notification("线索已记录：" + str(_clue_data.get("name", "")) + "（" + str(_clues.size()) + "/" + str(total) + "）")

## 全部线索记录完成 → 进入推理（virtual：子类可加华生点评）
func _on_all_done(_clues_arr: Array) -> void:
	_on_observe_complete()

func _get_hotspot(id: String):
	for h in hotspots():
		if str(h.get("id", "")) == id: return h
	return {}

func _owned_ids() -> Array:
	var r: Array = []
	for h in hotspots(): r.append(h["id"])
	return r

# ===================== 导航（通用分发 + 内容 virtual） =====================
func _on_nav(nav_id: String) -> void:
	match nav_id:
		"map": _show_map_panel()
		"casebook": _show_casebook_panel()
		"evidence": _open_evidence()
		"inventory": _show_inventory_panel()
		"options": _show_options_panel()

func _show_map_panel() -> void:
	var items: Array = []
	for loc in map_locations():
		items.append({"name": "◆ " + loc["t"], "desc": loc["d"]})
	_popup("伦敦地图", items)

func _show_casebook_panel() -> void:
	var items: Array = []
	var steps := casebook_steps()
	var done := casebook_done_flags()
	for i in steps.size():
		items.append({"name": ("✅ " if done[i] else "⬜ ") + steps[i], "desc": ""})
	_popup("案件簿 — 血字的研究 · " + scene_id(), items)

func _show_inventory_panel() -> void:
	var items: Array = []
	if _clues.size() > 0:
		items.append({"name": "📝 现场线索", "desc": "已收集 " + str(_clues.size()) + "/" + str(hotspots().size()) + " 条"})
	for t in inventory_items():
		items.append({"name": t, "desc": ""})
	_popup("物品栏", items)

func _show_options_panel() -> void:
	var p = Control.new(); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var dim = ColorRect.new(); dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(dim)
	var f = Panel.new(); f.size = Vector2(520, 470); f.position = Vector2(700, 300)
	f.add_theme_stylebox_override("panel", _sb(Color(0.13, 0.10, 0.07, 0.97), Color(0.78, 0.62, 0.28), 3, 8))
	var t = Label.new(); t.text = "⚙ 选项"; t.position = Vector2(20, 15); t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); f.add_child(t)
	var lines := options_lines()
	var y = 65
	for ln in lines:
		var l = Label.new(); l.text = "· " + ln; l.position = Vector2(20, y); l.size = Vector2(480, 28)
		l.add_theme_font_size_override("font_size", 16); l.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
		f.add_child(l); y += 35
	var cl = Button.new(); cl.text = "关闭"; cl.position = Vector2(190, 415); cl.size = Vector2(140, 38)
	cl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); cl.add_theme_font_size_override("font_size", 18)
	cl.pressed.connect(func(): p.queue_free()); f.add_child(cl); p.add_child(f)

func _open_evidence() -> void:
	if _clues.is_empty(): _ui.show_notification(_no_evidence_msg())
	else: _open_wall()

# ===================== 动作（通用分发 + 内容 virtual） =====================
func _on_action(action_id: String) -> void:
	match action_id:
		"look": _toggle_observe()
		"talk": _npc_talk()
		"examine": _use_magnifier()
		"think": _open_wall()
		"journal": _show_journal()
		"save": _do_save()
		"load": _do_load()

func _toggle_observe() -> void:
	if not _in_observe_phase(): _ui.show_notification(_observe_locked_msg()); return
	if _obs.is_active():
		_obs.hide()
		_ui.show_notification("观察模式关闭")
	else:
		_obs.show()
		_ui.show_notification(_observe_open_msg())

func _npc_talk() -> void:
	_ui.set_dialogue("", _npc_talk_text(_clues.size()))

func _use_magnifier() -> void:
	if not _in_observe_phase(): _ui.show_notification("当前无法使用放大镜"); return
	_obs.show(); _ui.show_notification(_magnifier_msg())

# ===================== 推理墙（通用，参数化来源/假设） =====================
func _open_wall() -> void:
	if _clues.is_empty() and (not ClueSystem or ClueSystem.count_collected(clue_source()) == 0):
		_ui.show_notification("推理墙需要至少一条线索才能打开。"); return
	# REASONING 阶段打开的墙（自动弹出或手动重开）验证后必须推进过渡；
	# 观察阶段手动开墙仅预览，不推进。不能无条件置 false（场景二/三同款 bug 已根治）。
	_wall_auto = _in_reasoning_phase()
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	if not rw: _ui.show_notification("推理墙模块未找到"); return
	var wall = rw.new(); wall.name = "ReasoningWall"; add_child(wall)
	# 推理墙读取通用线索登记（单一真相源），与场景内 _clues 保持一致
	var clues: Array = ClueSystem.get_collected(clue_source()) if ClueSystem else _clues
	var hypothesis := reasoning_hypothesis()
	wall.setup(clues, hypothesis, func(verdict: int):
		var labels = {0: "CONTRADICTORY", 1: "INSUFFICIENT", 2: "SUPPORTED", 3: "VERIFIED"}
		var v = labels.get(verdict, "WAITING")
		var star_icons = {0: "⭐", 1: "★★", 2: "★★★", 3: "🌟🌟🌟"}
		_ui.show_notification("推理验证结果：" + v + " " + star_icons.get(verdict, "⭐"))
		if _wall_auto: _enter_transition()
	)

func _show_journal() -> void:
	var items: Array = []
	if _clues.is_empty(): items.append({"name": "暂无记录", "desc": _journal_empty_hint()})
	else:
		for c in _clues:
			items.append({"name": "📌 " + str(c.get("name", "")), "desc": str(c.get("desc", ""))})
	_popup("侦探笔记", items)

# ===================== 存 / 读档（通用核心） =====================
func _do_save() -> void:
	if GameManager.is_guest: _ui.show_notification("游客模式下无法存档，请先注册账号。"); return
	var data := {"clue_ids": []}
	# 以本场景本地进度为权威（不读全局 ClueSystem，避免跨轮累计污染存档）
	var ids: Array = []
	for c in _clues: ids.append(c.get("id", ""))
	if ids.is_empty():
		for c in _obs.get_recorded_clues(): ids.append(c.get("id", ""))
	data["clue_ids"] = ids
	print("[SAVE " + scene_id() + "] _phase=", _phase, " data=", data)
	await SaveSystem.request_save(scene_id(), _phase, data)
	_ui.show_notification("✅ 进度已保存")

func _do_load() -> void:
	_ui.show_notification("正在读取存档…")
	if not SaveManager:
		_ui.show_notification("存档系统不可用")
		return
	# 从磁盘/云端重新读取最新存档，刷新 GameManager.scene_state 与 ClueSystem
	var ok = await SaveSystem.load_game()
	if not ok:
		_ui.show_notification("没有可用的存档")
		return
	# 就地重置当前场景：_ready 会调用 _restore_saved_state，从刚刷新的存档恢复进度
	get_tree().reload_current_scene()

## 恢复存档进度（单组场景的通用实现：场景一覆盖为两组版本）
## 返回 true 表示有存档且已恢复，false 表示新游戏。
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state(scene_id())
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 先恢复阶段（避免子方法漏设 _phase 导致阶段错乱——场景一/二/三同款防御）
	_phase = saved_phase
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")
	# 以存档 clue_ids 为唯一权威重建本地进度，并同步 ClueSystem（推理墙单一真相源），
	# 杜绝「场景内进度（_obs 已记录数）」与「推理墙（ClueSystem 全局累计）」不一致的「两层皮」。
	_clues = []
	if ClueSystem: ClueSystem.clear_source(clue_source())
	for cid in saved_ids:
		var h = _get_hotspot(cid)
		if not h.is_empty():
			_clues.append(h)
			if ClueSystem: ClueSystem.collect_clue(cid, h.get("label", ""), h.get("desc", ""), h.get("correct", true), clue_source())
	return _apply_restored_phase(saved_phase, saved_ids, _clues)

## 子类按自身 Phase 分支恢复（通用骨架已处理好 ClueSystem 同步与通知）
func _apply_restored_phase(_phase_val: int, _ids: Array, _clues_arr: Array) -> bool:
	return false

# ===================== 对话引擎（通用） =====================
## 启动一段对话：复用/重建 DialogueManager，连接通用 _on_line 与给定结束回调。
func _start_dialogue(nodes: Array, start: String, on_end: Callable) -> void:
	if _dm:
		if _dm.dialogue_advanced.is_connected(_on_line): _dm.dialogue_advanced.disconnect(_on_line)
		_dm.queue_free()
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(on_end)
	_dm.dialogue_resource = _make_dialogue_resource(scene_id() + "_dlg", nodes, start)
	_dm.start_dialogue()

func _on_line(_id: String) -> void:
	var n = _dm.current_node
	if n: _ui.set_dialogue(n.speaker, n.text)

## 构造对话节点：末节点不挂 next（advance() 检测到 next 为空即干净结束，
## 避免把末节点指到不存在的虚拟节点而刷 ERROR——已在场景二/三根治）。
func _make_nodes(raw: Array) -> Array:
	var nodes: Array[Resource] = []
	var last_idx := raw.size() - 1
	for i in raw.size():
		var r = raw[i]
		var n = DialogueNodeResource.new()
		n.node_id = r[0]; n.speaker = r[1]; n.text = r[2]; n.trigger = "click"
		var nxt: Array[String] = []
		if i < last_idx:
			if len(r) > 3:
				nxt.append(r[3])
			else:
				var base: String = r[0]
				var num: int = int(base.substr(1)) + 1
				nxt.append(base[0] + str(num))
		n.next_nodes = nxt; n.mood = "neutral"; nodes.append(n)
	return nodes

func _make_dialogue_resource(sid: String, ns: Array, start: String):
	var r = DialogueResource.new(); r.scene_id = sid; r.scene_name = scene_id()
	r.nodes = ns; r.easy_start_node = start; r.normal_start_node = start; r.hard_start_node = start
	return r

func _input(event: InputEvent) -> void:
	if not _in_dialogue_phase(): return
	if event is InputEventMouseButton and event.pressed:
		if _dm and _dm.is_active() and _dm.get_current_trigger() != "choice": _dm.advance()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
			if _dm and _dm.is_active() and _dm.get_current_trigger() != "choice": _dm.advance()

# ===================== 通用弹窗 / 样式（所有场景共用） =====================
func _create_notification(msg: String) -> void:
	if _ui: _ui.show_notification(msg)

func _sb(bg: Color, bc: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = bg; s.border_width_left = bw; s.border_width_right = bw
	s.border_width_top = bw; s.border_width_bottom = bw; s.border_color = bc
	s.set_corner_radius_all(cr); return s

func _popup(title_txt: String, items: Array) -> void:
	var o = Panel.new(); o.position = Vector2(460, 120); o.size = Vector2(1000, 700); o.z_index = 100
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.97), Color(0.78, 0.62, 0.28), 2, 6))
	var tt = Label.new(); tt.text = title_txt; tt.position = Vector2(30, 20); tt.add_theme_font_size_override("font_size", 28)
	tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	var sc = ScrollContainer.new(); sc.position = Vector2(30, 70); sc.size = Vector2(940, 570)
	var ct = Control.new(); ct.size = Vector2(920, len(items) * 60)
	var yy = 0
	for it in items:
		var n = Label.new(); n.text = str(it.get("name", "")); n.position = Vector2(10, yy); n.size = Vector2(900, 24)
		n.add_theme_font_size_override("font_size", 20); n.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		ct.add_child(n)
		var d = Label.new(); d.text = str(it.get("desc", "")); d.position = Vector2(30, yy + 26); d.size = Vector2(880, 24)
		d.add_theme_font_size_override("font_size", 16); d.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
		ct.add_child(d); yy += 60
	sc.add_child(ct); o.add_child(sc)
	var cl = Button.new(); cl.text = "关闭"; cl.position = Vector2(430, 620); cl.size = Vector2(140, 45)
	cl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); cl.add_theme_font_size_override("font_size", 20)
	cl.pressed.connect(func(): o.queue_free()); o.add_child(cl); add_child(o)

# ===================== 子类需实现的「内容」钩子 =====================
func _phase_name(_p: int) -> String: return "未知阶段"
func _enter_arrival() -> void: pass
func _on_observe_complete() -> void: pass
func _enter_reasoning() -> void: pass
func _enter_transition() -> void: pass
func _go_to_next_scene() -> void: pass
func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return false
func _in_dialogue_phase() -> bool: return false
func _observe_locked_msg() -> String: return "当前阶段无法观察"
func _observe_open_msg() -> String: return "观察模式已开启"
func _magnifier_msg() -> String: return "放大镜就绪"
func _hotspot_tip(_tool: String) -> String: return ""
func _npc_talk_text(_n: int) -> String: return ""
func _no_evidence_msg() -> String: return "尚未发现任何证据"
func _journal_empty_hint() -> String: return "去现场勘查痕迹"
func reasoning_hypothesis() -> Dictionary: return {"title": "", "description": ""}
func map_locations() -> Array: return []
func casebook_steps() -> Array: return []
func casebook_done_flags() -> Array: return []
func inventory_items() -> Array: return []
func options_lines() -> Array: return []
