## 项目概述

维多利亚伦敦探案 — 基于1864年斯坦福图书馆版伦敦地图的福尔摩斯主题推理探案游戏。玩家扮演福尔摩斯，通过线索拼接、推理演绎逐步揭开案件真相。地图随案件进度渐进式解锁，最终形成一张独一无二的维多利亚伦敦探索地图。

## 技术栈

- **游戏引擎**：Godot 4.x（GDScript + Compatibility 渲染器，支持 Web 导出 + 原生移动端导出）
- **后端 API**：Node.js + Express + Supabase（JWT 认证、PostgreSQL + RLS）
- **Web 原型**：纯 HTML/CSS/JS（无框架，单文件应用）
- **辅助脚本**：Python3（静态文件服务、代理服务器）
- **发布策略**：先网页游戏（游客 + 注册）→ 后手机应用端，共用同一后端

## 目录结构

```
/workspace/projects/
├── backend/                  # Node.js 后端 API 服务
│   ├── src/
│   │   ├── server.js         # Express 入口（端口 3000）
│   │   ├── routes/           # API 路由（auth/saves/progress）
│   │   ├── middleware/       # 中间件（认证、限流等）
│   │   ├── db/               # 数据库迁移
│   │   └── tres/             # 资源管理
│   ├── migrations/           # SQL 迁移文件
│   ├── tests/                # 后端测试
│   └── package.json          # 依赖：express, supabase-js, jsonwebtoken 等
│
├── web_prototype/            # Web 原型（纯 HTML/CSS/JS）
│   ├── index.html            # 场景一教学关原型（主游戏页面）
│   ├── editor.html           # 编辑器页面
│   └── assets/               # 静态资源
│
── godot_project/            # Godot 游戏引擎项目
│   ├── project.godot         # Godot 项目配置
│   ├── scenes/               # 场景文件
│   ├── scripts/              # GDScript 脚本
│   ├── assets/               # 美术资源
│   │   ├── characters/       # 角色资源（holmes/, watson/）
│   │   ├── props/            # 道具资源（马车等）
│   │   ├── portraits/        # 表情资源（pixel/）
│   │   ├── fonts/            # 字体资源
│   │   ├── scenes/           # 场景资源
│   │   └── ui/               # UI 资源
│   ├── autoload/             # 自动加载脚本
│   ├── config/               # 配置文件
│   ├── data/                 # 游戏数据
│   ├── web_build/            # Godot Web 导出构建产物
│   └── export_presets.cfg    # 导出预设
│
├── design_docs/ (设计文档/)   # 游戏设计文档（GDD 等）
├── scripts/                  # CI 脚本
├── tests/                    # 集成测试
├── tools/                    # 工具脚本
├── start_all.sh              # 一键启动（后端 + Web 原型）
├── serve_web.py              # Godot Web 构建静态服务器（端口 8081）
├── proxy_server.py           # 代理服务器
└── .coze                     # 项目配置
```

## 关键入口 / 核心模块

- **后端入口**：`backend/src/server.js`（Express，端口 3000，API 前缀 `/api/`）
- **Web 原型**：`web_prototype/index.html`（纯静态 HTML 游戏页面）
- **Godot Web 构建**：`godot_project/web_build/index.html`（Godot 导出的 WebAssembly 游戏）
- **一键启动**：`start_all.sh`（启动后端 + Web 原型）

## 角色表情资源

### 表情文件位置
- **Godot 项目**：`godot_project/assets/portraits/`
- **美术资源目录**：`美术资源/角色表情/`

### 福尔摩斯表情（15 种）
- 文件命名：`sherlock_表情名.png`
- 表情列表：兴奋、凝思、喜悦、坚定、开心、思考、愤怒、沉默、狡黠、生气、疑惑、疲惫、神秘、神秘2、自信

### 华生表情（18 种）
- 文件命名：`watson_表情名.png`
- 表情列表：惊讶、平静、倾佩、吃惊、羡慕、赞同、喜悦、开心、兴奋、自信、疑惑、沉默、思考、凝思、疲惫、生气、愤怒、神秘

