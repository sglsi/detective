# 像素艺术风格生成器

## 概述

专门用于生成像素艺术风格游戏元素的 Skill。从 AI 生成绿幕图到 Python 抠图，最后生成透明底 PNG，并可选进行像素化处理以确保风格统一。

## 适用场景

- 像素艺术风格的游戏角色、道具、建筑等元素
- 需要统一像素尺寸（如 64x64、128x128）的游戏资产
- 需要限制调色板（如 16 色、32 色）的复古风格游戏
- Godot、Unity 等游戏引擎的像素艺术资源

## 工作流程

```
AI 生成绿幕图 → Python 抠图 → 可选像素化处理 → 透明底 PNG
```

### 步骤 1：AI 生成绿幕图

使用 generate_image 工具，Prompt 必须包含：

```
<元素描述> alone, pixel art style, 64x64 sprite, 
clean solid color background (pure green #00ff00), 
NO other objects, isolated, game asset
```

**关键参数**：
- `pixel art style` - 指定像素艺术风格
- `64x64 sprite` - 指定像素尺寸（可根据需要调整）
- `clean solid color background (pure green #00ff00)` - 绿幕背景
- `NO other objects` - 确保只有主体
- `isolated, game asset` - 强调是游戏资产

### 步骤 2：Python 抠图

```bash
python3 skills/pixel_art_generator/scripts/pixel_art_cutout.py \
  --input <绿幕图.jpg> \
  --output <输出.png> \
  --pixel-size 64 \
  --colors 16
```

**参数说明**：
- `--input`：AI 生成的绿幕图路径
- `--output`：输出透明底 PNG 路径
- `--pixel-size`：目标像素尺寸（默认 64，可选 32/64/128/256）
- `--colors`：调色板颜色数（默认 16，可选 8/16/32/64）
- `--no-pixelate`：跳过像素化处理，只抠图

### 步骤 3：验证结果

检查输出文件：
- 透明背景（棋盘格显示）
- 像素边缘清晰
- 颜色数量符合预期
- 尺寸正确

## 使用示例

### 示例 1：生成福尔摩斯角色

```bash
# 1. AI 生成（使用 generate_image 工具）
# Prompt: "Sherlock Holmes standing, pixel art style, 64x64 sprite, 
#          clean solid color background (pure green #00ff00), 
#          NO other objects, isolated, game asset"

# 2. 抠图 + 像素化
python3 skills/pixel_art_generator/scripts/pixel_art_cutout.py \
  --input sherlock.jpg \
  --output godot_project/assets/characters/sherlock.png \
  --pixel-size 64 \
  --colors 16
```

### 示例 2：生成道具（放大镜）

```bash
# 1. AI 生成
# Prompt: "magnifying glass alone, pixel art style, 32x32 sprite, 
#          clean solid color background (pure green #00ff00), 
#          NO other objects, isolated, game asset"

# 2. 抠图 + 像素化
python3 skills/pixel_art_generator/scripts/pixel_art_cutout.py \
  --input magnifying_glass.jpg \
  --output godot_project/assets/props/magnifying_glass.png \
  --pixel-size 32 \
  --colors 16
```

### 示例 3：只抠图不像素化

```bash
python3 skills/pixel_art_generator/scripts/pixel_art_cutout.py \
  --input element.jpg \
  --output element.png
```

## Prompt 模板

### 角色（64x64）

```
<角色名> <动作/姿态>, pixel art style, 64x64 sprite, 
clean solid color background (pure green #00ff00), 
NO other objects, isolated, game asset
```

### 道具（32x32）

```
<道具名> alone, pixel art style, 32x32 sprite, 
clean solid color background (pure green #00ff00), 
NO other objects, isolated, game asset
```

### 建筑/大场景（128x128）

```
<建筑名> alone, pixel art style, 128x128 sprite, 
clean solid color background (pure green #00ff00), 
NO other objects, isolated, game asset
```

## 像素尺寸选择

| 尺寸 | 适用场景 | 细节程度 |
|------|----------|----------|
| 16x16 | 小图标、简单道具 | 低 |
| 32x32 | 道具、小角色 | 中 |
| 64x64 | 角色、中等元素 | 高 |
| 128x128 | 大角色、建筑 | 很高 |
| 256x256 | 复杂场景、BOSS | 极高 |

## 调色板颜色数

| 颜色数 | 风格 | 适用场景 |
|--------|------|----------|
| 8 色 | 极简复古 | Game Boy 风格 |
| 16 色 | 经典像素 | NES/SNES 风格 |
| 32 色 | 增强像素 | GBA 风格 |
| 64 色 | 现代像素 | 独立游戏风格 |

## 与其他 Skill 的区别

| Skill | 风格 | 特点 |
|-------|------|------|
| **pixel_art_generator** | 像素艺术 | 包含像素化处理和调色板限制 |
| **godot_asset_generator** | 通用 | 只抠图，不限制风格 |

## 注意事项

1. **AI 生成的图片可能不是真正的像素艺术**
   - AI 生成的是高分辨率图片，需要后续像素化处理
   - 本 Skill 的脚本会自动进行像素化

2. **像素尺寸选择**
   - 根据游戏实际显示尺寸选择
   - 常用 64x64（角色）和 32x32（道具）

3. **颜色数选择**
   - 颜色越少，复古感越强
   - 颜色越多，细节越丰富
   - 建议 16 色作为起点

4. **绿幕背景检测**
   - 脚本会自动检测背景色
   - 如果 AI 生成的背景不是纯绿色，脚本也能处理

## 文件结构

```
pixel_art_generator/
├── SKILL.md                           # 本文档
├── README.md                          # 快速开始指南
└── scripts/
    └── pixel_art_cutout.py            # 像素艺术抠图脚本
```

## 依赖

- Python 3.6+
- Pillow (PIL)

```bash
pip install Pillow
```

## 版本历史

- v1.0 (2026-07-25) - 初始版本
