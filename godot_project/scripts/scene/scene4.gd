extends DetectiveScene
## Scene 4 — 奥德利大院（兰斯巡警证词）
## 纯对话驱动：兰斯巡警的证词授予 401-404 四条线索（含 403 误导项）。
## 架构：继承 DetectiveScene，仅覆盖内容钩子；线索经 DialogueManager 的 clue 触发
## 走 ClueSystem.collect_clue_from_catalog 单一漏斗（与观察器路径一致、幂等）。
## 设计依据：03_关卡设计稿 §3.5 + 线索全表 C_SOTCB_401~404

enum Phase { ARRIVAL, REASONING, TRANSITION }

## 本场景线索权威定义（id/name/desc/correct）；对话节点 grants_clues 引用，
## 经 collect_clue_from_catalog 入 ClueSystem（目录无 .tres 时回退到此处内联文本）。
# P3.1：w = 线索分级权重（关键10/重要5/一般2/误导0）。无 .tres，权重经 grants 内联提供。
const CLUES = {
	"C_SOTCB_401": {"id":"C_SOTCB_401","name":"巡警看到'醉汉'","desc":"案发当晚兰斯巡警在院外看到一个摇摇晃晃的醉汉离开——案发后有人离开现场。","correct":true,"w":2},
	"C_SOTCB_402": {"id":"C_SOTCB_402","name":"醉汉身高6英尺+","desc":"兰斯估摸那醉汉身高得有六英尺出头，与花园街现场留下的高大足迹吻合。","correct":true,"w":5},
	"C_SOTCB_403": {"id":"C_SOTCB_403","name":"醉汉红脸","desc":"醉汉面色通红，看似酗酒或疾病所致——实为误导，红脸未必指向重病。","correct":false,"w":0},
	"C_SOTCB_404": {"id":"C_SOTCB_404","name":"醉汉棕色外衣","desc":"醉汉披一件棕色外衣，是伦敦出租马车夫常见的装束。","correct":true,"w":5},
}

func scene_id() -> String: return "scene4"
func clue_source() -> String: return "scene4"
func hotspots() -> Array: return []
func scene_title() -> String: return "奥德利大院 四十六号"
func scene_time_text() -> String: return "DAY 1 傍晚18:40"
func scene_background() -> Texture2D: return null

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "询问兰斯巡警"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "本场景无线索可观察，请与巡警对话"
func _npc_talk_text(_g: int) -> String: return "兰斯巡警：\"案子那天晚上，我瞅见个醉醺醺的高个子从院里晃悠出去了。\""
func _no_evidence_msg() -> String: return "尚未从兰斯巡警处获得证词"
func _journal_empty_hint() -> String: return "与兰斯巡警对话收集线索"

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "凶手是身高六英尺以上、红脸、穿棕色外衣的马车夫",
		"description": "兰斯看到的醉汉身高六英尺出头、披棕色外衣（马车夫常见装束），与花园街现场高大足迹吻合；红脸是干扰项，不必指向重病。综合指向：凶手是一名伦敦出租马车夫。"
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场 — 场景三"},
		{"t":"奥德利大院四十六号", "d":"巡警宿舍 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["抵达奥德利大院", "询问兰斯巡警", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.ARRIVAL, _clues.size() >= CLUES.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：对话收集线索 → 推理墙验证",
		"⚠️ 红脸是误导项，勿误判为'重病'",
	]

func _enter_arrival() -> void:
	_start_dialogue([
		_mk_node("a0","福尔摩斯","奥德利大院。当晚值班的兰斯巡警就住这儿——他该是最后一个见到那'醉汉'的人。","click",["a1"]),
		_mk_node("a1","兰斯巡警","福尔摩斯先生？您说案子？那天夜里天擦黑，我瞧见个醉醺醺的高个子从院里晃悠出去了。","click",["a2"]),
		_mk_node("a2","华生","醉汉？您看清他长相了吗？","click",["a3"]),
		_mk_node("a3","兰斯巡警","六英尺出头，准错不了——我在警局量过不少回个子。披件棕色外衣，脸喝得通红。","clue",["a4"],[CLUES["C_SOTCB_402"], CLUES["C_SOTCB_404"], CLUES["C_SOTCB_403"]]),
		_mk_node("a4","兰斯巡警","对，就是红脸膛，看着像喝高了，也像常年有病。反正那身影我忘不了。","clue",["a5"],[CLUES["C_SOTCB_401"]]),
		_mk_node("a5","福尔摩斯","（若有所思）六英尺出头、棕外衣、红脸……华生，把这几条记上。走，回去推一推。","click",["end"]),
	], "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_enter_reasoning()

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，兰斯看到的'醉汉'——六英尺出头、棕色外衣，正对上花园街那串高大足迹。把这四条摆上推理墙。")
	await get_tree().create_timer(2.0).timeout
	_open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	_start_dialogue([
		_mk_node("t0","福尔摩斯","推理墙印证了：凶手是个体格高大的马车夫。下一站——贝克街，等那位失主自己上门。","click",["t1"]),
		_mk_node("t1","华生","一枚女人的戒指，竟牵出这么长的线。","click",["end"]),
	], "t0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # P3.1：按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene4", Phase.TRANSITION, {"clue_ids": ids})
	get_tree().change_scene_to_file("res://scenes/scene5.tscn")

func _do_save() -> void:
	if GameManager.is_guest:
		_ui.show_notification("游客模式下无法存档，请先注册账号。"); return
	var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
	print("[SAVE scene4] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene4", _phase, {"clue_ids": ids})
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene4")
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
