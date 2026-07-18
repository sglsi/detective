extends SceneTree

# P5-6 体验收尾 — 主菜单云端存档检查 + 设置面板实例化测试（--script 模式，同步）
# - 主菜单 _parse_cloud_save_present 兼容 {saves}/{data.saves} 两种返回（纯解析，不触网）
# - 设置面板 SettingsPanel 可实例化并构建真实控件（绑定 SettingsManager 真实键）
# 注：main_menu.gd / settings_panel.gd 在 --script 下用裸名引用 autoload 全局（GameManager/SettingsManager 等），
#     直接 `MainMenu.new()` 会在依赖期编译时因全局不可见而失败；故改用运行时 load() 取类再 new()。
# 成功哨兵：P5_6_UI_OK

var started := false
var failures: Array[String] = []


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	run_test()
	return false


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("  ✗ " + msg)
	else:
		print("  ✓ " + msg)


func run_test() -> void:
	# ---- 主菜单云端存档解析（运行时 load 取类，避免早期依赖编译对 autoload 全局不可见）----
	var MainMenuScript = load("res://scripts/ui/main_menu.gd")
	if MainMenuScript == null:
		failures.append("MainMenu 脚本加载失败")
	else:
		var mm = MainMenuScript.new()
		check(mm._parse_cloud_save_present({"saves": [{"id": 1}]}) == true, "云端有存档(saves[])→true")
		check(mm._parse_cloud_save_present({"data": {"saves": [{"id": 1}]}}) == true, "云端有存档(data.saves[])→true")
		check(mm._parse_cloud_save_present({"saves": []}) == false, "云端空(saves:[])→false")
		check(mm._parse_cloud_save_present({"error": true, "message": "网络不可用"}) == false, "离线错误响应→false")
		check(mm._parse_cloud_save_present({}) == false, "空响应→false")
		mm.free()

	# ---- 设置面板实例化（运行时 load + new，SettingsManager 全局此时可用）----
	var SettingsPanelScript = load("res://scripts/ui/settings_panel.gd")
	if SettingsPanelScript == null:
		failures.append("SettingsPanel 脚本加载失败")
	else:
		var sm = root.get_node_or_null("/root/SettingsManager")
		if sm == null:
			failures.append("SettingsManager 单例缺失")
		else:
			var panel = SettingsPanelScript.new()
			root.add_child(panel)
			# _ready 在 add_child 时同步触发，无需等待帧
			check(panel.get_child_count() >= 2, "设置面板实例化并构建控件（子节点≥2）")
			var music_val = float(sm.get_setting("music_volume"))
			check(abs(panel._music_slider.value - music_val) < 0.001,
				"音乐滑块初值同步 SettingsManager(music_volume=%.2f)" % music_val)
			panel.closed.connect(panel.queue_free)
			panel.queue_free()

	if failures.is_empty():
		print("P5_6_UI_OK — 主菜单云端存档解析 + 设置面板实例化全部通过（%d 断言）" % 6)
	else:
		print("P5_6_UI_FAIL: " + str(failures))
	quit()
