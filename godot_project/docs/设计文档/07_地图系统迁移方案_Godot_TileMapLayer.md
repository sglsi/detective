# 地图系统迁移方案：Leaflet.js → Godot TileMapLayer

> 生成时间：2026-06-02
> 前置文档：[06_开发平台选型对比.md](./06_开发平台选型对比.md)
> 核心设计：[00_核心设计思路.md](./00_核心设计思路.md) 三层渐进式地图 + 地点三态

---

## 一、迁移目标

将基于 Leaflet.js 的 Web 地图系统迁移到 Godot 4.x TileMapLayer，保留以下核心设计不变：

| 核心设计 | 迁移要求 |
|---------|---------|
| **三层渐进式地图**（任务地图→探索地图→完整地图） | ✅ 必须保留，用Godot相机系统实现 |
| **地点三态**（隐藏→已标记→已探索） | ✅ 必须保留，用TileSet自定义数据实现 |
| **收藏品式地图**（随案件进度逐步解锁） | ✅ 必须保留，用存档系统持久化 |
| **1864年斯坦福真实地图** | ✅ 必须保留，瓦片化后作为TileMap纹理 |
| **地点标记交互**（点击标记进入场景） | ✅ 必须保留，用Area2D检测实现 |
| **缩放/平移** | ✅ 保留，用Camera2D实现 |

---

## 二、架构设计

### 2.1 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                    MapScene (Node2D)                      │
│                                                          │
│  ┌─ Camera2D ──────────────────────────────────────────┐ │
│  │  zoom: 0.5~3.0  |  limit: 地图边界                  │ │
│  │  smoothing: 开启  |  drag: 触摸拖拽                  │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ TileMapLayer: base_map ────────────────────────────┐ │
│  │  基础地图层：1864年伦敦地图瓦片                      │ │
│  │  TileSet: london_1864_tileset.tres                  │ │
│  │  渲染：Compatibility (GLES3)                        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ TileMapLayer: fog_layer ───────────────────────────┐ │
│  │  迷雾层：覆盖未解锁区域的半透明遮罩                  │ │
│  │  机制：解锁区域擦除对应瓦片，露出下层地图            │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Node2D: markers ──────────────────────────────────┐ │
│  │  地点标记节点容器                                   │ │
│  │  ├── LocationMarker (贝克街221B)                    │ │
│  │  │   ├─ Sprite2D (标记图标)                         │ │
│  │  │   ├─ Area2D + CollisionShape2D (点击检测)         │ │
│  │   │   └─ Label (地点名称)                            │ │
│  │   ├── LocationMarker (大英博物馆)                   │ │
│  │   └── ...                                          │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ CanvasLayer: ui_overlay ──────────────────────────┐ │
│  │  UI层：小地图、进度指示器、区域切换按钮             │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ MapController (脚本) ─────────────────────────────┐ │
│  │  地图核心逻辑控制器                                 │ │
│  │  ├── 地图层级切换（任务/探索/完整）                  │ │
│  │  ├── 地点三态管理                                    │ │
│  │  ├── 触摸交互处理                                    │ │
│  │  └── 动画/过渡效果                                   │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### 2.2 关键概念映射：Leaflet.js → Godot

| Leaflet.js 概念 | Godot 等价实现 | 说明 |
|----------------|---------------|------|
| `MapContainer` | `MapScene (Node2D)` | 场景根节点 |
| `TileLayer` (XYZ瓦片) | `TileMapLayer` + `TileSet` | 瓦片渲染层 |
| `Marker` | `LocationMarker (Node2D)` | 地点标记，含Sprite2D+Area2D |
| `Popup` | `Panel + RichTextLabel` | 点击标记后的信息弹窗 |
| `zoom` | `Camera2D.zoom` | 缩放控制 |
| `pan/drag` | `Camera2D + InputEvent` | 平移/拖拽 |
| `GeoJSON` 边界 | `Polygon2D` 或 `TileMapLayer` 区域 | 区域范围 |
| `CRS` 坐标系 | 像素坐标 | Godot用像素，不需要地理坐标转换 |
| `fitBounds` | `Camera2D.limit_*` + 动画 | 限制可视范围 |

