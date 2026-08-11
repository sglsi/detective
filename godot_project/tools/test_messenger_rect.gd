extends SceneTree

## 实测场景一立绘（华生/信使）的真实显示矩形：位置、尺寸、纹理、是否等比 contain。
## 用法：godot --headless --script tools/test_messenger_rect.gd

func _initialize() -> void:
	await create_timer(0.15).timeout
	var scn = load("res://scenes/scene1.tscn")
	if scn == null:
		print("LOAD_FAIL"); quit(); return
	var inst = scn.instantiate()
	root.add_child(inst)
	await create_timer(0.4).timeout
	_report(inst, "portrait_华生")
	_report(inst, "portrait_信使")
	quit()

func _report(root_node, nm) -> void:
	var ctrl = _find(root_node, nm)
	if ctrl == null:
		print(nm, " NOT_FOUND"); return
	print("=== ", nm, " ===")
	print("  pos=", ctrl.position, " size=", ctrl.size, " global_rect=", ctrl.get_global_rect(), " visible=", ctrl.visible)
	var img = ctrl.get_node_or_null("img")
	if img:
		var ts = img.texture.get_size() if img.texture else Vector2.ZERO
		var bottom = ctrl.get_global_rect().position.y + ctrl.get_global_rect().size.y
		print("  img.expand_mode=", img.expand_mode, " img.size=", img.size, " tex_size=", ts)
		print("  img.gx=", "%.1f" % img.get_global_rect().position.x, " gy=", "%.1f" % img.get_global_rect().position.y,
		      " gw=", "%.1f" % img.get_global_rect().size.x, " gh=", "%.1f" % img.get_global_rect().size.y)
		print("  port_bottom_y=", "%.1f" % bottom, " (视口高=1080, 对话栏顶约850)")
		var expected_scale = min(ctrl.size.x / ts.x, ctrl.size.y / ts.y) if ts.x > 0 else 0.0
		print("  contain_scale=", "%.4f" % expected_scale, " 期望显示=", Vector2(round(ts.x*expected_scale), round(ts.y*expected_scale)))
	else:
		print("  NO_IMG")

func _find(node, target):
	if str(node.name) == target:
		return node
	for c in node.get_children():
		var r = _find(c, target)
		if r:
			return r
	return null
