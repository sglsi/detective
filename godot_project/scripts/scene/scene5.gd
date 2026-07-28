extends DetectiveScene
## Scene 5 — 贝克街221B会客厅（等待失主）
## 对话驱动：黄页查出租马车公司（501/502）、失物招领启事（503）、维金斯回报（504/505）。
## 工具（黄页/化学试剂盒） flavous 在对话文本中体现；线索统一经 DialogueManager clue 触发
## 入 ClueSystem。设计依据：03_关卡设计稿 §3.6 + 线索全表 C_SOTCB_501~505

enum Phase { ARRIVAL, REASONING, TRANSITION }

# P3.1：w = 线索分级权重（关键10/重要5/一般2/误导0）。
const CLUES = {
	"C_SOTCB_501": {"id":"C_SOTCB_501","name":"出租马车公司登记","desc":"翻查黄页中的出租马车公司登记，可据此锁定马车车主。","correct":true,"w":5},
	"C_SOTCB_502": {"id":"C_SOTCB_502","name":"霍普登记记录","desc":"出租马车公司记录显示，该马车登记在杰弗森·霍普名下——凶手身份确认。","correct":true,"w":10},
	"C_SOTCB_503": {"id":"C_SOTCB_503","name":"失物招领触发来者","desc":"在失物招领处登出戒指招领启事，当晚便有人来问——戒指主人仍关心此物。","correct":true,"w":5},
	"C_SOTCB_504": {"id":"C_SOTCB_504","name":"戒指认领人特征","desc":"来认领戒指的年轻男子操美国口音——实为霍普安排的'同伙'放风。","correct":true,"w":2},
	"C_SOTCB_505": {"id":"C_SOTCB_505","name":"认领人逃走","desc":"认领人见势不妙拔腿就跑，证实确有'同伙'存在。（四签名伏笔）","correct":true,"w":2},
}

func scene_id() -> String: return "scene5"
func clue_source() -> String: return "scene5"
func hotspots() -> Array: return []
func scene_title() -> String: return "贝克街221B 会客厅"
func scene_time_text() -> String: return "DAY 1 晚21:10"
func scene_background() -> Texture2D: return null

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "查访出租马车"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "本场景无线索可观察，请推进对话"
func _npc_talk_text(_g: int) -> String: return "福尔摩斯：\"维金斯，去失物招领登个启事——就说捡到一枚女式结婚戒指。\""
func _no_evidence_msg() -> String: return "尚未查到出租马车与失主线索"
func _journal_empty_hint() -> String: return "查黄页、登启事、问维金斯"

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "凶手锁定为出租马车夫杰弗森·霍普",
		"description": "黄页登记显示棕色马车属杰弗森·霍普；失物招领启事引出一名年轻美国口音男子（霍普的'同伙'）来认领戒指后逃走。马车夫身份 + 对戒指的执念，共同锁定霍普即凶手。"
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一/当前"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场 — 场景三"},
		{"t":"奥德利大院四十六号", "d":"兰斯证词 — 场景四"},
	]

func casebook_steps() -> Array:
	return ["查出租马车登记", "登失物招领启事", "询问维金斯", "推理墙验证"]
func casebook_done_flags() -> Array:
	# 必须与 casebook_steps() 一一对应（基类按索引取值）：
	# 501/502=马车登记；503=启事；504/505=维金斯回报
	return [_clues.size() >= 2, _clues.size() >= 3, _clues.size() >= CLUES.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：对话收集线索 → 推理墙验证",
		"💡 黄页是场景五起解锁的工具",
	]

func _enter_arrival() -> void:
	_start_dialogue([
		_mk_node("a0","福尔摩斯","贝克街。戒指的主人迟早会自己找上门——我们先从出租马车查起。华生，把黄页拿来。","click",["a1"]),
		_mk_node("a1","华生","出租马车？全伦敦成百上千家，从哪查起？","click",["a2"]),
		_mk_node("a2","福尔摩斯","坎伯韦尔路那家——记着一辆棕色马车，车夫叫杰弗森·霍普。登记册上清清楚楚。","clue",["a3"],[CLUES["C_SOTCB_501"], CLUES["C_SOTCB_502"]]),
		_mk_node("a3","福尔摩斯","霍普……名字我记下了。华生，再去失物招领处登个启事，就说捡到一枚女式结婚戒指。","clue",["a4"],[CLUES["C_SOTCB_503"]]),
		_mk_node("a4","华生","启事登出去了，就等有人来认领。","click",["a5"]),
		_mk_node("a5","维金斯","福尔摩斯先生！有人来问戒指的事——年轻小伙子，美国口音，一听说要核实身份，撒腿就跑了！","clue",["a6"],[CLUES["C_SOTCB_504"], CLUES["C_SOTCB_505"]]),
		_mk_node("a6","福尔摩斯","逃了？那说明戒指背后真有故事。华生，证据够了，回去推理。","click",["end"]),
	], "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_enter_reasoning()

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，黄页登记锁定了霍普，失物招领又引出个逃走的'同伙'。把这五条摆上推理墙。")
	await get_tree().create_timer(2.0).timeout
	_open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	_start_dialogue([
		_mk_node("t0","福尔摩斯","推理墙印证了：凶手就是出租马车夫杰弗森·霍普。可他为何下此毒手？去会会卡彭蒂耶一家。","click",["t1"]),
		_mk_node("t1","华生","一个车夫，和一枚美国女人的戒指……","click",["end"]),
	], "t0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # P3.1：按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene5", Phase.TRANSITION, {"clue_ids": ids})
	get_tree().change_scene_to_file("res://scenes/scene6.tscn")

func _do_save() -> void:
	if GameManager.is_guest:
		_ui.show_notification("游客模式下无法存档，请先注册账号。"); return
	var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
	print("[SAVE scene5] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene5", _phase, {"clue_ids": ids})
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene5")
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