---

## 三、1864年斯坦福地图瓦片化方案

### 3.1 地图资源与网格定义

- **原始资料**：1864年斯坦福图书馆版伦敦地图
- **瓦片网格**：10行（1-10）× 8列（A-H）= 80格瓦片
- **核心原则**：不预加载全80格，按案件驱动只加载关联瓦片的包围矩形

### 3.2 案件驱动式瓦片加载

每个案件定义自己的关联瓦片列表，运行时只加载这些瓦片的最小包围矩形：

```
案件定义流程:
    │
    ▼ Step 1: 确定案件关联瓦片
    列出案件中所有地点所在的瓦片坐标
    例: 血字的研究 → 3D, 3E, 4E, 5F, 5H, 6F, 6G, 6H, 7F, 7G
    │
    ▼ Step 2: 计算包围矩形
    min_row=3, max_row=7, min_col=D, max_col=H
    → 行3-7 × 列D-H = 25格瓦片
    │
    ▼ Step 3: 瓦片预处理与导入
    仅对包围矩形内的25格瓦片进行：
    - ImageMagick裁切/对齐/2的幂尺寸
    - ASTC压缩（Android）导入Godot
    │
    ▼ Step 4: 创建TileSet + 绘制TileMapLayer
    TileSet只包含当前案件需要的瓦片纹理
    - tile_size: 256×256 或 512×512
    - 添加自定义数据层: tile_coord (String, 如"3D")
    │
    ▼ Step 5: 迷雾覆盖
    包围矩形内非关联瓦片覆盖迷雾
    关联瓦片中非已探索区域也覆盖迷雾
    │
    ▼ Step 6: 下一案件扩展
    新案件关联瓦片可能与当前区域重叠或扩展
    合并两个案件的包围矩形，加载新增瓦片
```

### 3.3 瓦片区域数据结构

```gdscript
class_name CaseTileRegion
extends Resource

## 案件ID
@export var case_id: String

## 案件直接关联的瓦片坐标列表（如 ["3D", "3E", "6F"]）
@export var related_tiles: PackedStringArray

## 包围矩形（自动从related_tiles计算）
@export var bounding_min_row: int    # 最小行号
@export var bounding_max_row: int    # 最大行号
@export var bounding_min_col: int    # 最小列号（1=A, 8=H）
@export var bounding_max_col: int    # 最大列号

## 包围矩形内所有瓦片
func get_bounding_tiles() -> PackedStringArray:
    var tiles: PackedStringArray = []
    var col_letters = "ABCDEFGH"
    for row in range(bounding_min_row, bounding_max_row + 1):
        for col in range(bounding_min_col, bounding_max_col + 1):
            tiles.append("%d%c" % [row, col_letters[col - 1]])
    return tiles

## 计算包围矩形（从related_tiles自动推导）
func recalculate_bounding() -> void:
    var col_letters = "ABCDEFGH"
    bounding_min_row = 10
    bounding_max_row = 1
    bounding_min_col = 8
    bounding_max_col = 1
    for tile_str in related_tiles:
        var row = int(tile_str.left(tile_str.length() - 1))
        var col = col_letters.find(tile_str.right(1)) + 1
        bounding_min_row = mini(bounding_min_row, row)
        bounding_max_row = maxi(bounding_max_row, row)
        bounding_min_col = mini(bounding_min_col, col)
        bounding_max_col = maxi(bounding_max_col, col)
```

### 3.4 案件区域合并

当玩家进入新案件时，将新案件的包围矩形与已有区域合并：

