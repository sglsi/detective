# 维多利亚伦敦探案 — 前后端联调指南 v1.0

> **最后更新**: 2026-07-14  
> **适用版本**: Godot 4.7 客户端 + Node.js Express 后端

---

## 目录

1. [环境准备](#1-环境准备)
2. [快速启动](#2-快速启动)
3. [联调验证](#3-联调验证)
4. [常见问题](#4-常见问题)
5. [开发工作流](#5-开发工作流)
6. [部署清单](#6-部署清单)

---

## 1. 环境准备

### 1.1 必需软件

| 软件 | 版本要求 | 用途 |
|------|---------|------|
| Node.js | >= 18.x | 后端 API 服务器 |
| Godot Engine | 4.7 | 游戏客户端 |
| npm | >= 9.x | 包管理 |
| Supabase 项目 | — | 数据库 + 认证 |

### 1.2 项目结构

```
维多利亚伦敦探案项目/
├── godot_project/          # Godot 客户端
│   ├── autoload/
│   │   ├── api_manager.gd      # 网络层核心
│   │   ├── auth_manager.gd     # 认证管理
│   │   └── save_manager.gd     # 存档管理
│   ├── config/
│   │   └── api_config.gd       # 网络配置
│   └── tests/
│       └── test_api_integration.gd  # Godot 端集成测试
├── backend/                # Node.js 后端
│   ├── src/
│   │   ├── server.js           # 服务入口
│   │   ├── routes/             # API 路由
│   │   ├── middleware/         # 中间件
│   │   └── db/                 # 数据库
│   ├── tests/
│   │   └── api_test.js         # 后端 API 测试
│   └── docs/
│       ├── communication_protocol.md  # 通信协议
│       └── integration_guide.md       # 本文档
├── start_backend.sh         # 后端启动脚本
└── start_all.sh             # 一键启动脚本
```

### 1.3 后端配置

```bash
# 进入后端目录
cd backend

# 从模板创建 .env
cp .env.example .env

# 编辑 .env，填入 Supabase 凭据
# SUPABASE_URL=https://xxxxx.supabase.co
# SUPABASE_SERVICE_KEY=eyJhbGciOi...
# SUPABASE_ANON_KEY=eyJhbGciOi...
# JWT_SECRET=your-jwt-secret
# PORT=3000
```

---

## 2. 快速启动

### 2.1 一键启动（推荐）

```bash
# 同时启动后端 API + Web 原型
./start_all.sh
```

### 2.2 分别启动

```bash
# 终端 1: 启动后端
./start_backend.sh
# 或: cd backend && npm start

# 终端 2: 启动 Web 原型
cd web_prototype && python3 -m http.server 8080

# 终端 3: 启动 Godot 编辑器
godot --path godot_project --editor
```

### 2.3 验证服务

```bash
# 健康检查
curl http://localhost:3000/api/health

# 预期响应:
# {"status":"ok","service":"维多利亚伦敦探案 — API","version":"0.1.0",...}
```

---

## 3. 联调验证

### 3.1 后端 API 测试

```bash
cd backend

# 运行全部测试
npm test

# 或直接运行
node tests/api_test.js

# 指定服务器
TEST_BASE_URL=http://your-server:3000 node tests/api_test.js

# 详细输出
node tests/api_test.js --verbose
```

**预期输出**: 全部 19 项测试通过。

### 3.2 Godot 网络层测试

在 Godot 编辑器中:
1. 打开 `godot_project/`
2. 将 `tests/test_api_integration.gd` 附加到场景根节点
3. 运行场景（F6）
4. 查看输出控制台的测试结果

或通过命令行:
```bash
godot --path godot_project --script tests/test_api_integration.gd --ci
```

### 3.3 手动联调

#### 测试游客流程

```bash
# 1. 创建游客会话
curl -X POST http://localhost:3000/api/auth/guest

# 响应示例:
# {"message":"游客会话已创建","guest_id":"uuid","expires_at":"..."}
```

#### 测试注册流程

```bash
# 2. 注册用户（需要 Supabase）
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123456",
    "username": "测试侦探"
  }'

# 3. 登录
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123456"
  }'

# 保存返回的 token
TOKEN="eyJhbGciOi..."
```

#### 测试存档流程

```bash
# 4. 上传存档
curl -X POST http://localhost:3000/api/saves \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "case_id": "case_study_in_scarlet",
    "scene_id": "scene_01",
    "difficulty": 1,
    "clue_count": 5,
    "observation_score": 3,
    "reasoning_score": 2,
    "insight_score": 1
  }'

# 5. 获取存档列表
curl http://localhost:3000/api/saves \
  -H "Authorization: Bearer $TOKEN"

# 6. 获取最新存档
curl "http://localhost:3000/api/saves/latest?case_id=case_study_in_scarlet" \
  -H "Authorization: Bearer $TOKEN"
```

#### 测试案件进度

```bash
# 7. 更新进度
curl -X PUT http://localhost:3000/api/progress/case_study_in_scarlet \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "status": "in_progress",
    "clues_found": 10,
    "observation_stars": 3
  }'

# 8. 查询进度
curl http://localhost:3000/api/progress/case_study_in_scarlet \
  -H "Authorization: Bearer $TOKEN"
```

### 3.4 数据流验证

完整的用户数据流:

```
启动游戏 → 游客会话(GET /api/auth/guest)
         → 开始案件 → 发现线索 → 本地存档
         → 注册账号(POST /api/auth/register)
         → 登录(POST /api/auth/login) → 获取 JWT token
         → 上传存档(POST /api/saves) → 云端同步
         → 继续游戏 → 自动同步
         → 退出 → 云端存档保留
```

---

## 4. 常见问题

### 4.1 后端无法启动

**问题**: `Error: Supabase 未配置`

**解决**: 后端在不配置 Supabase 时仍可启动，只是认证/存档 API 会返回 500。游客模式 + 本地存档功能不受影响。

### 4.2 Godot 连接后端失败

**问题**: Godot 客户端请求超时

**排查步骤**:
1. 确认后端已启动: `curl http://localhost:3000/api/health`
2. 检查 `api_config.gd` 中的 `DEV_BASE_URL`
3. Godot 编辑器中检查输出日志的 `[APIManager]` 前缀消息
4. Android/iOS 模拟器中需使用 `10.0.2.2` 代替 `localhost`

### 4.3 存档同步失败

**问题**: `POST /api/saves` 返回 401

**原因**: token 过期或无效  
**解决**: 重新登录获取新 token

### 4.4 CORS 错误

Godot 的 `HTTPRequest` 节点不受浏览器 CORS 限制，但 Web 原型受限制。后端已配置 `cors({ origin: '*' })`，正常情况不会有此问题。

### 4.5 离线队列堆积

**问题**: `APIManager.pending_requests` 持续增长

**排查**:
1. 检查网络连接: `APIManager.is_online`
2. 手动触发刷新: `APIManager.flush_pending()`
3. 检查请求是否格式错误导致服务端拒绝

---

## 5. 开发工作流

### 5.1 推荐工作流

```
1. 启动后端 (npm start)
2. 运行后端测试 (npm test) → 确保 19 项通过
3. 启动 Godot 编辑器
4. 开发游戏逻辑
5. 涉及 API 时: 先用 curl 验证，再写 Godot 代码
6. 运行 Godot 集成测试
7. 提交前: 确保两端测试全部通过
```

### 5.2 添加新 API 端点

1. **后端**: 在 `backend/src/routes/` 创建新路由文件
2. **注册**: 在 `server.js` 中 `app.use()` 注册
3. **协议**: 更新 `communication_protocol.md`
4. **Godot**: 在 `api_manager.gd` 添加对应方法
5. **测试**: 在 `api_test.js` 添加测试用例
6. **配置**: 在 `api_config.gd` 的 `ENDPOINTS` 字典中添加

### 5.3 Git 提交规范

```
feat(network): 添加线索同步 API
fix(api): 修复存档上传超时问题
test(api): 添加认证流程集成测试
docs(protocol): 更新通信协议 v1.1
```

---

## 6. 部署清单

### 6.1 生产环境配置

- [ ] 配置 HTTPS 证书
- [ ] 设置 Supabase 生产项目
- [ ] 配置 CORS 白名单（限制为游戏域名）
- [ ] 设置环境变量 `NODE_ENV=production`
- [ ] 配置日志收集（如 Winston + ELK）
- [ ] 设置进程守护（PM2 或 systemd）
- [ ] 配置自动备份（Supabase 自带）
- [ ] 设置监控告警（UptimeRobot）

### 6.2 Godot 发布配置

- [ ] 修改 `api_config.gd` 中 `PROD_BASE_URL` 为生产地址
- [ ] 关闭调试日志
- [ ] 配置代码混淆（如需要）
- [ ] 设置 Android/iOS 网络安全配置（允许 HTTP 明文仅限开发环境）
- [ ] 配置启动画面 + 图标

### 6.3 PM2 部署示例

```bash
# 安装 PM2
npm install -g pm2

# 启动
pm2 start backend/src/server.js --name sherlock-api

# 查看状态
pm2 status

# 设置开机自启
pm2 startup
pm2 save
```

---

## 附录: 测试覆盖率

### 后端 API 测试覆盖

| 模块 | 测试数 | 覆盖端点 |
|------|--------|---------|
| 健康检查 | 2 | GET /api/health |
| 游客会话 | 1 | POST /api/auth/guest |
| 用户注册 | 2 | POST /api/auth/register |
| 用户登录 | 3 | POST /api/auth/login |
| 认证中间件 | 2 | Bearer Token 验证 |
| 存档接口 | 4 | GET/POST /api/saves |
| 案件进度 | 3 | GET/PUT /api/progress |
| 错误处理 | 1 | 404 处理 |
| 速率限制 | 1 | 并发请求 |
| **总计** | **19** | **全部 9 个端点** |

### Godot 网络层测试覆盖

| 模块 | 测试内容 |
|------|---------|
| APIConfig | URL 配置、端点定义完整性 |
| APIManager | 初始化、默认状态、健康检查 |
| AuthManager | 游客状态、用户名、注册/登录流程 |
| SaveManager | 本地保存/加载、云端保存/加载 |
| 离线队列 | 请求入队、队列管理 |
| 信号系统 | SystemEventBus 信号完整性 |
| 错误处理 | 参数错误、认证错误、登出清理 |
