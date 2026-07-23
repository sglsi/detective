# 福尔摩斯像素艺术资源

## 概述
像素风格福尔摩斯角色资源，适用于 Godot 4.x 游戏引擎。

## 资源清单

### 精灵表
- `sherlock_spritesheet.png` - 完整精灵表（含全身立绘 + 动画帧）

### 动画帧（64x64 像素）
```
animations/
├── idle/      # 待机动画（5 帧）
── walk/      # 行走动画（5 帧）
├── think/     # 思考动画（5 帧）
├── inspect/   # 检查动画（5 帧，持放大镜）
└── point/     # 指向动画（5 帧）
```

### 场景与脚本
- `scenes/characters/holmes_pixel.tscn` - 角色场景
- `scripts/characters/holmes_pixel.gd` - 角色控制脚本

## 角色特征
- **帽子**：棕色猎鹿帽（Deerstalker Hat）
- **外套**：棕色格纹因弗内斯斗篷（Inverness Cape）
- **内搭**：深色马甲 + 白色衬衫 + 深色领带
- **道具**：烟斗、放大镜
- **表情**：睿智、神秘、专注

## 调色板（16 色）
| 颜色 | 用途 |
|------|------|
| 浅棕/米色 | 皮肤、衬衫 |
| 棕色系 | 帽子、斗篷、头发 |
| 深棕/黑色 | 西装、领带、鞋子 |
| 金色 | 怀表链、装饰 |

## 动画规格
- **帧尺寸**：64x64 像素
- **帧率**：4-8 FPS（根据动画类型）
- **格式**：PNG（支持透明）
- **引擎**：Godot 4.x 兼容

## 使用方法

### 在 Godot 中使用
1. 打开 `scenes/characters/holmes_pixel.tscn`
2. 将场景实例化到游戏场景中
3. 使用脚本控制动画状态

### 代码示例
```gdscript
# 播放行走动画
holmes.play_animation("walk")

# 播放思考动画
holmes.play_think()

# 播放检查动画
holmes.play_inspect()

# 设置朝向
holmes.set_facing_right(true)
```

## 文件结构
```
godot_project/
├── assets/characters/holmes/pixel_art/
│   ├── sherlock_spritesheet.png
│   ├── animations/
│   │   ├── idle/
│   │   ├── walk/
│   │   ├── think/
│   │   ├── inspect/
│   │   └── point/
│   ── README.md
├── scenes/characters/
│   └── holmes_pixel.tscn
└── scripts/characters/
    ── holmes_pixel.gd
```

## 版本信息
- **创建日期**：2026-07-23
- **Godot 版本**：4.x
- **资源类型**：像素艺术（Pixel Art）
- **角色类型**：可控制角色（CharacterBody2D）
