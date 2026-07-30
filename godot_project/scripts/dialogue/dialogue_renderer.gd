extends Control
class_name DialogueRenderer

## DialogueRenderer v2.0 — 对话渲染器
## 支持扩展角色、新 trigger 类型、六步闭环标记、四级验证展示

# ============ UI 组件 ============

@onready var speaker_label: Label = $SpeakerLabel
@onready var text_label: RichTextLabel = $TextLabel
@onready var portrait: TextureRect = $Portrait
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var continue_hint: Label = $ContinueHint
@onready var choices_container: VBoxContainer = $ChoicesContainer
@onready var step_indicator: Label = $StepIndicator
@onready var difficulty_badge: Label = $DifficultyBadge
@onready var system_hint_label: Label = $SystemHintLabel

# ============ 数据 ============

var dialogue_manager: DialogueManager
var expression_map: Dictionary = {}  # 福尔摩斯表情映射（向后兼容）
var watson_expression_map: Dictionary = {}  # 华生表情映射
var is_typing: bool = false
var typewriter_speed: float = 0.03

# ============ 台词回看（历史 + 指针；-1 = 实时最新） ============
const MAX_HISTORY: int = 300
var _history: Array[Dictionary] = []
var _review_index: int = -1
var _btn_prev: Button = null
var _btn_next: Button = null
var _hint_default_text: String = ""

# 角色名称映射
const SPEAKER_NAMES = {
	"福尔摩斯": "夏洛克·福尔摩斯",
	"华生": "约翰·华生医生",
	"赫德森太太": "赫德森太太",
	"信使": "信使",
	"system": "",
	"葛莱森警长": "葛莱森警长",
	"雷斯垂德警长": "雷斯垂德警长",
	"兰斯警士": "约翰·兰斯警士",
	"卡彭蒂耶太太": "卡彭蒂耶太太",
	"爱莉丝": "爱莉丝·卡彭蒂耶",
	"卡彭蒂耶中尉": "阿瑟·卡彭蒂耶中尉",
	"维金斯": "维金斯",
	"杰弗森·霍普": "杰弗森·霍普",
	"威廉·哈珀": "威廉·哈珀",
	"铁匠": "铁匠",
	"伪装者": "索叶太太（？）",
	"送牛奶的孩子": "送牛奶的孩子",
	"值班警官": "值班警官",
	"人事官员": "人事官员",
}

# 角色颜色
const SPEAKER_COLORS = {
	"福尔摩斯": Color(0.85, 0.75, 0.45),
	"华生": Color(0.7, 0.8, 0.9),
	"赫德森太太": Color(0.8, 0.7, 0.6),
	"信使": Color(0.75, 0.75, 0.75),
	"system": Color(0.6, 0.6, 0.6),
	"葛莱森警长": Color(0.9, 0.7, 0.5),
	"雷斯垂德警长": Color(0.8, 0.65, 0.5),
	"杰弗森·霍普": Color(0.9, 0.4, 0.3),
}

# 六步闭环步骤颜色
const STEP_COLORS = {
	1: Color(0.4, 0.8, 0.4),   # 观察发现 - 绿
	2: Color(0.4, 0.6, 0.9),   # 工具操作 - 蓝
	3: Color(0.9, 0.8, 0.3),   # 数据记录 - 黄
	4: Color(0.7, 0.4, 0.9),   # 知识检索 - 紫
	5: Color(0.9, 0.5, 0.3),   # 假设形成 - 橙
	6: Color(0.9, 0.3, 0.3),   # 验证修正 - 红
}

# ============ 生命周期 ============

