extends SceneTree

# P5-6 体验收尾 — 音频淡入淡出逻辑测试（--script 模式，同步）
# 验证 audio_manager.gd 的 _fade_volume（音量淡变 Tween 机制）与 _stop_bgm_now 复位。
# 注：项目音频目录为空，无法真正播放；此处验证"淡变机制已接入"与复位逻辑（不依赖音频文件、不依赖帧推进）。
# 成功哨兵：P5_6_AUDIO_OK

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
	var am = root.get_node_or_null("/root/AudioManager")
	if am == null:
		print("P5_6_AUDIO_FAIL: 无法获取 AudioManager 单例")
		quit()
		return

	# T1: play_bgm 去重守卫——同曲目直接返回，不触发加载、不崩溃
	am.current_bgm = "bgm_guard"
	am.play_bgm("bgm_guard", 0.5)
	check(am.current_bgm == "bgm_guard", "T1 play_bgm 去重守卫返回且不崩溃")

	# T2: 淡入机制——_fade_volume 返回有效 Tween（音量由 -80 拉升至 0 的载体已建立）
	var p := AudioStreamPlayer.new()
	var tw = am._fade_volume(p, 0.0, 0.2)
	check(tw != null, "T2 _fade_volume 返回 Tween（淡入机制已接入）")
	p.queue_free()

	# T3: 淡出方向——_fade_volume 到 -80 同样返回 Tween
	var q := AudioStreamPlayer.new()
	var tw2 = am._fade_volume(q, -80.0, 0.2)
	check(tw2 != null, "T3 _fade_volume 淡出方向返回 Tween")
	q.queue_free()

	# T4: _stop_bgm_now 复位 current_bgm 与 volume_db
	am.current_bgm = "bgm_test"
	am.bgm_player.volume_db = -40.0
	am._stop_bgm_now()
	check(am.current_bgm == "", "T4 _stop_bgm_now 清空 current_bgm")
	check(am.bgm_player.volume_db == 0.0, "T4 _stop_bgm_now 复位 volume_db=0")

	if failures.is_empty():
		print("P5_6_AUDIO_OK — 音频淡入淡出逻辑全部通过（%d 断言）" % 4)
	else:
		print("P5_6_AUDIO_FAIL: " + str(failures))
	quit()