```gdscript
## 全局已解锁区域管理器
class_name TileRegionManager
extends Node

var unlocked_tiles: Dictionary = {}  # tile_coord → bool
var current_bounds: Rect2i           # 合并后的包围矩形

func merge_case_region(case_region: CaseTileRegion) -> void:
    # 添加新案件的关联瓦片到已解锁集合
    for tile in case_region.related_tiles:
        unlocked_tiles[tile] = true

    # 扩展包围矩形（取并集）
    if current_bounds == Rect2i():
        current_bounds = Rect2i(
            Vector2i(case_region.bounding_min_col, case_region.bounding_min_row),
            Vector2i(
                case_region.bounding_max_col - case_region.bounding_min_col + 1,
                case_region.bounding_max_row - case_region.bounding_min_row + 1
            )
        )
    else:
        var min_x = mini(current_bounds.position.x, case_region.bounding_min_col)
        var min_y = mini(current_bounds.position.y, case_region.bounding_min_row)
        var max_x = maxi(current_bounds.end.x, case_region.bounding_max_col)
        var max_y = maxi(current_bounds.end.y, case_region.bounding_max_row)
        current_bounds = Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

    # 加载合并后包围矩形内的新增瓦片
    load_new_tiles()
```

### 3.5 《血字的研究》瓦片区域示例

```
     A   B   C   D   E   F   G   H
 1 │   │   │   │   │   │   │   │
 2 │   │   │   │   │   │   │   │
 3 │   │   │   │ ★ │ ★ │   │   │  ← 贝克街221B
 4 │   │   │   │   │ ★ │   │   │  ← 苏格兰场
 5 │   │   │   │   │   │ ★ │   │★  ← 布里克斯顿路 / 卡彭蒂耶公寓
 6 │   │   │   │   │   │ ★ │★ │★  ← 凶案现场 / 奥德利大院 / 卡彭蒂耶
 7 │   │   │   │   │   │ ★ │★ │   ← 布里克斯顿路 / 奥德利大院
 8 │   │   │   │   │   │   │   │
 9 │   │   │   │   │   │   │   │
10 │   │   │   │   │   │   │   │

包围矩形: 行3-7 × 列D-H = 25格
关联瓦片: 10格（★标记）
填充瓦片: 15格（迷雾覆盖，直到玩家探索）

纹理内存估算（单格512×512, ASTC 4×4）:
  25格 × ~170KB/格 ≈ 4.25MB（远低于30MB预算）
```

### 3.6 多案件区域扩展示例

```
案件1: 血字的研究  → 行3-7 × 列D-H (25格)
案件2: 四签名      → 行4-8 × 列F-H (15格，与案件1重叠6格)
合并后:            → 行3-8 × 列D-H (30格，新增5格)

案件3: 波西米亚丑闻 → 行2-4 × 列C-E (9格，与合并区域重叠3格)
合并后:             → 行2-8 × 列C-H (49格，新增19格)

...最终通关所有案件后，合并区域可能覆盖50-60格，而非全部80格
```

### 3.7 大地图内存管理

- **初始加载**：只加载当前案件包围矩形的瓦片纹理
- **案件扩展**：新案件合并包围矩形后，增量加载新增瓦片
- **卸载策略**：已加载瓦片常驻内存（纹理总量可控，单格~170KB，50格≈8.5MB）
- **目标内存**：地图纹理不超过 15MB

---

## 四、三层渐进式地图实现

### 4.1 层级定义

```
层级1: 任务地图（Mission Map）
├── 范围：仅当前案件相关地点（3-5个标记点）
├── 缩放：固定中距，不可自由缩放
├── 迷雾：仅显示任务区域，其余全雾
├── 交互：只能点击标记点进入场景
└── 触发：新案件开始时自动进入

层级2: 探索地图（Explore Map）
├── 范围：已解锁的所有区域
├── 缩放：可缩放（0.5x~2.0x），可平移
├── 迷雾：未探索区域半透明遮罩，已探索区域清晰
├── 交互：点击地点标记查看信息/进入场景
└── 触发：案件间隙自由探索

层级3: 完整地图（Full Map）
├── 范围：全伦敦地图
├── 缩放：可缩放（0.3x~3.0x），可平移
├── 迷雾：完全移除（游戏后期解锁）
├── 交互：查看所有历史资料和地点信息
└── 触发：通关所有案件或特定条件
```

### 4.2 Godot实现方案

