@tool
extends SceneTree

## 诊断：从已导出的 pck 中读取布局脚本，确认打包内容与磁盘源码一致。

func _init() -> void:
	var path := "res://scripts/clue/graph/graph_view_layout.gd"
	print("DIAG_PCK: file_exists=", FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		print("DIAG_PCK: MISSING -> ", path)
		quit(2)
		return

	var f := FileAccess.open(path, FileAccess.READ)
	var txt: String = f.get_as_text()
	f.close()
	print("DIAG_PCK: len=", txt.length())

	# 只需判定「新布局独有特征必须存在」+「旧布局独有特征必须消失」。
	# 注意 _assign_subtree 新旧两版都有，绝不能拿来当判定依据。
	var must_have := ["_subtree_span_est", "_place_side_children"]
	var must_not_have := ["cols[key]", "sign(d))"]

	var ok := true
	for k in must_have:
		var has: bool = txt.contains(k)
		print("DIAG_PCK: new-feature ", k, " = ", has)
		if not has:
			ok = false
	for k in must_not_have:
		var has2: bool = txt.contains(k)
		print("DIAG_PCK: old-feature ", k, " = ", has2)
		if has2:
			ok = false

	print("DIAG_PCK: ", "PASS_NEW" if ok else "FAIL_OLD_STILL_PACKED")
	quit(0 if ok else 1)
