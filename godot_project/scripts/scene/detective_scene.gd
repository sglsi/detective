extends Control
class_name DetectiveScene

const ClueAnchorCard = preload("res://scripts/ui/clue_anchor_card.gd")

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
var _wall_state: Dictionary = {}       # 推理墙跨重开的持久化状态（场景持有，墙 setup 时传入）
var _wall_instance: Control = null      # 当前已打开的推理墙（单例，避免多重叠加）
var _suppress_terminal_save := false    # 读档恢复到终局阶段时置 true，阻止「继续」按钮再次自动写入 identical 存档；人工 SAVE 不受影响
var _kb_panel: Control = null            # 当前已打开的知识库面板（单例，避免多重叠加）
var _modal_panel: Control = null        # 当前已打开的弹窗/面板（单例，避免多重叠加）
var _modal_title: String = ""           # 当前弹窗标题（用于同按钮开关切换）
var _props: Dictionary = {}             # 已获取道具 {id: {name, desc, icon}} (#139 道具系统)
var _obs_text_lbl: Label               # ClueObserver 文本标签（场景二/三用占位标签）
var _obs_speaker_lbl: Label

const WindowDrag = preload("res://scripts/ui/window_drag.gd")

# ===================== 生命周期骨架（子类通过 virtual 钩子定制） =====================
func _ready() -> void:
	_wall_state = {}   # 每实例独立的状态字典（GDScript 类级字典默认值是共享的，必须逐实例重建）
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

# 程序化氛围背景开关：返回 true 时底层用 ProceduralBackground 替代位图背景（默认关）
func use_procedural_background() -> bool: return false

# ===== 构建 =====
func _init_game_state() -> void:
	if GameManager:
		GameManager.current_case_id = "case_blood_letter"
		GameManager.current_scene_id = scene_id()
		if AuthManager: GameManager.is_guest = AuthManager.is_guest()

func _build_ui() -> void:
	if use_procedural_background():
		var pb := ProceduralBackground.new()
		pb.name = "ProceduralBG"
		add_child(pb)
		_ui = SceneFramework.new(); _ui.name = "ui"; add_child(_ui)
		_ui.setup(scene_title(), scene_time_text(), null)
	else:
		_ui = SceneFramework.new(); _ui.name = "ui"; add_child(_ui)
		_ui.setup(scene_title(), scene_time_text(), scene_background())
	# 工具栏（v2：真实图标 + 主动操作交互）
	_setup_toolbar()

## 实例化 ToolBar 并连接信号（按 §4.3.4 六步闭环 Step 2）
var _toolbar: ToolBar = null
func _setup_toolbar() -> void:
	# ToolBar 是核心工程脚本，始终存在；不判空（ClassDB.class_exists 对脚本类恒 false，
	# ResourceLoader.exists 在导出包里对 .gd 路径不可靠，两种判空都已在生产环境翻车）
	_toolbar = ToolBar.new(); _toolbar.name = "ToolBar"; add_child(_toolbar)
	_toolbar.scene_ui = _ui   # 供放大镜直接放大场景背景/立绘的真实纹理（不依赖屏幕捕获）
	_toolbar.tool_activated.connect(_on_tool_activated)
	_toolbar.tool_completed.connect(_on_tool_completed)
	# 场景控制器进入 STEP_2_TOOL 时显示工具栏
	if SceneEventBus:
		SceneEventBus.step_changed.connect(_on_step_changed)
		# 热点被点击即视为「当前正在观察的线索」→ 工具栏据此查 线索↔道具 关联
		SceneEventBus.hotspot_clicked.connect(_on_hotspot_clicked_for_tool)

## 玩家点击线索热点时，把该线索设为工具栏的当前目标，
## 使放大镜/卷尺/黄页等道具能查到对应的线索关联（看图片/测量/查地址）。
func _on_hotspot_clicked_for_tool(clue_id: String) -> void:
	if _toolbar:
		_toolbar.set_target(clue_id)

func _on_tool_activated(tool_id: String) -> void:
	print("[DetectiveScene] 工具激活:", tool_id)

func _on_tool_completed(tool_id: String, target_id: String, result: String) -> void:
	print("[DetectiveScene] 工具完成: %s → %s | %s" % [tool_id, target_id, result])
	# 通知场景控制器推进到 Step 3（数据记录）
	if SceneEventBus:
		SceneEventBus.emit_signal("tool_used", tool_id, target_id)

func _on_step_changed(step_name: String) -> void:
	if not _toolbar: return
	match step_name:
		"STEP_2_TOOL":
			_toolbar.show_toolbar()
		"STEP_1_OBSERVE", "STEP_3_RECORD", _:
			_toolbar.hide_toolbar()

# ===== 氛围遮罩（迷雾/灯光）已按需求移除：相关按钮/着色器叠加/切换功能全部删除 =====

func _create_dummy_labels() -> void:
	_obs_text_lbl = Label.new(); _obs_text_lbl.visible = false; add_child(_obs_text_lbl)
	_obs_speaker_lbl = Label.new(); _obs_speaker_lbl.visible = false; add_child(_obs_speaker_lbl)

## 默认：创建单组观察器并连线到本类通用处理器。
## 场景一覆盖为创建 watson/messenger 两组。
func _create_observers() -> void:
	_obs = ClueObserver.new()
	_obs.name = "observer"
	# ⚠️ 必须加入场景树：否则 _obs 不在树内，_open_zoom() 里 get_viewport() 返回 null，
	# 点中线索后放大图崩溃（表现为「点击无反应」）。场景一已 add_child，此处补齐二/三/七/八。
	add_child(_obs)
	# 按难度过滤误导线索（简单剔除，普通 30%，困难 70%）
	var filtered_hotspots: Array = hotspots()
	if DifficultyManager:
		filtered_hotspots = DifficultyManager.filter_hotspots_by_difficulty(filtered_hotspots)
	# M2.x：把摄像机世界层 + 场景根→世界局部的偏移传入，使地点类线索命中区/提示圈
	# 挂入 _world、随缩放平移变换（缩放后仍精准可点；点线索镜头也能推近）。
	_obs.setup(self, _obs_text_lbl, _obs_speaker_lbl, filtered_hotspots, null, null, "",
		_ui.get_world_layer() if _ui else null, _ui.get_world_offset() if _ui else Vector2.ZERO)
	_obs.hotspot_clicked.connect(_on_hotspot_seen)
	_obs.clue_recorded.connect(_on_clue_recorded)
	_obs.all_recorded.connect(_on_all_done)
	# 简单模式：场景进入即自动高亮所有可交互点（不用点「观察」）。
	# 关键护栏：仅当本场景确有可观察热点（hotspots().size()>0）时才 auto-show。
	# 否则（如场景四 人证调查类，_in_observe_phase 恒 false、hotspots 为空）空观察器一旦
	# 被激活，会永久让 _advance_blocked() 拦截对话推进 → 入场演出台词点不动、卡死。
	if DifficultyManager and DifficultyManager.auto_reveal_clues and hotspots().size() > 0:
		_obs.show()

## 当前生效的观察器（场景二/三即 _obs；场景一根据 phase 返回 watson/messenger）。
## 工具栏开关、观察模式切换都通过它操作，避免 scene1 的 _obs 为空导致空引用。
func _current_observer() -> ClueObserver:
	return _obs

