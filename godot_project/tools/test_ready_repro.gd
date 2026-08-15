extends SceneTree

## 纯引擎行为测试（不依赖任何 autoload）：
## 父节点 _ready 内 add_child 子节点，子节点的 _ready 是否「同步」执行？
## 若同步 → SceneFramework._world 在 _create_observers 时已进入场景树并 _ready，
##   则 get_world_layer() 有效；若延迟 → _world 为 null → 地点类 btn 落到错误坐标系。

class Child extends Control:
	var _built_flag := false
	func _ready() -> void:
		_built_flag = true

class Parent extends Node:
	var _child = null
	var _child_ready_at_create := false
	func _ready() -> void:
		_child = Child.new()
		add_child(_child)
		_child_ready_at_create = _child._built_flag

func _initialize() -> void:
	var p = Parent.new()
	root.add_child(p)
	print("[ENGINE] 子节点 _ready 在父 _ready 内「同步」执行? => ", p._child_ready_at_create)
	print("[ENGINE] 结论: ", ("父 _ready 内 add_child 后子 _ready 立即跑（时序非 bug）" if p._child_ready_at_create else "子 _ready 被延迟（_create_observers 时 _world 为 null → BUG）"))
	quit()
