# Godot 游戏元素生成器 - 快速开始

## 5 分钟上手

### 步骤 1：生成绿幕图

使用 AI 图像生成工具，在 prompt 中包含：
- **背景色**：`clean solid color background (pure green #00ff00)`
- **主体隔离**：`alone`, `NO other objects`, `isolated`

**示例 Prompt**：
```
Victorian street lamp alone, pixel art style, 64x64 sprite,
clean solid color background (pure green #00ff00),
isolated object, game asset, transparent background ready
```

### 步骤 2：执行抠图

```bash
python3 skills/godot_asset_generator/scripts/greenscreen_cutout.py \
  --input your_image.jpg \
  --output godot_project/assets/props/your_prop.png
```

### 步骤 3：在 Godot 中使用

```gdscript
# 加载资源
var prop = preload("res://assets/props/your_prop.png")

# 创建 Sprite2D 节点
var sprite = Sprite2D.new()
sprite.texture = prop
sprite.position = Vector2(800, 600)
add_child(sprite)
```

## 完整示例：生成马车

### 1. AI 生成

```
prompt: "Victorian carriage alone, pixel art style, 
         clean solid color background (pure green #00ff00),
         NO people, NO other objects, game asset"
```

### 2. 抠图

```bash
python3 skills/godot_asset_generator/scripts/greenscreen_cutout.py \
  --input carriage_greenscreen.jpg \
  --output godot_project/assets/props/carriage.png
```

### 3. Godot 集成

```gdscript
# 在场景控制器中
var carriage_scene = preload("res://assets/props/carriage.tscn")
var carriage = carriage_scene.instantiate()
add_child(carriage)
carriage.position = Vector2(700, 620)
carriage.scale = Vector2(0.5, 0.5)
```

## 参数调优

### 背景色不纯？

如果 AI 生成的背景不是纯绿色，脚本会自动检测。也可以手动指定：

```bash
python3 greenscreen_cutout.py \
  --input image.jpg \
  --output image.png \
  --bg-color 162,245,33  # 黄绿色
```

### 边缘有锯齿？

增加渐变过渡范围：

```bash
python3 greenscreen_cutout.py \
  --input image.jpg \
  --output image.png \
  --fade-range 60  # 默认 40，增加到 60 使边缘更平滑
```

### 主体被误删？

降低透明阈值：

```bash
python3 greenscreen_cutout.py \
  --input image.jpg \
  --output image.png \
  --threshold 40  # 默认 60，降低到 40 保留更多主体
```

## 检查清单

生成游戏元素前，确认：

- [ ] Prompt 中指定了纯色背景（绿色）
- [ ] Prompt 中要求"alone"、"NO other objects"
- [ ] 生成的图片背景是均匀的纯色
- [ ] 抠图后用棋盘格背景预览检查效果
- [ ] 透明像素占比 > 70%（背景干净）
- [ ] 不透明像素占比 > 10%（主体完整）

## 常见问题

**Q: 为什么不用白色或黑色背景？**
A: 绿色与大多数建筑/角色颜色差异最大，抠图最精确。白色会误删高光，黑色会误删阴影。

**Q: 抠图效果不好怎么办？**
A: 1) 检查原图背景是否均匀；2) 调整 `--threshold` 和 `--fade-range`；3) 重新生成绿幕图。

**Q: 可以批量处理吗？**
A: 可以，用循环：
```bash
for img in *.jpg; do
  python3 greenscreen_cutout.py --input "$img" --output "${img%.jpg}.png"
done
```

**Q: 支持其他颜色背景吗？**
A: 支持，用 `--bg-color R,G,B` 指定任意背景色。

## 文件位置

- **脚本**：`skills/godot_asset_generator/scripts/greenscreen_cutout.py`
- **文档**：`skills/godot_asset_generator/SKILL.md`
- **输出**：`godot_project/assets/<类型>/<元素名>.png`