func _ready() -> void:
	dialogue_manager = DialogueManager.new()
	add_child(dialogue_manager)
	
	dialogue_manager.dialogue_advanced.connect(_on_dialogue_advanced)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_manager.choice_presented.connect(_on_choices_presented)
	dialogue_manager.step_entered.connect(_on_step_entered)
	dialogue_manager.note_updated.connect(_on_note_updated)
	dialogue_manager.milestone_triggered.connect(_on_milestone)

	# 修复：连接对话面板左键点击 → 推进对话（此前仅回车/空格/E/右键能推进，
	# 左键点击因未接线而无效；推理墙遮挡后用户左键点不动更易卡死）
	if dialogue_panel:
		dialogue_panel.gui_input.connect(_on_dialogue_panel_gui_input)

	_load_expressions()
	
	if step_indicator: step_indicator.hide()
	if difficulty_badge: difficulty_badge.hide()

	if continue_hint:
		_hint_default_text = continue_hint.text
	_build_review_buttons()

	hide()

## 在对话栏顶部中央创建两个半透明回看箭头按钮（◀ / ▶）
func _build_review_buttons() -> void:
	if not dialogue_panel:
		return
	_btn_prev = _make_review_button("◀")
	_btn_next = _make_review_button("▶")
	_btn_prev.pressed.connect(func() -> void: _review_step(-1))
	_btn_next.pressed.connect(func() -> void: _review_step(1))
	dialogue_panel.add_child(_btn_prev)
	dialogue_panel.add_child(_btn_next)
	# 横向居中，贴对话栏上缘
	_btn_prev.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_btn_next.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_btn_prev.position = Vector2(dialogue_panel.size.x / 2.0 - 48.0, 4.0)
	_btn_next.position = Vector2(dialogue_panel.size.x / 2.0 + 12.0, 4.0)
	_update_review_buttons()

func _make_review_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(36, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.45)  # 半透明
	b.mouse_entered.connect(func() -> void: b.modulate = Color(1, 1, 1, 0.9))
	b.mouse_exited.connect(func() -> void: b.modulate = Color(1, 1, 1, 0.45))
	b.tooltip_text = "回看台词（← → 键 / 鼠标滚轮）"
	return b

func _load_expressions() -> void:
	# 立绘映射统一收口到 PortraitLibrary（单一数据源），此处不再重复定义。
	# expression_map / watson_expression_map 保留字典变量以兼容旧引用，但不再填充。
	print("[DialogueRenderer] 立绘由 PortraitLibrary 提供: NPC %d 位" % PortraitLibrary.NPC_PORTRAITS.size())

# ============ 对话加载 ============

func load_dialogue_resource(resource_path: String) -> void:
	dialogue_manager.load_dialogue_resource(resource_path)

func load_dialogue_txt(file_path: String) -> void:
	dialogue_manager.load_dialogue_txt(file_path)

func start_tutorial() -> void:
	show()
	# 优先加载 .tres 资源
	if ResourceLoader.exists("res://resources/dialogues/scene_01_phase1_tutorial.tres"):
		dialogue_manager.load_dialogue_resource("res://resources/dialogues/scene_01_phase1_tutorial.tres")
	else:
		dialogue_manager.load_dialogue_txt("res://data/dialogues/dlg_01_tutorial.txt")
	dialogue_manager.start_dialogue()

func start_dialogue(resource_path: String = "", start_id: String = "") -> void:
	show()
	if resource_path != "":
		dialogue_manager.load_dialogue(resource_path)
	dialogue_manager.start_dialogue(start_id)

# ============ 事件回调 ============

func _on_dialogue_advanced(node_id: String) -> void:
	var speaker = dialogue_manager.get_current_speaker()
	var text = dialogue_manager.get_current_text()
	var mood = dialogue_manager.get_current_mood()
	var trigger = dialogue_manager.get_current_trigger()
	var step = dialogue_manager.get_current_step()
	
	_update_ui(speaker, text, mood, trigger, step)

func _on_step_entered(step: int, step_name: String) -> void:
	if step_indicator:
		step_indicator.text = "Step %d: %s" % [step, step_name]
		step_indicator.add_theme_color_override("font_color", STEP_COLORS.get(step, Color.WHITE))
		step_indicator.show()
		# 2 秒后自动隐藏
		var t = create_tween()
		t.tween_interval(2.0)
		t.tween_property(step_indicator, "modulate:a", 0.0, 0.5)

