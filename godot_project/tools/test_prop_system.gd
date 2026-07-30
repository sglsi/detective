extends SceneTree
func _initialize() -> void:
	await create_timer(0.2).timeout
	var scene = load("res://scenes/scene4.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.3).timeout
	# 直接调用基类道具接口（绕过剧情，纯验证 UI 构建）
	scene.acquire_prop("coin", "半镑金币", "维多利亚时代半 Sovereign 金币，福尔摩斯用来敲门砖获取证词", "res://assets/props/coin.png")
	print("PROP_COUNT=", scene._props.size())
	scene._show_props()
	await create_timer(0.2).timeout
	scene._show_prop_detail(scene._props["coin"])
	await create_timer(0.2).timeout
	# 验证 ring 图标也能加载
	scene.acquire_prop("ring", "结婚金戒指", "关键物证，内侧刻字 L.F.", "res://assets/props/ring.png")
	print("PROP_COUNT2=", scene._props.size())
	scene._show_props()
	await create_timer(0.2).timeout
	print("PROP_PANEL_OK")
	quit()
