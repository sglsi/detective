class_name CaseData
extends Resource

## CaseData — 案件数据资源
## 作为 res://data/cases/<id>.tres 的格式契约，由 CaseManager 扫描并加载，
## 驱动关卡选择、场景顺序与线索/角色清单。

@export var id: String = ""
@export var title: String = ""             # 案件标题
@export var scenes: Array = []             # 场景ID顺序列表
@export var clues: Array = []              # 本案涉及线索ID列表
@export var npcs: Array = []               # 本案涉及角色ID列表