```gdscript
class_name MapController
extends Node2D

enum MapLevel { MISSION, EXPLORE, FULL }

@export var current_level: MapLevel = MapLevel.MISSION

# 相机配置
var camera_configs := {
    MapLevel.MISSION: {
        "zoom_min": 1.0, "zoom_max": 1.0,     # 固定缩放
        "pan_enabled": false,                    # 禁止平移
        "auto_center": true                      # 自动居中任务区域
    },
    MapLevel.EXPLORE: {
        "zoom_min": 0.5, "zoom_max": 2.0,
        "pan_enabled": true,
        "auto_center": false
    },
    MapLevel.FULL: {
        "zoom_min": 0.3, "zoom_max": 3.0,
        "pan_enabled": true,
        "auto_center": false
    }
}

func switch_level(level: MapLevel) -> void:
    current_level = level
    var config = camera_configs[level]
    camera.zoom_min = config.zoom_min
    camera.zoom_max = config.zoom_max
    camera.pan_enabled = config.pan_enabled
    
    # 更新迷雾可见性
    update_fog_visibility(level)
    
    # 更新标记点可见性
    update_marker_visibility(level)

func update_fog_visibility(level: MapLevel) -> void:
    match level:
        MapLevel.MISSION:
            fog_layer.modulate.a = 0.9  # 几乎全雾，只露出任务区域
        MapLevel.EXPLORE:
            fog_layer.modulate.a = 0.6  # 半透明迷雾
        MapLevel.FULL:
            fog_layer.visible = false   # 完全移除迷雾
```

---

## 五、地点三态系统实现

### 5.1 三态定义

```
状态1: HIDDEN（隐藏）
├── 地图上不可见
├── 迷雾完全覆盖
├── 无标记、无名称
└── 条件：尚未触发相关剧情

状态2: MARKED（已标记）
├── 地图上可见标记图标
├── 迷雾部分透明
├── 显示地点名称（灰色）
├── 点击可查看基本信息（无法进入场景）
└── 条件：剧情中提及该地点 / 线索指向该地点

状态3: EXPLORED（已探索）
├── 标记图标亮起
├── 迷雾完全移除
├── 显示地点名称（金色）+ 探索进度
├── 点击可进入场景
└── 条件：玩家已进入并交互过该地点
```

### 5.2 数据结构

```gdscript
class_name LocationState
extends Resource

enum Status { HIDDEN, MARKED, EXPLORED }

@export var location_id: String
@export var display_name: String
@export var status: Status = Status.HIDDEN
@export var map_position: Vector2          # 地图像素坐标
@export var scene_path: String             # 对应场景文件路径
@export var unlock_conditions: Dictionary  # 解锁条件
@export var description: String
@export var history_info: String           # 历史资料文本
@export var exploration_progress: float = 0.0  # 探索进度 0~1

# 标记图标资源（按状态切换）
@export var icon_hidden: Texture2D
@export var icon_marked: Texture2D
@export var icon_explored: Texture2D
```

### 5.3 地点标记节点

```gdscript
class_name LocationMarker
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea
@onready var label: Label = $Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var location_data: LocationState

func setup(data: LocationState) -> void:
    location_data = data
    position = data.map_position
    update_visual()

func update_visual() -> void:
    match location_data.status:
        LocationState.Status.HIDDEN:
            visible = false
        LocationState.Status.MARKED:
            visible = true
            sprite.texture = location_data.icon_marked
            label.add_theme_color_override("font_color", Color.GRAY)
            anim_player.play("pulse")  # 呼吸动画提示玩家
        LocationState.Status.EXPLORED:
            visible = true
            sprite.texture = location_data.icon_explored
            label.add_theme_color_override("font_color", Color.GOLD)
            anim_player.stop()

func set_status(new_status: LocationState.Status) -> void:
    location_data.status = new_status
    update_visual()
    # 通知MapController更新迷雾
    MapController.on_location_status_changed(location_data)
```

---

## 六、迷雾系统实现

### 6.1 方案选择

| 方案 | 优点 | 缺点 | 选用 |
|------|------|------|------|
| **TileMapLayer瓦片擦除** | 与地图层一致、精确控制 | 大量瓦片时set_cell性能 | ✅ 选用 |
| Shader遮罩 | 平滑过渡、GPU高效 | 复杂区域难以精确控制 | ❌ |
| CanvasItem.clip_children | 简单 | 不支持渐变边缘 | ❌ |

