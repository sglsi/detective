extends SceneTree

## 从 web_build/index.pck 直接读取脚本，确认打包内容是最新版（非陈旧缓存）。
## 用法：godot --headless --main-pack web_build/index.pck --script res://tools/diag_pck_smoke.gd

func _initialize() -> void:
	await create_timer(0.1).timeout
	var ok := true

	# ① 直接读 pck 内 scene7.gd 文本，查新版本独有特征串
	var f7 := FileAccess.open("res://scripts/scene/scene7.gd", FileAccess.READ)
	if f7 == null:
		print("PKC_FAIL 无法打开 res://scripts/scene/scene7.gd")
		ok = false
	else:
		var t7: String = f7.get_as_text()
		f7.close()
		for sig in ["_telegraph_confirmed", "H7-12", "杰弗森·霍普"]:
			if t7.find(sig) < 0:
				print("PKC_FAIL scene7.gd 缺特征串: %s" % sig)
				ok = false
		var hcount7 := t7.count('"id":"H7-')
		print("PKC scene7.gd H7-* 出现次数=%d (预期≥12)" % hcount7)
		if hcount7 < 12:
			ok = false

	# ② 直接读 pck 内 scene6.gd 文本
	var f6 := FileAccess.open("res://scripts/scene/scene6.gd", FileAccess.READ)
	if f6 == null:
		print("PKC_FAIL 无法打开 res://scripts/scene/scene6.gd")
		ok = false
	else:
		var t6: String = f6.get_as_text()
		f6.close()
		for sig in ["scene6_telegraph_rx", "H6-09", "酒馆老板"]:
			if t6.find(sig) < 0:
				print("PKC_FAIL scene6.gd 缺特征串: %s" % sig)
				ok = false
		var hcount6 := t6.count('"id":"H6-')
		print("PKC scene6.gd H6-* 出现次数=%d (预期≥9)" % hcount6)
		if hcount6 < 9:
			ok = false

	# ③ 直接读 pck 内 truth 文本，确认 CH09E 含 H7-11
	var ft := FileAccess.open("res://data/case_branch_truth.gd", FileAccess.READ)
	if ft == null:
		print("PKC_FAIL 无法打开 res://data/case_branch_truth.gd")
		ok = false
	else:
		var tt: String = ft.get_as_text()
		ft.close()
		if tt.find('"H7-11"') < 0:
			print("PKC_FAIL case_branch_truth.gd 缺 H7-11")
			ok = false
		else:
			print("PKC case_branch_truth.gd 含 H7-11 ✓")

	print("PKC_SMOKE_ALL_OK" if ok else "PKC_SMOKE_FAIL")
	quit()
