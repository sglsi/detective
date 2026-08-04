extends Object
class_name WindowDrag

## WindowDrag — 通用窗口/面板拖拽工具（静态接口）。
## make_draggable(control, handle, exclude=[]) 让在 handle 区域按下即可拖动整个 control。
## control 可为 Control（场景内面板，跟随 global_position）或 Window/AcceptDialog（弹窗，跟随 position）。
## exclude: 不触发拖拽的子控件数组（如标题条上的按钮），避免点按钮时误拖。

static func make_draggable(control: Node, handle: Control, exclude: Array = []) -> void:
	if control == null or handle == null:
		return
	if handle.has_meta("_wd_drag"):
		return  # 已绑定，防重复连接
	var st := { on = false, grab = Vector2.ZERO }

	# 统一回调：handle 必连（按下/释放/移动都在标题条内生效）；
	# 若 control 是 Control（比 handle 大），额外把回调也连到 control，
	# 使拖拽中鼠标移到面板任意处（未被子控件消费）都能跟随，体验更顺。
	var act := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if _hit_exclude(handle, exclude, ev.position):
					return
				st.on = true
				st.grab = _get_pos(control) - handle.get_global_mouse_position()
			else:
				st.on = false
		elif ev is InputEventMouseMotion and st.on:
			_set_pos(control, handle.get_global_mouse_position() + st.grab)

	handle.gui_input.connect(act)
	if control is Control:
		(control as Control).gui_input.connect(act)
	handle.set_meta("_wd_drag", true)

static func _get_pos(control: Node) -> Vector2:
	if control is Control:
		return (control as Control).global_position
	if control is Window:
		return (control as Window).position
	return Vector2.ZERO

static func _set_pos(control: Node, gp: Vector2) -> void:
	if control is Control:
		(control as Control).global_position = gp
	elif control is Window:
		(control as Window).position = gp

static func _hit_exclude(handle: Control, exclude: Array, local_pos: Vector2) -> bool:
	var gp := handle.global_position + local_pos
	for c in exclude:
		if c is Control and c.visible:
			var inv: Transform2D = c.get_global_transform().affine_inverse()
			var lp: Vector2 = inv * gp
			if Rect2(Vector2.ZERO, c.size).has_point(lp):
				return true
	return false