func _on_note_updated(note_text: String) -> void:
	if system_hint_label:
		system_hint_label.text = "📝 " + note_text
		system_hint_label.show()
		var t = create_tween()
		t.tween_interval(3.0)
		t.tween_property(system_hint_label, "modulate:a", 0.0, 1.0)

func _on_milestone(milestone_name: String) -> void:
	if system_hint_label:
		system_hint_label.text = "🏆 " + milestone_name
		system_hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		system_hint_label.show()

func _on_dialogue_ended() -> void:
	continue_hint.hide()
	choices_container.hide()
	if step_indicator: step_indicator.hide()
	DialogueEventBus.emit_signal("dialogue_finished")
	# 修复：对话结束后必须隐藏渲染器本身，否则对话框 Control 一直 visible 停留在屏幕上、
	# 且 dialogue_active=false 使输入被拦截，表现为「对话卡住、点哪都没反应」。
	hide()

func _on_choices_presented(choices: Array) -> void:
	continue_hint.hide()
	choices_container.show()
	
	for child in choices_container.get_children():
		child.queue_free()
	
	for choice in choices:
		var btn = Button.new()
		var label = choice.get("text", "")
		if choice.has("speaker") and choice["speaker"] != "" and choice["speaker"] != "system":
			label = "%s: %s" % [choice["speaker"], label]
		btn.text = label
		btn.custom_minimum_size = Vector2(600, 50)
		btn.pressed.connect(dialogue_manager.select_choice.bind(choice["id"]))
		choices_container.add_child(btn)

# ============ UI 更新 ============

func _update_ui(speaker: String, text: String, mood: String, trigger: String, step: int) -> void:
	# 记录台词历史（回看用）；新台词到来时退出回看态回到实时
	if not text.strip_edges().is_empty():
		_history.append({"speaker": speaker, "text": text, "mood": mood, "trigger": trigger})
		if _history.size() > MAX_HISTORY:
			_history.pop_front()
	_review_index = -1
	_update_review_buttons()
	# 角色名
	var display_name = SPEAKER_NAMES.get(speaker, speaker)
	speaker_label.text = display_name
	var color = SPEAKER_COLORS.get(speaker, Color(0.8, 0.8, 0.8))
	speaker_label.add_theme_color_override("font_color", color)
	
	# 系统提示特殊处理
	if speaker == "system":
		match trigger:
			"guide", "hint":
				speaker_label.text = "💡 提示"
				speaker_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
			"milestone":
				speaker_label.text = "🏆 里程碑"
				speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			"clue":
				speaker_label.text = "🔍 线索发现"
				speaker_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
			"note":
				speaker_label.text = "📝 侦探笔记"
				speaker_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			"knowledge":
				speaker_label.text = "📚 知识库"
				speaker_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			_:
				speaker_label.text = ""
	
	# 文本打字机效果
	text_label.text = ""
	_start_typewriter(text)
	
	# 表情头像 — 统一走 PortraitLibrary（福尔摩斯/华生按 mood 取表情，NPC 取单表情立绘）
	var tex: Texture2D = PortraitLibrary.get_portrait(speaker, mood)
	if tex != null:
		portrait.texture = tex
		portrait.show()
	else:
		portrait.hide()
	
	# 六步闭环步骤指示
	if step > 0 and step_indicator:
		step_indicator.text = "Step %d" % step
		step_indicator.add_theme_color_override("font_color", STEP_COLORS.get(step, Color.WHITE))
		step_indicator.show()
	elif step_indicator:
		step_indicator.hide()
	
	# 继续提示
	continue_hint.show()
	choices_container.hide()

var _tw_generation: int = 0  # 打字机代数：旧协程发现代数不符立即退出，不再写 text_label