## 通用：进入观察阶段（供各场景 _on_detective_ended 调用，去除重复的 boilerplate）。
## 只负责「显示观察器 + 给出观察提示」；阶段置位（_phase = Phase.OBSERVE）由各场景在自己的
## 钩子里完成（基类用 int 表示阶段，具体枚举由子类定义，故不能在此硬写）。
## target_noun 为观察对象名词（"花园" / "屋内" / "身上"），用于生成观察提示文案。
func _begin_observe(target_noun: String) -> void:
	_obs.show()
	_ui.set_dialogue("提示", _observe_hint(target_noun) + _observe_warn_suffix() + "\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙整理。")

func _connect_ui_signals() -> void:
	_ui.nav_clicked.connect(_on_nav)
	_ui.action_clicked.connect(_on_action)

# ===================== 观察器（通用） =====================
func _on_hotspot_seen(clue_id: String) -> void:
	# 线索说明统一在放大弹出框（ClueObserver._open_zoom）内展示，不再写入底部对话框。
	# 同时转发给工具栏，使放大镜/卷尺/黄页等道具能定位「当前正在观察的线索」
	# （与场景一 _on_obs_hotspot_to_tool 行为一致，统一线索机制接线）。
	if SceneEventBus:
		SceneEventBus.hotspot_clicked.emit(clue_id)

## 记录一条线索：追加到本地数组并同步到 ClueSystem（推理墙单一真相源）。
## 与场景二/三历史行为完全一致：name 取线索 label。
func _on_clue_recorded(_clue_id: String, _clue_data: Dictionary) -> void:
	_clues.append(_clue_data)
	if ClueSystem:
		# P3.1：观察热点权重由热点表 "wt" 字段提供（"w" 已被热点矩形宽度占用；scene7/8 无 .tres）
		ClueSystem.collect_clue_from_catalog(
			_clue_data.get("id", _clue_id),
			_clue_data.get("name", ""),
			_clue_data.get("desc", ""),
			_clue_data.get("correct", true),
			clue_source(),
			int(_clue_data.get("wt", -1))
		)
	var total := hotspots().size()
	_ui.show_notification("线索已记录：" + str(_clue_data.get("name", "")) + "（" + str(_clues.size()) + "/" + str(total) + "）")
	# ⚠️ 关键修复（2026-08-15 用户反馈「点线索后其他线索被放大场景隐藏、流程卡死」）：
	# 原 M2 实现在记录线索后调用 focus_world_point(wp, 2.2) 把摄像机推近并锁定在刚记录的线索处，
	# 导致其余未记录线索被推出视口外、点不到，流程无法继续。改为记录后回到「统览原场景」
	# （zoom=1, position=0），确保其余未记录线索始终可见、可点，直到全部收集完毕。
	# 推近镜头本只是「观察互动」的调味，却破坏了多线索勘查的可用性，故移除。
	if _ui:
		_ui.reset_camera()

## 全部线索记录完成 → 进入推理（virtual：子类可加华生点评）
func _on_all_done(_clues_arr: Array) -> void:
	# 关键修复：观察完成后必须停用观察器（_obs.hide 置 _active=false）。
	# 否则 _obs.is_active() 一直为 true，_advance_blocked() 会永久拦截过渡对话，
	# 导致「提交验证后游戏卡死不推进」（场景二/三/七/八 同源 bug；场景一已自行 hide）。
	if _obs and _obs.has_method("hide"): _obs.hide()
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
		"options": _show_options_panel()

func _show_map_panel() -> void:
	var items: Array = []
	for loc in map_locations():
		items.append({"name": "◆ " + loc["t"], "desc": loc["d"]})
	_popup("伦敦地图", items)

func _show_casebook_panel() -> void:
	if ClueSystem: _sync_clues()   # 进入推理前（对话阶段）也实时反映已收集线索，避免案件簿「已收集 0/N」失真
	var items: Array = []
	var steps := casebook_steps()
	var done := casebook_done_flags()
	for i in steps.size():
		# 防御：done 与 steps 长度不齐时按未完成处理，绝不越界崩溃
		var is_done: bool = i < done.size() and bool(done[i])
		items.append({"name": ("✅ " if is_done else "⬜ ") + steps[i], "desc": ""})
	_popup("案件簿 — 血字的研究 · " + scene_id(), items)

func _show_inventory_panel() -> void:
	var items: Array = []
	if _clues.size() > 0:
		items.append({"name": "📝 现场线索", "desc": "已收集 " + str(_clues.size()) + "/" + str(hotspots().size()) + " 条"})
	for t in inventory_items():
		items.append({"name": t, "desc": ""})
	_popup("物品栏", items)

func _show_options_panel() -> void:
	# 单例 + 开关：选项面板已开 -> 关闭（toggle）；否则开新的，杜绝多重叠加
	if _modal_panel and is_instance_valid(_modal_panel):
		if _modal_title == "⚙ 选项":
			_close_modal(); return
		_modal_panel.queue_free(); _modal_panel = null
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
	cl.pressed.connect(_close_modal); f.add_child(cl); p.add_child(f)
	_register_modal(p, "⚙ 选项")

## 证据库来源列表：默认本场景单一 source；多组场景（如场景一 watson/messenger）覆盖。
func _clue_sources() -> Array:
	return [clue_source()]

## 证据按钮（所有场景一致）：展示已收集线索列表，而非推理墙。
## 推理墙由左侧「思考」动作键打开——避免同一按钮身兼两职、各场景行为不一。
func _open_evidence() -> void:
	var cards: Array = []
	for src in _clue_sources():
		var collected = ClueSystem.get_collected(src) if ClueSystem else []
		for c in collected:
			var tag = "" if _clue_sources().size() <= 1 else ("【" + src + "】")
			var title = tag + str(c.get("name", c.get("id", "")))
			var img: String = c.get("image", "")
			var anchor: String = c.get("anchor", "")
			# 带锚点的线索 → 渲染「部位图 + 文字」同卡，关联身体部位；否则纯文字卡片
			var card = ClueAnchorCard.new()
			card.setup_card(img, anchor, title, str(c.get("desc", "")), 920, 200)
			cards.append(card)
	if cards.is_empty():
		_ui.show_notification(_no_evidence_msg())
	else:
		_popup_clue_cards("证据库", cards)

# ===================== 动作（通用分发 + 内容 virtual） =====================
func _on_action(action_id: String) -> void:
	match action_id:
		"look": _toggle_observe()
		"talk": _npc_talk()
		"examine": _toggle_toolbar()
		"think": _open_wall()
		"prop": _show_props()
		"journal": _show_journal()
		"kb": _open_knowledge_base()
		"save": _do_save()
		"load": _do_load()

func _toggle_observe() -> void:
	if not _in_observe_phase(): _ui.show_notification(_observe_locked_msg()); return
	var obs := _current_observer()
	if obs == null: _ui.show_notification("观察器未初始化"); return
	if obs.is_active():
		obs.hide()
		_ui.show_notification("观察模式关闭")
		if _toolbar: _toolbar.hide_toolbar()
	else:
		obs.show()
		_ui.show_notification(_observe_open_msg())
		# 进入观察即弹出道具工具栏（放大镜/卷尺/黄页等），不再依赖单独按钮时机
		if _toolbar: _toolbar.show_toolbar()

func _npc_talk() -> void:
	_ui.set_dialogue("", _npc_talk_text(_clues.size()))

