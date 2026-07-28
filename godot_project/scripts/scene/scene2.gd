extends DetectiveScene
## Scene 2 — 劳瑞斯顿花园街3号 · 案发现场（室外）
## 架构：继承统一框架 DetectiveScene（与场景三完全一致，所有机制在基类中）。
## 本文件只提供「内容」：热点、对话、推理假设、面板文案、流程分支。
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.3

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

const HOTSPOTS = [
	{"id":"c201","label":"碾轧的花草","x":260,"y":430,"w":150,"h":42,
	 "desc":"花园外围花草大片倒伏，被重物来回碾轧——有马车在此反复掉头或停靠。","tool":"none"},
	{"id":"c202","label":"平行车轮印","x":520,"y":430,"w":150,"h":42,
	 "desc":"泥地上两道平行的深沟轮印，间距约4.5英尺（约1.37米）——典型的四轮出租马车轴距。用卷尺精确测量后确认为伦敦双座出租马车。","tool":"卷尺"},
	{"id":"c203","label":"右前蹄新蹄铁","x":260,"y":530,"w":150,"h":42,
	 "desc":"四只马蹄印中，右前蹄的蹄铁崭新锃亮，其余三只明显磨损——这匹马近期刚修过蹄铁，说明马车主经常维护座驾。","tool":"none"},
	{"id":"c204","label":"马蹄印迹零乱","x":520,"y":530,"w":150,"h":42,
	 "desc":"蹄印分布杂乱无章，非直线排列而是多方向散开——马曾在无人驾驭状态下自由走动。说明驾者中途下车，无人看管马匹。","tool":"none"},
	{"id":"c205","label":"两组初始足迹","x":260,"y":630,"w":150,"h":42,
	 "desc":"泥地边缘有两组清晰的脚印，自街道方向走来，一深一浅指向空屋门口。案发当晚曾有两人步行进入花园。","tool":"卷尺"},
	{"id":"c206","label":"步伐距离差异","x":520,"y":630,"w":150,"h":42,
	 "desc":"测量后：第一人每步约2英尺（61cm），身高应超6英尺（183cm）；第二人步幅较小约5英尺半（168cm）。两人体格差异明显——高的一个与醉汉描述吻合。","tool":"卷尺"},
]

# ===== 框架配置 =====
func scene_id() -> String: return "scene2"
func clue_source() -> String: return "garden"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "劳瑞斯顿花园街 3号"
func scene_time_text() -> String: return "DAY 1 上午11:15"
func scene_background() -> Texture2D: return load("res://assets/characters/watson/watson_standing.jpg")

# ===== 阶段 / 进度判断 =====
func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "抵达案发现场"
		Phase.DETECTIVE_DIALOGUE: return "警长对话"
		Phase.OBSERVE: return "花园勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool:
	return _phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION

# ===== 观察 / 动作文案 =====
func _observe_locked_msg() -> String: return "请先听取警长们的现场说明"
func _observe_open_msg() -> String: return "🔍 观察模式 — 点击花园中的标记点进行勘查"
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 仔细检查现场痕迹"

func _hotspot_tip(tool: String) -> String:
	if tool == "卷尺": return "\n\n[📏 使用卷尺精确测量 — 场景二解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "葛莱森踱步道：\"这些花草全被碾平了。昨晚一定有马车在这门口停过。\""
		2,3: return "雷斯垂德指向地面：\"双轨平行轮印——四轮马车。再看看马蹄印，福尔摩斯。\""
		4: return "福尔摩斯蹲下：\"马蹄印里有一只是新换的蹄铁。记下这一点，华生——修过蹄，说明马车主很重视。\""
		5: return "福尔摩斯直起身：\"两组足迹，一深一浅……一个高个子加一个中等身材。就差进屋看尸体了。\""
		_: return "福尔摩斯：\"花园的证据够了。推推理墙，串起这些线索。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查花园。"
func _journal_empty_hint() -> String: return "去花园勘查现场痕迹"

# ===== 全部线索收集完成 =====
func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，花园里的痕迹全都记录好了——轮印间距、马蹄蹄铁、两组不同身高的足迹……证据很充足。", "思考")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

# ===== 推理假设 =====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "案发当晚的交通与人员（推理战场 M1）",
		"description": "一辆伦敦出租马车停在花园街3号门口，驾车者高大男性，另一人同行进入花园。\n\n活跃假设：\n· H2-01 凶手乘出租马车来（强）\n· H2-02 凶手身高6英尺以上（中·范围估计）\n· H2-03 凶手穿方头靴（中）\n· H2-04 凶手体格强壮（弱-中·可选）\n· H2-05 凶手中年人（弱·可选）\n\n矛盾标记：\n· C2-01 两组不同脚印（方头靴 vs 小步皮靴）\n· C2-02 乘马车来 vs 泥地大步走\n· C2-03 新蹄铁三只旧蹄铁 vs 统一蹄铁\n\n苏格兰场假设池：葛莱森=政治阴谋灭口（弱）/ 雷斯垂德=情杀（弱）。"
	}

# ===== 面板内容 =====
func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号·室外", "d":"案发现场 — 当前场景"},
		{"t":"花园街3号·室内", "d":"尸体现场 — 待进入场景三"},
	]

func casebook_steps() -> Array:
	return ["抵达案发现场", "听取警长汇报", "勘查花园痕迹", "推理墙验证"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() >= HOTSPOTS.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单", "普通", "困难"][_difficulty] + " — 选定场景后不可更改",
		"操作：点击观察→放大查看→记录线索→推理墙→评价",
		"📏 卷尺：场景二起可用，测量轴距/步幅等物理证据",
		"💡 本案马车轴距≈4.5英尺（伦敦出租马车标准）",
		"音效：MVP 阶段暂无（M3 补全）",
	]

