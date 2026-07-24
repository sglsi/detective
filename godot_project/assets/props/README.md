# 道具资源

本目录包含游戏中可交互的道具资源。

## 资源清单

### 马车 (Carriage)
- **文件**: `carriage_full_alpha.png`
- **尺寸**: 1024×1024 RGBA 透明底
- **场景文件**: `carriage.tscn`
- **用途**: 维多利亚时代四轮马车，用于场景一信使到达等剧情
- **推荐缩放**: 0.4 - 0.6（根据场景需求调整）

## 使用方式

### 在 Godot 中实例化

```gdscript
# 动态加载马车
var carriage_scene = preload("res://assets/props/carriage.tscn")
var carriage = carriage_scene.instantiate()
add_child(carriage)
carriage.position = Vector2(800, 600)
```

### 在场景编辑器中

1. 打开场景编辑器
2. 从文件系统面板拖拽 `carriage.tscn` 到场景中
3. 调整位置和缩放

## 资源规范

- 所有道具使用 RGBA 透明底 PNG
- 原始尺寸 1024×1024
- 命名格式：`道具名_full_alpha.png`
- 场景文件：`道具名.tscn`

## 添加新道具

1. 将透明底 PNG 放入此目录
2. 创建对应的 `.tscn` 场景文件
3. 更新本 README