### 6.2 迷雾瓦片实现

```gdscript
# fog_layer 是独立 TileMapLayer
# 初始状态：全地图覆盖迷雾瓦片
# 解锁时：擦除对应区域的迷雾瓦片

const FOG_TILE_SOURCE = 1    # 迷雾瓦片在TileSet中的source_id
const FOG_TILE_COORD = Vector2i(0, 0)  # 迷雾瓦片在图集中的坐标

func initialize_fog(case_region: CaseTileRegion) -> void:
    """初始化当前案件包围矩形的迷雾覆盖"""
    var bounding_tiles = case_region.get_bounding_tiles()
    for tile_coord in bounding_tiles:
        var cell = tile_coord_to_cell(tile_coord)
        fog_layer.set_cell(cell, FOG_TILE_SOURCE, FOG_TILE_COORD)
    
    # ⚠️ 性能注意：大包围矩形不要一帧全部绘制
    # 用 call_deferred 分帧初始化

func reveal_area(center: Vector2i, radius: int) -> void:
    """揭示以center为中心、radius为半径的区域"""
    for x in range(center.x - radius, center.x + radius + 1):
        for y in range(center.y - radius, center.y + radius + 1):
            var cell = Vector2i(x, y)
            if center.distance_to(cell) <= radius:
                fog_layer.erase_cell(cell)

func reveal_location(location: LocationState) -> void:
    """根据地点位置揭示周围区域"""
    # 地点坐标转瓦片坐标
    var tile_pos = base_map.local_to_map(location.map_position)
    reveal_area(tile_pos, 3)  # 揭示周围3格范围
```

### 6.3 迷雾瓦片设计

- **纹理**：半透明暖褐色（#5D4E37, alpha 0.7），泛黄做旧边缘
- **边缘处理**：使用TileSet自定义碰撞体或自定义数据标记边缘瓦片，实现渐变过渡
- **动画**：地点解锁时，迷雾擦除伴随fade-out动画（用Tween实现透明度渐变）

---

## 七、交互系统实现

### 7.1 触摸交互

```gdscript
# MapController.gd - 处理地图触摸交互

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            handle_tap(event.position)
    elif event is InputEventScreenDrag:
        if camera_configs[current_level].pan_enabled:
            handle_pan(event.relative)

func handle_tap(screen_pos: Vector2) -> void:
    # 检测是否点击了地点标记
    var world_pos = get_global_mouse_position()
    var clicked_marker = get_marker_at_position(world_pos)
    
    if clicked_marker:
        on_location_clicked(clicked_marker)
    else:
        # 点击空白区域，尝试平移地图
        pass

func on_location_clicked(marker: LocationMarker) -> void:
    match marker.location_data.status:
        LocationState.Status.HIDDEN:
            pass  # 不应该被点击到（隐藏状态不可见）
        LocationState.Status.MARKED:
            show_location_info(marker)  # 显示地点信息弹窗
        LocationState.Status.EXPLORED:
            enter_scene(marker)  # 进入场景

func enter_scene(marker: LocationMarker) -> void:
    # 过渡动画：地图淡出 → 场景淡入
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func():
        get_tree().change_scene_to_file(marker.location_data.scene_path)
    )
```

### 7.2 手势支持

| 手势 | 行为 | Godot实现 |
|------|------|-----------|
| 单指点击 | 选择地点/空地点击 | `InputEventScreenTouch` |
| 单指拖拽 | 平移地图 | `InputEventScreenDrag` + `Camera2D.position` |
| 双指捏合 | 缩放地图 | 两个touch的距离变化 → `Camera2D.zoom` |
| 双击 | 居中并放大到该位置 | 自定义逻辑 + Camera动画 |

---

## 八、相机系统

### 8.1 Camera2D配置

```gdscript
# Camera2D设置
camera = Camera2D.new()
camera.zoom = Vector2(1.0, 1.0)
camera.position_smoothing_enabled = true
camera.position_smoothing_speed = 5.0
camera.zoom_smoothing_enabled = true
camera.drag_horizontal_enabled = false  # 由脚本控制
camera.drag_vertical_enabled = false
camera.limit_left = 0
camera.limit_top = 0
camera.limit_right = MAP_WIDTH
camera.limit_bottom = MAP_HEIGHT
```

