extends Node
class_name DialogueManager

## DialogueManager v2.0 — 对话管理器
## 支持 .tres 资源格式，三难度条件分支，四级验证分支，六步闭环触发
##
## ⚠️ 数据源策略（P0 收敛后）：
##   - 唯一权威数据源：.tres 资源文件（res://resources/dialogues/*.tres）
##   - load_dialogue_txt() 保留作为安全网/调试用途，不用于正式数据加载
##   - 旧 .txt 数据已归档至 data/dialogues/_archive/

# ============ 数据 ============

var dialogue_resource: DialogueResource = null
var current_node: DialogueNodeResource = null
var dialogue_active: bool = false
var current_difficulty: int = 1       # 0=EASY, 1=NORMAL, 2=HARD
var current_verify_result: String = "" # 当前验证结果
var node_history: Array[String] = []   # 已访问节点历史

# ============ 信号 ============

signal dialogue_started(scene_id: String, phase_id: String)
signal dialogue_node_entered(node_id: String)
signal dialogue_advanced(node_id: String)
signal dialogue_ended()
signal choice_presented(choices: Array)
signal step_entered(step: int, step_name: String)
signal note_updated(note_text: String)
signal knowledge_triggered(domains: Array)
signal milestone_triggered(milestone_name: String)
signal sfx_triggered(sfx_name: String)
signal score_awarded(observation: int, reasoning: int, insight: int)

# ============ 生命周期 ============

func _ready() -> void:
	DialogueEventBus.connect("dialogue_trigger", _on_dialogue_trigger)
	if DifficultyManager:
		current_difficulty = DifficultyManager.current_difficulty

# ============ 资源加载 ============

## 加载 .tres 格式的对话资源
func load_dialogue_resource(resource_path: String) -> bool:
	var res = load(resource_path)
	if not res or not res is DialogueResource:
		push_error("[DialogueManager] 无法加载对话资源: %s" % resource_path)
		return false
	
	dialogue_resource = res
	node_history.clear()
	print("[DialogueManager] 对话资源已加载: %s (%d 节点)" % [res.scene_name, res.nodes.size()])
	return true

## 兼容旧格式：加载 .txt 格式的对话数据
func load_dialogue_txt(file_path: String) -> void:
	var res = DialogueResource.new()
	res.scene_id = "legacy"
	res.scene_name = file_path.get_file()
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[DialogueManager] 无法加载对话文件: %s" % file_path)
		return
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("##"):
			continue
		
		var parts = line.split("|")
		if parts.size() < 6:
			continue
		
		var node = DialogueNodeResource.new()
		node.node_id = parts[0].strip_edges()
		node.speaker = parts[1].strip_edges()
		node.text = parts[2].strip_edges()
		node.mood = parts[3].strip_edges()
		node.trigger = parts[4].strip_edges()
		node.next_nodes = [parts[5].strip_edges()] if parts.size() >= 6 else []
		
		res.nodes.append(node)
	
	file.close()
	dialogue_resource = res
	node_history.clear()

## 兼容旧接口
func load_dialogue(file_path: String) -> void:
	if file_path.ends_with(".tres"):
		load_dialogue_resource(file_path)
	else:
		load_dialogue_txt(file_path)

# ============ 对话控制 ============

## 开始对话
func start_dialogue(start_id: String = "") -> void:
	if not dialogue_resource:
		push_error("[DialogueManager] 未加载对话资源")
		return
	
	# 确定起始节点
	var start_node_id = start_id
	if start_node_id == "":
		start_node_id = dialogue_resource.get_start_node(current_difficulty)
	
	if not _go_to_node(start_node_id):
		return
	
	dialogue_active = true
	node_history.clear()
	dialogue_started.emit(dialogue_resource.scene_id, dialogue_resource.phase_id)
	print("[DialogueManager] 对话开始: %s (%s模式)" % [dialogue_resource.scene_name, _difficulty_name()])

## 外部触发：跳转到指定节点
func _on_dialogue_trigger(node_id: String) -> void:
	if not dialogue_active:
		start_dialogue(node_id)
	else:
		advance_to(node_id)

## 跳转到指定节点
## 注意：验证分支（四级验证）常在六步闭环 Step6 入口节点「等待」期间触发，
## 此时对话可能已被自动推进置为 inactive；advance_to 需重新激活以便从验证结果节点续跑。
func advance_to(node_id: String) -> void:
	if not dialogue_resource:
		return
	
	if node_id == "end":
		_end_dialogue()
		return
	
	dialogue_active = true
	_go_to_node(node_id)

## 推进到下一个节点
func advance() -> void:
	if not dialogue_active or not current_node:
		return
	
	# 如果是 choice 类型，等待玩家选择
	if current_node.trigger == "choice":
		_present_choices(current_node)
		return
	
	# 获取可用下一个节点
	var next_list = current_node.get_available_next(current_difficulty, current_verify_result)
	
	if next_list.is_empty():
		_end_dialogue()
		return
	
	# 取第一个可用节点
	var next_id = next_list[0]
	if next_id == "end":
		_end_dialogue()
		return
	
	_go_to_node(next_id)

