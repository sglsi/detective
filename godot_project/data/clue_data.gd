class_name ClueData
extends Resource

## ClueData — 线索数据资源（15 字段标准化结构）
## 作为 res://data/clues/<id>.tres 的格式契约，由 ClueSystem 加载并驱动推理。
## state 以整数存储 ClueState（0=未发现 1=已发现 2=已记录 3=已分析 4=已关联），
## 以便 .tres 序列化与存档恢复保持一致。

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: String = ""          # 物证/证言/文件/痕迹
@export var location: String = ""          # 发现地点
@export var discovery_condition: String = "" # 发现条件
@export var observation: String = ""        # 观察记录
@export var analysis: String = ""           # 分析结果
@export var related_clues: Array = []       # 关联线索ID列表
@export var related_npcs: Array = []        # 关联NPC列表
@export var timeline_position: float = 0.0  # 时间线位置
@export var importance: int = 1             # 重要度 1-5
@export var is_key_evidence: bool = false   # 是否关键证据
@export var state: int = 0                  # ClueState 整数
@export var discovery_time: String = ""
# ============ 三级标签体系（推理墙跨场景关联 / 人证物证区分的数据底座）============
# 设计依据：08_系统框架设计（ClueData 字段契约）+ 06_推理墙运行机制 §2.1/§3.1。
# - content_tags：线索指代的事物/概念（如「车轮印」「血字」「海军军士」），用于跨线索语义关联。
# - attribute_tags：属性标签（直接物证/目击证词/二手传闻/嫌疑人陈述），驱动人证/物证区分与可信度评估。
# - relation_tags：关系标签（该线索支持的假设/结论节点 id），驱动「标签→假设」自动匹配（替换 788 退化逻辑）。
@export var content_tags: Array = []
@export var attribute_tags: Array = []
@export var relation_tags: Array = []