## 调查按钮：调出/隐藏道具工具栏（toggle）。
## 未进入观察阶段时先进入观察（道具需可点击热点），再展开工具栏；
## 已在观察阶段则根据当前工具栏可见性切换显隐。
func _toggle_toolbar() -> void:
	# 真正的 toggle：已展开 → 收起；未展开 → 展开（非观察阶段则先进入观察再展开）。
	# 旧实现非观察阶段只 show 后直接 return，导致「能调出、不能隐藏」。
	if _toolbar and _toolbar.is_active:
		_toolbar.hide_toolbar()
		_ui.show_notification("道具栏已收起")
		return
	if not _in_observe_phase():
		var obs := _current_observer()
		if obs == null: _ui.show_notification("当前阶段无法观察"); return
		obs.show()
		_ui.show_notification(_observe_open_msg())
	if _toolbar: _toolbar.show_toolbar()
	_ui.show_notification("道具栏已展开")

# ===================== 推理墙（统一机制，参数化来源/假设/回调） =====================
## #146 根因修复：进入推理阶段的统一提示。
## 原实现各场景用 `await create_timer(2.x).timeout; _open_wall()` 定时自动开墙，
## 玩家没做任何操作剧情就被推着走（自动跳剧情）。此处只切台词 + 给出行动指引，
## 推理墙必须由玩家主动点击【思考 / 推理】才打开。
func _prompt_think(speaker: String, line: String, mood: String = "") -> void:
	_ui.set_dialogue(speaker, line, mood)
	_ui.show_notification("💡 准备好后，点击【思考】按钮打开推理墙")

## 全项目唯一的推理墙入口：始终使用 scripts/clue/reasoning_wall.gd。
## source    —— 线索源（默认 clue_source()）；多组场景（场景一）传 "watson"/"messenger"。
## hypothesis——假设字典（默认 reasoning_hypothesis()）。
## on_verify —— 验证后回调（默认 _default_wall_verify，按 _wall_auto 推进过渡）。
## 这样场景一与场景二/三共用同一套墙，杜绝「手搓墙 + 基类墙」两套机制并存。
func _open_wall(source: String = "", hypothesis: Dictionary = {}, on_verify: Callable = Callable(), on_continue: Callable = Callable()) -> void:
	# 单例 + 开关：已开则关闭（点一次出现，再点一次关闭），杜绝多重墙叠加导致显示异常
	if _wall_instance and is_instance_valid(_wall_instance):
		_wall_instance.close_wall()
		return
	# 案件级大墙：未显式指定 source（场景二~八）时打开「全案线索池」（归并所有场景已收集线索，
	# 支持跨场景线索关联）；场景一显式传 "watson"/"messenger" 时仍按该组范围（保留其分墙设计）。
	var use_case_wide := (source == "")
	var src := source if not use_case_wide else clue_source()
	var pool: Array = _clues
	if ClueSystem != null:
		pool = ClueSystem.get_collected("") if use_case_wide else ClueSystem.get_collected(src)
	if (ClueSystem and ClueSystem.count_collected("") == 0) and _clues.is_empty():
		_ui.show_notification("推理墙需要至少一条线索才能打开。"); return
	# REASONING 阶段打开的墙（自动弹出或手动重开）验证后必须推进过渡；
	# 观察阶段「线索已收满」后手动开墙（玩家在 _on_observe_complete 的 2.5s 对话窗口内
	# 顺手点「思考」即落在 OBSERVE 阶段）同样视为验证模式，必须推进过渡；
	# 仅「观察阶段且线索未收满」的手动开墙才是预览、不推进。
	_wall_auto = _in_reasoning_phase() or _clues.size() >= hotspots().size()
	# #129 根因修复：推理墙是全屏 MOUSE_FILTER_STOP 浮层，会压住任何已开弹窗
	# （如「知识检索」），使其关闭按钮点击无效。开墙前先关闭现有弹窗。
	_close_modal()
	if _ui: _ui.set_camera_enabled(false)   # 推理墙全屏覆盖，禁用摄像机平移/缩放
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	if not rw: _ui.show_notification("推理墙模块未找到"); return
	var wall = rw.new(); wall.name = "ReasoningWall"; add_child(wall)
	# 墙销毁时自动清空单例引用，保证下次「思考」能正确开关
	wall.tree_exiting.connect(func():
		if _wall_instance == wall: _wall_instance = null
		# 墙关闭（返回探索 或 验证后过渡）：恢复摄像机并归位到统览态。
		# 根治「观察推近后开墙/验证」残留放大态，导致下一阶段看不到场景
		# （场景一华生→信使同款 bug：华生推近后切信使，镜头停在放大态挡住信使立绘）。
		if _ui:
			_ui.set_camera_enabled(true)
			_ui.reset_camera()
	)
	_wall_instance = wall
	if _toolbar: _toolbar.hide_toolbar()   # 确保墙置顶、不被工具栏 CanvasLayer(layer 128) 遮挡
	# 推理墙读取通用线索登记（单一真相源）；案件级大墙传「全案线索池」，观察星仍按本场景已收集条数计
	var clues: Array = pool
	var local_count: int = clues.size()
	if ClueSystem != null:
		local_count = ClueSystem.count_collected(src)
	var hypo := hypothesis if not hypothesis.is_empty() else reasoning_hypothesis()
	# 未显式给定 expected_clues 时，用「本场景已收集条数」作观察星分母，避免全案池扩大抬高观察星
	if not hypo.has("expected_clues"):
		hypo["expected_clues"] = local_count
	var cb := on_verify if on_verify.is_valid() else _default_wall_verify
	# advance 始终传入 _advance_now；是否真正推进由「已验证 + 实时状态」在
	# _default_wall_verify / _on_back_pressed 中判定，避免开墙时刻的 _wall_auto
	# 把「提前开的预览墙」永久锁死为不推进（场景二反复复现的卡死根因）。
	var advance: Callable = Callable(self, "_advance_now")
	wall.setup(clues, hypo, cb, Callable(self, "_on_wall_closed"), _difficulty, on_continue, _wall_state, advance, true, local_count)

## 默认验证回调：展示判定结果；满足「推理阶段」或「线索已收满」则自动推进过渡。
## 三级反馈映射（06 §2.3 + 一致性报告 H-3）：已获证实+倾向成立→正确（绿）；
## 证据不足→存疑（黄）；矛盾冲突→错误（红）。
## ⚠️ 推进判定在「提交验证」这一刻实时重算，绝不依赖开墙时算出的 _wall_auto：
## 若玩家在 OBSERVE 阶段、线索未收满时就点「思考」开了墙（_wall_auto 当时为 false），
## 之后收满线索再在该墙内提交验证，仍须推进过渡——否则会卡死（场景二反复复现的坑）。
func _default_wall_verify(verdict: int) -> void:
	var fb = {
		0: ["错误 ❌", Color(0.95, 0.3, 0.3)],
		1: ["存疑 ❓", Color(0.95, 0.8, 0.2)],
		2: ["正确 ✅", Color(0.4, 0.85, 0.4)],
		3: ["正确 🌟", Color(0.3, 0.95, 0.3)],
	}
	var entry = fb.get(verdict, ["等待", Color.WHITE])
	_ui.show_notification("推理验证结果：" + entry[0])
	var advance := _in_reasoning_phase() or (_clues.size() >= hotspots().size())
	if advance:
		_advance_now()