### 表情系统代码
- **对话渲染器**：`godot_project/scripts/dialogue/dialogue_renderer.gd`
- 根据说话人自动切换表情集（福尔摩斯/华生）
- 通过 `expression_map` 和 `watson_expression_map` 管理表情映射

## 福尔摩斯角色资源

### 资源位置
- **Godot 项目**：`godot_project/assets/characters/holmes/`

### 角色立绘
| 文件 | 用途 |
|------|------|
| `holmes_three_views.jpg` | 三视图参考（正面/侧面/背面） |
| `holmes_standing.jpg` | 站立姿态（手持放大镜/烟斗） |
| `holmes_sitting.jpg` | 坐姿（221B会客厅） |
| `holmes_thinking.jpg` | 思考姿态（推理场景） |

### 道具图标
| 文件 | 道具 |
|------|------|
| `icon_deerstalker.jpg` | 猎鹿帽 |
| `icon_pipe.jpg` | 烟斗 |
| `icon_magnifying_glass.jpg` | 放大镜 |
| `icon_inverness_cape.jpg` | 因弗内斯斗篷 |

## 华生角色资源

### 资源位置
- **Godot 项目**：`godot_project/assets/characters/watson/`

### 角色立绘
| 文件 | 用途 |
|------|------|
| `watson_three_views.jpg` | 三视图参考（正面/侧面/背面） |
| `watson_standing.jpg` | 站立姿态（场景/对话） |
| `watson_crouching.jpg` | 半蹲姿态（调查/探索） |
| `watson_sitting.jpg` | 坐姿（221B会客厅） |

### 道具图标
| 文件 | 道具 |
|------|------|
| `icon_pipe.jpg` | 烟斗 |
| `icon_pocket_watch.jpg` | 怀表与表链 |
| `icon_bow_tie.jpg` | 领结 |
| `icon_deerstalker.jpg` | 猎鹿帽 |

## 运行与预览

- **后端**：`cd backend && pnpm install && node src/server.js`（端口 3000）
- **Web 原型**：在 `web_prototype/` 目录启动静态 HTTP 服务
- **Godot Web 构建**：`python3 serve_web.py --directory godot_project/web_build`（端口 8081）
- **预览**：通过预览服务访问 Web 原型页面

## 预览链路

- **判定依据**：项目核心可交互界面是 `web_prototype/index.html`（纯静态 HTML 游戏页面），需通过 Web 浏览器访问，属于 Web 预览型项目
- **预览入口**：`scripts/coze-preview-build.sh`（安装后端依赖）+ `scripts/coze-preview-run.sh`（启动后端 API + 在 5000 端口服务 web_prototype）
- **根 .coze 映射**：技术项目根目录与工作区根目录重合（`path = "."`），根 `.coze` 同时承担子项目 `.coze` 职责
- **注意事项**：
  - 预览服务同时运行后端 API（端口 3000）和 Web 原型（端口 5000）
  - 后端依赖 Supabase，部署环境需配置 `.env`
  - 预览脚本具备幂等性，重复执行会先清理 5000 端口残留进程

## 部署配置

- **deploy.profile**：`kind = "service"`, `flavor = "web"`
- **部署入口**：`scripts/coze-deploy-build.sh` + `scripts/coze-deploy-run.sh`
- **运行时**：`nodejs-24`, `python-3.12`
- **服务端口**：5000（Web 原型）+ 3000（后端 API）

## 用户偏好与长期约束

- Node.js 项目使用 pnpm 管理依赖（禁止 npm/yarn）
- Python 使用 uv 管理环境
- 后端 API 端口固定 3000
- Web 预览端口固定 5000
- Godot 项目需要 Compatibility 渲染器以支持 Web 导出

## 常见问题和预防

- 后端依赖 Supabase，需要配置 `.env`（参考 `backend/.env.example`）
- Godot Web 构建的 `.wasm` 文件必须以 `application/wasm` MIME 类型提供
- Web 原型为单文件应用，修改时注意保持内联 CSS/JS 的组织性
- `start_all.sh` 中使用 `npm install`，在 Coze 环境中应替换为 `pnpm install`
