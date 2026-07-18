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