## 统一推进剧情入口（验证确认 与 关墙返回 共用）：先清掉可能残留的浮层，
## 再进过渡对话。这是「新玩不推进、读档能推进」的根治点——
## 新玩过程中若开过知识库弹窗(右下角难点到关闭)或工具栏(关不掉)，其 _modal_panel /
## 工具栏覆盖层会残留，_advance_blocked() 永久拦截过渡对话；读档重建场景把这些状态清零，
## 故读档能推进。此处防御性清场，保证无论之前开过什么，验证后剧情必定推进。
func _advance_now() -> void:
	_close_modal()                       # 清掉残留弹窗（知识库等），否则 _advance_blocked 拦截
	if _toolbar: _toolbar.hide_toolbar() # 清掉残留工具栏覆盖层
	_enter_transition()

## 推理墙关闭回调（玩家点击「返回探索 / X 关闭」后触发）。
## 默认空实现：墙本身是模态浮层，关闭即恢复底层场景交互，等于玩家进入前的状态。
## 子类可重写以返回到具体来源（如场景一在 watson / messenger 两种推理墙间切换）。
func _on_wall_closed() -> void:
	pass

# ===================== 知识库面板（#接入：《04_推理知识库.md》） =====================
## 单例 + toggle：已开则关闭（点一次出现，再点一次关闭），杜绝多重叠加。
## 遵循项目铁律：开面板须 hide_toolbar() 置顶，并用 _register_modal 记录单例引用。
func _open_knowledge_base() -> void:
	if _kb_panel and is_instance_valid(_kb_panel):
		_close_modal()
		return
	var kbs = load("res://scripts/knowledge/knowledge_base_panel.gd")
	if not kbs:
		_ui.show_notification("知识库模块未找到")
		return
	var panel = kbs.new(); panel.name = "KnowledgeBasePanel"; add_child(panel)
	# 销毁时自动清空单例引用，保证下次「百科」能正确开关
	panel.tree_exiting.connect(func():
		if _kb_panel == panel: _kb_panel = null
	)
	panel.close_requested.connect(_close_modal)
	_kb_panel = panel
	# 复用弹窗单例机制：记录引用 + 隐藏工具栏，避免被 CanvasLayer(layer 128) 遮挡
	_register_modal(panel, "知识库")

func _show_journal() -> void:
	if ClueSystem: _sync_clues()   # 进入推理前（对话阶段）也实时反映已收集线索，避免笔记显示为空
	var items: Array = []
	if _clues.is_empty(): items.append({"name": "暂无记录", "desc": _journal_empty_hint()})
	else:
		for c in _clues:
			items.append({"name": "📌 " + str(c.get("name", "")), "desc": str(c.get("desc", ""))})
	_popup("侦探笔记", items)

# ===================== 道具系统（#139） =====================
## 获取道具（去重：已获取的不会重复添加）。
## 子类在剧情节点调用：acquire_prop("coin", "半镑金币", "兰斯警士发现时死者手中的硬币", "")
func acquire_prop(prop_id: String, prop_name: String, prop_desc: String, icon_path: String = "") -> void:
	if _props.has(prop_id):
		return
	_props[prop_id] = {"id": prop_id, "name": prop_name, "desc": prop_desc, "icon": icon_path}
	_ui.show_notification("🎒 获得道具：" + prop_name)

## 显示道具栏弹窗（单例 + toggle）。每个道具渲染为「图标 + 名称 + 描述 + 查看」卡片。
func _show_props() -> void:
	var title := "道具栏"
	if _modal_title == title and is_instance_valid(_modal_panel):
		_close_modal(); return
	_close_modal()
	var o := Panel.new(); o.position = Vector2(460, 120); o.size = Vector2(1000, 700); o.z_index = 100
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.97), Color(0.78, 0.62, 0.28), 2, 6))
	var tt := Label.new(); tt.text = title + "（" + str(_props.size()) + " 件）"; tt.position = Vector2(30, 18)
	tt.add_theme_font_size_override("font_size", 28); tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	if _props.is_empty():
		var empty := Label.new(); empty.text = "（空）尚未获取任何道具"; empty.position = Vector2(30, 80)
		empty.add_theme_font_size_override("font_size", 20); empty.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45)); o.add_child(empty)
	else:
		var sc := ScrollContainer.new(); sc.position = Vector2(20, 70); sc.size = Vector2(960, 560)
		var ct := VBoxContainer.new(); ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ct.add_theme_constant_override("separation", 12)
		sc.add_child(ct)
		for p in _props.values():
			ct.add_child(_make_prop_card(p))
		o.add_child(sc)
	var cl := Button.new(); cl.text = "关闭"; cl.position = Vector2(430, 620); cl.size = Vector2(140, 45)
	cl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); cl.add_theme_font_size_override("font_size", 20)
	cl.pressed.connect(_close_modal); o.add_child(cl)
	add_child(o); _register_modal(o, title)

## 单个道具卡片：图标(110) + 名称/描述 + 查看按钮
func _make_prop_card(p: Dictionary) -> Control:
	var card := Panel.new(); card.custom_minimum_size = Vector2(940, 120)
	card.add_theme_stylebox_override("panel", _sb(Color(0.14, 0.10, 0.06, 0.55), Color(0.55, 0.42, 0.20), 1, 6))
	var hb := HBoxContainer.new(); hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)
	var icon := TextureRect.new(); icon.custom_minimum_size = Vector2(110, 110); icon.size = Vector2(110, 110)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ip := str(p.get("icon", ""))
	if not ip.is_empty():
		var tex = load(ip)
		if tex: icon.texture = tex
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(icon)
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vb.add_theme_constant_override("separation", 6)
	var nm := Label.new(); nm.text = str(p.get("name", "")); nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", Color(0.92, 0.85, 0.6)); vb.add_child(nm)
	var ds := Label.new(); ds.text = str(p.get("desc", "")); ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ds.add_theme_font_size_override("font_size", 16)
	ds.add_theme_color_override("font_color", Color(0.62, 0.57, 0.47)); vb.add_child(ds)
	hb.add_child(vb)
	var look := Button.new(); look.text = "查看"; look.size = Vector2(120, 50); look.add_theme_font_size_override("font_size", 18)
	look.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	look.pressed.connect(func(): _show_prop_detail(p)); hb.add_child(look)
	return card

## 道具详情：大图 + 名称 + 描述；并触发场景相关功能 on_use_prop（如查看戒指揭示刻字）。
func _show_prop_detail(p: Dictionary) -> void:
	_close_modal()
	on_use_prop(str(p.get("id", "")))
	var o := Panel.new(); o.position = Vector2(660, 220); o.size = Vector2(600, 470); o.z_index = 110
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.98), Color(0.78, 0.62, 0.28), 2, 6))
	var tt := Label.new(); tt.text = str(p.get("name", "")); tt.position = Vector2(30, 18); tt.add_theme_font_size_override("font_size", 26)
	tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	var icon := TextureRect.new(); icon.position = Vector2(220, 70); icon.size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ip := str(p.get("icon", ""))
	if not ip.is_empty():
		var tex = load(ip)
		if tex: icon.texture = tex
	o.add_child(icon)
	var ds := Label.new(); ds.text = str(p.get("desc", "")); ds.position = Vector2(30, 260); ds.size = Vector2(540, 130)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ds.add_theme_font_size_override("font_size", 18)
	ds.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55)); o.add_child(ds)
	var cl := Button.new(); cl.text = "关闭"; cl.position = Vector2(230, 405); cl.size = Vector2(140, 45)
	cl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); cl.add_theme_font_size_override("font_size", 20)
	cl.pressed.connect(_close_modal); o.add_child(cl)
	add_child(o); _register_modal(o, "道具详情")

