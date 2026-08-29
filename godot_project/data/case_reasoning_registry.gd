## 案件推理链统一登记表（一张表）
## 用途（设计文档 09_推理墙跨场景累积与画布自适应_设计补充说明.md）：
##   1. 跨场景累积的「节点真相源」：场景二~八的推断(H*)/结论(CL*/C*) 预设原本散落在各 sceneN.gd 的
##      reasoning_hypothesis().battlefield 里，导致场景N 开墙只认本场景预设、前一场景的推断/结论节点
##      缺失、其关系边因找不到端点被丢弃（信息缺失主因之一）。本表在开墙时聚合全部场景预设为并集，
##      让所有场景的推断/结论节点始终存在于画布，关系边得以完整解析、完整带入。
##   2. 全局获取/检索/对照层：提供 get_node / scene_of / get_all_nodes，便于检索「某推断来自哪个场景」。
##
## 设计要点：
##   - 不重复录入数据：各 sceneN.gd 仍是预设的唯一作者源；本表在 _ensure_built 时加载各场景脚本、
##     调用其 reasoning_hypothesis() 聚合，避免双份维护漂移。
##   - reasoning_hypothesis() 为近似纯数据函数（仅引用 scene_id() 字面量与 HOTSPOTS const），
##     裸 .new() 调用不进树、不触发 _ready，安全。
##   - 按 id 去重（跨场景 id 唯一，如 H2-01 / H3-01），结论与推断分别存入 _hyps / _cons。
##   - 全程静态方法 + 静态缓存：调用方用 load("res://...").get_hypo_union() 取用，不依赖 class_name
##     类型解析（规避 headless 工具下脚本编译顺序导致的「找不到类型」问题），也无需 .new() 实例。
##   - 返回深拷贝，避免调用方改动污染共享缓存。
class_name CaseReasoningRegistry
extends RefCounted

const SCENE_SCRIPTS := [
	"res://scripts/scene/scene2.gd",
	"res://scripts/scene/scene3.gd",
	"res://scripts/scene/scene4.gd",
	"res://scripts/scene/scene5.gd",
	"res://scripts/scene/scene6.gd",
	"res://scripts/scene/scene7.gd",
	"res://scripts/scene/scene8.gd",
]

static var _nodes_by_id: Dictionary = {}   # id -> 节点 dict（推断或结论）
static var _scene_of: Dictionary = {}      # id -> 来源场景 id（对照/检索）
static var _hyps: Array = []               # 推断节点列表（去重）
static var _cons: Array = []               # 结论节点列表（去重）
static var _built := false

static func _ensure_built() -> void:
	if _built:
		return
	_built = true
	# 先加载基类脚本，注册 DetectiveScene 类，否则下方 load(sceneN.gd) 会因
	# 「extends DetectiveScene 无法解析基类」而 Parse 失败（headless 工具/首次加载时尤甚）。
	var _base := load("res://scripts/scene/detective_scene.gd")
	if _base == null:
		push_warning("[CaseReasoningRegistry] 基类 detective_scene.gd 加载失败")
	for path in SCENE_SCRIPTS:
		var sc := load(path) as Script
		if sc == null:
			push_warning("[CaseReasoningRegistry] 加载失败: " + path)
			continue
		var inst = sc.new()
		if inst == null or not inst.has_method("reasoning_hypothesis"):
			continue
		var sid := ""
		if inst.has_method("scene_id"):
			sid = inst.scene_id()
		var rh: Dictionary = inst.reasoning_hypothesis()
		var bf: Dictionary = rh.get("battlefield", {})
		for h in bf.get("hypotheses", []):
			var hid := str(h.get("id", ""))
			if hid != "" and not _nodes_by_id.has(hid):
				_nodes_by_id[hid] = h
				_scene_of[hid] = sid
				_hyps.append(h)
		for c in bf.get("conclusions", []):
			var cid := str(c.get("id", ""))
			if cid != "" and not _nodes_by_id.has(cid):
				_nodes_by_id[cid] = c
				_scene_of[cid] = sid
				_cons.append(c)
	print("[CaseReasoningRegistry] 构建完成：场景=%d 推断=%d 结论=%d 节点总数=%d" % [
		SCENE_SCRIPTS.size(), _hyps.size(), _cons.size(), _nodes_by_id.size()])

## 合并后的 hypo 字典（供 wall.setup 第二参使用）。标题/描述由调用方按「当前场景」另行填充。
## 返回深拷贝，避免调用方改动污染共享缓存。
static func get_hypo_union() -> Dictionary:
	_ensure_built()
	return {
		"title": "",
		"description": "",
		"battlefield": {"hypotheses": _hyps.duplicate(true), "conclusions": _cons.duplicate(true)}
	}

## 全部推断+结论节点（去重后，深拷贝）。
static func get_all_nodes() -> Array:
	_ensure_built()
	var out: Array = []
	for n in _hyps:
		out.append(n.duplicate(true))
	for n in _cons:
		out.append(n.duplicate(true))
	return out

## 按 id 取单节点（推断或结论），深拷贝。
static func get_node(id: String) -> Dictionary:
	_ensure_built()
	if _nodes_by_id.has(id):
		return _nodes_by_id[id].duplicate(true)
	return {}

## 某节点来自哪个场景（检索/对照用）。
static func scene_of(id: String) -> String:
	_ensure_built()
	return _scene_of.get(id, "")