## 玩家选择选项
func select_choice(choice_id: String) -> void:
	if choice_id == "end":
		_end_dialogue()
		return
	_go_to_node(choice_id)

# ============ 内部方法 ============

## 跳转到指定节点（同步：设置当前节点并派发信号；自动推进交由计时器异步触发）
## 注意：原函数含 `await`，使其成为协程，但全部调用点（advance_to/advance/start_dialogue/
## select_choice 及场景脚本）均未 await，导致 Godot 4.7 编译失败。改为同步执行 +
## 一次性计时器延迟推进，既修复编译错误，又保留原 0.15s 自动推进节奏，且无需改动任何调用方。
func _go_to_node(node_id: String) -> bool:
	var node = dialogue_resource.find_node(node_id)
	if not node:
		push_error("[DialogueManager] 节点不存在: %s" % node_id)
		_end_dialogue()
		return false

	current_node = node
	node_history.append(node_id)

	# 检查是否应显示
	if not node.should_show(current_difficulty, current_verify_result):
		# 跳过此节点，尝试下一个
		var next_list = node.get_available_next(current_difficulty, current_verify_result)
		if not next_list.is_empty() and next_list[0] != node_id:
			return _go_to_node(next_list[0])
		_end_dialogue()
		return false

	# 处理六步闭环步骤入口
	if node.is_step_entry and node.exploration_step > 0:
		var step_name = ""
		match node.exploration_step:
			1: step_name = "观察发现"
			2: step_name = "工具操作"
			3: step_name = "数据记录"
			4: step_name = "知识检索"
			5: step_name = "假设形成"
			6: step_name = "验证修正"
		step_entered.emit(node.exploration_step, step_name)
		print("[DialogueManager] 六步闭环 Step %d: %s" % [node.exploration_step, step_name])

	# 处理特殊 trigger 类型
	match node.trigger:
		"note":
			note_updated.emit(node.note_text)
		"knowledge":
			if dialogue_resource.knowledge_domains.size() > 0:
				knowledge_triggered.emit(dialogue_resource.knowledge_domains)
		"milestone":
			milestone_triggered.emit(node.text)
		"sfx":
			sfx_triggered.emit(node.stage_direction)
		"clue":
			ClueEventBus.emit_signal("clue_discovered", node_id)

	# 发射信号
	dialogue_node_entered.emit(node_id)
	dialogue_advanced.emit(node_id)

	# 自动推进：延迟 0.15s 异步触发，避免阻塞；保留原节奏
	if node.trigger in ["auto", "optional", "note", "knowledge", "milestone", "sfx", "clue", "guide", "hint"]:
		_schedule_auto_advance(node)

	return true

## 安排一次性自动推进计时器；仅当计时触发时仍停在该节点才推进，避免重复/竞态
func _schedule_auto_advance(node: DialogueNodeResource) -> void:
	var timer := get_tree().create_timer(0.15)
	timer.timeout.connect(func() -> void:
		if dialogue_active and current_node == node:
			advance()
	, Object.CONNECT_ONE_SHOT)

func _present_choices(node: DialogueNodeResource) -> void:
	var choices: Array = []
	var next_list = node.get_available_next(current_difficulty, current_verify_result)
	
	for next_id in next_list:
		if next_id == "end":
			choices.append({
				"id": "end",
				"text": "（结束对话）",
			})
			continue
		
		var next_node = dialogue_resource.find_node(next_id)
		if next_node and next_node.should_show(current_difficulty, current_verify_result):
			choices.append({
				"id": next_id,
				"text": next_node.text,
				"speaker": next_node.speaker,
			})
	
	choice_presented.emit(choices)

func _end_dialogue() -> void:
	dialogue_active = false
	current_node = null
	
	# 发放评分
	if dialogue_resource:
		score_awarded.emit(
			dialogue_resource.score_observation,
			dialogue_resource.score_reasoning,
			dialogue_resource.score_insight
		)
		
		# 触发完成事件
		if dialogue_resource.completion_event != "":
			SceneEventBus.emit_signal(dialogue_resource.completion_event)
	
	dialogue_ended.emit()
	print("[DialogueManager] 对话结束")

# ============ 查询方法 ============

func is_active() -> bool:
	return dialogue_active

func get_current_speaker() -> String:
	return current_node.speaker if current_node else ""

func get_current_text() -> String:
	return current_node.text if current_node else ""

func get_current_mood() -> String:
	return current_node.mood if current_node else "neutral"

func get_current_trigger() -> String:
	return current_node.trigger if current_node else ""

func get_current_stage_direction() -> String:
	return current_node.stage_direction if current_node else ""

func get_current_step() -> int:
	return current_node.exploration_step if current_node else 0

func set_verify_result(result: String) -> void:
	current_verify_result = result

func set_difficulty(diff: int) -> void:
	current_difficulty = diff

func _difficulty_name() -> String:
	match current_difficulty:
		0: return "EASY"
		1: return "NORMAL"
		2: return "HARD"
	return "UNKNOWN"