## 道具使用钩子：子类可重写以触发剧情（如 scene5 查看戒指揭示刻字「L.F.」）。
func on_use_prop(prop_id: String) -> void:
	pass

# ===================== 存 / 读档（通用核心） =====================
func _do_save(slot: int = -1) -> void:
	# 存档为登录用户专属（游客不可存档）
	if GameManager and GameManager.is_guest:
		_ui.show_notification("游客模式不支持存档 — 请返回主菜单注册/登录")
		return
	var data := {"clue_ids": []}
	# 以本场景本地进度为权威（不读全局 ClueSystem，避免跨轮累计污染存档）
	var ids: Array = []
	for c in _clues: ids.append(c.get("id", ""))
	if ids.is_empty():
		for c in _obs.get_recorded_clues(): ids.append(c.get("id", ""))
	data["clue_ids"] = ids
	print("[SAVE " + scene_id() + "] _phase=", _phase, " data=", data)
	# 保存不需要选槽位：自动分配（空槽位优先，满则覆盖最旧），滚动保留最近 3 次存档
	await SaveSystem.request_save(scene_id(), _phase, data, slot)
	# 保存成功提示用本地时间（get_datetime_string_from_system 默认即本地时区），
	# 修复此前用 UTC 时间戳直接格式化导致「存档时间与现实差好几个小时」。
	_ui.show_notification("✅ 进度已保存 " + Time.get_datetime_string_from_system().replace("T", " "))

func _do_load() -> void:
	# 存档为登录用户专属（游客不可读档）
	if GameManager and GameManager.is_guest:
		_ui.show_notification("游客模式不支持读档 — 请返回主菜单注册/登录")
		return
	if not SaveManager:
		_ui.show_notification("存档系统不可用")
		return
	# 读档时才显示槽位：仅列出已有存档，按时间倒序（最新在最上面）
	var slots: Array = SaveManager.get_slot_list_sorted()
	if slots.is_empty():
		_ui.show_notification("暂无存档")
		return
	var dlg = preload("res://scripts/ui/slot_dialog.gd").new()
	dlg.configure("load", slots, func(slot):
		var ok = await SaveSystem.load_game(slot)
		if ok:
			# 关键：跳转到「存档所属场景」，而不是盲目重载当前场景。
			# 否则跨场景读档时 scene_id 不匹配 → take_save_state 返回空 → 场景从头开始（读档失效）。
			var target_id: String = GameManager.current_scene_id if GameManager else ""
			var target_path := "res://scenes/" + target_id + ".tscn"
			if target_id != "" and target_id != scene_id() and ResourceLoader.exists(target_path):
				SceneLoader.transition_to(target_path)
			else:
				get_tree().reload_current_scene()
		else:
			_ui.show_notification("没有可用的存档"))
	add_child(dlg)

## 恢复存档进度（单组场景的通用实现：场景一覆盖为两组版本）
## 返回 true 表示有存档且已恢复，false 表示新游戏。
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state(scene_id())
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 先恢复阶段（避免子方法漏设 _phase 导致阶段错乱——场景一/二/三同款防御）
	_phase = saved_phase
	# 若读档的是终局阶段，则本次「继续推进」按钮不再自动存档——否则每次读档点继续
	# 都会写入一份 identical 存档，导致读档面板出现多个一模一样的终局槽位。
	_suppress_terminal_save = _is_terminal_phase(saved_phase)
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")
	# 以存档 clue_ids 为唯一权威重建本地进度，并同步 ClueSystem（推理墙单一真相源），
	# 杜绝「场景内进度（_obs 已记录数）」与「推理墙（ClueSystem 全局累计）」不一致的「两层皮」。
	_clues = []
	if ClueSystem: ClueSystem.clear_source(clue_source())
	for cid in saved_ids:
		var h = _get_hotspot(cid)
		if not h.is_empty():
			_clues.append(h)
			if ClueSystem: ClueSystem.collect_clue_from_catalog(cid, h.get("label", ""), h.get("desc", ""), h.get("correct", true), clue_source(), int(h.get("wt", -1)))
	return _apply_restored_phase(saved_phase, saved_ids, _clues)

## 子类按自身 Phase 分支恢复（通用骨架已处理好 ClueSystem 同步与通知）
func _apply_restored_phase(_phase_val: int, _ids: Array, _clues_arr: Array) -> bool:
	return false

# ===================== 对话引擎（通用） =====================
## 启动一段对话：复用/重建 DialogueManager，连接通用 _on_line 与给定结束回调。
## 启动一段对话。start_e/start_n/start_h 分别指定三难度入口（缺省回退 start）；
## 场景二~八据此让同一段对话按难度走不同链（scene1 已验证）。
func _start_dialogue(nodes: Array[Resource], start: String, on_end: Callable, start_e: String = "", start_n: String = "", start_h: String = "") -> void:
	if _dm:
		if _dm.dialogue_advanced.is_connected(_on_line): _dm.dialogue_advanced.disconnect(_on_line)
		_dm.queue_free()
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	# M2：对话进行中禁用摄像机（避免点击推进与拖拽/缩放冲突），结束后由基类恢复
	if _ui: _ui.set_camera_enabled(false)
	_dm.dialogue_ended.connect(_on_dialogue_ended_base.bind(on_end))
	_dm.dialogue_resource = _make_dialogue_resource(scene_id() + "_dlg", nodes, start, start_e, start_n, start_h)
	_dm.start_dialogue()

## 对话结束统一处理：先恢复摄像机（回到可观察状态），再执行场景自定义的 on_end。
## 推理墙/评分等会自行再次禁用摄像机，故此处无条件恢复是安全的。
## 额外安全网：对话结束一律 reset_camera() 归位到统览态（zoom=1, position=0），
## 杜绝「观察推近后残留放大态」导致下一阶段/场景看不到内容（场景一华生→信使同款 bug）。
func _on_dialogue_ended_base(on_end: Callable) -> void:
	if _ui:
		_ui.set_camera_enabled(true)
		_ui.reset_camera()
	if on_end.is_valid(): on_end.call()

func _on_line(_id: String) -> void:
	var n = _dm.current_node
	if n: _ui.set_dialogue(n.speaker, n.text, n.mood)

## 构造对话节点：末节点不挂 next（advance() 检测到 next 为空即干净结束，
## 避免把末节点指到不存在的虚拟节点而刷 ERROR——已在场景二/三根治）。
## 行格式: [id, speaker, text] 或 [id, speaker, text, next] 或 [id, speaker, text, next, mood]
##   或 [id, speaker, text, next, mood, diff_filter]
## next 传 "" 表示按 id 自增推导（与省略等价），便于只想指定 mood 的行。
## diff_filter: 0=全难度 / 1=EASY / 2=NORMAL / 3=HARD（缺省 0）；用于「不同难度不同台词」分支变体。
func _make_nodes(raw: Array) -> Array[Resource]:
	var nodes: Array[Resource] = []
	var last_idx := raw.size() - 1
	for i in raw.size():
		var r = raw[i]
		var n = DialogueNodeResource.new()
		n.node_id = r[0]; n.speaker = r[1]; n.text = r[2]; n.trigger = "click"
		var nxt: Array[String] = []
		if i < last_idx:
			if len(r) > 3 and str(r[3]) != "":
				nxt.append(r[3])
			else:
				var base: String = r[0]
				var num: int = int(base.substr(1)) + 1
				nxt.append(base[0] + str(num))
		n.next_nodes = nxt
		n.mood = r[4] if len(r) > 4 else "neutral"
		n.difficulty_filter = r[5] if len(r) > 5 else 0
		nodes.append(n)
	return nodes

