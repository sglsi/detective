# 像素艺术风格生成器 - 快速开始

## 快速使用

### 1. 生成绿幕图

使用 AI 图像生成工具，Prompt 示例：

```
Sherlock Holmes standing, pixel art style, 64x64 sprite, 
clean solid color background (pure green #00ff00), 
NO other objects, isolated, game asset
```

### 2. 执行抠图 + 像素化

```bash
python3 scripts/pixel_art_cutout.py \
  --input <生成的图片.jpg> \
  --output <输出.png> \
  --pixel-size 64 \
  --colors 16
```

### 3. 在 Godot 中使用

将生成的 PNG 文件放入 `godot_project/assets/` 对应目录，在场景中引用即可。

## 完整文档

查看 `SKILL.md` 获取完整使用说明。