### 8.2 三层地图相机行为

```
任务地图:
┌─────────────────┐
│   Camera2D      │  zoom: 固定1.0
│   ┌───┐         │  position: 居中任务区域
│   │ 🎯│ ← 聚焦  │  pan: 禁止
│   └───┘         │  点击标记: 进入场景
└─────────────────┘

探索地图:
┌───────────────────────┐
│  ↕ 可自由平移          │  zoom: 0.5~2.0
│   🔍 🔍 🔍            │  position: 跟随拖拽
│   🏛️  🏠  ☕          │  pan: 允许
│       🎪              │  点击标记: 查看信息
└───────────────────────┘

完整地图:
┌─────────────────────────────────┐
│  ↕↔ 全范围平移+缩放              │  zoom: 0.3~3.0
│  🔍 🏛️ 🏠 ☕ 🎪 ⛪ 🏰 🌉 🗼    │  全地点可见
│                                 │  pan: 允许
└─────────────────────────────────┘
```

---

## 九、数据持久化

### 9.1 存档结构

```gdscript
class_name MapSaveData
extends Resource

# 地点状态字典：location_id → Status
@export var location_states: Dictionary = {}

# 已揭示的迷雾区域（瓦片坐标列表）
@export var revealed_tiles: PackedVector2Array = []

# 当前地图层级
@export var current_level: int = 0  # MapLevel.MISSION

# 地图相机位置
@export var camera_position: Vector2 = Vector2.ZERO
@export var camera_zoom: Vector2 = Vector2.ONE

func save_to_file(path: String) -> bool:
    return ResourceSaver.save(self, path) == OK

static func load_from_file(path: String) -> MapSaveData:
    if ResourceLoader.exists(path):
        return ResourceLoader.load(path) as MapSaveData
    return null
```

### 9.2 云端同步

游戏进度通过后端API同步：

```
本地存档（.tres）→ HTTPRequest → 后端服务器
                     ↑
本地加载 ← HTTPRequest ← 后端服务器
```

- **上传时机**：进入场景时、退出游戏时、案件完成时
- **下载时机**：首次登录、切换设备时
- **冲突策略**：以时间戳较新者为准

---

## 十、性能优化策略

### 10.1 瓦片渲染优化

| 优化项 | 方法 | 目标 |
|--------|------|------|
| 渲染器 | Compatibility (GLES3) | 覆盖最广Android设备 |
| 纹理压缩 | ASTC (Android 9+) / ETC2 (兼容) | 减少70%显存占用 |
| Mipmaps | 开启 | 缩放时平滑，避免马赛克 |
| Filter | 关闭 | 保持地图线条清晰锐利 |
| YSort | 不需要（俯视图无深度排序） | 减少排序开销 |

### 10.2 大地图分帧加载

```gdscript
func load_map_chunked(chunk_coords: Array[Vector2i], frames_between: int = 2) -> void:
    """分帧加载地图瓦片，避免一帧卡顿"""
    var idx = 0
    for coord in chunk_coords:
        if idx % 16 == 0:  # 每16个瓦片等一帧
            await get_tree().process_frame
        base_map.set_cell(coord, MAP_SOURCE, get_tile_atlas(coord))
        idx += 1
```

### 10.3 内存预算

| 设备级别 | 纹理内存上限 | 加载策略 |
|---------|-------------|---------|
| 低端（<3GB RAM）| 15MB | 单案件包围矩形（25~30格） |
| 中端（3-6GB）| 30MB | 双案件合并区域 |
| 高端（>6GB）| 50MB | 三案件以上合并区域 |

### 10.4 标记点优化

```gdscript
# 标记点仅在可视范围内更新
func _process(_delta: float) -> void:
    var visible_rect = get_viewport_rect()
    for marker in markers:
        marker.visible = visible_rect.has_point(marker.global_position)
        # 隐藏的标记不处理输入和动画
```

---

## 十一、迁移路线图

### Phase 1：基础框架（1-2周）

