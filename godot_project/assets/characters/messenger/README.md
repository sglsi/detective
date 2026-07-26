# 英文信使（Messenger）

## 角色说明

维多利亚时代伦敦的英文信使角色，负责在场景中传递信件和消息。

## 资源结构

```
messenger/
├── README.md                      # 本文档
├── messenger_spritesheet.png      # 精灵表（1.1MB）
├── messenger_portrait.png         # 角色立绘（1.2MB）
├── animations/                    # 动画帧目录（待创建）
│   ├── idle/                      # 待机动画
│   ├── walk/                      # 行走动画
│   ── deliver/                   # 送信动画
└── portraits/                     # 表情资源（待添加）
```

## 当前资源

### 精灵表（messenger_spritesheet.png）
- 文件大小：1.1 MB
- 用途：角色动画帧集合
- 风格：16-bit 像素艺术

### 角色立绘（messenger_portrait.png）
- 文件大小：1.2 MB
- 用途：角色展示/对话立绘
- 风格：16-bit 像素艺术，细节清晰

## 待办事项

- [ ] 分割精灵表为动画帧（idle/walk/deliver）
- [ ] 创建动画场景文件
- [ ] 添加表情资源
- [ ] 创建角色场景文件

## 设计风格

- 像素艺术风格（16-bit）
- 维多利亚时代邮差/信使装扮
- 与福尔摩斯、华生风格保持一致

## 使用示例

```gdscript
# 加载信使角色
var messenger = preload("res://assets/characters/messenger/messenger.tscn").instantiate()
add_child(messenger)
messenger.position = Vector2(800, 600)
```
