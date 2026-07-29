extends SceneTree
## P17 — 场景二/三氛围遮罩（迷雾/灯光）回归测试
## 验证 wants_atmosphere 的场景确实建立了 fog_atmosphere 遮罩 + 切换按钮，且切换有效。
## 注意：刻意不使用 DetectiveScene 类型标注，避免脚本编译期强编 detective_scene.gd
## （那时 autoload 全局尚未注册）；改为运行时加载场景后鸭子类型访问。

func _initialize() -> void:
	# 等一帧让 autoload 就绪
	await create_timer(0.15).timeout
	var scene = load("res://scenes/scene2.tscn")
	if scene == null:
		print("P17_FAIL scene2 加载失败")
		quit(1)
	var inst = scene.instantiate()
	root.add_child(inst)
	await create_timer(0.15).timeout

	if inst.get("_fog_overlay") == null:
		print("P17_FAIL 氛围遮罩未创建（wants_atmosphere 应开启）")
		quit(1)
	if inst.get("_atmo_btn") == null:
		print("P17_FAIL 切换按钮未创建")
		quit(1)

	var before = inst._fog_overlay.visible
	inst._on_atmo_toggled()
	var after = inst._fog_overlay.visible
	if before == after:
		print("P17_FAIL 切换无效：可见性未翻转")
		quit(1)
	if inst._atmo_btn.text.find("关") < 0 and inst._atmo_btn.text.find("开") < 0:
		print("P17_FAIL 按钮文案异常：", inst._atmo_btn.text)
		quit(1)

	# 场景三应为 Night 预设，此处确认也建立了遮罩节点
	var s3 = load("res://scenes/scene3.tscn").instantiate()
	root.add_child(s3)
	await create_timer(0.15).timeout
	if s3.get("_fog_overlay") == null:
		print("P17_FAIL 场景三氛围遮罩未创建")
		quit(1)

	print("P17_OK 场景二/三氛围: scene2遮罩=", inst._fog_overlay != null,
		" 按钮=", inst._atmo_btn != null, " 切换=", before, "->", after,
		" scene3遮罩=", s3._fog_overlay != null)
	quit(0)