```
□ Godot项目初始化（Compatibility渲染器）
□ 1864年伦敦地图预处理（ImageMagick → 2的幂尺寸 → ASTC压缩）
□ TileSet创建（london_1864_tileset.tres）
□ 基础TileMapLayer绘制（中心区域）
□ Camera2D基础配置（缩放、平移、边界限制）
□ 触摸交互原型（单指拖拽、双指缩放）
```

### Phase 2：核心系统（2-3周）

```
□ 地点三态系统（LocationState + LocationMarker）
□ 迷雾系统（fog_layer + 区域揭示）
□ 三层地图切换（Mission/Explore/Full + 相机配置切换）
□ 地点标记交互（点击弹窗/进入场景）
□ 地图与场景系统的过渡动画
```

### Phase 3：数据持久化（1周）

```
□ 本地存档（MapSaveData → .tres文件）
□ 云端同步（HTTPRequest + 后端API）
□ 存档恢复（启动时加载 + 迷雾状态还原）
```

### Phase 4：优化与打磨（1-2周）

```
□ 大地图分块加载
□ 低端设备性能测试
□ 内存预算验证
□ 手势交互打磨（惯性滚动、弹性边界）
□ 迷雾渐变边缘效果
□ 地图解锁动画/音效
```

**预估总工期：5-8周**（一个人独立开发）

---

## 十二、与现有Web方案的兼容策略

### 12.1 数据层兼容

GDD中定义的TypeScript接口可以1:1映射到GDScript：

| TypeScript (GDD) | GDScript (Godot) |
|-------------------|-------------------|
| `interface Scene` | `class_name SceneState extends Resource` |
| `interface GameSave` | `class_name MapSaveData extends Resource` |
| `unlockedAreas: string[]` | `var unlocked_areas: PackedStringArray` |
| `currentCase: string` | `var current_case: String` |

### 12.2 后端API

Godot客户端（Web导出和原生移动端）通过HTTPClient + WebSocket与统一后端API通信：

```
用户 ←→ API网关 ── Godot客户端（Web导出 / 原生移动端）
```

- **统一后端**：Web端和移动端共用同一套后端API，保持数据一致性
- **游客模式**：本地临时缓存，不持久化到服务端
- **注册用户**：服务端持久化，跨平台同步

---

## 十三、风险与缓解

| 风险 | 严重度 | 缓解措施 |
|------|--------|---------|
| 地图纹理过大导致低端机OOM | 高 | 区域分块加载 + ASTC压缩 + 内存预算监控 |
| TileMapLayer大量set_cell卡顿 | 中 | 分帧加载 + call_deferred + 预渲染缓存 |
| 迷雾边缘不够平滑 | 中 | 使用ShaderMaterial实现边缘渐变，替代纯瓦片擦除 |
| 手势操作与UI冲突 | 低 | 输入优先级：UI > 地图手势 > 默认处理 |
| 缺少地图编辑工具 | 低 | 编写EditorPlugin脚本，批量导入瓦片数据 |

---

## 十四、来源

- [Godot 4.3+ TileMapLayer替代TileMap](https://qiita.com/Ziva/items/f21aa6d9ae8d15f1dfcb)（2026-04-13，TileMapLayer过程化地图生成）
- [Godot瓦片系统深度实践](https://blog.csdn.net/weizen_32285411/article/details/161279346)（2026-05-20，TileSet构建与性能优化）
- [Godot 4 vs Unity 2D性能对比](https://toxigon.com/godot-4-versus-unity-for-2d-game-development)（2026-04-28，200x200 TileMap 144FPS/180MB）
- [Godot 4.x移动端预加载清单](https://www.gamineai.com/blog/godot-4-x-resource-preloading-mobile-measurement-checklist-large-scenes-2026)（2026-04-25，移动端内存预算）
- [GDQuest: Godot 4存档系统](https://www.gdquest.com/library/cheatsheet_save_systems/)（2026-02-16，Resource序列化方案）
- [Godot论坛：大世界流式加载讨论](https://forum.godotengine.org/t/how-are-massive-open-world-games-actually-managed/136773)（2026-04-09，分块+LOD策略）
