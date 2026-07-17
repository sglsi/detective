# 维多利亚伦敦探案 — 前后端架构连接总览 v1.0

> **目的**: 将设计文档中的七层架构与已实现的前后端代码建立精确对应关系  
> **最后更新**: 2026-07-14  
> **关联文档**: `00_标准化开发目录.md`, `08_系统框架设计.md`, `E-25_技术架构专项文档.md`, `communication_protocol.md`

---

## 目录

1. [架构全景图](#1-架构全景图)
2. [七层架构 → 代码映射](#2-七层架构--代码映射)
3. [数据流路径](#3-数据流路径)
4. [启动链路](#4-启动链路)
5. [实现状态矩阵](#5-实现状态矩阵)
6. [设计文档 → 代码追溯表](#6-设计文档--代码追溯表)

---

## 1. 架构全景图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          跨平台发布层 (第 7 层)                               │
│     Web (HTML5) ─────────────── 统一后端 API ────────────── Mobile (原生)     │
│     web_prototype/index.html    backend/                    Godot 导出预设    │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │ HTTPS / JWT
┌────────────────────────────────────┴────────────────────────────────────────┐
│                          网络与认证层 (第 6 层)                               │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │  AuthManager.gd │  │  APIManager.gd   │  │  Express API (:3000)     │   │
│  │  GUEST→LOGGED_IN│  │  HTTP + 离线队列  │  │  auth/saves/progress     │   │
│  └────────┬────────┘  └────────┬─────────┘  └───────────┬──────────────┘   │
│           │                    │                         │                   │
│           └────────────────────┼─────────────────────────┘                   │
│                                │ Supabase Client                             │
│                                ▼                                             │
│                    ┌──────────────────────────┐                             │
│                    │  Supabase                │                             │
│                    │  Auth + PostgreSQL + RLS │                             │
│                    │  5 tables / 自动触发器    │                             │
│                    └──────────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │ 事件总线 (7 buses)
┌────────────────────────────────────┴────────────────────────────────────────┐
│                              UI 层 (第 5 层)                                 │
│  UIManager ─ ScreenManager ─ TopBar ─ SidePanel ─ Notification              │
│  main_menu.gd  screen_manager.gd  top_bar.gd  side_panel.gd  notification.gd│
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
┌────────────────────────────────────┴────────────────────────────────────────┐
│                            地图 层 (第 4 层)                                 │
│  MapScene ─ TileRegionManager ─ FogSystem ─ LocationMarkerSystem            │
│  (M2+ 阶段实现)                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
┌────────────────────────────────────┴────────────────────────────────────────┐
│                          游戏逻辑层 (第 3 层)                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ GameManager  │ │ CaseManager  │ │SceneController│ │DialogueSystem│       │
│  │ 状态机+同步   │ │ 案件生命周期  │ │ 六步探索闭环  │ │ 对话树+分支   │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ ClueSystem   │ │  ToolSystem  │ │StarRatingSys │ │DifficultyMgr │       │
│  │ 45线索+5状态  │ │ 放大镜/卷尺   │ │ 3D评分+7徽章  │ │ EASY/NORMAL/HARD│    │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│                                                                             │
│              7 个事件总线 (Case/Scene/Dialogue/Clue/UI/Map/System)           │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
┌────────────────────────────────────┴────────────────────────────────────────┐
│                           数据层 (第 2 层)                                    │
│  SaveManager ─ ResourceManager ─ DataLoader ─ ConfigManager                 │
│  save_manager.gd   (M2+)           (M2+)       api_config.gd                │
│  本地JSON+云端同步                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
┌────────────────────────────────────┴────────────────────────────────────────┐
│                          引擎层 (第 1 层)                                     │
│  Godot 4.7 ─ GDScript ─ Compatibility (GLES3) ─ 1920×1080 ─ 60 FPS         │
│  project.godot  boot.gd  env_checker.gd                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 七层架构 → 代码映射

### 第 1 层: 引擎层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| Godot 4.7 版本锁定 (ADR-#1) | `project.godot` § config_version=5 | ✅ 已实现 |
| Compatibility (GLES3) 渲染管线 (ADR-#2) | `project.godot` § renderer/rendering_method | ✅ 已实现 |
| GDScript 脚本语言 (ADR-#3) | 全部 `.gd` 文件 | ✅ 已实现 |
| 1920×1080 分辨率 | `project.godot` § display/window/size | ✅ 已实现 |
| 60 FPS 物理帧率 | `project.godot` § physics/common | ✅ 已实现 |
| 环境检查 | `autoload/boot.gd` § _phase_1_engine_check | ✅ 已实现 |
| 环境验证 | `autoload/env_checker.gd` | ✅ 已实现 |

### 第 2 层: 数据层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| SaveManager (本地+云端) | `autoload/save_manager.gd` | ✅ 已实现 |
| 存档格式版本控制 (save_version=1) | `save_manager.gd` § save_version | ✅ 已实现 |
| 游客本地 JSON 存储 | `save_manager.gd` § _save_local | ✅ 已实现 |
| 注册用户云端同步 | `save_manager.gd` § _save_to_server | ✅ 已实现 |
| 设置持久化 | `autoload/settings_manager.gd` | ✅ 已实现 |
| ResourceManager / DataLoader | — | ⏳ M2+ 阶段 |
| ConfigManager | `config/api_config.gd` | ✅ 已实现 |
| 数据格式分层 (Resource > JSON) | — | ⏳ M2+ 阶段 |

### 第 3 层: 游戏逻辑层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| GameManager 五态状态机 | `autoload/game_manager.gd` § GameState | ✅ 已实现 |
| CaseManager 案件生命周期 | `autoload/case_manager.gd` | ✅ 已实现 |
| SceneController 六步探索闭环 | `scripts/scene/scene_controller.gd` | ✅ 已实现 |
| HotspotArea 热点交互 | `scripts/scene/hotspot_area.gd` | ✅ 已实现 |
| DialogueSystem 对话树 | `scripts/dialogue/dialogue_manager.gd` | ✅ 已实现 |
| DialogueRenderer 打字机效果 | `scripts/dialogue/dialogue_renderer.gd` | ✅ 已实现 |
| ClueSystem 45 线索/5 状态机 | `autoload/clue_system.gd` | ✅ 已实现 |
| ToolSystem 放大镜/卷尺 | `scripts/tool/tool_bar.gd` | ✅ 已实现 |
| StarRatingSystem 3D 评价+7 徽章 | `autoload/star_rating_system.gd` | ✅ 已实现 |
| DifficultyManager 三档难度 | `autoload/difficulty_manager.gd` | ✅ 已实现 |
| 推理墙 ReasoningWall | `scripts/clue/reasoning_wall_ui.gd` | ✅ 已实现 |
| 7 个领域事件总线 | `autoload/*_event_bus.gd` × 7 | ✅ 已实现 |

### 第 4 层: 地图层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| MapScene 地图主场景 | — | ⏳ M2+ 阶段 |
| TileRegionManager 区域管理 | — | ⏳ M2+ 阶段 |
| FogSystem 战争迷雾 | — | ⏳ M2+ 阶段 |
| LocationMarkerSystem 地点标记 | — | ⏳ M2+ 阶段 |

### 第 5 层: UI 层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| UIManager 12 屏界面栈 | `autoload/ui_manager.gd` | ✅ 已实现 |
| ScreenManager 场景转场 | `scripts/ui/screen_manager.gd` | ✅ 已实现 |
| 主菜单 | `scripts/ui/main_menu.gd` + `scenes/main_menu.tscn` | ✅ 已实现 |
| TopBar 顶部状态栏 | `scripts/ui/top_bar.gd` | ✅ 已实现 |
| SidePanel 侧边导航 | `scripts/ui/side_panel.gd` | ✅ 已实现 |
| Notification 浮动通知 | `scripts/ui/notification.gd` | ✅ 已实现 |
| GameScene 游戏主场景 | `scripts/scene/game_scene.gd` + `scenes/game_scene.tscn` | ✅ 已实现 |
| ThemeManager 主题管理 | — | ⏳ M2+ 阶段 |
| AnimationController | — | ⏳ M2+ 阶段 |

### 第 6 层: 网络与认证层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| APIManager HTTP 请求封装 | `autoload/api_manager.gd` | ✅ 已实现 |
| APIManager 离线队列 | `api_manager.gd` § pending_requests | ✅ 已实现 |
| APIManager 超时重试 | `api_manager.gd` § _wait_for_response | ✅ 已实现 |
| AuthManager GUEST→LOGGED_IN | `autoload/auth_manager.gd` | ✅ 已实现 |
| AuthManager 注册/登录/游客 | `auth_manager.gd` § register/login/create_guest | ✅ 已实现 |
| JWT Token 管理 | `api_manager.gd` § auth_token | ✅ 已实现 |
| Express API 服务器 | `backend/src/server.js` | ✅ 已实现 |
| /api/auth/* 端点 | `backend/src/routes/auth.js` | ✅ 已实现 |
| /api/saves/* 端点 | `backend/src/routes/saves.js` | ✅ 已实现 |
| /api/progress/* 端点 | `backend/src/routes/progress.js` | ✅ 已实现 |
| JWT 中间件 | `backend/src/middleware/auth.js` | ✅ 已实现 |
| Supabase 客户端 | `backend/src/db/supabase.js` | ✅ 已实现 |
| 数据库 Schema (5 表) | `backend/migrations/001_initial_schema.sql` | ✅ 已实现 |
| RLS 安全策略 | `001_initial_schema.sql` § RLS policies | ✅ 已实现 |
| SyncManager 同步管理器 | — | ⏳ M2+ 阶段 |
| CacheManager 缓存管理器 | — | ⏳ M2+ 阶段 |
| WebSocket 实时通信 | — | ⏳ M2+ 阶段 |

### 第 7 层: 跨平台发布层

| 设计文档描述 | 实现文件 | 状态 |
|-------------|---------|------|
| Web 原型 (手机验证) | `web_prototype/index.html` | ✅ 已实现 |
| Godot HTML5 导出预设 | — | ⏳ M2+ 阶段 |
| Android AAB 导出 | — | ⏳ M3+ 阶段 |
| iOS IPA 导出 | — | ⏳ M3+ 阶段 |
| CDN 分发 (EdgeOne/Cloudflare) | — | ⏳ 发布阶段 |

---

## 3. 数据流路径

### 3.1 玩家操作 → 线索发现 (完整链路)

```
玩家点击热点
    │
    ▼
hotspot_area.gd — InputEvent
    │
    ▼
scene_controller.gd — on_hotspot_clicked(id)
    │
    ▼
SceneEventBus — emit("hotspot_clicked", {id, pos})
    │
    ▼
ClueSystem — mark_discovered(clue_id)
    │  ├─ ClueState: UNDISCOVERED → DISCOVERED
    │  └─ clue_count += 1
    │
    ▼
ClueEventBus — emit("clue_discovered", {id, case_id})
    │
    ├─► StarRatingSystem — add_observation(10)
    │
    ├─► UIManager — play_animation("clue_collected")
    │       └─ Notification — "新线索发现！"
    │
    ├─► SaveManager — schedule_save()
    │       ├─ [游客] _save_local() → user://save_game.json
    │       └─ [注册用户] _save_to_server() → APIManager.upload_save()
    │               └─ POST /api/saves → Supabase game_saves
    │
    └─► GameManager — _sync_cloud_data()
            └─ PUT /api/progress/:caseId → Supabase case_progress
```

### 3.2 用户认证 → 云端同步 (完整链路)

```
用户登录
    │
    ▼
AuthManager.login(email, password)
    │
    ▼
APIManager.login_user(email, password)
    │  └─ POST /api/auth/login → Supabase Auth
    │       └─ 返回 JWT token
    │
    ▼
AuthManager._on_login_success(data)
    ├─ auth_token 保存
    ├─ AuthState → LOGGED_IN
    └─ SystemEventBus → emit("user_logged_in")
        │
        ▼
Boot._on_user_logged_in()
    │
    ▼
GameManager._sync_cloud_data()
    ├─ SaveManager.load_game() → GET /api/saves/latest
    └─ APIManager.get_all_progress() → GET /api/progress
```

### 3.3 离线降级 (完整链路)

```
网络断开
    │
    ▼
APIManager._check_connectivity() → is_online = false
    │
    ▼
APIManager.connectivity_changed.emit(false)
    │
    ├─► GameManager._on_connectivity_changed(false)
    │       └─ SystemEventBus → emit("network_offline")
    │
    ├─► SaveManager._on_connectivity_changed(false)
    │       └─ 存档切换为仅本地模式
    │
    └─► Boot._on_connectivity_changed(false)
            └─ 日志记录
    │
    ▼
用户操作触发存档
    │
    ▼
SaveManager._save_to_server()
    ├─ 检测 is_online == false
    ├─ _save_local() → 本地 JSON
    └─ APIManager._queue_request("upload_save", data)
            └─ pending_requests.append(...)
    │
    ▼
... 时间推移 ...
    │
    ▼
网络恢复 → APIManager._check_connectivity() → is_online = true
    │
    ▼
APIManager.flush_pending()
    ├─ 遍历 pending_requests
    ├─ 逐条 POST /api/saves
    ├─ 成功的移除
    └─ 失败的重新入队
```

---

## 4. 启动链路

### 4.1 完整启动流程

```
project.godot → run/main_scene="res://scenes/boot.tscn"
    │
    ▼
boot.gd → _ready()
    │
    ├─[1] _phase_1_engine_check()      # 引擎层
    │   ├─ 版本锁定 (Godot 4.4+)
    │   ├─ 渲染器检查 (GLES3)
    │   └─ 目录/配置完整性
    │
    ├─[2] _phase_2_data_init()          # 数据层
    │   ├─ SettingsManager._load_settings()
    │   └─ AudioServer 总线初始化
    │
    ├─[3] _phase_3_event_binding()      # 事件层
    │   ├─ 7 个事件总线存在性检查
    │   └─ 跨层信号连接 (System/Case/Scene/...)
    │
    ├─[4] _phase_4_network_init()       # 网络层
    │   ├─ APIConfig.get_base_url()
    │   ├─ APIManager 参数配置
    │   └─ 连通性检查 (异步)
    │
    ├─[5] _phase_5_auth_check()         # 认证层
    │   ├─ AuthManager 状态初始化
    │   └─ 游客会话创建 (异步)
    │
    ├─[6] _phase_6_save_check()         # 存档层
    │   ├─ 本地存档检查
    │   └─ GameManager.has_existing_save
    │
    ├─[7] _phase_7_ui_launch()          # UI 层
    │   ├─ GameState → MAIN_MENU
    │   └─ change_scene → main_menu.tscn
    │
    └─ _phase_complete()
        ├─ 计时输出
        ├─ SystemEventBus → "boot_complete"
        └─ FrameworkTest → run_all_tests()
```

### 4.2 Autoload 加载顺序 (project.godot)

| 序号 | 名称 | 层级 | 依赖 |
|------|------|------|------|
| 1 | Boot | 启动器 | 无 |
| 2-8 | 7 个 EventBus | 事件层 | 无 |
| 9 | GameManager | 逻辑层 | EventBuses |
| 10 | CaseManager | 逻辑层 | GameManager |
| 11 | DifficultyManager | 逻辑层 | 无 |
| 12 | ClueSystem | 逻辑层 | EventBuses |
| 13 | StarRatingSystem | 逻辑层 | 无 |
| 14 | SaveManager | 数据层 | GameManager, APIManager |
| 15 | AuthManager | 网络层 | APIManager |
| 16 | APIManager | 网络层 | APIConfig |
| 17 | APIConfig | 配置 | 无 |
| 18 | UIManager | UI 层 | EventBuses |
| 19 | SettingsManager | 数据层 | 无 |
| 20 | AudioManager | 音频 | SettingsManager |
| 21 | FrameworkTest | 测试 | 全部 |

---

## 5. 实现状态矩阵

### 5.1 总体进度

| 架构层 | 设计子系统数 | 已实现 | 进度 |
|--------|------------|--------|------|
| 引擎层 (1) | 7 | 7 | ████████████ 100% |
| 数据层 (2) | 6 | 4 | ████████░░░░ 67% |
| 逻辑层 (3) | 12 | 12 | ████████████ 100% |
| 地图层 (4) | 4 | 0 | ░░░░░░░░░░░░ 0% |
| UI 层 (5) | 9 | 7 | █████████░░░ 78% |
| 网络层 (6) | 17 | 15 | ██████████░░ 88% |
| 发布层 (7) | 5 | 1 | ██░░░░░░░░░░ 20% |
| **总计** | **60** | **46** | █████████░░░ **77%** |

### 5.2 各层详细状态

#### 引擎层 — ✅ 100% 完成

```
✅ Godot 4.7 版本锁定        → project.godot
✅ Compatibility 渲染管线     → project.godot
✅ GDScript 脚本语言          → 全部 .gd 文件
✅ 1920×1080 分辨率           → project.godot
✅ 60 FPS                    → project.godot
✅ 环境检查                   → boot.gd
✅ 环境验证                   → env_checker.gd
```

#### 数据层 — ⚠️ 67% 完成

```
✅ SaveManager (本地+云端)    → save_manager.gd
✅ 设置持久化                 → settings_manager.gd
✅ ConfigManager              → api_config.gd
✅ 存档格式版本控制           → save_manager.gd
⏳ ResourceManager           → M2+ 阶段
⏳ DataLoader                → M2+ 阶段
```

#### 逻辑层 — ✅ 100% 完成

```
✅ GameManager 状态机         → game_manager.gd
✅ CaseManager               → case_manager.gd
✅ SceneController 六步闭环   → scene_controller.gd
✅ HotspotArea 热点交互       → hotspot_area.gd
✅ DialogueSystem 对话树      → dialogue_manager.gd
✅ DialogueRenderer 打字机    → dialogue_renderer.gd
✅ ClueSystem 线索管理        → clue_system.gd
✅ ToolSystem 工具系统         → tool_bar.gd
✅ StarRatingSystem 评价      → star_rating_system.gd
✅ DifficultyManager 难度     → difficulty_manager.gd
✅ ReasoningWall 推理墙       → reasoning_wall_ui.gd
✅ 7 个事件总线               → *_event_bus.gd
```

#### 网络层 — ⚠️ 88% 完成

```
✅ APIManager HTTP 封装       → api_manager.gd
✅ 离线队列                    → api_manager.gd
✅ 超时重试                    → api_manager.gd
✅ AuthManager 认证流程        → auth_manager.gd
✅ JWT Token 管理             → api_manager.gd
✅ Express API 服务器          → backend/src/server.js
✅ /api/auth/* 端点           → backend/src/routes/auth.js
✅ /api/saves/* 端点          → backend/src/routes/saves.js
✅ /api/progress/* 端点       → backend/src/routes/progress.js
✅ JWT 中间件                  → backend/src/middleware/auth.js
✅ Supabase 客户端             → backend/src/db/supabase.js
✅ 数据库 Schema (5 表)        → backend/migrations/001_initial_schema.sql
✅ RLS 安全策略                → 001_initial_schema.sql
✅ 通信协议文档                → communication_protocol.md
✅ 联调指南                    → integration_guide.md
⏳ SyncManager               → M2+ 阶段
⏳ CacheManager              → M2+ 阶段
```

---

## 6. 设计文档 → 代码追溯表

### 6.1 设计文档章节 → 实现代码

| 设计文档 | 章节 | 实现文件 | 行数/方法 |
|---------|------|---------|----------|
| `08_系统框架设计.md` | §1.1 分层架构总览 | `ARCHITECTURE_CONNECTION.md` (本文档) | 全文 |
| `08_系统框架设计.md` | §1.3 核心单例 Autoload | `project.godot` § [autoload] | 20 项 |
| `08_系统框架设计.md` | §2.1 Godot 项目配置 | `project.godot` | 1-66 行 |
| `08_系统框架设计.md` | §2.2 目录结构 | `godot_project/` 目录树 | — |
| `08_系统框架设计.md` | §3.x 游戏逻辑层 | `autoload/game_manager.gd` 等 | — |
| `E-25_技术架构.md` | §2.1 引擎版本锁定 | `boot.gd` § _phase_1_engine_check | 54-69 行 |
| `E-25_技术架构.md` | §2.3 渲染管线选型 | `project.godot` § rendering | 12-14 行 |
| `E-25_技术架构.md` | §4.3 事件总线 7 总线 | `autoload/*_event_bus.gd` × 7 | 各文件 |
| `E-25_技术架构.md` | §4.4 Autoload 注册顺序 | `project.godot` § [autoload] | 26-46 行 |
| `E-25_技术架构.md` | §4.5 模块依赖图 | 本文档 §4.2 | — |
| `E-25_技术架构.md` | §5.1 整体数据流 | 本文档 §3.1-3.3 | — |
| `E-25_技术架构.md` | §5.2 三大核心状态机 | `game_manager.gd` + `dialogue_manager.gd` + `scene_controller.gd` | — |
| `E-25_技术架构.md` | §6.1 Supabase 选型 | `backend/src/db/supabase.js` | 全文 |
| `E-25_技术架构.md` | §6.2 数据模型 | `backend/migrations/001_initial_schema.sql` | 全文 |
| `E-25_技术架构.md` | §6.3 同步策略 | `save_manager.gd` § M1 覆盖策略 | 63-101 行 |
| `E-25_技术架构.md` | §6.4 网络请求规范 | `api_manager.gd` § HTTP 请求核心 | 61-160 行 |
| `00_标准化开发目录.md` | §A-1.2 核心目标 | `scene_controller.gd` 六步闭环 | 全文 |
| `00_标准化开发目录.md` | §E-25 技术架构 | 本文档 (架构连接) | 全文 |

### 6.2 代码 → 设计文档追溯

| 代码文件 | 对应设计文档 | 对应章节 |
|---------|------------|---------|
| `autoload/boot.gd` | `E-25_技术架构.md` | §4.4, §5.1 |
| `autoload/game_manager.gd` | `08_系统框架设计.md` | §3.x, §5.2.1 |
| `autoload/api_manager.gd` | `E-25_技术架构.md` | §6.4, communication_protocol.md |
| `autoload/auth_manager.gd` | `E-25_技术架构.md` | §6.1, communication_protocol.md §3 |
| `autoload/save_manager.gd` | `E-25_技术架构.md` | §6.3, communication_protocol.md §4.3 |
| `config/api_config.gd` | `E-25_技术架构.md` | §2.5, communication_protocol.md §2 |
| `backend/src/server.js` | `E-25_技术架构.md` | §6.4, communication_protocol.md §1 |
| `backend/migrations/001_initial_schema.sql` | `E-25_技术架构.md` | §6.2 |

---

## 附录: 快速命令

```bash
# 启动完整开发环境
./start_all.sh

# 仅启动后端
./start_backend.sh

# 运行后端 API 测试
cd backend && npm test

# 启动 Web 原型 (手机验证)
cd web_prototype && python3 -m http.server 8080

# 验证健康检查
curl http://localhost:3000/api/health

# 完整 API 联调测试
curl -X POST http://localhost:3000/api/auth/guest
```
