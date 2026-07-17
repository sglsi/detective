# 维多利亚伦敦探案 — 前后端通信协议 v1.0

> **状态**: 已实施  
> **更新日期**: 2026-07-14  
> **适用版本**: Godot 4.7 客户端 ↔ Node.js Express 服务端

---

## 目录

1. [概述](#1-概述)
2. [基础约定](#2-基础约定)
3. [认证与授权](#3-认证与授权)
4. [API 端点清单](#4-api-端点清单)
5. [数据模型](#5-数据模型)
6. [错误码规范](#6-错误码规范)
7. [离线策略](#7-离线策略)
8. [安全策略](#8-安全策略)

---

## 1. 概述

### 1.1 架构

```
┌──────────────────┐       HTTP/JSON        ┌──────────────────┐
│   Godot 客户端    │ ◄───────────────────► │  Express API 服务 │
│  (GDScript)       │    RESTful API         │  (Node.js)        │
└────────┬─────────┘                         └────────┬─────────┘
         │                                            │
         │  本地 JSON 存档                             │  Supabase Client
         │  (游客模式)                                 │
         ▼                                            ▼
┌──────────────────┐                         ┌──────────────────┐
│  本地文件系统      │                         │  Supabase         │
│  user://save.json │                         │  PostgreSQL + Auth │
└──────────────────┘                         └──────────────────┘
```

### 1.2 设计原则

| 原则 | 说明 |
|------|------|
| **RESTful** | 标准 HTTP 方法，JSON 数据交换 |
| **无状态** | 每个请求携带完整认证信息（JWT Bearer Token） |
| **渐进增强** | 游客模式可用本地存档，注册后迁移到云端 |
| **离线优先** | 客户端维护请求队列，网络恢复后自动同步 |
| **幂等性** | 存档上传采用 upsert 策略，重复请求安全 |

---

## 2. 基础约定

### 2.1 基础 URL

| 环境 | URL |
|------|-----|
| 本地开发 | `http://localhost:3000` |
| 生产环境 | `https://api.sherlock-game.com`（待定） |

### 2.2 请求头

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <jwt_token>    # 需要认证的端点
X-Guest-ID: <uuid_v4>               # 游客模式
```

### 2.3 响应格式

**成功响应**:
```json
{
  "message": "操作描述",
  "data": { ... }
}
```

**错误响应**:
```json
{
  "error": "错误描述"
}
```

### 2.4 HTTP 状态码

| 状态码 | 含义 |
|--------|------|
| 200 | 成功 |
| 201 | 创建成功 |
| 400 | 请求参数错误 |
| 401 | 未认证 / token 过期 |
| 404 | 资源不存在 |
| 429 | 请求过于频繁 |
| 500 | 服务器内部错误 |

---

## 3. 认证与授权

### 3.1 认证流程

```
游客模式:  客户端 → POST /api/auth/guest → 获得 guest_id
注册流程:  客户端 → POST /api/auth/register → 创建用户
登录流程:  客户端 → POST /api/auth/login → 获得 JWT token
```

### 3.2 Token 管理

- **Token 类型**: Supabase Auth JWT
- **有效期**: 默认 1 小时（由 Supabase 控制）
- **刷新**: 使用 `refresh_token` 重新获取（预留接口）
- **客户端存储**: 内存变量 `APIManager.auth_token`，不持久化到磁盘

### 3.3 游客模式

- 游客通过 `X-Guest-ID` 请求头标识
- 游客数据仅保存在本地 `user://save_game.json`
- 注册后可通过迁移接口将本地存档上传到云端（预留）

---

## 4. API 端点清单

### 4.1 健康检查

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/health` | 否 | 服务器健康检查 |

**响应**:
```json
{
  "status": "ok",
  "timestamp": "2026-07-14T05:30:00Z",
  "version": "0.1.0",
  "endpoints": ["/api/health", "/api/auth", "/api/saves", "/api/progress"]
}
```

---

### 4.2 认证接口

#### POST /api/auth/register — 用户注册

**请求体**:
```json
{
  "email": "holmes@bakerstreet.com",
  "password": "221B_secure",
  "username": "夏洛克·福尔摩斯",
  "phone": "+44-xxxx-xxxxxx"
}
```

**响应** (201):
```json
{
  "message": "注册成功",
  "user": {
    "id": "uuid",
    "username": "夏洛克·福尔摩斯",
    "email": "holmes@bakerstreet.com"
  }
}
```

#### POST /api/auth/login — 用户登录

**请求体**:
```json
{
  "email": "holmes@bakerstreet.com",
  "password": "221B_secure"
}
```

**响应** (200):
```json
{
  "message": "登录成功",
  "token": "eyJhbGciOi...",
  "refresh_token": "xxx...",
  "user": {
    "id": "uuid",
    "username": "夏洛克·福尔摩斯",
    "email": "holmes@bakerstreet.com"
  }
}
```

#### POST /api/auth/guest — 创建游客会话

**响应** (200):
```json
{
  "message": "游客会话已创建",
  "guest_id": "550e8400-e29b-41d4-a716-446655440000",
  "expires_at": "2026-07-15T05:30:00Z",
  "note": "游客数据仅保存在本地，退出即清除。注册后可同步到云端。"
}
```

---

### 4.3 存档接口

#### GET /api/saves — 获取存档列表

**认证**: Bearer Token

**响应** (200):
```json
{
  "saves": [
    {
      "id": "uuid",
      "case_id": "case_study_in_scarlet",
      "scene_id": "scene_03_劳瑞斯顿花园",
      "difficulty": 1,
      "clue_count": 12,
      "updated_at": "2026-07-14T04:00:00Z"
    }
  ],
  "count": 1
}
```

#### GET /api/saves/latest — 获取最新存档

**认证**: Bearer Token  
**查询参数**: `?case_id=<case_id>`（可选）

**响应** (200):
```json
{
  "save": {
    "id": "uuid",
    "user_id": "uuid",
    "case_id": "case_study_in_scarlet",
    "save_version": 1,
    "scene_id": "scene_03_劳瑞斯顿花园",
    "difficulty": 1,
    "clue_count": 12,
    "observation_score": 8,
    "reasoning_score": 6,
    "insight_score": 4,
    "unlocked_locations": ["贝克街221B", "劳瑞斯顿花园", "苏格兰场"],
    "completed_milestones": ["tutorial_complete", "first_clue_found"],
    "dialogue_progress": { "scene_01": 15, "scene_02": 8 },
    "clue_states": { "clue_001": "ANALYZED", "clue_002": "DISCOVERED" },
    "game_time": 3600,
    "metadata": { "version": "0.1.0", "platform": "Android" },
    "created_at": "2026-07-14T03:00:00Z",
    "updated_at": "2026-07-14T04:00:00Z"
  }
}
```

**404 响应**（无存档）:
```json
{
  "error": "没有找到存档"
}
```

#### POST /api/saves — 上传存档

**认证**: Bearer Token  
**策略**: M1 覆盖（同一用户+同一案件，upsert 最新）

**请求体**:
```json
{
  "case_id": "case_study_in_scarlet",
  "save_version": 1,
  "scene_id": "scene_03_劳瑞斯顿花园",
  "difficulty": 1,
  "clue_count": 15,
  "observation_score": 9,
  "reasoning_score": 7,
  "insight_score": 5,
  "unlocked_locations": ["贝克街221B", "劳瑞斯顿花园", "苏格兰场"],
  "completed_milestones": ["tutorial_complete", "first_clue_found"],
  "dialogue_progress": { "scene_01": 20, "scene_02": 12 },
  "clue_states": { "clue_001": "LINKED", "clue_002": "ANALYZED" },
  "game_time": 4200,
  "metadata": { "version": "0.1.0", "platform": "Android" }
}
```

**响应** (200):
```json
{
  "message": "存档已同步",
  "save_id": "uuid",
  "updated_at": "2026-07-14T05:00:00Z"
}
```

---

### 4.4 案件进度接口

#### GET /api/progress — 获取所有案件进度

**认证**: Bearer Token

**响应** (200):
```json
{
  "progress": [
    {
      "case_id": "case_study_in_scarlet",
      "status": "in_progress",
      "observation_stars": 4,
      "reasoning_stars": 3,
      "insight_stars": 2,
      "badges_earned": ["FIRST_CLUE", "KEEN_EYE"],
      "completed_at": null
    }
  ]
}
```

#### GET /api/progress/:caseId — 获取指定案件进度

**认证**: Bearer Token

**响应** (200):
```json
{
  "progress": {
    "case_id": "case_study_in_scarlet",
    "user_id": "uuid",
    "status": "in_progress",
    "scenes_completed": ["scene_01", "scene_02"],
    "clues_found": 15,
    "clues_total": 45,
    "observation_stars": 4,
    "reasoning_stars": 3,
    "insight_stars": 2,
    "badges_earned": ["FIRST_CLUE", "KEEN_EYE"],
    "started_at": "2026-07-14T03:00:00Z",
    "completed_at": null,
    "updated_at": "2026-07-14T05:00:00Z"
  }
}
```

**未开始案件的响应**:
```json
{
  "progress": {
    "case_id": "case_study_in_scarlet",
    "status": "not_started",
    "scenes_completed": [],
    "clues_found": 0,
    "clues_total": 0
  }
}
```

#### PUT /api/progress/:caseId — 更新案件进度

**认证**: Bearer Token

**请求体**（部分更新）:
```json
{
  "status": "in_progress",
  "scenes_completed": ["scene_01", "scene_02"],
  "clues_found": 15,
  "observation_stars": 4
}
```

**响应** (200):
```json
{
  "message": "进度已更新",
  "progress": { ... }
}
```

---

## 5. 数据模型

### 5.1 profiles — 用户档案

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID (PK) | 关联 Supabase Auth |
| username | VARCHAR(50) | 用户名 |
| email | VARCHAR(255) | 邮箱 |
| phone | VARCHAR(30) | 手机号（可选） |
| is_guest | BOOLEAN | 是否游客 |
| created_at | TIMESTAMPTZ | 创建时间 |

### 5.2 game_saves — 游戏存档

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID (PK) | 存档ID |
| user_id | UUID (FK) | 关联 profiles |
| case_id | VARCHAR(100) | 案件标识 |
| save_version | INTEGER | 存档格式版本 |
| scene_id | VARCHAR(100) | 当前场景 |
| difficulty | INTEGER | 难度 (0=EASY,1=NORMAL,2=HARD) |
| clue_count | INTEGER | 已发现线索数 |
| observation_score | INTEGER | 观察评分 |
| reasoning_score | INTEGER | 推理评分 |
| insight_score | INTEGER | 洞察评分 |
| unlocked_locations | JSONB | 已解锁地点列表 |
| completed_milestones | JSONB | 已完成里程碑 |
| dialogue_progress | JSONB | 对话进度 |
| clue_states | JSONB | 线索状态映射 |
| game_time | INTEGER | 游戏时长（秒） |
| metadata | JSONB | 扩展元数据 |
| created_at | TIMESTAMPTZ | 创建时间 |
| updated_at | TIMESTAMPTZ | 更新时间（自动） |

### 5.3 case_progress — 案件进度

| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | UUID (FK) | 关联 profiles |
| case_id | VARCHAR(100) | 案件标识 |
| status | VARCHAR(20) | not_started/in_progress/completed |
| scenes_completed | JSONB | 已完成场景列表 |
| clues_found | INTEGER | 已发现线索数 |
| clues_total | INTEGER | 总线索数 |
| observation_stars | INTEGER | 观察星级 |
| reasoning_stars | INTEGER | 推理星级 |
| insight_stars | INTEGER | 洞察星级 |
| badges_earned | JSONB | 已获得徽章 |
| started_at | TIMESTAMPTZ | 开始时间 |
| completed_at | TIMESTAMPTZ | 完成时间 |
| updated_at | TIMESTAMPTZ | 更新时间（自动） |

**联合主键**: `(user_id, case_id)`

---

## 6. 错误码规范

### 6.1 应用层错误

| 错误信息 | HTTP 状态码 | 说明 |
|----------|------------|------|
| `邮箱和密码为必填项` | 400 | 参数缺失 |
| `缺少 case_id` | 400 | 必需参数缺失 |
| `未提供认证令牌` | 401 | 缺少 Authorization 头 |
| `认证令牌无效或已过期` | 401 | JWT 验证失败 |
| `邮箱或密码错误` | 401 | 凭据不匹配 |
| `没有找到存档` | 404 | 指定资源不存在 |
| `请求过于频繁，请稍后再试` | 429 | 触发速率限制 |
| `服务器内部错误` | 500 | 未预期的错误 |

### 6.2 客户端错误处理流程

```
请求发送 → 超时?(15s) → 是 → 重试(最多2次) → 仍失败 → 离线队列
                    → 否 → 解析响应 → 401? → emit auth_expired
                                     → 5xx? → 离线队列
                                     → 4xx? → 显示错误
                                     → 2xx → 处理成功
```

---

## 7. 离线策略

### 7.1 客户端离线队列

```
┌──────────────────────────────────────┐
│         APIManager.pending_requests   │
│                                      │
│  [{type: "upload_save", data, ts}]   │
│  [{type: "update_progress", data, ts}]│
│  ...                                 │
└──────────────────────────────────────┘
         │
         │ 网络恢复
         ▼
  flush_pending() → 逐条发送 → 成功的移除
                              → 失败的重新入队
```

### 7.2 离线行为

| 操作 | 在线 | 离线 |
|------|------|------|
| 注册 | 调用 API | 入队，网络恢复后发送 |
| 登录 | 调用 API | 显示"网络不可用" |
| 存档（游客） | 写入本地 JSON | 写入本地 JSON |
| 存档（注册用户） | 上传 Supabase + 本地缓存 | 写入本地 + 入队 |
| 读档（游客） | 读取本地 JSON | 读取本地 JSON |
| 读档（注册用户） | 从 Supabase 下载 | 读取本地缓存 |
| 进度更新 | 调用 API | 入队 |

### 7.3 冲突解决

- **M1 策略**: 同一案件只保留最新存档，时间戳为准
- **M2+ 策略**: 案件级合并，保留最佳评分（预留）

---

## 8. 安全策略

### 8.1 传输安全

- 生产环境强制 HTTPS
- JWT token 通过 Authorization 头传输
- 敏感数据（密码）仅在请求体中出现，不缓存

### 8.2 服务端防护

| 措施 | 实现 |
|------|------|
| HTTP 安全头 | helmet 中间件 |
| CORS | 仅允许 Godot 客户端域名 |
| 速率限制 | 15 分钟 200 次/ IP |
| 请求体限制 | 最大 1MB |
| 日志脱敏 | 不记录密码等敏感字段 |

### 8.3 数据库安全

- Supabase Row Level Security (RLS)
- 用户只能访问自己的数据
- Service Key 仅服务端使用，不暴露给客户端

---

## 附录 A: Godot 客户端调用示例

```gdscript
# 登录
var result = await APIManager.login_user("holmes@bakerstreet.com", "221B_secure")
if not result.get("error", true):
    print("登录成功: ", result["data"]["user"]["username"])

# 上传存档
var save_data = {
    "case_id": "case_study_in_scarlet",
    "scene_id": "scene_03",
    "difficulty": 1,
    "clue_count": 15,
}
var result = await APIManager.upload_save(save_data)

# 获取案件进度
var progress = await APIManager.get_case_progress("case_study_in_scarlet")
```

## 附录 B: curl 测试示例

```bash
# 健康检查
curl http://localhost:3000/api/health

# 创建游客会话
curl -X POST http://localhost:3000/api/auth/guest

# 注册
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123","username":"测试用户"}'

# 登录
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# 上传存档（需要 token）
curl -X POST http://localhost:3000/api/saves \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"case_id":"case_001","scene_id":"scene_01","difficulty":1}'
```