## 构造对话资源。start_e/start_n/start_h 分别指定三难度的入口节点（缺省回退 start），
## 用于「不同难度走独立对话链」（如 scene1 开场 s0_e/s0_n/s0_h）。
func _make_dialogue_resource(sid: String, ns: Array[Resource], start: String, start_e: String = "", start_n: String = "", start_h: String = "") -> DialogueResource:
	var r = DialogueResource.new(); r.scene_id = sid; r.scene_name = scene_id()
	r.nodes = ns
	var e := start_e if start_e != "" else start
	var n_ := start_n if start_n != "" else start
	var h := start_h if start_h != "" else start
	r.easy_start_node = e; r.normal_start_node = n_; r.hard_start_node = h
	return r

## P3-0 构造对话节点：支持 trigger 与 grants_clues（对话授予线索）。
## 默认 trigger=="click" 即点即推进；grants 为 [{"id","name","desc","correct"}, ...]。
## ⚠️ diff_filter: 0=全难度 / 1=EASY / 2=NORMAL / 3=HARD（见 DialogueNodeResource.should_show）。
##    用于「不同难度不同台词」：父节点 next 指 [variant_e, variant_n, variant_h]，每个变体带各自
##    diff_filter 并链式为 next（variant_e→variant_n→variant_h→end），引擎 skip-walk 会自动走到
##    当前难度第一个可见变体，且不误判 end 提前结束（scene1 已验证，tools/test_difficulty_dialogue.gd 通过）。
func _mk_node(id: String, speaker: String, text: String, trigger: String = "click", next: Array = [], grants: Array = [], mood: String = "neutral", diff_filter: int = 0) -> DialogueNodeResource:
	var n = DialogueNodeResource.new()
	n.node_id = id; n.speaker = speaker; n.text = text; n.trigger = trigger
	var nn: Array[String] = []
	for s in next:
		if s is String: nn.append(s)
	n.next_nodes = nn
	n.grants_clues = grants
	n.mood = mood
	n.difficulty_filter = diff_filter
	return n

## ===== 难度相关对话辅助（scene1 已验证，下沉为基类供场景二~八复用） =====
## 观察提示文案按难度分流。person=true 主语用「身上」（人物，如华生/信使），false 用「里」（地点/场景）。
func _observe_hint(target: String, person: bool = false) -> String:
	var where := "身上" if person else "里"
	if DifficultyManager:
		match DifficultyManager.current_difficulty:
			DifficultyManager.Difficulty.EASY:
				return "观察模式 — 所有可观察点已高亮，点击%s%s高亮的圆圈" % [target, where]
			DifficultyManager.Difficulty.HARD:
				return "观察模式 — 无提示标记，请自行观察%s%s的细节" % [target, where]
	return "观察模式 — 点击%s%s高亮的圆圈" % [target, where]

## 从推理墙返回继续观察时的提示尾句（困难无高亮）。
func _resume_suffix() -> String:
	if DifficultyManager and DifficultyManager.current_difficulty == DifficultyManager.Difficulty.HARD:
		return "继续自行观察收集剩余线索"
	return "继续点击高亮的圆圈收集剩余线索"

## 困难/普通模式（当前难度过滤后仍存在干扰项）下，提示玩家甄别干扰线索。
## 仅在「当前难度确有 correct=false 的热点」时返回非空，避免无干扰项的场景（如场景二/三）误报。
## （场景一信使观察的 sleeve/limp 干扰项即走此路径；场景二~八无干扰项，恒返回空）
func _observe_warn_suffix() -> String:
	if _has_misleading_clues():
		return "（注意：本场景线索可能混有干扰项，请甄别判断）"
	return ""

func _has_misleading_clues() -> bool:
	var hs: Array = hotspots()
	if DifficultyManager:
		hs = DifficultyManager.filter_hotspots_by_difficulty(hs)
	for h in hs:
		if not h.get("correct", true):
			return true
	return false

## 同步本地 _clues 数组（证据库/物品栏展示用）为 ClueSystem 中本场景 source 的已收集线索。
func _sync_clues() -> void:
	if ClueSystem:
		_clues = ClueSystem.get_collected(clue_source())

## 从存档 clue_ids 重建 ClueSystem 已收集线索（对话/工具授予、非热点线索也能恢复，不依赖热点）。
## 在 SaveManager 已全局恢复 collected_clues 之后调用：先抓回本 source 的 name/desc，
## 避免 clear_source 后重新 collect 时空 name/desc 覆盖已恢复的好数据。
func _restore_clues_from_ids(saved_ids: Array) -> void:
	if not ClueSystem:
		_clues = []
		for cid in saved_ids: _clues.append({"id": cid})
		return
	var prior: Dictionary = {}
	for c in ClueSystem.get_collected(clue_source()):
		prior[c.get("id", "")] = c
	ClueSystem.clear_source(clue_source())
	_clues = []
	for cid in saved_ids:
		var h = _get_hotspot(cid)
		if not h.is_empty():
			_clues.append(h)
			ClueSystem.collect_clue_from_catalog(cid, h.get("label", ""), h.get("desc", ""), h.get("correct", true), clue_source(), int(h.get("wt", -1)))
		else:
			var p = prior.get(cid, {})
			# 对话/工具授予的非热点线索：从先前已收集副本回收权重（prior 含 "weight"）
			ClueSystem.collect_clue_from_catalog(cid, p.get("name", ""), p.get("desc", ""), p.get("correct", true), clue_source(), int(p.get("weight", -1)))
			_clues.append({"id": cid, "name": p.get("name", ""), "desc": p.get("desc", "")})

## 剧情推进闸门（#124 根因修复）：以下情形一律不推进剧情——
##   1. 推理墙开着（点墙上的卡片/按钮不能把剧情偷跑到下一场景）
##   2. 任一弹窗/面板开着（知识检索、案件簿、地图、选项等）
##   3. 工具交互覆盖层激活（放大镜/卷尺/试剂弹窗）
##   4. 观察模式激活（点击热点是在收集线索，不是在推剧情）
##   5. 鼠标悬停在任意按钮等交互控件上（点按钮就只是点按钮）
func _advance_blocked(is_mouse: bool) -> bool:
	if _wall_instance and is_instance_valid(_wall_instance): return true
	if _modal_panel and is_instance_valid(_modal_panel): return true
	if _toolbar and _toolbar.has_method("_is_overlay_active") and _toolbar._is_overlay_active(): return true
	# 观察器激活只应在「观察阶段」拦截对话推进（点击热点是在收集线索，不是在推剧情）。
	# 非观察阶段（如场景四人证调查类，_in_observe_phase 恒 false）即使观察器因简单模式
	# auto-show 残留为 active，也不得拦截对话推进，否则入场演出台词点不动、卡死。
	if _obs and _obs.has_method("is_active") and _obs.is_active() and _in_observe_phase(): return true
	if is_mouse:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered is BaseButton: return true
	return false

