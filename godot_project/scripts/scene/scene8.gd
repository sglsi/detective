extends DetectiveScene
## Scene 8 — 贝克街221B起居室（最终对决 · 真相闭环）
## 混合驱动：霍普自白对话授予 803/804/805；观察热点 801/802（衣领马虱卵=决定性证据）。
## 完成时调用 GameManager.end_case() 触发结局评定（EndingSystem/BadgeSystem）。
## 设计依据：03_关卡设计稿 §3.9 + 线索全表 C_SOTCB_801~805

enum Phase { ARRIVAL, OBSERVE, REASONING, TRANSITION }

# P3.1：热点权重用 "wt"（"w" 为矩形宽度）；对话线索用 "w"。关键10/重要5/一般2/误导0。
const HOTSPOTS = [
	{"id":"C_SOTCB_801","label":"手背血迹","name":"霍普手背有血","x":700,"y":340,"w":160,"h":48,"wt":5,
	 "desc":"霍普手背沾着干涸血迹，证实他确实到过命案现场。","tool":"none","correct":true},
	{"id":"C_SOTCB_802","label":"衣领马虱卵","name":"霍普衣领马虱卵","x":820,"y":270,"w":160,"h":46,"wt":10,
	 "desc":"霍普衣领里嵌着马虱卵——长期与马相伴，马车夫职业的铁证。这是场景八的决定性证据。","tool":"放大镜","correct":true},
]

const DIALOGUE_CLUES = {
	"C_SOTCB_803": {"id":"C_SOTCB_803","name":"霍普太阳穴血管跳动","desc":"霍普太阳穴青筋突跳、神情亢奋，似有隐疾或极度执念——实为误导，勿忽略。","correct":false,"w":0},
	"C_SOTCB_804": {"id":"C_SOTCB_804","name":"霍普自白动机","desc":"霍普自白：十八年前犹他荒漠，费里尔父女被摩门教迫害，他立誓复仇——真相闭环。","correct":true,"w":10},
	"C_SOTCB_805": {"id":"C_SOTCB_805","name":"戒指归还","desc":"福尔摩斯将那枚'L·F'戒指交还霍普——物证闭环，呼应场景三核心线索。","correct":true,"w":5},
}

func scene_id() -> String: return "scene8"
func clue_source() -> String: return "scene8"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "贝克街221B 起居室"
func scene_time_text() -> String: return "DAY 3 凌晨02:15"
func scene_background() -> Texture2D: return null

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "霍普现身自白"
		Phase.OBSERVE: return "勘查霍普"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "结案"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "请先听完霍普的自白"
func _observe_open_msg() -> String: return "🔍 观察模式 — 点击霍普身上的标记点"
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 细看衣领马虱卵"
func _hotspot_tip(tool: String) -> String:
	match tool:
		"放大镜": return "\n\n[🔍 使用放大镜仔细查看 — 初始工具]"
		"化学试剂盒": return "\n\n[🧪 使用化学试剂盒检验 — 场景三解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "霍普：\"你们想知道为什么？那就听我把话说完——这桩事，憋了快二十年。\""
		2,3: return "福尔摩斯：\"手背的血、衣领里的马虱卵，都替你说了。先让我看个仔细。\""
		4,5: return "霍普：\"那枚戒指，是她的。还给我吧——这趟我了无牵挂了。\""
		_: return "福尔摩斯：\"证据齐了。把这桩复仇的来龙去脉，摆上推理墙。\""

func _no_evidence_msg() -> String: return "尚未勘查霍普。"
func _journal_empty_hint() -> String: return "听霍普自白、再观察他身上的痕迹"

func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，霍普的动机、血迹、还有衣领里那枚马虱卵——一件件都对上了。这是场跨越十八年的复仇。")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "真相闭环：霍普为费里尔父女复仇",
		"description": "霍普自白动机（十八年前费里尔父女被摩门教迫害，立誓复仇）；手背血迹证其到过现场；衣领马虱卵是马车夫职业的铁证；戒指归还完成物证闭环。全部线索指向同一结论：杰弗森·霍普为复仇连杀德雷伯与斯特兰森。"
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 当前场景"},
		{"t":"劳瑞斯顿花园街3号", "d":"德雷伯尸体现场"},
		{"t":"郝黎代旅馆", "d":"斯特兰森命案"},
	]