# ===== 对话阶段（节点由基类 _make_nodes / _start_dialogue 驱动） =====
func _enter_arrival() -> void:
	_start_dialogue(_make_nodes([
		["a0","葛莱森","福尔摩斯先生！您总算来了——昨晚在花园街三号的空屋里发现了一具男尸，表面没有任何外伤，像是中毒而死……"],
		["a1","福尔摩斯","没有外伤的中毒死者？有意思。带我们去看看现场，警长。","","兴奋"],
		["a2","华生","（环顾四周）这座花园……轮印、马蹄印、脚印全都混在泥里。昨晚这里可真热闹。","","思考"],
		["a3","福尔摩斯","先别急着下结论，华生。看——栅栏外面还有一个人。雷斯垂德，你也来了？","","从容"]]), "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	_start_dialogue(_make_nodes([
		["b0","雷斯垂德","福尔摩斯，你来晚了。我和葛莱森已经把屋内初步查过了——墙上用血写了几个字母：'R-A-C-H-E'。"],
		["b1","葛莱森","德语，意思是'复仇'。我们推测凶手可能是德国人。"],
		["b2","福尔摩斯","（微微一笑）德语倒是没错，但我不认为这是德国人干的。真正的德国人不会在犯罪现场用母语留字——太刻意。这几个字写得歪歪扭扭，像是用左手蘸血随意涂抹的。","","狡黠"],
		["b3","雷斯垂德","左手？你怎么……算了。说正经的——附近居民昨晚听到马车声和马蹄声，还有一个醉汉在街上踉跄。"],
		["b4","葛莱森","所以我们先来外面勘查花园——地上这些痕迹说不定比屋里更有用。"],
		["b5","福尔摩斯","很好。华生，你戴上放大镜仔细检查地面——注意车轮印的间距、马蹄印中哪只新旧不一，以及脚印的多少和大小。我和警长们先在边上等着。","","指导"],
		["b6","葛莱森","我跟他打赌，这是桩政治阴谋——R-A-C-H-E 是德语'复仇'，八成是某个秘密团体的灭口行动。雷斯垂德的情杀论？太俗套。"],
		["b7","雷斯垂德","（哼了一声）我倒觉得是情杀。死者衣着体面，多半是私人恩怨。葛莱森总喜欢把事情想复杂。"],
		["b8","福尔摩斯","两位的推论，都会进推理战场当'待验证假设'——但真相得靠我们自己看。华生，你先自己查，别被带偏。","","从容"],
		["b9","福尔摩斯","记住一个细节：四只蹄铁里，一只崭新三只老旧。全伦敦那么多出租马车，偏偏这一匹最特别。","","指导"]]), "b0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击花园中的标记点开始勘查。\n左侧 LOOK 可重新激活标记；收集完全部 6 条线索后打开推理墙整理。")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_ui.set_dialogue("福尔摩斯", "华生，证据齐全了。把这些线索摆上推理墙——什么车、什么人、几号人，在案发那晚进过这座花园。", "自信")
	await get_tree().create_timer(2.5).timeout; _open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_start_dialogue(_make_nodes([
		["c0","福尔摩斯","推理墙的结果印证了我的判断：一辆伦敦出租马车、两人一高一矮。高个子的体貌特征和'醉汉'吻合——他很可能就是凶手，或者凶手的帮手。","","自信"],
		["c1","华生","花园的证据都齐了。外面看完了——进去看看尸体现场吧。","","赞同"],
		["c2","葛莱森","跟我来。死者的遗体还在里面没有动过。"],
		["c3","福尔摩斯","（低声自语）有意思……这位凶手比我想象的更懂章法。","","从容"],
		["c4","system","（谜题钩子）马蹄印显示：一个新蹄铁，三只旧蹄铁——全城那么多出租马车，怎么找到这一匹？此问题已记入推理战场待验证。","guide"]]), "c0", _go_to_next_scene)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		# 自动存档必须写入本场景的 scene_state（phase + scene_id + clue_ids），
		# 否则读档时 _restore_saved_state 因 scene_id 不匹配而判定「无存档」→ 场景从头重启。
		var ids: Array = []
		for c in _clues: ids.append(c.get("id", ""))
		await SaveSystem.request_save("scene2", Phase.TRANSITION, {"clue_ids": ids})
	# 场景三已实现，进入室内尸体现场
	get_tree().change_scene_to_file("res://scenes/scene3.tscn")

# ===== 读档分支（ClueSystem 同步与通知已由基类 _restore_saved_state 完成） =====
func _apply_restored_phase(p: int, ids: Array, _clues_arr: Array) -> bool:
	_phase = p
	match p:
		Phase.ARRIVAL:
			_enter_arrival(); return true
		Phase.DETECTIVE_DIALOGUE:
			_show_detective_dialogue(); return true
		Phase.OBSERVE:
			_phase = Phase.OBSERVE
			if _clues.size() >= HOTSPOTS.size():
				# 死局防御：线索已集齐但阶段还停在勘查——all_recorded 不会再触发
				_enter_reasoning(); return true
			_ui.restore_observer(_obs, ids, _owned_ids())
			_ui.set_dialogue("提示", "已恢复进度 — 花园勘查阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size()) + " 条）")
			return true
		Phase.REASONING:
			_phase = Phase.REASONING; _wall_auto = true; _open_wall(); return true
		Phase.TRANSITION:
			_enter_transition(); return true
	return false
