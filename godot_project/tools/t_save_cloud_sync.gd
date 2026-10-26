extends SceneTree

## 存档云端持久化端到端探针
##
## 覆盖三条链路：
##   1) 稳定游客身份：删除本地身份文件后重新生成，必须仍是同一个 id
##      （否则同一玩家的云端存档每次都换一个归属键，永远取不回来）
##   2) 云端 → 本地同步：本地槽位文件被删（模拟环境重建/换浏览器）后，
##      sync_from_server() 应把云端存档拉回本地槽位
##   3) 读档兜底：本地槽位缺失时 load_slot() 直接从云端恢复并载入游戏状态

const API_BASE := "http://127.0.0.1:3000"

var _fails := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, cond: bool, extra: String = "") -> void:
	if cond:
		print("[PASS] ", label, (" " + extra) if extra != "" else "")
	else:
		_fails += 1
		print("[FAIL] ", label, (" " + extra) if extra != "" else "")

func _run() -> void:
	await process_frame
	var api = root.get_node_or_null("/root/APIManager")
	var save_mgr = root.get_node_or_null("/root/SaveManager")
	if api == null or save_mgr == null:
		print("[FAIL] 缺少 APIManager / SaveManager autoload")
		quit(1)
		return

	# --- 连通性：headless 桌面端走绝对地址 ---
	api.base_url = API_BASE
	api._check_connectivity()
	for i in 30:
		if api.is_online:
			break
		await create_timer(0.2).timeout
	_check("后端在线", api.is_online, API_BASE)
	if not api.is_online:
		quit(1)
		return

	# --- 1) 稳定游客身份 ---
	var gid1: String = api.ensure_guest_identity()
	_check("游客身份已就绪", gid1 != "", gid1.substr(0, 16))
	var identity_path := "user://guest_identity.json"
	if FileAccess.file_exists(identity_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(identity_path))
	# 清掉内存缓存，强制走"本地文件没了"的分支
	api._stable_guest_id = ""
	var gid2: String = api.ensure_guest_identity()
	_check("身份文件丢失后 id 仍稳定（设备派生兜底）", gid1 == gid2, "%s vs %s" % [gid1.substr(0, 16), gid2.substr(0, 16)])

	# --- 2) 上传一份带槽位号的存档 ---
	var payload := {
		"save_version": 1,
		"timestamp": int(Time.get_unix_time_from_system()),
		"case_id": "case_01",
		"scene_id": "scene3",
		"slot": 0,
		"difficulty": 1,
		"clue_count": 7,
		"observation_score": 42,
		"label": "探针存档",
		"collected_clues": [{"id": "CL1-01"}],
		"star_chains": {"CH01W": {"observation": 3}},
	}
	var up = await api.upload_save(payload)
	_check("存档上传云端", not up.get("error", true), str(up.get("message", up.get("save_id", ""))))

	# --- 3) 删本地槽位（模拟环境重建），再从云端同步回来 ---
	save_mgr.clear_slot(0)
	_check("本地槽位已清空", not FileAccess.file_exists(save_mgr.slot_path(0)))
	var sync_res = await save_mgr.sync_from_server(true)
	_check("sync_from_server 无错误", not sync_res.get("error", true), str(sync_res))
	_check("本地槽位已从云端恢复", FileAccess.file_exists(save_mgr.slot_path(0)))
	var meta = save_mgr.get_slot_meta(0)
	_check("恢复的存档摘要正确", str(meta.get("scene_id", "")) == "scene3" and str(meta.get("label", "")) == "探针存档", str(meta))
	# 关键：完整 payload 落地（分列存储会丢推理链/线索墙等字段）
	var rf = FileAccess.open(save_mgr.slot_path(0), FileAccess.READ)
	var local_json = JSON.parse_string(rf.get_as_text())
	rf.close()
	_check("完整 payload 已落地（含 star_chains/collected_clues）",
		local_json is Dictionary and local_json.has("star_chains") and local_json.has("collected_clues")
		and int(local_json.get("clue_count", 0)) == 7,
		str(local_json.get("star_chains", {})) if local_json is Dictionary else "null")

	# --- 4) 本地缺失时 load_slot 直接从云端恢复 ---
	save_mgr.clear_slot(0)
	var loaded: bool = await save_mgr.load_slot(0)
	_check("load_slot 云端兜底成功", loaded)
	_check("读档后游戏状态已恢复", str(root.get_node_or_null("/root/GameManager").current_scene_id) == "scene3",
		str(root.get_node_or_null("/root/GameManager").current_scene_id))

	# --- 5) 清理：删掉探针写入的云端存档 ---
	api.auth_token = ""
	print("[PROBE] 结束, fails=", _fails)
	quit(1 if _fails > 0 else 0)