func _input(event: InputEvent) -> void:
	# 对话推进只取决于「对话是否在进行中」（_dm.is_active()，与场景一机制一致），
	# 但受 _advance_blocked 闸门约束：收集线索/点按钮/开墙/开弹窗期间剧情绝不推进。
	if not _dm or not _dm.is_active(): return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if _advance_blocked(true): return
		# 鼠标滚轮：回看台词（上滚更早，下滚更新）
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _ui: _ui.review_step(-1)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _ui and _ui.is_reviewing(): _ui.review_step(1)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		# 回看态下点击：先返回实时台词，不推进（防误跳过剧情）
		if _ui and _ui.is_reviewing():
			_ui.exit_review()
			return
		if _dm.get_current_trigger() != "choice": _dm.advance()
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if _advance_blocked(false): return
		# 键盘左右键：回看台词
		if key.keycode == KEY_LEFT:
			if _ui: _ui.review_step(-1)
			return
		if key.keycode == KEY_RIGHT:
			if _ui and _ui.is_reviewing(): _ui.review_step(1)
			return
		if key.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
			if _ui and _ui.is_reviewing():
				_ui.exit_review()
				return
			if _dm.get_current_trigger() != "choice": _dm.advance()

# ===================== 通用弹窗 / 样式（所有场景共用） =====================
func _create_notification(msg: String) -> void:
	if _ui: _ui.show_notification(msg)

func _sb(bg: Color, bc: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = bg; s.border_width_left = bw; s.border_width_right = bw
	s.border_width_top = bw; s.border_width_bottom = bw; s.border_color = bc
	s.set_corner_radius_all(cr); return s

## 弹窗单例注册：记录当前打开的面板并隐藏工具栏，避免被 CanvasLayer 遮挡。
func _register_modal(panel: Control, title: String) -> void:
	_modal_panel = panel
	_modal_title = title
	if _toolbar: _toolbar.hide_toolbar()

## 弹窗单例关闭：释放当前面板并清空引用（点一次开/再点一次关）。
func _close_modal() -> void:
	if _modal_panel and is_instance_valid(_modal_panel):
		_modal_panel.queue_free()
	_modal_panel = null
	_modal_title = ""

func _popup(title_txt: String, items: Array) -> void:
	# 单例 + 开关：同标题面板已开 -> 关闭（toggle）；否则关闭旧的再开新的，杜绝多重叠加
	if _modal_panel and is_instance_valid(_modal_panel):
		if _modal_title == title_txt:
			_close_modal(); return
		_modal_panel.queue_free(); _modal_panel = null
	var o = Panel.new(); o.position = Vector2(460, 120); o.size = Vector2(1000, 700); o.z_index = 100
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.97), Color(0.78, 0.62, 0.28), 2, 6))
	var tt = Label.new(); tt.text = title_txt; tt.position = Vector2(30, 20); tt.add_theme_font_size_override("font_size", 28)
	tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	# 顶部拖拽手柄：按住标题区即可移动弹窗（透明覆盖，不挡视觉）
	var drag_bar := Control.new(); drag_bar.name = "DragBar"
	drag_bar.position = Vector2(0, 0); drag_bar.size = Vector2(1000, 64)
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP; o.add_child(drag_bar)
	WindowDrag.make_draggable(o, drag_bar)
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
	cl.pressed.connect(_close_modal); 	o.add_child(cl); add_child(o)
	_register_modal(o, title_txt)

## 证据库专用弹窗：直接容纳 ClueAnchorCard 卡片列表（线索与身体部位同卡绑定）。
## 与 _popup 共用同一套 modal 单例/拖拽/关闭机制，仅内容区改为卡片纵向滚动。
func _popup_clue_cards(title_txt: String, cards: Array) -> void:
	if _modal_panel and is_instance_valid(_modal_panel):
		if _modal_title == title_txt:
			_close_modal(); return
		_modal_panel.queue_free(); _modal_panel = null
	var o = Panel.new(); o.position = Vector2(460, 120); o.size = Vector2(1000, 700); o.z_index = 100
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.97), Color(0.78, 0.62, 0.28), 2, 6))
	var tt = Label.new(); tt.text = title_txt; tt.position = Vector2(30, 20); tt.add_theme_font_size_override("font_size", 28)
	tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	var drag_bar := Control.new(); drag_bar.name = "DragBar"
	drag_bar.position = Vector2(0, 0); drag_bar.size = Vector2(1000, 64)
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP; o.add_child(drag_bar)
	WindowDrag.make_draggable(o, drag_bar)
	var sc = ScrollContainer.new(); sc.position = Vector2(30, 70); sc.size = Vector2(940, 570)
	var ct = Control.new(); ct.size = Vector2(920, max(cards.size() * 212, 10))
	var yy = 0
	for c in cards:
		c.position = Vector2(0, yy); ct.add_child(c); yy += 212
	sc.add_child(ct); o.add_child(sc)
	var cl = Button.new(); cl.text = "关闭"; cl.position = Vector2(430, 620); cl.size = Vector2(140, 45)
	cl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); cl.add_theme_font_size_override("font_size", 20)
	cl.pressed.connect(_close_modal); o.add_child(cl); add_child(o)
	_register_modal(o, title_txt)

# ===================== 自定义选项面板 / 自由调查（统一基类，所有场景共用） =====================
## 通用选项面板（安全分支，不依赖对话引擎 choice 渲染）：title + options[{text,cb}]，
## 点击选项先关闭面板再执行 cb。所有场景的「追问面板 / 自由调查 / 行动决策 / 自白」均走这里，
## 修改只改这一处即可全局生效（满足「统一为基类」诉求）。
func _show_choice_panel(title_txt: String, options: Array) -> void:
	if _modal_panel and is_instance_valid(_modal_panel):
		_modal_panel.queue_free(); _modal_panel = null
	var o := Panel.new()
	o.position = Vector2(460, 180); o.size = Vector2(1000, 640); o.z_index = 100
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.97), Color(0.78, 0.62, 0.28), 2, 6))
	var tt := Label.new(); tt.text = title_txt; tt.position = Vector2(30, 20); tt.add_theme_font_size_override("font_size", 26)
	tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	# 顶部拖拽手柄：按住标题区即可移动面板（透明覆盖，不挡视觉；选项按钮从 y=84 起，不冲突）
	var drag_bar := Control.new(); drag_bar.name = "DragBar"
	drag_bar.position = Vector2(0, 0); drag_bar.size = Vector2(1000, 80)
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP; o.add_child(drag_bar)
	WindowDrag.make_draggable(o, drag_bar)
	var y := 84
	for opt in options:
		var b := Button.new()
		b.text = opt["text"]
		b.position = Vector2(40, y); b.size = Vector2(920, 70)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(0.92, 0.85, 0.65))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.14, 0.10, 0.06, 0.95); bs.border_color = Color(0.55, 0.42, 0.20)
		bs.border_width_left = 2; bs.border_width_right = 2; bs.border_width_top = 2; bs.border_width_bottom = 2; bs.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", bs)
		var bsh := StyleBoxFlat.new(); bsh.bg_color = Color(0.25, 0.16, 0.08, 0.95); bsh.border_color = Color(0.80, 0.68, 0.38)
		bsh.border_width_left = 2; bsh.border_width_right = 2; bsh.border_width_top = 2; bsh.border_width_bottom = 2; bsh.set_corner_radius_all(4)
		b.add_theme_stylebox_override("hover", bsh)
		var cb_callable: Callable = opt["cb"]
		b.pressed.connect(func(): _close_modal(); cb_callable.call())
		o.add_child(b); y += 80
	add_child(o); _register_modal(o, "choice_" + title_txt)

