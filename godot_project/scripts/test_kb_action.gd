extends Control

## test_kb_action.gd — 验证「百科」动作能否打开知识库面板（完整项目环境，含 autoload）。
## 运行： godot --headless --path <project> res://scenes/test_kb_action.tscn
## 退出码 0 = PASS。

func _ready() -> void:
	await get_tree().create_timer(0.6).timeout
	var scn = load("res://scenes/scene1.tscn")
	if scn == null:
		print("SCENE1_LOAD_FAIL")
		get_tree().quit(1)
		return
	var inst = scn.instantiate()
	add_child(inst)
	await get_tree().create_timer(1.2).timeout
	print("kb_panel before: ", inst.get("_kb_panel"))
	inst.call("_on_action", "kb")
	await get_tree().create_timer(1.2).timeout
	var after = inst.get("_kb_panel")
	print("kb_panel after : ", after)
	var found: bool = _find(inst)
	print("panel node found: ", found)
	print("children of inst: ", inst.get_child_count())
	var ok: bool = (after != null) and found
	print("KB_ACTION_RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _find(n: Node) -> bool:
	if n.name == "KnowledgeBasePanel":
		return true
	for c in n.get_children():
		if _find(c):
			return true
	return false
