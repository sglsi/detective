# 道具资源

本目录包含游戏中可交互的道具资源。

## 资源清单

### 马车 (Carriage)
- **文件**: `carriage_full_alpha.png`
- **尺寸**: 1024×1024 RGBA 透明底
- **场景文件**: `carriage.tscn`
- **用途**: 维多利亚时代四轮马车，用于场景一信使到达等剧情
- **推荐缩放**: 0.4 - 0.6（根据场景需求调整）

### 大本钟 (Big Ben)
- **文件**: `bigben_pixel.png`
- **尺寸**: 2048×2048 RGBA 透明底（像素艺术风格）
- **场景文件**: `bigben.tscn`
- **用途**: 伦敦地标建筑，用于场景背景元素
- **推荐缩放**: 0.3 - 0.5（根据场景需求调整）
- **风格**: 64x64 像素艺术，与福尔摩斯角色风格一致

### 维多利亚建筑 (Victorian Building)
- **文件**: `victorian_building.png`
- **尺寸**: 2048×2048 RGBA 透明底（像素艺术风格）
- **像素规格**: 256×256 像素，64 色调色板
- **文件大小**: 179KB
- **场景文件**: `victorian_building.tscn`
- **用途**: 维多利亚时代伦敦建筑，用于街道场景背景
- **推荐缩放**: 0.3 - 0.5（根据场景需求调整）
- **风格**: 高精度像素艺术，三层砖砌建筑，带烟囱和店面

### 维多利亚花园 (Victorian Garden)
- **文件**: `victorian_garden.png`
- **尺寸**: 2048×2048 RGBA 透明底（像素艺术风格）
- **像素规格**: 256×256 像素，64 色调色板
- **文件大小**: 204KB
- **场景文件**: `victorian_garden.tscn`
- **用途**: 维多利亚时代花园围栏，用于建筑前景装饰
- **推荐缩放**: 0.3 - 0.5（根据场景需求调整）
- **风格**: 高精度像素艺术，铁艺围栏、石柱、植物花卉

## 使用方式

### 在 Godot 中实例化

```gdscript
# 动态加载马车
var carriage_scene = preload("res://assets/props/carriage.tscn")
var carriage = carriage_scene.instantiate()
add_child(carriage)
carriage.position = Vector2(800, 600)

# 动态加载大本钟
var bigben_scene = preload("res://assets/props/bigben.tscn")
var bigben = bigben_scene.instantiate()
add_child(bigben)
bigben.position = Vector2(1600, 400)  # 背景位置

# 动态加载维多利亚建筑
var building_scene = preload("res://assets/props/victorian_building.tscn")
var building = building_scene.instantiate()
add_child(building)
building.position = Vector2(400, 300)
building.scale = Vector2(0.4, 0.4)

# 动态加载维多利亚花园
var garden_scene = preload("res://assets/props/victorian_garden.tscn")
var garden = garden_scene.instantiate()
add_child(garden)
garden.position = Vector2(400, 700)
garden.scale = Vector2(0.4, 0.4)
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
