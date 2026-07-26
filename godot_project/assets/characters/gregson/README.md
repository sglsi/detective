# 葛莱森（Gregson）

## 角色说明

苏格兰场警探，福尔摩斯的合作伙伴之一。

## 资源结构

```
gregson/
├── README.md                    # 本文档
├── gregson_spritesheet.png      # 精灵表（1.3MB）
├── gregson_portrait.png         # 角色立绘（1.3MB）
├── animations/                  # 动画帧目录（待创建）
│   ├── idle/                    # 待机动画
│   └── walk/                    # 行走动画
└── portraits/                   # 表情资源（待添加）
```

## 当前资源

### 精灵表（gregson_spritesheet.png）
- 文件大小：1.3 MB
- 用途：角色动画帧集合
- 风格：像素艺术

### 角色立绘（gregson_portrait.png）
- 文件大小：1.3 MB
- 用途：角色展示/对话立绘
- 风格：像素艺术，细节清晰

## 待办事项

- [ ] 分割精灵表为动画帧（idle/walk）
- [ ] 创建动画场景文件
- [ ] 添加表情资源
- [ ] 创建角色场景文件

## 设计风格

- 像素艺术风格
- 维多利亚时代警探装扮
- 与福尔摩斯、华生风格保持一致

## 使用示例

```gdscript
# 加载葛莱森角色
var gregson = preload("res://assets/characters/gregson/gregson.tscn").instantiate()
add_child(gregson)
gregson.position = Vector2(800, 600)
```
