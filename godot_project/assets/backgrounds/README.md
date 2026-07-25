# 伦敦背景系统

本目录包含伦敦背景绘制相关资源，用于游戏场景的氛围营造。

## 资源清单

### 背景图片
- `bg_london_1920x1080.jpg` - 伦敦街景高清背景（1920×1080）

### 着色器
- `fog_atmosphere.gdshader` - 雾气/暗角/煤气灯辉光全屏后处理着色器
- `sky_gradient.gdshader` - 天空渐变着色器
- `fog_material.tres` - 雾气材质参数预设

### 脚本
- `london_background.gd` - 背景控制器（摄像机缓移、氛围切换）
- `gas_lamp_glow.gd` - 程序化煤气灯辉光绘制

### 场景
- `london_background.tscn` - 可复用的伦敦背景场景（含天空 + 背景 + 雾气 + 煤气灯）

## 使用方式

### 在场景编辑器中

1. 打开场景编辑器
2. 从文件系统面板拖拽 `res://scenes/london_background.tscn` 到场景中
3. 在 Inspector 中调整参数：
   - **Camera**: `auto_pan` / `pan_speed` / `pan_range` - 摄像机控制
   - **Atmosphere**: `atmosphere_preset` - 氛围预设（Day/Dusk/Night/Foggy）
   - **Lamps**: `draw_lamp_glow` - 是否显示煤气灯辉光

### 在 GDScript 中动态加载

```gdscript
# 加载伦敦背景场景
var bg_scene = preload("res://scenes/london_background.tscn")
var background = bg_scene.instantiate()
add_child(background)

# 切换氛围
var bg_controller = background.get_node(".") as LondonBackground
bg_controller.set_atmosphere("Night")  # Day / Dusk / Night / Foggy

# 手动控制摄像机位置
bg_controller.set_camera_position(960.0)  # 0-1920 范围
```

### 作为子场景嵌入

```gdscript
# 在场景框架中嵌入背景
@onready var background: Node2D = $LondonBackground

func _ready():
    # 设置为黄昏氛围
    background.set_atmosphere("Dusk")
```

## 氛围预设说明

| 预设 | 雾气颜色 | 雾气浓度 | 暗角强度 | 灯光强度 | 适用场景 |
|------|----------|----------|----------|----------|----------|
| **Day** | 浅蓝灰 | 0.15 | 0.6 | 0.0 | 白天场景 |
| **Dusk** | 深紫灰 | 0.35 | 1.1 | 0.9 | 黄昏/默认 |
| **Night** | 深蓝黑 | 0.55 | 1.6 | 1.4 | 夜晚场景 |
| **Foggy** | 中灰 | 0.65 | 1.0 | 1.1 | 雾天场景 |

## 可调整参数

### LondonBackground 节点
- `pan_speed` (float): 摄像机平移速度，默认 8.0
- `pan_range` (float): 平移范围（±），默认 120.0
- `auto_pan` (bool): 是否自动平移，默认 true
- `atmosphere_preset` (String): 氛围预设，默认 "Dusk"
- `draw_lamp_glow` (bool): 是否绘制煤气灯，默认 true

### GasLamps 节点
- `lamp_positions` (Array[Vector2]): 灯源 UV 坐标（0~1）
- `lamp_color` (Color): 灯光颜色，默认暖黄色
- `lamp_radius` (float): 灯光半径，默认 90.0
- `flicker_speed` (float): 闪烁速度，默认 6.0

## 扩展建议

- 将 `Background` 拆分为多层 `ParallaxBackground` 实现景深
- 为 `GasLamps` 添加 `PointLight2D` 实现真实 2D 光照
- 将 `FogOverlay` 替换为 `SubViewport` 限制后处理范围
