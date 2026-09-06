class_name BtnIconCenter

## Button 的 icon_alignment 与 alignment 是独立对齐（icon LEFT+text CENTER=剩余区居中，
## CENTER+CENTER 重叠），引擎无"图标+文字组合居中"；用内部 HBox 实现。
## 动态改文字的按钮需同步 meta("icon_label") 的 text。
static func apply_center(btn: Button, icon_path: String, icon_w: int, sep: int = 8) -> void:
	var text: String = btn.text
	btn.icon = null
	btn.text = ""
	var fs: int = btn.get_theme_font_size("font_size")
	var col: Color = btn.get_theme_color("font_color")
	var fnt: Font = btn.get_theme_font("font")
	var ts: Vector2 = fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var sw: float = 0.0
	var sb: StyleBox = btn.get_theme_stylebox("normal")
	if sb != null:
		sw = sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT)
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, icon_w + sep + ts.x + sw), btn.custom_minimum_size.y)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", sep)
	var ic := TextureRect.new()
	ic.texture = load(icon_path)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(icon_w, 0)
	ic.size_flags_vertical = Control.SIZE_FILL
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)
	var lb := Label.new()
	lb.text = text
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.size_flags_vertical = Control.SIZE_FILL
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lb)
	btn.add_child(hb)
	btn.set_meta("icon_label", lb)
