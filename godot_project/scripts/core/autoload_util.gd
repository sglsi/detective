class_name AutoloadUtil
extends RefCounted

## 统一获取 autoload 节点。
##
## ⚠️ autoload 是场景树节点（/root/Xxx），不是 Engine singleton。
##    Engine.has_singleton() 对 autoload 恒为 false，
##    用 Engine.get_singleton() 取 autoload 永远拿到 null。
##    Godot 4 也没有 Engine.register_singleton，autoload 不走这条注册路径。
##
## 正确写法：Engine.get_main_loop() as SceneTree → root.get_node_or_null(name)
static func get_autoload(name: String) -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null or ml.root == null:
		return null
	return ml.root.get_node_or_null(name)