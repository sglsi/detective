extends Control

## SlotDialog — 存档槽位选择面板（保存 / 读取复用）
## 调用方：
##   var dlg = preload("res://scripts/ui/slot_dialog.gd").new()
##   dlg.configure("save", SaveManager.get_slot_list(), func(slot): ...)
##   add_child(dlg)
## mode = "save" 时按钮为「保存到此处」；mode = "load" 时按钮为「继续」（空槽位禁用）。

const SCENE_NAMES := {
	"scene1": "第一案 · 贝克街221B",
	"scene2": "第二案 · 劳瑞斯顿花园",
	"scene3": "第三案 · 尸体现场",
	"scene4": "第四案 · 奥德利大院",
	"scene5": "第五案 · 出租马车",
	"scene6": "第六案 · 卡彭蒂耶家",
	"scene7": "第七案 · 郝黎代旅馆",
	"scene8": "第八案 · 复仇终章",
}

var _mode: String = "load"
var _on_choice: Callable
var _slots: Array = []

func configure(mode: String, slots: Array, on_choice: Callable) -> void:
	_mode = mode
	_slots = slots
	_on_choice = on_choice
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var fw := 760.0
	var rows := _slots.size()
	var fh := 150.0 + float(rows) * 92.0 + 80.0
	var f = Panel.new()
	f.size = Vector2(fw, fh)
	f.position = Vector2(1920.0 / 2.0 - fw / 2.0, 1080.0 / 2.0 - fh / 2.0)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, 0.98)
	sb.border_color = Color(0.78, 0.62, 0.28)
	sb.border_width_left = 3; sb.border_width_right = 3; sb.border_width_top = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	f.add_theme_stylebox_override("panel", sb)
	add_child(f)

	var title = Label.new()
	title.text = "选择存档槽位" if _mode == "load" else "保存到存档槽位"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	title.position = Vector2(30, 22); title.size = Vector2(fw - 60, 40)
	f.add_child(title)

	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.42, 0.20, 0.5)
	sep.position = Vector2(30, 70); sep.size = Vector2(fw - 60, 2)
	f.add_child(sep)

	var y := 90.0
	if _slots.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "（暂无存档）"
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", Color(0.70, 0.64, 0.52))
		empty_lbl.position = Vector2(30, y); empty_lbl.size = Vector2(fw - 60, 40)
		empty_lbl.horizontal_alignment = 1
		f.add_child(empty_lbl)
		y += 60.0
	var row_idx := 0
	for meta in _slots:
		var slot: int = meta.get("slot", 0)
		var exists: bool = meta.get("exists", false)

		var row = Panel.new()
		row.position = Vector2(30, y); row.size = Vector2(fw - 60, 80)
		var rsb = StyleBoxFlat.new()
		rsb.bg_color = Color(0.20, 0.16, 0.10, 0.6)
		rsb.border_color = Color(0.50, 0.38, 0.18)
		rsb.border_width_left = 1; rsb.border_width_right = 1; rsb.border_width_top = 1; rsb.border_width_bottom = 1
		rsb.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", rsb)
		f.add_child(row)

		var name_lbl = Label.new()
		# 读档模式下列表已按时间倒序：首条标「最新」，其余标「较早」
		if _mode == "load":
			name_lbl.text = "🕐 最新" if row_idx == 0 else "存档 " + str(row_idx + 1)
		else:
			name_lbl.text = "槽位 " + str(slot + 1)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.58))
		name_lbl.position = Vector2(20, 12); name_lbl.size = Vector2(160, 30)
		row.add_child(name_lbl)

		var info = Label.new()
		if exists:
			var sid = meta.get("scene_id", "")
			var sname = SCENE_NAMES.get(sid, sid)
			info.text = sname + "  ·  " + _fmt_time(meta.get("timestamp", 0))
		else:
			info.text = "（空槽位）"
		info.add_theme_font_size_override("font_size", 16)
		info.add_theme_color_override("font_color", Color(0.80, 0.74, 0.62))
		info.position = Vector2(190, 18); info.size = Vector2(fw - 280, 28)
		row.add_child(info)

		var btn = Button.new()
		if _mode == "load":
			btn.text = "继续" if exists else "—"
			btn.disabled = not exists
		else:
			btn.text = "保存到此处"
		btn.position = Vector2(fw - 60 - 160, 20); btn.size = Vector2(140, 40)
		btn.add_theme_font_size_override("font_size", 18)
		if not (not exists and _mode == "load"):
			btn.pressed.connect(func():
				var cb = _on_choice
				queue_free()
				if cb.is_valid():
					cb.call(slot))
		row.add_child(btn)
		y += 92.0
		row_idx += 1

	# 返回按钮
	var back = Button.new()
	back.text = "返    回"
	back.position = Vector2(fw / 2.0 - 130, y + 10); back.size = Vector2(260, 50)
	back.add_theme_font_size_override("font_size", 22)
	var bsn = StyleBoxFlat.new(); var bsh = StyleBoxFlat.new(); var bsp = StyleBoxFlat.new()
	bsn.bg_color = Color(0.20, 0.16, 0.10, 0.9); bsn.border_color = Color(0.55, 0.42, 0.20)
	bsh.bg_color = Color(0.30, 0.24, 0.15, 0.95); bsh.border_color = Color(0.75, 0.58, 0.30)
	bsp.bg_color = Color(0.15, 0.12, 0.08, 0.95); bsp.border_color = Color(0.50, 0.38, 0.18)
	for s in [bsn, bsh, bsp]:
		s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2; s.set_corner_radius_all(4)
	back.add_theme_stylebox_override("normal", bsn)
	back.add_theme_stylebox_override("hover", bsh)
	back.add_theme_stylebox_override("pressed", bsp)
	back.pressed.connect(func(): queue_free())
	f.add_child(back)

func _fmt_time(t: int) -> String:
	if t <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(t)
