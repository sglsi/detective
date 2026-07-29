class_name PortraitLibrary
extends RefCounted

## PortraitLibrary — 立绘/表情统一查询库（单一数据源）
##
## 所有"说话人 → 立绘纹理"的映射集中在此，供以下消费方复用：
##   - DialogueRenderer（教程/资源对话渲染器）
##   - SceneFramework.set_dialogue（游戏内对话栏）
##   - scene_controller / 各场景的角色立绘占位
##
## 用法：
##   var tex: Texture2D = PortraitLibrary.get_portrait("福尔摩斯", "思考")
##   var tex2: Texture2D = PortraitLibrary.get_portrait("赫德森太太")  # NPC 单表情
##
## 返回 null 表示该说话人无立绘（如 system），调用方自行 hide。

# ============ 表情集角色 ============

## 福尔摩斯：像素立绘 assets/portraits/pixel/sherlock_*.png（14 张实测存在）
const SHERLOCK_DIR := "res://assets/portraits/pixel/sherlock_%s.png"
const SHERLOCK_MOODS := {
	"自信": "自信", "从容": "自信", "指导": "自信",
	"神秘": "神秘",
	"思考": "思考", "默认": "思考", "提示": "思考", "中性": "思考", "neutral": "思考",
	"微笑": "喜悦", "喜悦": "喜悦", "敬佩": "喜悦",
	"严肃": "凝思", "凝思": "凝思",
	"坚定": "坚定",
	"狡黠": "狡黠",
	"期待": "兴奋", "兴奋": "兴奋",
	"开心": "开心",
	"愤怒": "愤怒",
	"沉默": "沉默",
	"生气": "生气",
	"疑惑": "疑惑", "困惑": "疑惑", "惊讶": "疑惑", "吃惊": "疑惑",
	"疲惫": "疲惫",
}

## 华生：表情立绘 assets/characters/watson/watson_*.png（18 张实测存在，已抠底透明）
const WATSON_DIR := "res://assets/characters/watson/watson_%s.png"
const WATSON_MOODS := {
	"平静": "平静", "默认": "平静", "中性": "平静", "neutral": "平静",
	"惊讶": "惊讶",
	"吃惊": "吃惊",
	"倾佩": "倾佩", "敬佩": "倾佩",
	"羡慕": "羡慕",
	"赞同": "赞同", "指导": "赞同",
	"喜悦": "喜悦", "微笑": "喜悦",
	"开心": "开心",
	"兴奋": "兴奋",
	"自信": "自信", "坚定": "自信",
	"疑惑": "疑惑", "困惑": "疑惑",
	"沉默": "沉默", "严肃": "沉默",
	"思考": "思考", "提示": "思考",
	"凝思": "凝思",
	"疲惫": "疲惫",
	"生气": "生气",
	"愤怒": "愤怒",
	"神秘": "神秘",
}

# ============ NPC 单表情立绘 ============

## 键 = 对话数据 speaker 字段（与 DialogueNodeResource.speaker 一致）
## 文件均实测存在于 assets/characters/<角色>/ 下
const NPC_PORTRAITS := {
	"赫德森太太": "res://assets/characters/mrs_hudson/mrs_hudson.png",
	"葛莱森警长": "res://assets/characters/gregson/gregson_portrait.png",
	"葛莱森": "res://assets/characters/gregson/gregson_portrait.png",
	"雷斯垂德警长": "res://assets/characters/lestrade/lestrade.png",
	"雷斯垂德": "res://assets/characters/lestrade/lestrade.png",
	"兰斯警士": "res://assets/characters/police_constable/police_constable_portrait.png",
	"值班警官": "res://assets/characters/police_constable/police_constable_portrait.png",
	"维金斯": "res://assets/characters/baker_street_captain/baker_street_captain_portrait.png",
	"杰弗森·霍普": "res://assets/characters/jefferson_hope/jefferson_hope_portrait.png",
	"卡彭蒂耶太太": "res://assets/characters/mrs_carpentier/mrs_carpentier_portrait.png",
	"爱莉丝": "res://assets/characters/alice/alice_portrait.png",
	"卡彭蒂耶中尉": "res://assets/characters/lieutenant_carpentier/lieutenant_carpentier_portrait.png",
	"送牛奶的孩子": "res://assets/characters/milk_boy/milk_boy_portrait.png",
	"伪装者": "res://assets/characters/old_woman/old_woman_portrait.png",
	"信使": "res://assets/characters/messenger/messenger_portrait.png",
	"人事官员": "res://assets/characters/recorder/recorder_portrait.png",
	"斯坦格森": "res://assets/characters/stangerson/stangerson_portrait.png",
	# —— 以下为对话中实际使用的别名/缺失角色（与场景 speaker 字段对齐）——
	"霍普": "res://assets/characters/jefferson_hope/jefferson_hope_portrait.png",
	"送奶工": "res://assets/characters/milk_boy/milk_boy_portrait.png",
	"老太婆": "res://assets/characters/old_woman/old_woman_portrait.png",
	"哈珀中士": "res://assets/characters/harper/harper_portrait.png",
	"分队小孩": "res://assets/characters/team_kid/team_kid_portrait.png",
}

# ============ 查询接口 ============

## 纹理缓存（懒加载：首次查询才 load，避免开场一次性加载全部大图）
static var _cache: Dictionary = {}

## 主入口：按说话人+情绪取立绘。无立绘返回 null。
static func get_portrait(speaker: String, mood: String = "") -> Texture2D:
	var path := _resolve_path(speaker, mood)
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[path] = tex  # null 也缓存，避免重复探测
	return tex

## 该说话人是否有立绘（不触发加载）
static func has_portrait(speaker: String) -> bool:
	return speaker == "福尔摩斯" or speaker == "华生" or NPC_PORTRAITS.has(speaker)

## 路径解析（可单测：不依赖资源实际存在）
static func _resolve_path(speaker: String, mood: String) -> String:
	match speaker:
		"福尔摩斯":
			return SHERLOCK_DIR % SHERLOCK_MOODS.get(mood, SHERLOCK_MOODS["默认"])
		"华生":
			return WATSON_DIR % WATSON_MOODS.get(mood, WATSON_MOODS["默认"])
		_:
			return NPC_PORTRAITS.get(speaker, "")