func _start_typewriter(full_text: String) -> void:
	_tw_generation += 1
	var gen := _tw_generation
	is_typing = true
	text_label.text = ""

	var speed = 1.0
	if SettingsManager:
		var s = SettingsManager.get_setting("dialogue_speed")
		if s != null: speed = s
	
	var delay = typewriter_speed / speed
	
	for c in full_text:
		if gen != _tw_generation:
			return  # 已被更新的台词/回看取代，静默退出，不覆盖屏幕文本
		text_label.text += c
		await get_tree().create_timer(delay).timeout
		if gen != _tw_generation:
			return
		if not is_typing:
			if _review_index < 0:  # 回看态下不回填实时全文
				text_label.text = full_text
			break
	
	if gen != _tw_generation:
		return
	is_typing = false

# ============ 台词回看 ============

## 是否处于回看态（非实时最新台词）
func _is_reviewing() -> bool:
	return _review_index >= 0

## 回看步进：delta=-1 向前（更早），delta=1 向后（更新）
func _review_step(delta: int) -> void:
	if _history.is_empty():
		return
	var cur := _review_index if _is_reviewing() else _history.size() - 1
	var target := cur + delta
	if target >= _history.size() - 1:
		# 走到最新 → 退出回看态，恢复实时台词
		_exit_review()
		return
	target = clampi(target, 0, _history.size() - 2)
	_review_index = target
	_show_history_entry(target)
	_update_review_buttons()

## 显示某条历史台词（无打字机，整段直出）
func _show_history_entry(i: int) -> void:
	var e: Dictionary = _history[i]
	is_typing = false  # 终止进行中的打字机协程，防止残留字符覆盖
	var sp: String = e.get("speaker", "")
	speaker_label.text = SPEAKER_NAMES.get(sp, sp)
	speaker_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(sp, Color(0.8, 0.8, 0.8)))
	text_label.text = e.get("text", "")
	var tex: Texture2D = PortraitLibrary.get_portrait(sp, e.get("mood", "neutral"))
	if tex != null:
		portrait.texture = tex
		portrait.show()
	if continue_hint:
		continue_hint.text = "回看 %d/%d（→ 返回）" % [i + 1, _history.size()]
		continue_hint.show()

## 退出回看态，恢复当前实时台词
func _exit_review() -> void:
	_review_index = -1
	if continue_hint:
		continue_hint.text = _hint_default_text
	if _history.is_empty():
		_update_review_buttons()
		return
	var e: Dictionary = _history[_history.size() - 1]
	var sp: String = e.get("speaker", "")
	speaker_label.text = SPEAKER_NAMES.get(sp, sp)
	speaker_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(sp, Color(0.8, 0.8, 0.8)))
	text_label.text = e.get("text", "")
	_update_review_buttons()

func _update_review_buttons() -> void:
	if not _btn_prev or not _btn_next:
		return
	var can_back := _history.size() > 1 and (not _is_reviewing() or _review_index > 0)
	_btn_prev.visible = can_back
	_btn_next.visible = _is_reviewing()

# ============ 输入处理 ============

func _input(event: InputEvent) -> void:
	if not visible or not dialogue_manager.is_active():
		return
	
	# 直接检查按键码，避免依赖可能未注册的输入动作（ui_accept 等）
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var code = key.keycode
		if code == KEY_LEFT:
			_review_step(-1)
			return
		if code == KEY_RIGHT:
			if _is_reviewing():
				_review_step(1)
			return
		if code == KEY_ENTER or code == KEY_SPACE or code == KEY_E:
			if _is_reviewing():
				_exit_review()  # 回看态下先返回实时，不推进（防误跳）
			elif is_typing:
				is_typing = false
			elif choices_container.get_child_count() == 0:
				dialogue_manager.advance()

func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	# 鼠标滚轮：上滚回看更早台词，下滚返回更新台词
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_review_step(-1)
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _is_reviewing():
			_review_step(1)
		return
	if _is_reviewing():
		_exit_review()  # 回看态下点击先返回实时，不推进（防误跳）
	elif is_typing:
		is_typing = false
	elif choices_container.get_child_count() == 0:
		dialogue_manager.advance()
