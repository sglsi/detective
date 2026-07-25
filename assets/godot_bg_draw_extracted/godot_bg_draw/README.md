# London Background Draw — Godot 4.7

用 Godot 4.7 重新绘制/渲染《对话交互界面.jpg》中的伦敦背景建筑（大本钟、议会大厦、街道、煤气灯）。

## 项目结构

```
godot_bg_draw/
├── project.godot                 # Godot 项目配置
├── icon.svg                      # 项目图标
├── README.md                     # 本说明
├── assets/
│   └── backgrounds/
│       ├── bg_london_1920x1080.jpg   # 1920×1080 高清伦敦背景（AI 生成）
│       └── bigben_visible.png        # 从原图中切出的大本钟局部
├── scenes/
│   └── main.tscn                 # 主场景：背景 + 天空 + 雾气 + 煤气灯
├── scripts/
│   ├── background_controller.gd  # 摄像机缓移、昼夜氛围切换
│   └── gas_lamp_glow.gd          # 程序化绘制煤气灯辉光
└── shaders/
    ├── fog_atmosphere.gdshader   # 雾气、暗角、煤气灯辉光（全屏后处理）
    ├── sky_gradient.gdshader     # 天空渐变底色
    └── fog_material.tres         # ShaderMaterial 参数预设
```

## 运行方式

1. 在 Godot 4.7 编辑器中选择 **项目 → 导入** 或直接用命令行打开项目：
   ```bash
   D:/AI/godot/Godot_v4.7-stable_win64/Godot_v4.7-stable_win64.exe --path "D:/AI/workbuddy/2026-07-23-23-25-55/godot_bg_draw"
   ```
2. 主场景为 `res://scenes/main.tscn`，运行即可看到伦敦背景 + 雾气 + 煤气灯闪烁效果。

## 场景节点说明

| 节点 | 类型 | 作用 |
|------|------|------|
| `Main` | `Node2D` | 根节点，挂载 `background_controller.gd` |
| `Sky` | `ColorRect` | 天空渐变，防止相机平移露出黑边 |
| `Background` | `Sprite2D` | 伦敦背景图，缩放 1.15 以覆盖平移范围 |
| `Atmosphere/FogOverlay` | `ColorRect` + `ShaderMaterial` | 雾气、暗角、煤气灯辉光（后处理） |
| `GasLamps` | `Node2D` + `gas_lamp_glow.gd` | 程序化绘制灯晕 |
| `Camera2D` | `Camera2D` | 1920×1080 居中，默认自动缓移 |

## 可调整参数

在 `Main` 节点上：
- `auto_pan` / `pan_speed` / `pan_range`：开关与速度控制摄像机缓移。
- `atmosphere_preset`：Day / Dusk / Night / Foggy，一键切换氛围。
- `draw_lamp_glow`：是否显示煤气灯辉光。

在 `GasLamps` 节点上：
- `lamp_positions`：灯源在屏幕 UV 中的位置（0~1）。
- `lamp_color` / `lamp_radius` / `flicker_speed`：灯色、半径、闪烁频率。

在 `shaders/fog_material.tres` 中：
- `fog_color` / `fog_density`：雾气颜色与浓度。
- `vignette_strength`：暗角强度。
- `lamp_1_uv` / `lamp_2_uv`：shader 中内置灯源位置，与 `GasLamps` 脚本配合使用。

## 资源来源

- `bg_london_1920x1080.jpg`：来自上一次从《对话交互界面.jpg》提取并 AI 放大后的高清背景。
- `bigben_visible.png`：从原截图中直接切出的大本钟局部。

## 后续扩展建议

- 将 `Background` 拆分为多层 `ParallaxBackground`（远景天空、中景建筑、前景街道），实现更真实的镜头深度。
- 为 `GasLamps` 添加 `PointLight2D` 节点，结合 Godot 2D 灯光实现更真实的局部光照。
- 将 `FogOverlay` 替换为 `SubViewport` 方案，可把后处理限制在背景区域而不是全屏。
