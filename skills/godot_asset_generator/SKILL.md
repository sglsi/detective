# Godot 游戏元素生成器

## 概述

这是一个通用的 Godot 游戏元素生成 skill，用于将 AI 生成的图片转换为游戏可用的透明底 PNG 资源。

**工作流程**：
```
AI 生成绿幕图 → Python 绿幕抠图 → 透明底 PNG → Godot 场景文件
```

## 适用场景

- 生成角色精灵（sprites）
- 生成道具图标（props）
- 生成背景元素（backgrounds）
- 生成 UI 元素
- 任何需要透明底的游戏资源

## 使用方法

### 1. 生成绿幕图

使用 AI 图像生成工具，在 prompt 中指定：
- **背景色**：纯绿色 `#00ff00` 或黄绿色 `#a2f521`
- **主体**：只包含目标元素，不要其他杂物
- **风格**：根据项目需求（像素艺术/写实/等）

**Prompt 示例**：
```
Big Ben clock tower alone, pixel art style, 64x64 sprite, 
Victorian London landmark, NO street lamps, NO other objects, 
clean solid color background (pure green #00ff00), 
isolated building, game asset, retro pixel art
```

### 2. 执行绿幕抠图

运行 Python 脚本：
```bash
python3 skills/godot_asset_generator/scripts/greenscreen_cutout.py \
  --input <绿幕图片路径> \
  --output <输出透明底 PNG 路径>
```

**参数说明**：
- `--input`：输入的绿幕图片（JPG 或 PNG）
- `--output`：输出的透明底 PNG 路径
- `--bg-color`：背景色 RGB 值（默认自动检测）
- `--threshold`：透明阈值（默认 60）
- `--fade-range`：渐变过渡范围（默认 40）

### 3. 集成到 Godot 项目

将生成的透明底 PNG 放入 Godot 项目的资源目录：
```
godot_project/assets/
├── characters/    # 角色
├── props/         # 道具
├── backgrounds/   # 背景
└── ui/            # UI 元素
```

创建 `.tscn` 场景文件（可选）：
```gdscript
# 示例：加载道具
var prop_scene = preload("res://assets/props/your_prop.tscn")
var prop = prop_scene.instantiate()
add_child(prop)
prop.position = Vector2(800, 600)
prop.scale = Vector2(0.5, 0.5)
```

## 技术细节

### 绿幕抠图算法

1. **自动检测背景色**：统计图片边缘像素颜色，找出最常见的颜色
2. **计算颜色距离**：每个像素与背景色的欧几里得距离
3. **渐变透明**：
   - 距离 < 阈值：完全透明
   - 距离 阈值~阈值 + 过渡：渐变半透明
   - 距离 > 阈值 + 过渡：完全不透明

### 为什么使用绿幕

- AI 图像生成工具不支持直接输出透明底 PNG
- 绿色与大多数建筑/角色颜色差异大，抠图精确
- 影视工业标准，算法成熟

### 背景色选择

| 背景色 | 适用场景 | 优点 |
|--------|----------|------|
| 纯绿色 `#00ff00` | 通用 | 与大多数主体颜色差异大 |
| 黄绿色 `#a2f521` | AI 生成常用 | AI 工具倾向于生成此色调 |
| 蓝色 `#0000ff` | 绿色主体（如植物） | 避免与主体冲突 |

## 文件结构

```
skills/godot_asset_generator/
├── SKILL.md                           # 本说明文档
── README.md                          # 快速开始指南
└── scripts/
    └── greenscreen_cutout.py          # 绿幕抠图脚本
```

## 示例

### 生成大本钟

1. AI 生成绿幕图：
   ```
   prompt: "Big Ben clock tower alone, pixel art style, 
            clean solid color background (pure green #00ff00)"
   ```

2. 执行抠图：
   ```bash
   python3 skills/godot_asset_generator/scripts/greenscreen_cutout.py \
     --input bigben_greenscreen.jpg \
     --output godot_project/assets/props/bigben_pixel.png
   ```

3. 在 Godot 中使用：
   ```gdscript
   var bigben = preload("res://assets/props/bigben.tscn").instantiate()
   add_child(bigben)
   bigben.position = Vector2(1600, 400)
   bigben.scale = Vector2(0.4, 0.4)
   ```

## 注意事项

1. **生成时只包含目标元素**：不要在 prompt 中包含其他物体（如路灯、人物等）
2. **背景色要纯色**：确保 AI 生成的背景是均匀的纯色
3. **检查抠图效果**：生成后用棋盘格背景预览，确认边缘干净
4. **保留绿幕原图**：建议保留绿幕原图作为备份，方便重新抠图

## 兼容性

- Python 3.7+
- 依赖：PIL (Pillow)、numpy
- 支持格式：JPG、PNG 输入，PNG 输出
- 适用于任何 AI 图像生成工具（generate_image、Midjourney、DALL-E 等）

## 版本历史

- **v1.0** (2026-07-25)：初始版本，支持绿幕抠图和自动背景色检测
