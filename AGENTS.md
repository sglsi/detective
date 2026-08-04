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
├── skills/                     # 通用技能脚本
│   └── godot_asset_generator/  # Godot 游戏元素生成器（绿幕抠图）
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

### 可绑骨素材（Rig Assets）

**位置**：`godot_project/assets/characters/watson/rig/`

**用途**：2D 骨骼绑定动画（SkeletonCharacter2D）

**素材清单**（11 个部件，全部符合规格书要求）：

| 文件 | 尺寸 | 比例 | 描述 |
|------|------|------|------|
| `watson_head.png` | 1024x1344 | 256:336 | 头部（正面肖像，八字胡，军人发型） |
| `watson_torso.png` | 1024x2284 | 208:464 | 躯干（深褐外套，棕格马甲，白衬衫，黑领带） |
| `watson_upperarm_L.png` | 1024x2340 | 112:256 | 左上臂（深褐外套袖子） |
| `watson_upperarm_R.png` | 1024x2340 | 112:256 | 右上臂（深褐外套袖子） |
| `watson_forearm_L.png` | 1024x2474 | 96:232 | 左前臂（带手部） |
| `watson_forearm_R.png` | 1024x2474 | 96:232 | 右前臂（带手部） |
| `watson_thigh_L.png` | 1024x2389 | 144:336 | 左大腿（深蓝长裤） |
| `watson_thigh_R.png` | 1024x2389 | 144:336 | 右大腿（深蓝长裤） |
| `watson_shin_L.png` | 1024x2867 | 120:336 | 左小腿（黑色皮靴） |
| `watson_shin_R.png` | 1024x2867 | 120:336 | 右小腿（黑色皮靴） |
| `watson_hat.png` | 2560x1024 | 480:192 | 圆顶礼帽（棕色） |

**规格特点**：
- 统一正面视角（禁止侧脸、俯视）
- 竖直绘制，近端关节在顶边水平正中央
- 内容顶满画布（上下留白≤5%）
- 硬边缘透明背景（PNG-24，无柔光/投影）
- 维多利亚写实/插画风格，深棕描边

**后续步骤**：
1. 运行 `gen_character_rig.py` 生成骨架定义
2. 注册到 `PortraitLibrary.get_rig("华生")`
3. 测试骨架动画效果

**详细报告**：`WATSON_RIG_GENERATION_REPORT.md`

## 运行与预览

- **后端**：`cd backend && pnpm install && node src/server.js`（端口 3000）
- **Web 原型**：在 `web_prototype/` 目录启动静态 HTTP 服务
- **Godot Web 构建**：`python3 serve_web.py --directory godot_project/web_build`（端口 8081）
- **预览**：通过预览服务访问 Web 原型页面

### 本地开发环境

当前项目运行两个工程：
- **http://localhost:8081/** — Godot Web 构建版本（**主要开发环境**，后续开发设计主要在此进行）
- **http://localhost:8080/** — Web 原型版本（纯 HTML/CSS/JS）

**开发重点**：后续的开发设计主要在 **8081 端口**（Godot Web 构建）中进行。

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

## 通用 Skill

### Godot 游戏元素生成器

**位置**：`skills/godot_asset_generator/`

**功能**：将 AI 生成的绿幕图片转换为透明底 PNG，用于 Godot 游戏资源

**工作流程**：
```
AI 生成绿幕图 → Python 绿幕抠图 → 透明底 PNG → Godot 场景文件
```

**使用方法**：
```bash
python3 skills/godot_asset_generator/scripts/greenscreen_cutout.py \
  --input <绿幕图片> \
  --output <输出 PNG>
```

**AI 生成 Prompt 模板**：
```
<元素描述> alone, <风格>, clean solid color background (pure green #00ff00),
NO other objects, isolated, game asset
```

**详细文档**：`skills/godot_asset_generator/SKILL.md`
**快速开始**：`skills/godot_asset_generator/README.md`

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

### 像素艺术风格生成器

**位置**：`skills/pixel_art_generator/`

**功能**：专门用于生成像素艺术风格游戏元素

**工作流程**：
```
AI 生成绿幕图 → Python 抠图 → 像素化处理 → 调色板量化 → 透明底 PNG
```

**使用方法**：
```bash
python3 skills/pixel_art_generator/scripts/pixel_art_cutout.py \
  --input <绿幕图.jpg> \
  --output <输出.png> \
  --pixel-size 64 \
  --colors 16
```

**参数说明**：
- `--pixel-size`：目标像素尺寸（16/32/64/128/256，默认 64）
- `--colors`：调色板颜色数（8/16/32/64，默认 16）
- `--no-pixelate`：跳过像素化处理，只抠图
- `--bg-color R,G,B`：手动指定背景色

**AI 生成 Prompt 模板**：
```
<元素描述> alone, pixel art style, 64x64 sprite,
clean solid color background (pure green #00ff00),
NO other objects, isolated, game asset
```

**与 godot_asset_generator 的区别**：
- `pixel_art_generator`：专用像素艺术风格，包含像素化处理和调色板量化
- `godot_asset_generator`：通用抠图工具，不限制风格

**详细文档**：`skills/pixel_art_generator/SKILL.md`
**快速开始**：`skills/pixel_art_generator/README.md`

## 用户偏好与长期约束

- Node.js 项目使用 pnpm 管理依赖（禁止 npm/yarn）
- Python 使用 uv 管理环境
- 后端 API 端口固定 3000
- Web 预览端口固定 5000
- Godot 项目需要 Compatibility 渲染器以支持 Web 导出
- **Git 提交策略**：不用每次都向 GitHub 提交，在进行一个阶段的工作后再集中进行提交
- **图片预览规则**：禁止让用户通过 GitHub 链接查看图片。生成的图片必须直接在对话中展示给用户（使用 generate_image 工具或提供可直接访问的 URL），不要让用户去 GitHub、本地拉取或启动预览服务查看

## 本地开发环境

### Godot 引擎
- **版本**：Godot 4.7.1 stable
- **路径（Windows）**：`D:\AI\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe`
- **导出模板路径（Windows）**：`C:\Users\sglsi\AppData\Roaming\Godot\export_templates\4.7.stable`
- **用途**：本地编译、测试和导出 Godot 项目

### 编译命令（Windows 本地）
```powershell
# 导入项目
& "D:\AI\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe" --headless --import

# 运行烟雾测试
& "D:\AI\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe" --headless --script res://tools/smoke_load_check.gd

# 导出 Web 版本
& "D:\AI\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe" --headless --export-release "Web"
```
