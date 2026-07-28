extends Node

## PackManager - 运行时按需加载分包（分场景/分资源组）
##
## 设计目标：把 186MB 单体 pck 拆成
##   - base（引擎+脚本+菜单+共享 UI+字体，进游戏前必须下）
##   - actors（所有角色/立绘，进入案件时一次性下，常驻）
##   - sceneN（第 N 幕独占背景图，进入该幕时按需下）
## 从而把"首屏必须整机下载"改为"首屏只下 base，进案件再下 actors，切幕只下该幕小包"。
##
## Web 端：pck 通过 HTTP 下载到 user://（IndexedDB 持久化）后 load_resource_pack。
## 编辑器/非 Web 导出：资源已全在，自动跳过下载（is_pack_needed=false）。

signal pack_loaded(pack_id: String)
signal pack_progress(pack_id: String, received: int, total: int)
signal pack_failed(pack_id: String, msg: String)

const PACK_EXT := ".pck"

var _loaded: Dictionary = {}        # pack_id -> true（已成功 load）
var _loading: Dictionary = {}       # pack_id -> true（正在下载/加载，防并发重复）
var _base_url: String = ""          # 分包相对地址（与 index.html 同目录）
var _packs_available: bool = false  # 仅当部署时真正附带分包清单才激活按需加载

func _ready() -> void:
	# 分包与 index.html 同目录，使用相对路径最稳（兼容任意子路径部署）。
	_base_url = "web_build/" if _running_from_web_build() else ""
	# 门控：只有部署时生成了 pack_manifest.json（真正附带分包）才激活按需加载。
	# 单体全量 pck 构建下保持 false —— 否则会去下载不存在的分包而卡死。
	_packs_available = FileAccess.file_exists("res://web_build/pack_manifest.json")

func _running_from_web_build() -> bool:
	# Web 导出时 index.html 在 web_build/，且通过 http(s) 加载。
	return OS.has_feature("web")

func is_pack_needed() -> bool:
	# 编辑器内资源全在，无需下载；只有 Web 导出且真正附带分包清单时才需要。
	return OS.has_feature("web") and _packs_available

func pack_url(pack_id: String) -> String:
	return _base_url + pack_id + PACK_EXT

func pack_local_path(pack_id: String) -> String:
	return "user://" + pack_id + PACK_EXT

## 确保某个资源组已加载（幂等）。可 `await`。
func ensure_pack(pack_id: String) -> void:
	if not is_pack_needed():
		return                      # 编辑器：资源已存在，直接返回
	if _loaded.get(pack_id, false):
		return                      # 已加载，跳过
	if _loading.get(pack_id, false):
		# 已有同包在加载中：轮询等待其完成（简单防并发）
		while _loading.get(pack_id, false) and not _loaded.get(pack_id, false):
			await get_tree().process_frame
		return

	_loading[pack_id] = true

	var local := pack_local_path(pack_id)
	# 本地已有缓存（上次会话下载过）→ 直接 load，不重下
	if FileAccess.file_exists(local):
		if _try_load(local, pack_id):
			_loading[pack_id] = false
			return

	# 下载
	var url := pack_url(pack_id)
	var http := HTTPRequest.new()
	add_child(http)
	pack_progress.emit(pack_id, 0, 1)
	var err := http.request(url)
	if err != OK:
		_loading[pack_id] = false
		pack_failed.emit(pack_id, "HTTP 请求失败 (err=%d)" % err)
		http.queue_free()
		return

	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[0]
	var body: PackedByteArray = result[3]
	if code != HTTPRequest.RESULT_SUCCESS:
		_loading[pack_id] = false
		pack_failed.emit(pack_id, "下载失败 (code=%d)" % code)
		return

	pack_progress.emit(pack_id, body.size(), body.size())

	# 写入 user://（IndexedDB 持久化，下次免下载）
	var f := FileAccess.open(local, FileAccess.WRITE)
	if f == null:
		_loading[pack_id] = false
		pack_failed.emit(pack_id, "写入本地缓存失败")
		return
	f.store_buffer(body)
	f.close()

	_try_load(local, pack_id)
	_loading[pack_id] = false

func _try_load(local: String, pack_id: String) -> bool:
	var ok := ProjectSettings.load_resource_pack(local)
	if not ok:
		pack_failed.emit(pack_id, "load_resource_pack 失败")
		return false
	_loaded[pack_id] = true
	pack_loaded.emit(pack_id)
	return true

## 进入某幕前的统一入口：先确保 actors（一次）+ 该幕包已就绪。
func ensure_scene(scene_id: String) -> void:
	await ensure_pack("actors")
	await ensure_pack(scene_id)
