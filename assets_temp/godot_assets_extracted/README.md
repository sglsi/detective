# 福尔摩斯对话界面 · Godot 4.7 美术资源包

> 由 `对话交互界面.jpg` 转换而来，包含 AI 补全高清版 + 原图可见区域切出版。  
> **未触碰你的原工程**，所有文件都在独立的 `godot_assets_export/` 目录内。

---

## 资源清单

```
godot_assets_export/
├── assets/
│   ├── backgrounds/
│   │   ├── bg_london_1920x1080.jpg   # 游戏背景（1920×1080，可直接用作 TextureRect）
│   │   ├── bg_london_full.png        # AI 生成原图（1216×832）
│   │   ├── bg_london_visible.jpg     # 原图可见背景（360×350，低分辨率参考）
│   │   └── bigben_visible.png        # 原图大本钟区域（280×150）
│   ├── characters/
│   │   ├── sherlock_full.png         # 福尔摩斯高清原图（1024×1024）
│   │   ├── sherlock_full_alpha.png   # 福尔摩斯透明底（RGBA，自动抠图）
│   │   ├── sherlock_visible.png      # 福尔摩斯原图露出区（180×200）
│   │   ├── lestrade_full.png         # 莱斯特雷德探长高清原图（1024×1024）
│   │   ├── lestrade_full_alpha.png   # 探长透明底（RGBA，自动抠图）
│   │   └── lestrade_visible.png      # 探长原图露出区（232×270）
│   └── props/
│       ├── carriage_full.png         # 马车高清原图（1024×1024）
│       ├── carriage_full_alpha.png   # 马车透明底（RGBA）
│       ├── carriage_scene_visible.png# 马车街景区原图（280×200）
│       ├── streetlamp_full.png       # 路灯高清原图（1024×1024）
│       ├── streetlamp_full_alpha.png # 路灯透明底（RGBA）
│       └── streetlamp_visible.png    # 路灯原图露出区（70×270）
├── docs/
│   ├── assets_preview_composite.jpg  # 资源组合效果预览
│   ├── ui_occlusion_mask.png         # 原图 UI 遮挡区域标注
│   └── manifest.txt                  # 完整尺寸清单
└── demo/                             # 最小 Godot 4.7 演示项目
    ├── project.godot
    ├── demo.tscn
    └── demo.gd
```

---

## 在 Godot 4.7 中使用

### 1. 只拖资源
把你需要的文件复制到你的 Godot 项目 `assets/` 下，Godot 会自动生成 `.import` 文件。

### 2. 推荐节点结构

```
DialogueStage (Control / Node2D)
├── Background (TextureRect 或 Sprite2D)
│   └── texture = bg_london_1920x1080.jpg
├── Props (Node2D / Control)
│   ├── StreetLamp (Sprite2D) → streetlamp_full_alpha.png
│   └── Carriage (Sprite2D)   → carriage_full_alpha.png
└── Characters (Control / Node2D)
    ├── Sherlock (Sprite2D)   → sherlock_full_alpha.png
    └── Lestrade (Sprite2D)   → lestrade_full_alpha.png
```

### 3. 运行 demo
用 Godot 4.7 打开 `godot_assets_export/demo/project.godot`，运行 `demo.tscn` 即可看到资源组合效果。

---

## 注意事项（直说）

1. **AI 水印**：所有 AI 生成的图片右下角都有「图片由AI生成」水印。正式上线前需要让美术修掉或重绘。
2. **自动抠图边缘不完美**：`*_full_alpha.png` 用 OpenCV grabCut 自动抠图，人物/道具边缘可能有少量锯齿或残留。建议用 Photoshop、GIMP 或 Remove.bg 做精修后再进工程。
3. **风格一致性**：AI 补全版尽量贴近了原图维多利亚煤气灯画风，但和原工程其他美术资源是否完全统一，需要你自己眼测。
4. **分辨率**：背景已缩放到 1920×1080；人物/道具为 1024×1024，在 Godot 里通常需要再缩放到合适尺寸（例如人物高 700–900 px）。

---

## 下一步建议

- 把 `*_full_alpha.png` 交给美术精修去水印 + 抠边缘。
- 若需要动态效果，给 `StreetLamp` 加一个自发光 Shader（如 `CanvasItem` 材质的 `modulate` 动画）。
- 若人物需要说话动画，可把嘴部/眉毛切分做 Spine/DragonBones 或简单帧动画。
