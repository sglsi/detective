extends RefCounted
class_name GraphViewData

## 图谱视图 · 数据派生层（拆自 graph_view_controller.gd，Request C 后架构分层）
##
## 职责：纯数据派生（identity 门控 / 人物中文名 / 线索查找与过滤 / 证据连线派生 /
## verdict 实时推算 / 邻接与配色）。不持有任何视图私有状态，全部读取与回写 owner
## （GraphViewController）的成员；常量（COL_* / _COLOR_KEYS / _NPC_DISPLAY_NAMES 等）
## 仍归属控制器，本层经 owner. 引用。
##
## 设计铁律（doc 09/10）：读取与老推理墙同一份数据，数据层零改动——本文件只做「投影」。
##
## 玩家视角术语（doc 10 v1.1）：证据连线=关系、矛盾=两种情况对不上、互相矛盾=红、

var owner: GraphViewController

# ===================== 关系性质 ↔ 颜色键（数据层绑定） =====================
func kind_to_key(kind: String) -> String:
	return owner._KIND_TO_KEY.get(kind, "grey")


func key_to_kind(key: String) -> String:
	return owner._KEY_TO_KIND.get(key, "relate")


func color_from_key(key: String) -> Color:
	return owner._COLOR_KEYS.get(key, owner._COLOR_KEYS["grey"])


# ===================== 身份揭示门控（doc 10 需求2） =====================
## 某些 NPC 在「揭示名字的证据」被收集前不得作为已知人物出现（避免 related_npcs 提前带名上墙）。
func _identity_revealed(pid: String, live: Array) -> bool:
	var gates: Array = owner._IDENTITY_REVEAL_GATES.get(pid, [])
	if gates.is_empty():
		return true
	for g in gates:
		for c in live:
			if c.get("id", "") == g:
				return true
	return false


# ===================== 人物 / 线索查找 =====================
## 人物显示名：1) _persons 别名；2) NPC ID → 中文名静态映射；3) 原 id
func _person_name(id: String) -> String:
	for p in owner._persons:
		if p.get("id", "") == id:
			var nm: String = p.get("name", "")
			if nm != "" and nm != id:
				return nm
	if owner._NPC_DISPLAY_NAMES.has(id):
		return owner._NPC_DISPLAY_NAMES[id]
	return id


func _find_clue(cid: String) -> Dictionary:
	for c in owner._clues:
		if c.get("id", "") == cid: return c
	return {}


func _clues_for_person(pid: String) -> Array:
	var out := []
	for c in owner._clues:
		if pid in c.get("related_npcs", []):
			out.append(c)
	return out


## 共同线索：被 ≥2 人物关联 → 金边标记
func _compute_common_clues() -> void:
	owner._common_clues = {}
	for c in owner._clues:
		var np := 0
		for _p in c.get("related_npcs", []):
			np += 1
		if np >= 2:
			owner._common_clues[c.get("id", "")] = true


## 证据连线（数据边）派生：只保留玩家真实建立的关系（_relations）。
## ⚠️ 已移除两种「全局批量自动边」：
##   ① clue.relation_tags → 推断 的 support 边（自动、always=false，在默认视图下不绘制，
##      却会干扰 _derive_hypo 的重复判定，使线索→推断连线不可见，问题3）；
##   ② 所有推断 → 结论 的 imply 边（不管玩家是否推导都画，导致结论发散多余连线，问题1）。
## 正向推导时由 _add_derived_conclusion / _derive_hypo 主动写入 _relations，画出来的边即玩家真实建立的边。
func _derive_edges() -> void:
	owner._edge_list = []
	var seen := {}
	var add := func(f: String, t: String, kind: String, always: bool, color_key: String = "", dashed: bool = false) -> void:
		if f == "" or t == "": return
		var key = "%s|%s|%s" % [f, t, kind]
		if seen.has(key): return
		seen[key] = true
		var ck := color_key if color_key != "" else kind_to_key(kind)
		var col := color_from_key(ck)
		owner._edge_list.append({"from": f, "to": t, "kind": kind, "color": col, "color_key": ck, "dashed": dashed, "dotted": false, "always": always})

	for r in owner._relations:
		var k: String = r.get("kind", "relate")
		# 用户手动建立的关系常显
		add.call(r.get("from", ""), r.get("to", ""), k, true, r.get("color_key", ""), r.get("dashed", false))


