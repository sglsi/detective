extends Node

## EndingSystem — 结局档位系统（P2-4）
## 监听 SystemEventBus.case_completed，依据 StarRatingSystem 总星级占比判定四档结局。
## 结局档位与难度无关；跨案累积，见习档可回溯重做。
## 设计基准：08_系统框架设计.md §3.11（B-11.6）
## 注：本项目 autoload 不写 class_name（避免与同名单例冲突，见项目约定）。

enum EndingTier { LEGENDARY, OUTSTANDING, PASSING, PROBATION }

# 满星分母随已提交推理链数动态计算（v4.0：链数 × 9；例 14 链 = 126⭐）
# 旧常量 9 仅作兜底（无任何链提交时）。
const FALLBACK_MAX_TOTAL_STARS: int = 9

var case_endings: Dictionary = {}   # case_id -> EndingTier(int)

func _ready() -> void:
	if SystemEventBus:
		SystemEventBus.case_completed.connect(_on_case_completed)

func _on_case_completed(case_id: String, _stars: Dictionary) -> void:
	var tier := determine_ending(case_id)
	var info := get_ending_info(tier)
	if SystemEventBus:
		SystemEventBus.emit_signal("ending_determined", case_id, tier, info)
	print("[EndingSystem] 案件 %s 结局: %s" % [case_id, info.get("name", "")])

## 当前案件满星（链数 × 9；无链时回退 9）
func _max_stars() -> int:
	if StarRatingSystem and StarRatingSystem.has_method("get_max_total_stars"):
		var m := StarRatingSystem.get_max_total_stars()
		if m > 0:
			return m
	return FALLBACK_MAX_TOTAL_STARS

## 依据总星级占比判定结局档位（case_id 非空时写入跨案累积）
## 档位（v4.0）：传奇≥90% / 杰出 70-89% / 合格 50-69% / 见习<50%
func determine_ending(case_id: String = "") -> int:
	var total := StarRatingSystem.get_total_stars() if StarRatingSystem else 0
	var ratio := float(total) / float(_max_stars())
	var tier := EndingTier.PROBATION
	if ratio >= 0.9:
		tier = EndingTier.LEGENDARY
	elif ratio >= 0.7:
		tier = EndingTier.OUTSTANDING
	elif ratio >= 0.5:
		tier = EndingTier.PASSING
	else:
		tier = EndingTier.PROBATION
	if case_id != "":
		case_endings[case_id] = tier
	return tier

func get_ending_info(tier: int) -> Dictionary:
	match tier:
		EndingTier.LEGENDARY:
			return {"tier": "legendary", "name": "传奇", "description": "你展现了卓越的侦探才能，所有核心推理链均达到极高水准，堪称福尔摩斯级别的表现。", "can_replay": true, "reward": "解锁全结局画廊 + 侦探本色徽章"}
		EndingTier.OUTSTANDING:
			return {"tier": "outstanding", "name": "杰出", "description": "案件侦破质量出色，大部分推理链达到高水准，部分细节仍有提升空间。", "can_replay": true, "reward": "解锁杰出结局画廊"}
		EndingTier.PASSING:
			return {"tier": "passing", "name": "合格", "description": "成功破案，但推理过程中有较多疏漏和弯路，基本达到侦探入门标准。", "can_replay": true, "reward": "解锁合格结局画廊"}
		_:
			return {"tier": "probation", "name": "见习", "description": "推理表现尚有较大提升空间，建议回到推理墙重新梳理证据链。", "can_replay": true, "reward": "可回溯重做关键推理节点"}

func get_ending_for_case(case_id: String) -> int:
	return case_endings.get(case_id, EndingTier.PROBATION)

func get_all_endings() -> Dictionary:
	return case_endings.duplicate()

func restore_endings(data: Dictionary) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		case_endings = data.duplicate()
