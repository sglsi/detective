extends DetectiveScene
## Scene 6 — 卡彭蒂耶公寓（四名 NPC 证词）
## 对话驱动：卡彭蒂耶太太(601)、爱莉丝(602)、阿瑟中尉(603,误导)、威廉·哈珀(604,排除)。
## 设计依据：03_关卡设计稿 §3.7 + 线索全表 C_SOTCB_601~604

enum Phase { ARRIVAL, REASONING, TRANSITION }

# P3.1：w = 线索分级权重（关键10/重要5/一般2/误导0）。
const CLUES = {
	"C_SOTCB_601": {"id":"C_SOTCB_601","name":"卡彭蒂耶太太证词","desc":"卡彭蒂耶太太说，德雷伯曾租住过她家，此人品行不端、欠下不少风流债。","correct":true,"w":5},
	"C_SOTCB_602": {"id":"C_SOTCB_602","name":"爱莉丝被骚扰","desc":"女儿爱莉丝说，阿瑟中尉曾因她与德雷伯往来而教训过德雷伯——引出感情纠纷。","correct":true,"w":5},
	"C_SOTCB_603": {"id":"C_SOTCB_603","name":"阿瑟·卡彭蒂耶中尉","desc":"阿瑟中尉体貌与凶手（高大马车夫）不符，易被误锁为嫌疑人——实为误导。","correct":false,"w":0},
	"C_SOTCB_604": {"id":"C_SOTCB_604","name":"威廉·哈珀作证","desc":"威廉·哈珀作证，案发当晚卡彭蒂耶一家并不在场——排除阿瑟中尉嫌疑。","correct":true,"w":5},
}

func scene_id() -> String: return "scene6"
func clue_source() -> String: return "scene6"
func hotspots() -> Array: return []
func scene_title() -> String: return "卡彭蒂耶公寓"
func scene_time_text() -> String: return "DAY 2 上午10:20"
func scene_background() -> Texture2D: return null

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "走访卡彭蒂耶家"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "本场景无线索可观察，请与住户对话"
func _npc_talk_text(_g: int) -> String: return "卡彭蒂耶太太：\"德雷伯那人，住过一阵，品行可不怎么样。\""
func _no_evidence_msg() -> String: return "尚未收集到卡彭蒂耶家的证词"
func _journal_empty_hint() -> String: return "与四名住户对话收集线索"

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "排除阿瑟中尉，确认德雷伯的情史是案件核心",
		"description": "卡彭蒂耶太太与爱莉丝证实德雷伯风流成性、留有感情纠纷；阿瑟中尉（误导项）体貌不符且哈珀证明其不在场，应予排除。案件动机指向一段被辜负的情史。"
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场"},
		{"t":"卡彭蒂耶公寓", "d":"德雷伯旧居 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["拜访卡彭蒂耶家", "收集四名证词", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.ARRIVAL, _clues.size() >= CLUES.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：对话收集线索 → 推理墙验证",
		"⚠️ 阿瑟中尉是误导项，勿误锁为凶手",
	]

func _enter_arrival() -> void:
	_start_dialogue([
		_mk_node("a0","福尔摩斯","卡彭蒂耶家。德雷伯生前曾租住此处，这里兴许藏着他的旧事。","click",["a1"]),
		_mk_node("a1","卡彭蒂耶太太","德雷伯？那个美国人，住过一阵，品行可不怎么样，欠下不少风流债。","clue",["a2"],[CLUES["C_SOTCB_601"]]),
		_mk_node("a2","爱莉丝","他还缠着我……要不是阿瑟哥哥替我出头教训过他，真不知怎样。","clue",["a3"],[CLUES["C_SOTCB_602"]]),
		_mk_node("a3","阿瑟中尉","我？我不过教训过那登徒子！我身板你瞧瞧，哪像什么六英尺的马车夫？","clue",["a4"],[CLUES["C_SOTCB_603"]]),
		_mk_node("a4","哈珀","福尔摩斯先生，案发那晚这家人都在我表亲的婚礼上，压根没离开伦敦城郊。","clue",["a5"],[CLUES["C_SOTCB_604"]]),
		_mk_node("a5","福尔摩斯","不在场证明成立。阿瑟中尉出局——德雷伯的死，是情杀。把这四条摆上墙。","click",["end"]),
	], "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_enter_reasoning()

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，哈珀的不在场证明把阿瑟中尉摘了出去，德雷伯的风流债才是引线。把这四条摆上推理墙。")
	await get_tree().create_timer(2.0).timeout
	_open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	_start_dialogue([
		_mk_node("t0","福尔摩斯","推理墙印证了：情杀，且凶手另有其人。郝黎代旅馆又出一桩命案——斯特兰森死了。","click",["t1"]),
		_mk_node("t1","华生","两桩命案，同一个凶手？","click",["end"]),
	], "t0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # P3.1：按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene6", Phase.TRANSITION, {"clue_ids": ids})
	SceneLoader.transition_to("res://scenes/scene7.tscn")

func _do_save(slot: int = -1) -> void:
	var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
	print("[SAVE scene6] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene6", _phase, {"clue_ids": ids}, slot)
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene6")
	if ss.is_empty(): return false
	var sp := int(ss.get("phase", 0))
	_phase = sp
	_restore_clues_from_ids(ss.get("clue_ids", []))
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(sp) + "」")
	match sp:
		Phase.ARRIVAL: _enter_arrival(); return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