func _rel_color(kind: String) -> Color:
	return color_from_key(kind_to_key(kind))


# ===================== 线索状态文案 / 配色 =====================
func _clue_sub(c: Dictionary) -> String:
	var correct: bool = c.get("correct", true)
	var st := "已关联" if c.get("associated", false) else "未关联"
	if not correct: st = "干扰项"
	# P0-2 用户标记状态覆盖
	var uid: String = c.get("id", "")
	if owner._user_excluded.has(uid): st = "已排除"
	elif owner._user_pending.has(uid): st = "待查"
	return st


# P0-2 状态过滤辅助：判断线索是否匹配当前过滤
func _clue_matches_filter(c: Dictionary, filter: String) -> bool:
	var uid: String = c.get("id", "")
	match filter:
		"excluded": return owner._user_excluded.has(uid)
		"pending": return owner._user_pending.has(uid)
		"key":
			if owner._user_excluded.has(uid): return false
			return c.get("correct", true) and int(c.get("importance", 0)) >= 5
	return true


func _clue_color(c: Dictionary) -> Color:
	if not c.get("correct", true): return owner.COL_RED
	if c.get("associated", false): return owner.COL_GREEN
	return owner.COL_GOLD_LIGHT


# ===================== 轻量结论推算（视图派生，不缓存） =====================
func _verdict_text() -> String:
	var v := _compute_verdict()
	return ["两种对不上", "证据不足", "有点道理", "说得通"][v]


func _verdict_color() -> Color:
	var v := _compute_verdict()
	return [owner.COL_RED, owner.COL_ORANGE, owner.COL_YELLOW, owner.COL_GREEN][v]


## 与 reasoning_wall.get_verdict 同规则，供结论节点着色。
func _compute_verdict() -> int:
	if owner._verdict >= 0:
		return owner._verdict
	var contra := 0
	for c in owner._clues:
		if c.get("associated", false) and not c.get("correct", true):
			contra += 1
	for r in owner._relations:
		if r.get("dashed", false): continue   # 虚线（存疑）只显示不计入判定
		if r.get("kind", "") in ["contradict", "oppose"]:
			contra += 1
	if contra > 0: return 0
	var support := 0
	for c in owner._clues:
		if c.get("associated", false) and c.get("correct", true):
			support += 1
	for r in owner._relations:
		if r.get("dashed", false): continue
		if r.get("kind", "") == "support":
			support += 1
	if support >= 3: return 3
	if support >= 1: return 2
	return 1


# ===================== 线索放置（placed）状态 =====================
func _clue_has_relation(cid: String) -> bool:
	for r in owner._relations:
		if r.get("from", "") == cid or r.get("to", "") == cid:
			return true
	return false


func _id_is_clue(cid: String) -> bool:
	for c in owner._clues:
		if c.get("id", "") == cid:
			return true
	return false


func _clue_by_id(cid: String) -> Dictionary:
	for c in owner._clues:
		if c.get("id", "") == cid:
			return c
	return {}


func _clue_placed(cid: String) -> bool:
	return cid in owner._placed_clues


func _mark_clue_placed(cid: String) -> void:
	if cid in owner._placed_clues:
		return
	owner._placed_clues.append(cid)
	if not owner._state_store.is_empty():
		owner._state_store["graph_placed_clues"] = owner._placed_clues.duplicate()


func _unmark_clue_placed(cid: String) -> void:
	if cid not in owner._placed_clues:
		return
	owner._placed_clues.erase(cid)
	if not owner._state_store.is_empty():
		owner._state_store["graph_placed_clues"] = owner._placed_clues.duplicate()
