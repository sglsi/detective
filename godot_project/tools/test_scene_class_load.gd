extends SceneTree
## 回归：确认所有场景脚本能被 load + .new() 成功（DetectiveScene 基类已注册，
## 公共脚本 preload 依赖齐全）。若基类 preload 缺失，load() 返回 null 或 .new() 抛错。

func _initialize() -> void:
	var scenes := ["scene1","scene2","scene3","scene4","scene5","scene6","scene7","scene8"]
	var ok := true
	for s in scenes:
		var path := "res://scripts/scene/%s.gd" % s
		var scr = load(path)
		if scr == null:
			printerr("FAIL load ", path); ok = false; continue
		var inst = scr.new()
		if inst == null:
			printerr("FAIL new ", path); ok = false; continue
		print("OK ", s)
	if ok:
		print("SCENE_CLASS_LOAD: PASS")
	else:
		print("SCENE_CLASS_LOAD: FAIL")
	quit()