## 自由调查 / 追问面板（统一基类）：questions 为全部问题 [{"id","text","cb"}]，
## asked 为已问 id 字典（引用，自动累积）；每回答一题后该题从面板消失，直至选完或点"结束"。
## 这保证了 scene4 追问面板 / scene5/6/7 自由调查 / scene8 自白 行为完全一致（已问消失）。
func _render_investigate_panel(title_prefix: String, questions: Array, asked: Dictionary, on_done: Callable, done_text: String = "结束，整理说辞") -> void:
	var opts := []
	for q in questions:
		if asked.has(q["id"]):
			continue
		opts.append(q)
	opts.append({"text": "✅ " + done_text, "cb": on_done})
	_show_choice_panel(title_prefix + "（已问 " + str(asked.size()) + "/" + str(questions.size()) + "）", opts)

# ===================== 场景「侦破过程」评价面板（全场景共用，风格对齐场景一 _show_rating） =====================
## 在过渡对话结束后、进入下一场景前弹出本场景的侦破过程评价面板：
##   · 本链三星（观察🔍/推理🧠/洞察💡，来自 StarRatingSystem.get_chain_stars）
##   · 本场景线索收集进度 / 调查完成情况
##   · 案件累计星级
## show_case_total=true 时（结局场景八）额外展示全案总星级、结局档位与各链星级概览。
## on_continue 为空则按钮默认 SceneLoader.transition_to(next_scene_path)。
func _show_scene_rating(scene_label: String, next_scene_path: String, on_continue: Callable, show_case_total: bool = false) -> void:
	if _ui: _ui.set_camera_enabled(false)   # 评分面板全屏覆盖，禁用摄像机
	if _toolbar: _toolbar.hide_toolbar()
	var panel := Control.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(panel)
	var bg := ColorRect.new(); bg.color = Color(0.06,0.05,0.08,0.97); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.add_child(bg)
	var tt := Label.new(); tt.text = scene_label; tt.add_theme_font_size_override("font_size", 34)
	tt.add_theme_color_override("font_color", Color(0.92,0.82,0.45)); tt.position = Vector2(0,50); tt.size = Vector2(1920,50); tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tt)
	# 三星（来自 StarRatingSystem 当前链）
	var stars := {"observation":0,"reasoning":0,"insight":0}
	var srs = StarRatingSystem
	if srs: stars = srs.get_chain_stars(scene_id())
	var names := ["观察之星","推理之星","洞察之星"]; var keys := ["observation","reasoning","insight"]; var icons := ["🔍","🧠","💡"]
	var y := 160
	for i in 3:
		var sval: int = int(stars.get(keys[i], 0))
		var nl := Label.new(); nl.text = icons[i] + " " + names[i]; nl.add_theme_font_size_override("font_size", 24); nl.add_theme_color_override("font_color", Color(0.88,0.82,0.72))
		nl.position = Vector2(560, y); nl.size = Vector2(260,40); panel.add_child(nl)
		for s in 3:
			var sl := Label.new(); sl.text = "★" if s < sval else "☆"; sl.add_theme_font_size_override("font_size", 34)
			sl.add_theme_color_override("font_color", Color(0.95,0.78,0.20) if s < sval else Color(0.35,0.30,0.22))
			sl.position = Vector2(840 + s*54, y-6); sl.size = Vector2(46,46); panel.add_child(sl)
		y += 60
	# 本场景进度
	var prog := "调查问询完成"
	if hotspots().size() > 0:
		prog = "线索收集 %d/%d" % [_clues.size(), hotspots().size()]
	var pl := Label.new(); pl.text = prog; pl.add_theme_font_size_override("font_size", 18); pl.add_theme_color_override("font_color", Color(0.6,0.55,0.45))
	pl.position = Vector2(560, y); pl.size = Vector2(600,30); panel.add_child(pl); y += 40
	# 案件累计星级
	if srs:
		var cl := Label.new(); cl.text = "案件累计星级：%d / %d ⭐" % [srs.get_total_stars(), srs.get_max_total_stars()]; cl.add_theme_font_size_override("font_size", 18); cl.add_theme_color_override("font_color", Color(0.7,0.65,0.5))
		cl.position = Vector2(560, y); cl.size = Vector2(700,30); panel.add_child(cl); y += 40
	# 结局全案总结
	if show_case_total and srs:
		var pct := 0.0
		if srs.get_max_total_stars() > 0:
			pct = float(srs.get_total_stars()) / float(srs.get_max_total_stars())
		var grade := "见习侦探"
		if pct >= 0.9: grade = "传奇侦探"
		elif pct >= 0.7: grade = "杰出侦探"
		elif pct >= 0.5: grade = "合格侦探"
		var gl := Label.new(); gl.text = "结局评定：%s（完整度 %.0f%%）" % [grade, pct*100]; gl.add_theme_font_size_override("font_size", 22); gl.add_theme_color_override("font_color", Color(0.92,0.82,0.45))
		gl.position = Vector2(560, y); gl.size = Vector2(820,36); panel.add_child(gl); y += 46
		for cid in srs.chains.keys():
			var c: Dictionary = srs.chains[cid]
			var ll := Label.new(); ll.text = "%s：🔍%d 🧠%d 💡%d" % [cid, int(c["observation"]), int(c["reasoning"]), int(c["insight"])]; ll.add_theme_font_size_override("font_size", 15); ll.add_theme_color_override("font_color", Color(0.55,0.50,0.40))
			ll.position = Vector2(580, y); ll.size = Vector2(800,26); panel.add_child(ll); y += 26
	# 继续按钮
	var cont := Button.new(); cont.text = "继续推进"; cont.position = Vector2(760, 980); cont.size = Vector2(400, 64)
	cont.add_theme_font_size_override("font_size", 26); cont.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	cont.add_theme_stylebox_override("normal", _sb(Color(0.50,0.10,0.10,0.95), Color(0.85,0.65,0.25), 2, 4))
	cont.pressed.connect(_on_rating_continue.bind(panel, on_continue, next_scene_path))
	panel.add_child(cont)

func _on_rating_continue(panel: Control, on_continue: Callable, next_scene_path: String) -> void:
	if is_instance_valid(panel): panel.queue_free()
	if on_continue.is_valid():
		on_continue.call()
	elif next_scene_path != "":
		var sl = SceneLoader
		if sl: sl.transition_to(next_scene_path)

## 通用存档并跳转（封装场景进入下一场景前的自动存档；线索优先取本地 _clues，空则回退 ClueSystem）。
## 若 _suppress_terminal_save 为 true（刚从终局存档恢复而来），跳过本次自动存档，避免生成 identical 槽位。
func _save_and_transition(scene_key: String, next_path: String) -> void:
	if not _suppress_terminal_save:
		var gm = GameManager
		var sm = SaveManager
		var cs = ClueSystem
		var sv = SaveSystem
		if gm and (not gm.is_guest) and sm:
			var ids := []
			for c in _clues: ids.append(c.get("id", ""))
			if ids.is_empty() and cs:
				for cid in cs.get_collected_ids(clue_source()): ids.append(cid)
			await sv.request_save(scene_key, _phase, {"clue_ids": ids})
	var sl = SceneLoader
	if sl: sl.transition_to(next_path)

# ===================== 子类需实现的「内容」钩子 =====================
func _phase_name(_p: int) -> String: return "未知阶段"
## 子类覆盖：哪些阶段属于「终局阶段」。读档恢复到终局阶段时，会置 _suppress_terminal_save=true，
## 避免玩家点击「继续推进/进入下一场景」时再次自动存档，产生 identical 重复槽位。
## 人工 SAVE 按钮不受此标志影响，始终允许手动重复存档。
func _is_terminal_phase(_p: int) -> bool: return false
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
