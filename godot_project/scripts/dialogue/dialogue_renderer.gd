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
	hide()

func _load_expressions() -> void:
	# 福尔摩斯表情映射
	var sherlock_moods = {
		"自信": "sherlock_自信",
		"从容": "sherlock_自信",
		"神秘": "sherlock_神秘",
		"思考": "sherlock_思考",
		"微笑": "sherlock_喜悦",
		"严肃": "sherlock_凝思",
		"坚定": "sherlock_坚定",
		"狡黠": "sherlock_狡黠",
		"期待": "sherlock_兴奋",
		"指导": "sherlock_自信",
		"默认": "sherlock_思考",
		"提示": "sherlock_思考",
		# —— 预留头像接入（美术扩展包 7 张）——
		"开心": "sherlock_开心",
		"愤怒": "sherlock_愤怒",
		"沉默": "sherlock_沉默",
		"生气": "sherlock_生气",
		"疑惑": "sherlock_疑惑",
		"疲惫": "sherlock_疲惫",
		"神秘2": "sherlock_神秘2",
	}
	
	for mood in sherlock_moods:
		var path = "res://assets/portraits/%s.png" % sherlock_moods[mood]
		if ResourceLoader.exists(path):
			expression_map[mood] = load(path)
		else:
			expression_map[mood] = null
	
	# 华生表情映射（18 种表情）
	var watson_moods = {
		"平静": "watson_平静",
		"默认": "watson_平静",
		"惊讶": "watson_惊讶",
		"吃惊": "watson_吃惊",
		"倾佩": "watson_倾佩",
		"羡慕": "watson_羡慕",
		"赞同": "watson_赞同",
		"喜悦": "watson_喜悦",
		"开心": "watson_开心",
		"兴奋": "watson_兴奋",
		"自信": "watson_自信",
		"疑惑": "watson_疑惑",
		"沉默": "watson_沉默",
		"思考": "watson_思考",
		"凝思": "watson_凝思",
		"疲惫": "watson_疲惫",
		"生气": "watson_生气",
		"愤怒": "watson_愤怒",
		"神秘": "watson_神秘",
		# 情绪别名映射
		"严肃": "watson_沉默",
		"微笑": "watson_喜悦",
		"坚定": "watson_自信",
		"提示": "watson_思考",
		"指导": "watson_赞同",
	}
	
	for mood in watson_moods:
		var path = "res://assets/portraits/%s.png" % watson_moods[mood]
		if ResourceLoader.exists(path):
			watson_expression_map[mood] = load(path)
		else:
			watson_expression_map[mood] = null
	
	print("[DialogueRenderer] 表情加载完成: 福尔摩斯 %d 种, 华生 %d 种" % [expression_map.size(), watson_expression_map.size()])

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
	
	# 表情头像（根据说话人切换表情集）
	var current_expression_map: Dictionary = {}
	if speaker == "福尔摩斯":
		current_expression_map = expression_map
	elif speaker == "华生":
		current_expression_map = watson_expression_map
	
	if current_expression_map.size() > 0:
		if current_expression_map.has(mood) and current_expression_map[mood] != null:
			portrait.texture = current_expression_map[mood]
			portrait.show()
		elif current_expression_map.has("默认") and current_expression_map["默认"] != null:
			portrait.texture = current_expression_map["默认"]
			portrait.show()
		else:
			portrait.hide()
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

func _start_typewriter(full_text: String) -> void:
	is_typing = true
	text_label.text = ""
	
	var speed = 1.0
	if SettingsManager:
		var s = SettingsManager.get_setting("dialogue_speed")
		if s != null: speed = s
	
	var delay = typewriter_speed / speed
	
	for c in full_text:
		text_label.text += c
		await get_tree().create_timer(delay).timeout
		if not is_typing:
			text_label.text = full_text
			break
	
	is_typing = false

# ============ 输入处理 ============

func _input(event: InputEvent) -> void:
	if not visible or not dialogue_manager.is_active():
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if is_typing:
			is_typing = false
		elif choices_container.get_child_count() == 0:
			dialogue_manager.advance()

func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_input(event)