func casebook_steps() -> Array:
	return ["听霍普自白", "勘查霍普痕迹", "推理墙验证", "结案"]
func casebook_done_flags() -> Array:
	# 必须与 casebook_steps() 一一对应（基类按索引取值）
	return [_phase >= Phase.OBSERVE, _clues.size() >= (HOTSPOTS.size() + DIALOGUE_CLUES.size()), _phase >= Phase.REASONING, _phase >= Phase.TRANSITION]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：听自白 → 观察 → 推理墙 → 结案",
		"💡 衣领马虱卵是场景八决定性证据",
		"⚠️ 太阳穴跳动是误导项",
	]

func _enter_arrival() -> void:
	_start_dialogue([
		_mk_node("a0","霍普","你们想知道为什么？那就听我把话说完——这桩事，憋了快二十年。","click",["a1"]),
		_mk_node("a1","霍普","十八年前，犹他荒漠。费里尔父女被摩门教的人逼得走投无路，是我把他们护了下来。后来……他们还是没能逃过那一劫。","clue",["a2"],[DIALOGUE_CLUES["C_SOTCB_804"]]),
		_mk_node("a2","霍普","（太阳穴青筋突跳，呼吸急促）我这身子，怕是熬不了几天了。可恨没亲手了结那桩宿怨。","clue",["a3"],[DIALOGUE_CLUES["C_SOTCB_803"]]),
		_mk_node("a3","福尔摩斯","（缓缓）手背的血、衣领里的马虱卵，都替你说了。先让我看个仔细。","click",["a4"]),
		_mk_node("a4","霍普","那枚戒指，是她的。还给我吧——这趟我了无牵挂了。","clue",["end"],[DIALOGUE_CLUES["C_SOTCB_805"]]),
	], "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_enter_observe()

func _enter_observe() -> void:
	_phase = Phase.OBSERVE
	_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击霍普身上的标记点（共 " + str(HOTSPOTS.size()) + " 处）。\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙。")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，动机、血迹、马虱卵、戒指——都齐了。把这五条摆上推理墙，给这桩跨越十八年的复仇收尾。")
	await get_tree().create_timer(2.5).timeout
	_open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	_start_dialogue([
		_mk_node("t0","福尔摩斯","推理墙印证了：杰弗森·霍普，为费里尔父女复仇，连杀德雷伯与斯特兰森。案子了了。","click",["t1"]),
		_mk_node("t1","华生","一桩复仇，缠了二十年。福尔摩斯，这案子……你打算怎么写进报告？","click",["end"]),
	], "t0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # P3.1：按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	# 注意：星级评定已在 _enter_transition() 中 _award() 一次；此处不再重复，
	# 否则 scene8 星级会被双倍计入（与 scene4–7 仅在 _enter_transition 评定的行为一致）。
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene8", Phase.TRANSITION, {"clue_ids": ids})
	# 触发结局评定（EndingSystem 依据总星级占比判定档位；BadgeSystem 同步徽章）
	if GameManager:
		GameManager.end_case("completed")
	_create_notification("案件告破 — 结局已评定")
	await get_tree().create_timer(2.5).timeout
	SceneLoader.transition_to("res://scenes/main_menu.tscn")

func _do_save(slot: int = -1) -> void:
	var ids: Array = []
	for c in _clues: ids.append(c.get("id", ""))
	if ids.is_empty() and ClueSystem:
		for cid in ClueSystem.get_collected_ids(clue_source()): ids.append(cid)
	print("[SAVE scene8] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene8", _phase, {"clue_ids": ids}, slot)
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene8")
	if ss.is_empty(): return false
	var sp := int(ss.get("phase", 0))
	_phase = sp
	_restore_clues_from_ids(ss.get("clue_ids", []))
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(sp) + "」")
	match sp:
		Phase.ARRIVAL: _enter_arrival(); return true
		Phase.OBSERVE:
			_phase = Phase.OBSERVE
			if _clues.size() >= (HOTSPOTS.size() + DIALOGUE_CLUES.size()):
				_enter_reasoning(); return true
			_ui.restore_observer(_obs, ss.get("clue_ids", []), _owned_ids())
			_ui.set_dialogue("提示", "已恢复进度 — 勘查霍普阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size() + DIALOGUE_CLUES.size()) + " 条）")
			return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
