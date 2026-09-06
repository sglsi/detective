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

## 模式 B（纵向链）移除（2026-09-05，用户裁定）
- **模式 B（推理链纵向布局）已整体删除**（用户："基本没用，还可能影响正常功能"）。删除面：layout `_compute_layout` else 纵向分支、controller 墙内"推理链"tab、reasoning_wall 顶栏"推理链"按钮、edge 绘制 MODE_B 分支、chain 节点点击自动切模式、`graph_view_mode` 持久化读写、test_graph_fix2 的 Fix5 段。`_mode` 恒 `ViewMode.MODE_C`（星型树），enum 值保留防引用断裂。
- **用户场景二拖拽"故障依旧"的最终根因即在此**：用户的墙 state_store 持久化了 `graph_view_mode=MODE_B`（点过顶栏按钮或 chain 节点），而 MODE_B 分支完全没有钉位/拖动保持逻辑——此前所有拖拽修复都在 MODE_C 分支。删除 MODE B 后此路径不复存在。**教训：修"共用功能"先确认用户实测所处分支**。
- 拖拽回弹完整根因链（三叠加）：①建边路径钉位写在 rebuild 后（钉回弹位）→已改为先钉玩家落点再 nudge/rebuild；②落点误判建边可成环→`_would_create_cycle` 拒绝+toast；③rebuild 后去重叠推走钉位节点→两个 overlap_fix 循环 continue `_manual_nodes` 成员。
- **测试方法论**：`test_drag_follow.gd` 走简化参数路径非真实 `gv.build(dict)`——测试过≠用户实测过；`tools/t_drag_seq_repro.gd` 用真实 build(dict)+六步协程序列（拖结论/拖推断/归锚人物/拖人物/自动排列后再拖/收尾）作权威回归，**协程函数调用必须 await**（漏 await 会交错执行状态互相污染，输出全错）。

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
- **对话括号内容清洗——tres + GDScript 双层（2026-09，两批）**：台词内括号按甄别规则处理，**不一刀切**（用户明确要求）：演出指示/设计标注剥除并迁 `stage_direction`（不上屏）；玩家功能信息/线索内容（`（可记录在线索墙）``（0-10 滑杆）``（身高6英尺+…）``（E.J.D.）``（手腕/左臂/面色/站姿）`等）**有意保留**。覆盖两处数据源：①场景一至四 tres 28 条（`tools/clean_dialogue_parens.py` 幂等脚本，`stage_direction` 仅 `trigger=sfx` 时 emit 且无人连接；空 text 节点 0.15s 自动流转不卡对话）②**场景一开场/信使对话硬编码在 `scene1.gd` 的 `_show_mrs_hudson_dialogue`/`_show_opening_dialogue`（26 条，用户截图实证）**——用 `_dn(...)` 末尾位置参数传 `stage_direction`；运行时断言 `tools/t_scene1_dialogue_clean.gd`（19 节点 BAD=0）
- **GDScript 4.7.1 调用不支持命名参数（重要教训）**：`f(a, sd="x")` 直接报 "Assignment is not allowed inside an expression"（对照实验实证）；必须用纯位置参数。且**解析类改动必须先过编译冒烟**（`GDScript.new()+reload()` 或 export 查 SCRIPT ERROR）再导出——盲改正错三次（sd 落 diff_filter 位/挤掉 mood/双逗号）
- **方向不确定时先问用户再做（用户明确要求）**：清洗范围/保留策略这类有多种合理解读的决策，先给出方案让用户拍板，不要自行"一刀切"扩大改动；用户会以实际显示效果反馈纠偏（如开场对话在 GDScript 而非 tres——只扫 tres 会漏）
- **沙箱回收会还原未提交改动（重要教训）**：沙箱实例被回收重建时，工作区恢复到最近快照，未提交的文件修改与 /tmp 文件全部丢失；一次清洗完成后曾在导出前被整体回滚。对策：重要数据/资源改动完成后**立即验证落盘并尽快提交**（关键数据改动不等阶段末集中提交），一次性脚本放项目 `tools/` 而非 /tmp

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
- **用户上传图片落点（2026-09-03 确认）**：对话中用户上传的图片文件会存入 `/workspace/projects/assets/`（文件名常带 `_时间戳` 副本，内容相同）；不要凭 find 时间过滤断言"图片不在环境里"，先直接 `ls assets/` 查中文名文件
- **台词库括号内容规则**：台词库（08_血字的研究_对话台词库.md 等）中人名/台词内的小括号内容（如 `（上下打量华生，停顿2秒，特写）`）仅是给游戏设计使用的演出指示，**不展示在游戏对话台词中**；开发对话渲染/台词导入时必须过滤剔除小括号段，不得原样上屏

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

### 沙箱（Coze/Linux）Godot 工具链

> ⚠️ **持久化位置 = `/workspace/projects/tools/godot/`（项目工作区内）。** `/workspace/tools`、`/root`、`/tmp` 都是**非持久**的（沙箱周期性回收容器 overlay 可写层，只对受托管的项目工作区做快照），不要再把工具链装到这些地方。
> **首次（或工具被清后）只需重新播种一次：** 从 `gh.ddlc.top` 代理下载 Godot 编辑器 zip + 导出模板 tpz（分片 Range 并行），把**编辑器 zip + 4 个 Web 模板 zip**（`web_release/web_nothreads_release/web_nothreads_debug/web_debug`）存到 `tools/godot/`，tpz 用完即删（约 1.3GB，勿入库）。此后运行 `bash tools/godot/setup_godot.sh` 幂等解压编辑器、软链模板到运行路径，**不再联网**。

- **持久存档**：`/workspace/projects/tools/godot/`（含 `godot_editor.zip`、4 个 Web 模板 zip、`setup_godot.sh`；已 `/tools/godot/` 加入 `.gitignore`）
- **bootstrap（每次会话若工具缺失先跑一次）**：`bash /workspace/projects/tools/godot/setup_godot.sh`
  - 解压编辑器到 `tools/godot/editor_extract/`
  - 把 `web_*.zip` 软链到 `~/.local/share/godot/export_templates/4.7.1.stable/`
- **Godot 编辑器**：`/workspace/projects/tools/godot/editor_extract/Godot_v4.7.1-stable_linux.x86_64`
- **Web 导出模板（运行路径）**：`~/.local/share/godot/export_templates/4.7.1.stable/web_nothreads_release.zip`（软链自持久区的同名 zip；持久源在 `tools/godot/`）
- **沙箱导出命令**：`cd godot_project && GODOT --headless --path . --export-release "Web"`（产物写 `web_build/`，预览即 proxy 上 5000 服务 `web_build/`）
- **导出后必须给 index.html 打 pck 版本戳**（浏览器缓存兜底）：**每次 export 都会重新生成 index.html（无 mainPack 字段）并丢掉旧戳——必须每次导出后重新插入**：`sed -i 's/"executable":"index",/"executable":"index","mainPack":"index.pck?v=<日期+序号>",/' web_build/index.html`（已有 mainPack 时用 `s/"mainPack":"index.pck?v=[^"]*"/"mainPack":"index.pck?v=<新戳>"/`；**不可改 executable**——loader 会拼 `executable+".pck"/".wasm"`，query 加在 executable 上导致 `index?v=x.wasm` 404 加载失败）。proxy 对所有响应发 no-store，但无 no-store 时期的旧缓存条目普通刷新仍会复用；mainPack 带版本使 pck URL 变化强制拉新（loader index.js 823 行 `config.mainPack || executable+'.pck'`）。导出后内容验证：GDScript 在 binary tokens 下字符串全不可 grep（含 ASCII），用测试脚本 load 同一源文件验证（见下方 pck 验证条目）+ tres 明文特征（如 NPC_MSG）
- **脚本语法校验**：`GODOT --headless --path . -s <脚本>.gd`（项目把 Variant 推断等 GDScript 警告当作错误，新增脚本必须显式类型标注）
- **封存后不可预览时**：推理墙图谱改动在 `godot_project/scripts/clue/`，改完必须重新导出 Web 才生效，仅改源码不重新导出会造成"预览仍是旧版"。

## 推理墙图谱（graph_view_controller.gd）交互能力
- **图谱契入让出（2026-08 现用方案，替代契回全屏+命中分离）**：图谱契回墙顶层铺满（`_on_open_graph_view` 里 `add_child(gv)` + `PRESET_FULL_RECT` + `gv.z_index=5`），但图内部 `_clip` 契入让出「左栏右侧、顶栏之下」的图谱交互区（`_clip.offset_left=hit_off_left / .offset_top=hit_off_top`，`clip_contents=true`）。`_clip`/`_canvas` 均 `MOUSE_FILTER_STOP` + `gui_input.connect(_on_canvas_gui)`——**同一区域既显示又承接全部画布交互（平移/滚轮/空白点击/shift 建边/折叠）**，顶栏/左栏不被图谱覆盖故天然优先可点，无需命中分离层（曾用 `_hit_layer` 分离让 `_on_canvas_gui` 脱链导致 shift 连线/折叠失效，已废除）。拓扑根 `self.mouse_filter=IGNORE`。
  - **世界坐标原点 = 墙左上（canvas 反补）**：契入让出只让 `_clip` 裁掉顶栏/左栏（显示+命中），`_canvas` 用 offset `-hit_off_left/-hit_off_top` 反补，使画布覆盖契入前的整个墙画布(0,0..W,H)——**布局基准不随契入压缩**，横向阶梯树在宽松全屏宽上重排，目标不会覆盖（曾因契入让 `_canvas.size` 压缩到契入区(≈740 宽)、节点放不下被 `_clamp_to_canvas` 挤压重叠）。所有命中/坐标转换仍一律 `_canvas.get_global_transform().affine_inverse() * 视口坐标`（get_global_transform 自带 clip 偏移，契入不影响）。仅手工写 `_canvas.position` 的锚点位需按 `_clip.get_global_transform().origin` 校正：`_zoom_at` 用 `mouse_pos - lp*ns - clip_origin`，`fit_view` 用 `-center_gl*ns + vp*0.5`（契回全屏 clip.origin=0 时二者皆退化为正确，契入下数学精确居中）。平移 `_pan` 是增量移动，clip.origin 常量相消无需改。
  - **契入首帧自动 fit**：契入模式下布局基准是全屏画布、契入 viewport 只显示其一部分，故 `_rebuild_graph` 首帧 `call_deferred("fit_view")` 缩放到契入区内看全（`_did_initial_fit` 只在 build 复位，后续 rebuild 不重置玩家缩放）。契入裁剪会把部分节点 clip 在契入让出区外，玩家可用「适应」/缩放看全。
  - **让出区单源传入**：图谱用成员 `hit_off_top/hit_off_left`（默认 110/540），由 `_on_open_graph_view` 处设 `gv.hit_off_top=110`、`gv.hit_off_left=540`（对齐顶栏底 `_top_bar.offset_bottom` / 左栏右缘 `_left_panel.offset_right`）。改 UI 尺寸须同步这两值（`tools/q6_contract_guard.gd` 源码契约守卫 Q6 会断言：clip/canvas 均 STOP+gui_input、无 `_hit_layer`、契入偏移用 `hit_off_*`、`_zoom_at`/`fit_view` 含 `_clip.get_global_transform().origin`）。
  - 回归：P0/P12_E2E_OK/P15/P16_E2E_OK/Q2_OK/Q5_OK/Q6(fails=0)/case_panorama(11/12) 全过。
- **ESC 关闭修复**：关闭处理用 `call_deferred("_on_close_pressed")`，避免在 `_input()` 里销毁节点卡死。
- **ESC 关闭修复**：关闭处理用 `call_deferred("_on_close_pressed")`，避免在 `_input()` 里销毁节点卡死。
- **提交验证按钮**：由 reasoning_wall 的常驻顶部栏（z=100，始终盖在图谱之上）提供，图谱自身工具栏默认 `_show_toolbar=false`，避免重复工具栏。
- **教学墙评分明细反馈（2026-09-03，用户决策）**：练习墙（teaching/practice）验证后评价体系照常显示（四档等级+三星），并附「教学反馈」明细告诉玩家差在哪。落地：① `wall_branch_evaluator._score_branch` 每链输出 4 个明细数组进 per_branch：`missing_nodes`（真相推断/结论未产出）、`missing_edges`（真相连线未连）、`reversed_edges`（两端对但方向反，半分）、`extra_edges`（玩家建的、不在真相里的连线，进分母拉低正确率）；② `wall_verify._build_verify_summary` practice 分支改 `_teaching_report()`：逐链列出缺节点/缺连线/方向反/多余连线（id 经 `_pretty_id` 翻译成中文：线索→`_clues.name`、推断/结论→`_battle_current` hypotheses/conclusions 的 text、人物→`_NPC_DISPLAY_NAMES`），并附战场命中行；③ `wall_state._update_star_rating` 原练习墙「练习墙·不计分」特判改为正常三星+「教学反馈」标注——**此前 _last_stars 在 practice 判断前赋值导致练习墙亮星但不给明细，用户实测把教学反馈误读为正式评分（华生 2⭐/信使 1⭐），是本轮改动根因**；练习墙仍不提交 `StarRatingSystem`（不计案件总分，裁定 5 保持）。诊断结论：推理星低主因「边覆盖不全」（尤其 推断→推断/结论→人物 收尾边）+ 多余连线拉低；洞察 1⭐ 主因玩家没碰战场按钮（战场与图谱双系统脱节，`_battle_hypo_states` 仅手动点击/存档恢复两处赋值）。
- **场景一对话误推进修复（2026-09-03，用户实证）**：scene1.gd 曾自写简化 `_input`（任意鼠标键/滚轮按下 → `_dm.advance()` 无闸门），左栏动作栏 ScrollContainer 是 MOUSE_FILTER_PASS，滚轮事件穿透后直接推进对话直至转场——已删除子类 `_input`，让基类 `detective_scene._input` 的完整闸门生效（滚轮仅台词回看、悬停按钮阻塞推进、回看态处理）。**教训：场景子类不要用简化 `_input` 覆盖基类闸门**；左栏"只在左栏滚动"由 PASS+闸门共同保证
- **槽位存档空壳问题（2026-09-03 发现）**：用户导出的最新槽位（get_slot_list_sorted[0]）仅含 difficulty/timestamp，scene_id/scene_state/collected_clues/star_chains 全空——用户进行中的推理进度从未成功落入槽位（手动存档挂死类 side_panel 不存在；自动存档仅场景切换触发）。因此「🗄 存档」导出改为**内存快照优先**：导出当前墙 `_state_store`（scene1 双墙共享，含华生+信使全部连线）+ `_battle`/`_battle_hypo_states`/`_last_branch`/`_last_stars` + 全部槽位内容附后；复盘工具 `analyze_save_report.gd` 以 `kind=="wall_state_export"` 分支解析（memory 快照格式），旧存档格式仍兼容
- **推理墙层级拖拽"回弹/子树不动"真根因链（2026-09-05，用户五次反馈后实证）**：场景一/场景二/后续场景**全部共用同一模块链** `_open_wall→reasoning_wall→graph_view_controller`（模块化成立），行为差异不是架构问题，而是三个叠加 bug 在"节点密集的场景二墙"高频触发、在"节点稀疏的场景一"几乎不触发：①**建边路径钉位时序错误**——钉位写在 `_rebuild_graph()` 之后，钉的是重排回弹位而非玩家落点（已改为：环检测→先钉 `_node_center`（拖拽跟手位）→建边→nudge→rebuild，重派生以钉位为准）；②**落点误判建边+环边毁布局**——松手落点落在其它节点框内被判定为建边，若建出环边（如结论→自己下游），`_build_parent_of` 树带环→BFS 布局丢节点（节点从 `_node_center` 消失=用户看到的"树枝以下不随根动"）→`_commit_move` 建边前 `_would_create_cycle` 环防护（沿 to 可达 from 则拒绝建边，toast 提示，落点空则按移动路径钉位）；③**去重叠后处理推走钉位节点**——`_apply_column_overlap_fix`/`_apply_global_overlap_fix` 在 rebuild 后把与其它节点 AABB 相交的钉位节点推走（Y 恒被 +84 位移）→两个 fix 的"被推者"循环均 `continue` 钉位节点（`_manual_nodes` 成员），未钉节点正常被推
- **拖拽测试方法论重大教训（2026-09-05）**：`test_drag_follow.gd` 走的是**简化 build 路径**（手写参数直调），全 PASS 但用户实测仍回弹——**真实链路是 `gv.build(dict)`**（reasoning_wall 组装的 Dictionary：clues/hypo/persons/focus_person/battlefield…），两者行为可分叉；新回归 `tools/t_drag_seq_repro.gd` 用**真实 build(dict) + 六步协程序列**（拖结论/拖推断/拖结论归锚人物/拖人物/自动排列后再拖/收尾），**协程函数调用必须 `await`**（漏 await 会四步交错执行、状态互相污染，输出完全失真）；派生节点必须出现在 `battlefield.hypotheses/conclusions` 定义里，否则 rebuild 按权威列表剔除（节点消失）
- **m0 房东太太头像缺失修复（2026-09-05）**：信使来时对话节点 m0 说话人误写"系统"+台词手写"赫德森太太："前缀+kind="guide"（渲染器对系统发言显示 guide 样式无头像）——改回说话人"赫德森太太"（NPC_BUSTS 已注册 hudson_bust）、去台词前缀、mood="平静"。**教训：新对话节点说话人字段必须用人物名，系统旁白才用"系统"，禁止在台词文本里手写说话人前缀**
- **导出面板通用化**：`graph_view_controller._show_export_panel` 由固定偏移 Panel 改为 Godot `Window`（`popup_centered` 屏幕中央、标题栏可拖、始终置顶、× 关闭）——markdown 导出与存档导出共用
- **赫德森太太对话头像**：`hudson_bust.png` 从全身图（assets/房东太太00.png）裁人物顶部 26%（肩部以上）contain 进 512x512 底对齐；全身像 `mrs_hudson.png` 等比缩放到高 512
- **洞察星改源（2026-09-04 已实施，用户裁定）**：「推理战场」不再作为洞察星数据源，改评图谱**合成层完整度**。算法：真相链中两端均非线索层的边（hypo→hypo / hypo→concl / concl→person）+ 结论节点产出，`insight_ratio = 命中合成项 / 真相合成项`（exact 1.0 / reversed 0.5）；星阈 r≥0.8→3⭐、≥0.55→2⭐、否则 1⭐，分母 0（insight_ratio=-1）回退推理星；`insight_bonus`（识破误导 +1）保留。落地：`wall_branch_evaluator._score_branch` 增输出 `matched_edges`（真相边被 exact(1.0)/reversed(0.5) 命中，Dictionary 数组含 weight）+ evaluate 顶层聚合 `insight_ratio/insight_hit/insight_truth`（`_is_synthesis_edge` 判合成）；`wall_state._update_star_rating` 洞察段改读 `br.insight_ratio`，删除 `_battle_hypo_states` 命中计算；战场按钮 UI 保留但不再计分（教学反馈中战场行已同步删除）。方案 B（战场联动引导）/C（放宽阈值 80/55/25）此前已明确舍弃。
- **真相表与 battlefield gate 同源化（2026-09-04，信使墙复盘实证后的根因修复）**：用户信使墙连线（10 条全符合设计意图：4 线索各归 M-01~04 + 4 条 hypo→concl + 2 条结论→人物）在旧真相表 CH01M 下只得 33%「证据不足」——**根因是 `case_branch_truth.gd` 的 CH01M 还是「单假设 M-01 吃全部线索」的旧设计，与 scene1 battlefield gate（4 假设各绑 1 线索、CL1-01←M-01/02/03、CL1-02←M-04、结论 target person:NPC_SERGEANT）脱节**。修复：①CH01M 按 battlefield gate 机械重写（6 节点→4 hypo+2 concl+person:NPC_SERGEANT，10 条真相边）；②CH01W 补 2 条结论→person 边（C-A1/C-C1→person:NPC_WT，三个结论均 target NPC_WT，此前只有 C-MAIN→person 一条）；③**人物 id 统一**：6 个信使线索 tres 的 `related_npcs` 从 NPC_MES 改为 NPC_MSG（图谱人物节点由 related_npcs 自动派生，NPC_MES 是旧 id 残留；persons 数组权威 id=NPC_MSG/NPC_SERGEANT）。重跑存档复盘：branch 87.5% verdict=3（推理成立 3⭐）、insight 75%（2⭐）——用户当时的操作在新表下接近满分，仅剩「结论应锚海军军士（身份揭示）而非信使本人」的教学差距。**维护规则：真相链必须与 battlefield 的 gate_clue_ids/gate_hypo_ids/target 同源，改 battlefield 必同步 case_branch_truth**。另修 `wall_branch_evaluator._score_branch` 边匹配的 norm 不对称（truth map 端点 norm 了、玩家边 ef/et 没 norm，带 person:/conclusion_ 前缀的连线反查 reversed 会误判 extra）。
- **华生教学链三层结论重构（2026-09-05，用户关系表）**：用户给出华生墙新推理关系表（线索→推导→阶段性结论1→2→3→关联人物），CH01W 与 scene1 battlefield 按表同源重写。新结构：5 hypo（W-A1 不是原来的肤色←wrist+face_dark / W-B1 多年军事气质←pose / **W-B2 从事医疗行业←medical**（军医线拆两条独立推导）/ W-C1 左臂受伤←arm / W-C2 久病初愈←face_haggard）+ **6 concl 含三层**（C-A1 曾经在热带生活过 / C-B1 是名军医←W-B1+W-B2 / C-C1 承受伤痛←W-C1+W-C2；**结论2 层**：C-A2 英国殖民地为阿富汗←C-A1、C-C2 伤害来自军事任务←C-C1；**结论3**：C-MAIN 在阿富汗服役过←C-A2+C-B1+C-C2 三线汇聚）→锚 person:NPC_WT（**仅 C-MAIN 连人物**，中间结论不连）。关键机制：①**gate_hypo_ids 引用结论节点必须写完整节点 id（`"conclusion_C-A1"` 含前缀）**——`_sync_conclusion_gate_edges`/放置锚定按 `_node_center.has(_gid)` 查节点 id，写裸 id 永不匹配；真相表写裸 id 即可（norm 剥前缀）。②**结论→结论边（concl→concl 同层）是首个先例**：真相边 `C-A1→C-A2`、布局按 BFS 树深度分列（to 端为父）无重叠、教学墙不自动补 gate 边（玩家手动从结论节点拖线连下一层结论）。③truth T 计数语义=**边数+可产出节点（hypo+concl），clue/person 不计入**（CH01W：17 边+11=28）；missing_nodes 只列非线索非人物未产出节点。④评分测试 `tools/t_eval_details.gd` 期望值已同步（truth=28/hit=3.5/missing_nodes=9/missing_edges=15/reversed=1/extra=2）。回归：t_eval_details OK、t_scene1_dialogue_clean 19节点 BAD=0、test_drag_follow PASS。
### 界面按钮图标系统（2026-09-05，用户图标集接入）
- **图标库**：`godot_project/assets/ui/icons/`（37 个透明底 PNG，≤224px）。25 个来自用户上传黄铜浮雕图标集切分（`assets/图标00.png` 5×5，PIL 等分+棋盘格灰白转透明+trim）；12 个 AI 生成补缺（绿幕生成→`skills/godot_asset_generator/scripts/greenscreen_cutout.py` 抠图；其中 deerstalker/chemistry 抠图残留需二次 g>r*1.12 重抠+despill 绿通道压制）。
- **映射原则（用户裁定）**：一图标只对应一个功能；同功能域多入口可复用同一图标（保存→floppy/保存到此处、返回→back_arrow、开始→deerstalker/开始挑战、继续→casebook/继续、账户→person）。
- **接入点**：①`tool_bar.gd` TOOL_DEFS 8 侦探工具（icon 路径原指 res://assets/tools/ 全部缺失→fallback 首字，即"按钮图标为空"根因；已改指 icons/，TextureButton 自带 exists fallback）②`side_panel.gd` 8 动作按钮 btn_defs 加 icon 字段+文字去 emoji（eye/chat/lens/brain/journal_book/floppy/folder/download）③main_menu 主按钮（开始→deerstalker/选项→gear/退出→padlock/注册登录→person/继续→casebook/返回→back_arrow）④slot_dialog（保存→floppy、载入→casebook、返回→back_arrow）⑤difficulty_select（开始挑战→deerstalker）⑥auth_panel（模式切换→person）⑦wall_clue_library 动作工厂（提交验证→shield_star、返回→back_arrow、调查记录→calendar，match text 分配）。
- **Button 图标规范**：`btn.icon = load(...)` + `add_theme_constant_override("icon_max_width", 24~30)`（主按钮 44）+ `h_separation` 6~10；过滤器类小按钮不加图标（避免语义稀释）。
- **资源新增必须 `--headless --import` 后 ResourceLoader.exists 才为 true**（新目录 icons/ 未导入时 exists=false，冒烟会误报 ICON_MISSING）。
- **总览图**：`web_build/icons_preview.png`（37 图标拼图，预览 URL 可看）。
### 左栏按钮改古董金属牌样式（2026-09-06，用户参考图）
- scene_framework.gd `_make_action_button` 按**用户参考图**重做：深底(0.07,0.05,0.03) + 外 2px 金边 corner10 + **内嵌细线 Panel(4px 内缩, 1px 半透明金, draw_center=false) 做双线效果**；图标 32×32 居左垂直居中，EN(11号金)+ZH(14号浅金) 两行居右；按钮 116×96 圆牌 → 132×64 扁牌（LEFT_W=140 内）。ENCYCLOPEDIA 11 号在 (w-54) 文字区刚好放下。hover=亮金边+暖棕底。版本戳 v=20260906f。

### 预览"一直转圈进不去"：图标库 78MB 致 pck 膨胀 + 减肥（2026-09-06）
- **用户报预览一直滚动/转圈进不去**。服务器端链路正常（fileSizes 匹配、pck 200 完整）→ 定位为 **pck 123MB 过大 + proxy 全响应 no-store（浏览器不能缓存）→ 每次刷新全量重下 → 慢**。主因：generate_image 生成的 41 枚图标全是 2048 级 PNG（icons/ 共 78MB），而显示尺寸仅 20~44px。
- **减肥**：PIL `thumbnail((128,128), LANCZOS)` 批量缩图（保持 alpha；128px 对 44px 显示 3x 余量）→ icons/ 1.1MB，pck 123MB→**68.6MB**（图标在 pck 内为 ctex 压缩格式，实际减 57MB）。**后续生成图标 prompt 后必须立即 resize 到 ≤256 再入 pck**。
- **两个既有坑复发记录**：①`--import` 后立即 export 报 "Project export failed"（_fs_changed 推迟导出），**重跑一次 export 即可**；②沙箱回收清空 export_templates 软链（/root 非持久），报 "configuration errors"——重跑 `bash tools/godot/setup_godot.sh` 恢复。导出是否真成功以 **fileSizes 与 stat 精确一致** 为准（失败时 index.html/pck 保持旧值）。
- 版本戳 v=20260906e（pck 71891220）。遗留优化项：pck 分片/断点续传、大资源（watson 立绘等）按需加载。

### 场景框架左栏/顶栏图标接入（2026-09-06，用户双截图需求）
- **关键发现：游戏内场景左栏/顶栏是 `scripts/ui/scene_framework.gd`**，与推理墙的 side_panel/reasoning_wall 是**不同面板**（此前给 side_panel 配的图标与此无关）。左栏 9 按钮（LOOK/TALK/EXAMINE/THINK/PROP/JOURNAL/ENCYCLOPEDIA/SAVE/LOAD）字典 icon 字段原是 **emoji 字符，游戏字体无 emoji 字形→渲染为空**（"图标未显示"根因）；顶栏 4 按钮（MAP/CASEBOOK/EVIDENCE/OPTIONS）_make_nav_button 无图标代码。
- **接入**：左栏 icon 值换 png 路径，emoji Label → TextureRect（EXPAND_IGNORE_SIZE+KEEP_ASPECT_CENTERED，(0,6,w,36)）；顶栏 navs 加 icon 字段，_make_nav_button 加 TextureRect (6,15,24×24) + EN/ZH 文字区右移 x=30 居中。映射：观察→eye/对话→chat/调查→lens/思考→lightbulb/道具→satchel(新)/日志→journal_book/百科→directory/保存→floppy/读取→folder；地图→map(新)/案件簿→casebook/证物→evidence_box/选项→gear。
- **新图标 2 枚**：map.png（折叠地图）、satchel.png（侦探皮包）——generate_image 黄铜浮雕绿幕 → **despill 二段处理**（首轮 greenscreen_cutout 绿残留 9.9%/6.1% 超标；宽容重抠 mask=(g>lum*1.12&g>55) + spill=(g>lum*1.05) 压绿 g=min(g,lum)）→ 0.00% 残留 + getbbox trim。跨面板同功能复用同一图标可接受（eye/floppy 等），不同功能不共用。
- 版本戳 v=20260906d（pck 128996720）。

### 主菜单图标调整（2026-09-06）：开始游戏去图标 + 退出游戏换开门图标
- "开 始 游 戏"按钮去掉 deerstalker 图标（用户要求，删除其 BtnIconCenter.apply_center 调用，按钮恢复纯文字）。
- "退出游戏"按钮 padlock → **door_open.png（新造）**：generate_image 黄铜浮雕风格绿幕图（2048²）→ greenscreen_cutout.py 抠图（绿残留 0.7% 合格）→ getbbox trim 到 1550×1583 → `assets/ui/icons/door_open.png`。生成 prompt 要点：door panel swung open + antique brass embossed relief + golden bronze + dark engraved outlines，与图标00.png 黄铜浮雕集同风格。版本戳 v=20260906c。

### 按钮"图标+文字整体居中"重构（2026-09-06，用户澄清：不要左对齐，要整体居中）
- **Godot 4.7 无原生组合居中**（读引擎源码确认）：icon_alignment 与 alignment 独立生效——icon CENTER 时 text 可用区**不减 icon 宽**，CENTER+CENTER 直接重叠；LEFT+CENTER 是"剩余区居中"（text 中心=(W+icon+sep)/2，偏右）。纯属性方案无法实现"图标+文字作为整体居中"。
- **方案：内部 HBoxContainer 组合居中**——新工厂 `scripts/ui/btn_icon_center.gd`（class_name BtnIconCenter）：`apply_center(btn, icon_path, icon_w, sep)` 清空 btn.icon/text，挂 PRESET_FULL_RECT + ALIGNMENT_CENTER 的 HBox（mouse_filter=IGNORE 链），内含 TextureRect（EXPAND_IGNORE_SIZE+KEEP_ASPECT_CENTERED，min=(icon_w,0)）+ Label（复制 btn 的 font_size/font_color override，VERTICAL_CENTER）；并按 icon_w+sep+文本实测宽（Font.get_string_size）+ stylebox content margin 设 custom_minimum_size，防清空 text 后容器内按钮塌缩。**新增 API 注意：Button 没有 get_theme_font_color，是 get_theme_color("font_color")**（主场景冒烟 4 报错实证）。
- 19 处调用点由 python 批量替换（.icon=load 行 + 相邻 icon_max_width/h_separation/alignment 行合并为一次工厂调用）。**唯一动态 text 按钮=auth_panel._mode_btn**（登录/注册模式切换），在 _apply_mode 两处赋值后同步 `get_meta("icon_label")` 的 text——工厂把 Label 存在 btn.set_meta("icon_label")。wall_clue_library 的 `if btn.icon != null` icon_max_width 死代码已删。
- 已知代价：按钮 hover/pressed 态的**字色**变化丢失（Label 固定色），stylebox 底色变化反馈仍在；顶栏按钮颜色创建时定死不受影响。版本戳 v=20260906b。

### 按钮图标与文字脱节修复（2026-09-06，用户反馈"图标在最左边离文字远"）
- **根因（headless 探针实测）**：Godot 4.7 Button 的 `icon_alignment` 默认 LEFT（图标贴按钮左内缘）、`alignment`（文字）默认 CENTER（居中）——两者**独立对齐**，宽按钮上图标贴左、文字居中，脱节感强。h_separation（4~10）不是原因。
- **修复**：全部 19 处 `.icon = load(...)` 赋值点后统一插入 `X.alignment = HORIZONTAL_ALIGNMENT_LEFT`（文字左对齐紧贴图标，间距=h_separation）。涉及：main_menu×7、difficulty_select×4、wall_clue_library×3、slot_dialog×2、reasoning_wall _mk_top_btn×1、side_panel×1、auth_panel×1。tool_bar 是首字 Label 按钮不涉及。
- **注意**：主菜单"开 始 游 戏"等按钮文字原靠全角空格舒展，LEFT 后内容整体靠左、右侧留白——用户要求"图标贴近首字符"优先；若要"图标+文字整体居中"需手动 pad（Godot 无组合居中开关，icon/text 分开对齐模型下 CENTER+CENTER 会重叠）。版本戳 v=20260906a。

### 预览 pck 一直加载旧版根因 + proxy 构建戳重定向（2026-09-06）
- **用户报"刷新几次也连不上最新 pck"**。取证：服务器端全链路正常（index.html no-store+新戳、pck 200 尺寸与磁盘一致、wasm MIME 正确、fileSizes=实际大小）。根因=**浏览器缓存的旧 index.html**：旧 html 的 fileSizes 是旧 pck 尺寸，loader 校验新 pck 下载尺寸不符直接报错——普通刷新复用缓存救不回来（AGENTS.md 已有"无 no-store 时期旧缓存条目普通刷新仍会复用"教训的复现）。
- **修复：proxy_server.py 根入口构建戳 302 重定向**——`GET /`、`/index.html`（及任何 v 参数不匹配的 /index.html?v=x）自动 302 到 `/index.html?v=<当前构建戳>`；戳从磁盘 index.html 的 mainPack 实时正则读取（每次导出打戳后自动跟随，无需同步 proxy），无 mainPack 时 fallback mtime。浏览器/中间层对 `/` 或 `/index.html` 的任何旧缓存都被绕开（重定向目标 URL 带当前戳，永不命中旧缓存条目）。HEAD 请求不走 do_GET（curl -I 验证不了 302，必须 GET）。
- **顺带清理**：web_build 下 3 个历史 pck 分片残留（index.pck-VrAhL4/-Vxu9nM/-vUpHqG，旧导出遗留、新 loader 无 `pck-` 引用）。
- **验证方法**：`curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:5000/` 应 302 到当前戳；用户端操作=普通刷新即可（强刷 Ctrl+Shift+R 更彻底）。

### 华生教学图第三版（2026-09-06，watson03 + 左肩锚定回退旧值）
- **教学图替换**：`watson_teaching.png` ← `assets/watson03.png`（与 watson01 同构图微调版 640×1663），引用路径不变。
- **左肩锚定用户裁定沿用旧值**：上一版把 shoulder 锚到右缘垂下左臂（cx0.79/cy0.48）用户实测"锚定范围不对"；从 `git show 044519a:godot_project/data/clue_image_anchors.gd` 考古旧版锚定（512 图时代），**shoulder=cx0.594 cy0.242 w0.20 h0.20（头下偏右上胸）用户认可**——新表直接沿用。**教训：换图重标锚点时，用户上一版认可的部位位置先考古旧值再决定要不要动，不凭新图轮廓自作主张重标**。
- 新表值：face cx0.49/cy0.07/w0.30/h0.14、wrist cx0.20/cy0.33/w0.24/h0.26、shoulder cx0.594/cy0.242（旧值）、torso cx0.50/cy0.42/w0.32/h0.32（**消毒液=上半身**，y0.26-0.58，用户指定）、pose 全图；scene1.gd 5 处 crop 回退同步（arm 的 crop 也指向 shoulder 区域）。
- 回归：test_watson_v6_anchor 断言同步更新（shoulder 断言从 cx≥0.65 改为 0.52..0.68 + cy 0.15..0.35）CLUE_ANCHOR_OK；导出 v=20260905i pck 120459292，预览 proxy 根路径已服务新构建。注意 scene1.gd 的 crop JSON 是**无空格紧凑格式**（`"crop":{"x":0.08,...}`），python 替换按此格式匹配。

### 华生教学图替换 + 消毒液线索改名（2026-09-05，用户三连需求）
- **教学图替换**：`watson_teaching.png` ← `assets/watson01.png`（像素风全身立绘 640×1663 透明底，用户上传），文件名不变、全部引用路径不动。锚点表 `data/clue_image_anchors.gd` 重标（PIL alpha 轮廓+肤色聚类定位人物部位）：face cx0.467/cy0.07（含发整头）、wrist cx0.19/cy0.31（画面左侧伸出的右手）、shoulder cx0.79/cy0.48（右缘垂下的左臂——arm 线索沿用此锚点名）、**torso 新增** cx0.50/cy0.40（躯干马甲区，medical 专用避免与 pose 重叠）、pose 全图不变。
- **锚点机制确认**：`clue_observer.gd` 在 setup 传入 `_portrait_ctrl` 时热点按钮由**锚点表统一归一化定位**（`_position_buttons`），scene1.gd 各线索的 x/y/w/h 字段此时不生效（仅无立绘的地点类线索用）——**换图只需改锚点表 + scene1.gd 的 crop 回退取景 + anchor 名**。
- **medical 线索改名**："医务工作者风度"→"身上有消毒液气味"（用户关系表原句）。改动面：`data/clues/clue_medical.tres`（name/description/observation/discovery_condition）+ scene1.gd 观察文案 + 5 处台词（h5_e、s0_e、s1_e 教程目标、s0_n、wv2 验证推理台词）。**线索 id "medical" 与 battlefield gate_clue_ids、CH01W 真相表全部不变**。3 个测试文件（test_watson_chain/test_star_layout/test_delete_edges）的线索 name 已 sed 同步。用户裁定：6 线索锚定尽量不重叠，脸色黝黑/面容憔悴可同锚 face（只能锚脸部）。
- **回归**：t_watson_img_smoke OK（scene1 编译+medical.tres 加载+纹理 640×1663）、test_watson_v6_anchor CLUE_ANCHOR_OK。**两个存量测试过期待对齐（stash 验证与本次无关）**：test_watson_chain.gd FAIL（期望 target 金边 C-A1/C-MAIN/C-C1→NPC_WT 全连+左右均分+W-C3 组合推断，与远程新逻辑"仅保留玩家连线/布局树只跟玩家结构"不符）；test_clue_anchor.gd 断言的 `_make_zoom/_drawn_rect` 内部 API 已被远程重构删除（该文件 5 处 Variant 推断已修：`:=` 接 load()/preload().new()/Variant 返回值必须显式 `: Variant`/`: Node`）。
- **导出**：v=20260905d，pck 69743064，fileSizes 已对齐；预览 proxy（常驻 pid）静态读盘，服务即新构建。
- **按钮字号统一规范（2026-09-05，用户裁定）**：游戏内全部按钮字体以主菜单「退出游戏」按钮（`main_menu.mkbtn` primary=false → fs **22**）为基准——**小于 22 调到 22，大于 22 保持**。共改 26 处 Button 字面量（reasoning_wall×3、wall_battlefield×2、wall_comparison×3、wall_history×2、wall_verify×2、wall_hypothesis、wall_clue_library×4（含线索卡片 Button）、graph_view_dock xbtn、slot_dialog、difficulty_select、auth_panel、side_panel、scene1 难度弹窗×2、detective_scene、tool_bar）+ 2 处 AcceptDialog 内建按钮（`get_ok_button().add_theme_font_size_override`）。**范围界定**：main_menu 的 `small=true` 变体（fs 20）全部用于主菜单/选项界面（起始界面），不在"游戏内部界面"范围，保持。**扫描方法**：Button 字号静态扫描必须覆盖 `:=` 推断声明（`var btn := Button.new()`），正则漏 `:=` 会漏掉 wall 系列全部——主题 .tres/.tscn 无按钮字号设置，全部按钮字号都在 .gd 代码里。
- **pck 内容验证方法修正（2026-09-05）**：**GDScript 在 binary tokens（script_export_mode=2）下所有字符串常量（含 ASCII id 如 W-B2）都不可 grep**——此前「NPC_MSG 可抓」仅因它在 tres 文本资源里。脚本内容验证改靠：测试脚本 `GODOT --headless -s res://tools/xxx.gd` 直接 load 同一源文件（如 t_eval_details 实测 truth=28 即证明真相表正确）+ 导出正常完成 + pck 大小变化。`strings`/二进制 grep 中文与 .gd 内 ASCII 均失效，勿再据「grep=0」误判 pck 旧。
- **导出窗口 X 关闭修复（2026-09-04）**：`graph_view_controller._show_export_panel` 的 `close_requested` 只把 `_export_panel` 置 null **未销毁窗口**——Godot Window 点 X 只发 close_requested 信号不自动关闭，需显式 queue_free。已改为 lambda 内置 null + queue_free。全项目仅此一处 Window 用法有此问题（detective_scene modal 的 close_requested→_close_modal 是正确写法），非通用问题。
- **对话头像通用构图（2026-09-04 两点设计要求，用户裁定）**：NPC bust 必须同时满足 **①肩部以上内容（不含上胸/交叠手）②充满对话框（内容占 512 画布 90~98% 高、底对齐）**，两点缺一不可。此前 hudson_bust 两连错：先只顾构图比例裁到上胸（89% 高）不符合"肩部以上"；再只裁肩部却没放大充满（53% 高偏下）。最终裁法：源图（1024x1024）取 x350-664/y20-378（头顶+颈+完整肩部），放大到内容高 94% 底对齐居中。**教训：改头像前先测同目录其他 bust 的 alpha bbox 占比对齐通用构图；两个约束要同时校验，不是满足一个就不管另一个**。
- **线索弹出界面统一（2026-09-04）**：场景一/二/三…所有线索观察放大弹出框走同一 `ClueObserver._open_zoom`（框 side=min(vp.x*0.42,500) 本就一致），观感差异来自**裁切区域宽高比**：场景一立绘是竖图（裁出竖长区域撑满框），场景二/三横图背景锚点裁出扁条（如 c201=225x115px→框内 500x256 上下空白显小）。修复：`_zoom_crop_region` 改**方形像素裁切**（以锚点中心为中心，边长=max(锚点像素宽,锚点像素高,0.35×图高)，clamp 图界）——横图热点放大后同样接近满框，场景间观感统一。**新增场景热点沿用此规则，无需各场景单独调框**。
- **场景一信息揭示时序约束（2026-09-04，用户裁定）**：福尔摩斯的台词**不得提前说出玩家尚未获得的信息**——委托信打开前只谈"有封委托信"，案件内容（地点/男尸/死因）必须来自信件原文（cl1 全文展示）或之后的现场勘查；**"像是中毒"这类无依据过早结论禁止出现**（信原文只说"未发现任何能说明致死原因之证据"）。落地：`scene1.gd _show_commission_letter_dialogue` 的 cl0 改为一句"信使留下的，是葛莱森警长的委托信。"；cl5 删"墙上有血字"（血字是场景二现场核心线索，提前说会削弱发现感）；委托信线索描述同步删"疑似中毒"。设计文档（assets/02_血字的研究_场景设计与流程.md）委托信 Step5 段已补"信息揭示时序约束"。**维护规则：新增台词先过"信息来源检查"——这条信息玩家此刻通过什么途径获得？**
- **存档导出与复盘工具（诊断链路）**：**入口=推理墙顶栏 row2「🗄 存档」按钮**（`reasoning_wall._on_export_save_pressed`）。教训：首版挂在 `side_panel.gd`——该类是**从未实例化的死类**（全项目无引用），按钮永远不可见；加 UI 前必须先确认挂载点真实在 UI 树里。实现：内存快照优先导出（`wall_state_export` 格式：`_state_store.duplicate(true)` + battlefield/battle_hypo_states/last_branch/last_stars + 槽位参考），弹 graph `_show_export_panel`（Godot Window）文本窗复制 + Web 下 base64 data URI 自动下载。拿到 JSON 后跑 `GODOT --headless --path . -s res://tools/analyze_save_report.gd -- <save_export.json>` 复盘：复用 WallBranchEvaluator（同一评分引擎）复算教学墙，打印 verdict/branch_ratio/insight_ratio/逐链明细。**注意：`_persist_state` 只持久化 associated/milestones_lit/battlefield/verified/verdict/doubt_book/relations——graph_nodes/derived_conclusions 不入档**，复盘工具按「relations 端点出现即视为节点产出」近似（内存快照格式 wall_state_export 中有真实 graph_nodes 时用真实数据）。云存档链路不可用（develop 库无 game_saves 表，迁移未跑；Web 构建存档实际只在浏览器 IndexedDB）。
- **连线交互**：点击连线命中检测（采样二次贝塞尔曲线 ×0.01 步长，容差 16px）弹出浮动菜单，支持删除连线 / 线型(dashed)切换 / 关系性质切换（relate→support→oppose→contradict）。关系变更统一走 `_undo` + `_do_*` → `_cb_relations_changed` → `_persist_view` → `_rebuild_graph()` 模式（`_redraw_all()` 不会重建 `_edge_list`）。
- **方向自动调整已实现（用户设计原则确认，2026-09-04 检查通过）**：`graph_view_edge._add_edge` 按 ring_depth 层级规范化（person=0 < conclusion=1 < hypo/chain=2 < clue=3，rd 小=层级高）：from 层级高于 to 时自动交换，保证「from=子（依据层）/to=父（被推导层）」——跨层反向拖拽自动翻转为 线索→推断→结论→人物；**同层连线（推断→推断）不翻转**（组合推导方向有语义，保持玩家拖拽方向）。`_kind_of`（graph_view_fold）全类型识别（conclusion_/chain:/battlefield hypo/persons/clues/_node_kind 兜底）。**推断→推断/推断→结论的交互入口存在**：拖线索入画布弹「可推导推断」候选窗（clue→hypo，graph_view_dock._open_derive_popup）；推断详情卡有「组合推导 ▾」（hypo→hypo，_open_hypo_derive_popup）与「推导结论 ▾」（hypo→concl）按钮——教学反馈缺边明细按边型标注对应操作路径（wall_verify._edge_hint）。
- **推理墙层级拖拽（根-树枝-分枝-叶子）修复（2026-09-04）**：用户实测拖树枝/分枝松手后子节点回弹原位。根因：**拖到空白=移动（_commit_move moved 分支钉位+rebuild ✓），但拖到节点 48px 内=建边（drop 分支不钉位）→ _add_edge → rebuild → X 未钉位回放射布局位回弹**（树形图节点密，48px 兜底极易误命中）。修复：①drop 建边/标记分支末尾同样钉位（`_root_anchor_pos[id]=_node_center[id]` + `_manual_nodes.append`），X 停在推离位、子树随 X 生长；②`graph_view_layout._compute_layout` 出口加**钉位重派生**保险（saved_pos 钉位节点以钉位为基准整体平移其未钉子树，覆盖孤立根分列等非规则2 路径）；③规则2（_assign_subtree 钉位分支"拖 2→3/4/5/6 随 2"）本就正确。回归 `tools/test_drag_follow.gd` 场景 A（拖人物根）/B（拖结论）/C（拖树枝到节点上建边）全 PASS。**注意：拖根跟随子树的前提是 relations 有链到根（结论→人物边）——没连线时"子树"在图结构上不存在，无从跟随**。
- **约束**：GDScript 只要关系字典就用 `r.get(...)`/`r["..."]`；`_relations` 元素是 Dictionary，可用 `e.dashed` 点读、写用 `e["dashed"]=...` 更稳妥。
- **响应式顶栏**：`reasoning_wall._create_top_bar` 用 VBoxContainer(col) 拆两行——row1 关键控件（标题/难度/线型/性质/人物星型/推理链/焦点/撤销/重做/提交验证/求助/关闭）、row2 次要工具（搜索/过滤/折叠/导出/连线）。顶栏 `offset_bottom=110`，图谱 `mid.offset_top=110`；`_mk_top_btn` 字号 16/最小 64x42，`_mk_sep`=6x40。此前单条 HBox 合计约 2450px 超出窗口导致「人物星型/推理链/提交验证」被挤出屏幕。
- **字号统一**：顶栏按钮 16、左栏“已收集线索”线索卡 18、连线说明 16；图谱节点 name≈40/sub≈20 为展示级字号，未改。「推理墙-血字的研究」标题保持原样（38）。
- **「已收集线索」只保留一套（reasoning_wall 左栏）**：`_create_ui` 不再把 `_left_panel` 放进 `mid`，改移动 `reasoning_wall` 顶层并 `z_index=20`（> 图谱 gv.z=5 < 顶栏100），且不隐藏——推理墙打开时左侧「已收集线索」常驻图谱之上，是**唯一**的线索列表（graph 自带的可折叠 `_create_clue_dock` 已废弃：`build()` 中不调用，避免两套系统；`_dock` 相关方法保留为死代码）。卡片显示、可点击/拖拽、拖入图谱后即消失（唯一性）。拖拽：`_make_clue_card` 额外 `card.gui_input.connect(_on_clue_drag.bind(clue["id"]))`；`_on_clue_drag` 用 Godot 粘性 gui_input 捕获（按下→移动>12px 起 ghost Label→抬起），若抬起点不在左栏矩形内（即落入图谱画布）则调 `_graph_view.place_clue(cid, 抬起点viewport坐标)`；图谱公开 `place_clue(cid, drop_at)`——落点 `drop_at` 命中图上一个已有节点（hypo/clue/conclusion，用 `_drop_node_except` 坐标转换与命中判定）时，**先 `_add_edge(cid, hit, "support","green",false)` 自动建绿实线关系**（`_add_edge` 内部会 `_mark_clue_placed`+persist+rebuild）再放置；落点为空白时仅放置（`_mark_clue_placed`+`_persist_view`+`_rebuild_graph`）。放置后 `_refresh_clue_list()` 即时隐藏该线索（独一性），细节卡「从图谱移除（归还线索）」`_unplace_clue_from_graph` 末尾补 `_cb_relations_changed.call(_relations.duplicate())` 使孤立线索（无关系边）也即时归还左栏。左栏提升后左上会出现覆盖图谱画布左 540px 的浮层（不会缩放图形，避免节点坐标溢出）。
- **验证命令**：`GODOT --headless --path . --script res://tools/test_wall_interact.gd`（顶栏按钮）与 `res://tools/test_wall_relations.gd`（边/关系链路）均 PASS；`test_wall_drag.gd` 在 headless 下因卡片重叠存在环境性失败。
- **节点重复悬挂（拖动中出现多个同名节点，如「右肩损伤」x5）防护**：根因在 `_rebuild_graph` 只对 `_node_views` 字典跟踪节点做 `queue_free`——拖动/place 触发多轮重建、字典被 reset 后，旧视图丢失引用成为孤儿残留在 `_canvas` 上，叠加成多个同名节点。修复分两路：① `_rebuild_graph` 清理段先遍历 `_canvas.get_children()`，把 `has_meta("graph_node")` 的历史图元全部 `queue_free`（新建节点与折叠控件统一 `set_meta("graph_node", true)`），保证每轮重建画布上同一 id 至多一份；② `_node_list` MODE_C 里「关联线索」与「已放置线索」本因嵌套在同一个 `for c2 in _clues` 内且关联线索 append 后未补 `_in_list` 可能被重复追加，已拆成两个独立循环并各自 append 后写 `_in_list`。数据源 `_clues` 本身各 id 唯一，无需担心数据重复。
- **节点卡片自适应（#1）**：`graph_view_controller._make_node` 不再用固定尺寸，据 `label` 长度自适应卡片宽（约 28px/字，封顶 480）并按换行数扩高；位置由 620 行 `position=center-size*0.5` 重新居中，边/菜单锚 `_node_center` 不受影响。name 标签加了 `autowrap_mode=WORD_SMART`。
- **教学线索不进入真实案件（#3）**：场景一示范为 source `watson`/`messenger`，`detective_scene._open_wall` 在 `use_case_wide`（场景二后全案池）时过滤掉这两个 source，避免华生/信使教学线索混入后续案件图谱。
- **每堵墙独立验证（#2）**：scene1 的华生与信使墙共享 `_wall_state`，华生墙验证后 `verified=true` 会泄漏进信使墙导致图谱锁定不可拖动；`_show_messenger_reasoning_wall` 打开前重置 `_wall_state["verified"]=false`。
- **双级存储（#4）**：`reasoning_wall._on_back_pressed` 退出墙只调 `_persist_state()`（内存态 `_state_store`，即临时存储），不再调用 `_on_persist`（落盘）。长期存储（写档）只由 ①手动存档（side_panel）②场景结束自动存档（`_save_and_transition`/`_save_and_continue`）触发，二者会快照当前内存态。场景二后的基类 `_do_save` 目前只写 `clue_ids`，wall 布局只在 scene1 的 `_do_save` 写入存档。
- **跨场景共享推理大图（除教学外一张大图）**：全案墙（`detective_scene._open_wall` 中 `source==""`→`use_case_wide`，覆盖场景二~八）的图谱状态提升为**全案跨场景共享**——`ClueSystem.case_wall_state: Dictionary`（autoload 常驻、随存档 snapshot 保存与恢复、`new_game`/`clear_collected` 时清空）。`_open_wall` 在全案墙分支把实例 `_wall_state` **指向 `ClueSystem.case_wall_state`（同一引用）**，墙 `_persist_state()` 写入即跨场景驻留；场景切换后新场景 `_wall_state` 重新 `={}`（基类行内重建防类级字典共享）再次 `_open_wall` 又指回共享态——前一场景建立的图谱（关系/节点位置/折叠/放置）自然带到下一场景。场景一教学墙（`source="watson"/"messenger"`）仍用实例 `_wall_state`（双墙独立，不污染案件共享态）。**折叠**：`_open_wall` 传 `use_case_wide` 给 `setup` 的 `_auto_fold`，新场景打开大墙时若 `_folded_nodes` 空且已有 `_relations`，自动播种折叠已确立推理主干（conclusion/person/chain）→"前一场景内容统一折叠到人物/节点下"。回归：`tools/p12_scene2_to_scene3_e2e.gd` 断言场景三墙线索=19（6 garden+13 indoor 全案池并入，>13 即证明跨场景线索并入），全链路 P12_E2E_OK。
  - **全案平铺（多人物分组铺开，2026-08）**：用户要求全案墙把所有已收集线索/推断/结论**都**作为节点引入（场景切换后前方场景线索可能是孤立节点，随剧情后续与人物建关系），且**按人物分组平铺**。落地：`setup` 尾参（即 `_auto_fold`，值=`detective_scene` 传的 `use_case_wide`）同时存入 `_case_wide: bool`；reasoning_wall `_on_open_graph_view` 把 `case_wide` 传 `gv.build`。graph 侧：`build` 读 `"case_wide"`；`_node_list` MODE_C 在 `case_wide` 分支**不再用 `_clues_for_person(focus)` 过滤**，而是 append 全部 `_persons` 为人物节点 + 全部 `_clues` 为线索节点（平铺）；`_relation_tree_layout` 本就遍历所有 person 作根各自成树、孤立线索外围散布，多人物分组天然成立。教学墙（case_wide=false）仍走单焦点模式。**回归**：`tools/test_case_panorama.gd`（CASE_PANORAMA）断言 case_wide 下全部线索平铺、多人物分组、孤立线索也展示，8 PASS。
  - **适应画布（内容多画布小、内容少画布大）**：画布为缩放/平移相机模型（滚轮缩放 + 平移），内容多可缩小看全貌。row1 新增「🔎 适应」按钮调 graph `fit_view()`——遍历全部 `_node_center` 包围盒，按视口算最小缩放比并居中（`_fit_bbox` 限制下界防过度放大），实现一键看全；仍可滚轮继续微调。
  - **自动排列（2026-08 顶栏按钮）**：顶栏 row1「\uD83D\uDD04 自动排列」调 `reasoning_wall._on_auto_arrange_pressed` → `graph.auto_layout()`。`auto_layout` 置 `_use_rank_layout=true` 触发 `_rebuild_graph`（`_compute_layout` 据此切到 `_auto_rank_layout`），随后 `_persist_view` + `fit_view` 看全。`_auto_rank_layout` 与现有 `_relation_tree_layout` 同级分支：以 persons 为 col0（BFS 求深度），所有节点按深度分列（person 最右、向外逐列左移 col_gap=300），无关系游离节点归最左列；同列用 barycenter 均值法 3 轮迭代对相邻列邻居排序降交叉，再按 ROW=130 纵向堆叠、`_apply_column_overlap_fix` 兜底防重叠。即参考「人物→结论→推断→线索」横向分层思维导图的一次性整理，对手工拖乱/重连后的布局一键归位。**不动**默认 `_relation_tree_layout`（持续建边时仍走它）。回归：`tools/test_auto_layout.gd`（AUTO_LAYOUT_OK：分列对齐+同列间距）、Q6 契约束新增自动排列断言。
  - **验证状态不跨场景锁定（关键坑）**：`case_wall_state` 跨场景共享**只该共享图谱内容（relations/节点/折叠/放置）**，不能连 `verified`（已验证锁定）一起带过去——否则场景二墙提交验证后 `verified=true` 写进共享态，场景三打开同一共享态整个图谱被 LOCKED（右下提示「已封存，仅可浏览」，所有节点冻结不可拖选）、且场景二内容因被折叠+锁定而看似丢失。落地：`_open_wall` 全案墙分支在 `wall.setup` 前**重置 `_state_store["verified"]=false`、`["verdict"]=0`**（只清验证锁，保留 relations/节点/折叠），使每个新场景墙都回到可编辑。玩家在同一场景内提交验证后重开墙也会被重置（可继续编辑，符合预期）。回归：`EDITABLE_DECO` 单测（case_wall_state 带 verified=true 打开→重置后 verified=false 且 graph_relations 保留）。
  - **身份揭示占位（神秘嫌疑犯）**：`_identity_revealed(pid, live)` 未满足揭示证据的 NPC（如 NPC_HOP 未收 C_SOTCB_501/502）在人物中心**不剔除而是保留**，显示名 `_npc_display_name(pid)` 对未揭示者返回「神秘嫌疑犯」占位（revealed 才返真名）——保证案件人物中心始终有【死者+神秘嫌疑犯】等节点，凶手身份揭示后再换真名，不提前曝名也不整节点消失。`_derive_persons`（reasoning_wall）与 graph build 兜底两处统一应用。
- **按关系驱动的横向阶梯树布局**（`_compute_layout` 的 MODE_C 调 `_relation_tree_layout`，它是当前启用的布局；旧 `_xmind_layout` 仅作参考保留，不再调用）。核心语义（对照用户 华生示范：人物→结论→推断→线索 整条推理链阶梯树）：
  - **以关系驱动建树（人物→结论→推断→线索，B 序列）**：`_build_adjacency` 取消「人物↔全部线索」自动连边（曾让线索成为人物直接子节点并连棕线，表现出 A 序列观感），改为**人物只锚定到结论节点**（常量 id `"conclusion"`，不用 `_node_list()` 判定以避免 `_node_list→_derive_edges→_build_adjacency` 无限递归）；线索-人物连线在 `_redraw_all` 已移除。人物=根(col0) BFS，邻居"性质层更深者"作子（conclusion→1、chain/hypo→2、clue→3，person→0），每节点只承接一次防环；同父子树归组（`_collect_high` 靠后序统计子带高 `high`），父居中于其子树纵向带（`_assign_subtree` 叶子累计、`top2/bot2` 分配）。
  - **方向不硬性统一**：人物居中/偏右/偏左时树自动朝画布空余侧生长（`dirv` 由 `saved_pos` 与空余空间决定）；人物可自由移动、位置保存位优先；多人物各自一棵独立子树、纵向带独立互不交叉。
  - **每次增删关系自动重排**：`_rebuild_graph`→`_compute_layout` 每次对整棵树重排（非根节点不用 `saved_pos` 沿用），孤儿/孤立线索留在外围按 `saved_pos` 鼻孔放置。
  - **全部节点可自由移动（手动固定）**：`_manual_nodes: Array` 记录玩家拖动过的节点（`_build_adjacency` 勿调 `_node_list()`，见上递归坑）；`_commit_move` 空位释放时加入并写入 `_state_store["graph_manual_nodes"]`，`_persist_view` 落盘。`_relation_tree_layout` 收尾把 `_manual_nodes` 里已保存位置的节点恢复到 `out`，避免每次增删关系重排把它们拉回。曾因「按下即折叠子树+`_rebuild_graph`」打断拖拽导致只有游离线索能移动，已移除该逻辑。
  - **MODE_B 推理链视图为纵向自上而下**：根在上、row2 向下，每行树子树紧凑排布。
  - 布局收尾对所有节点 `_clamp_to_canvas`（margin 60）防止文本框挤出可视区。拖拽落下走 `_clamp_to_canvas(new_center)`。函数用 `else` 包裹/末尾 `for idf in out` 钳制，避免裸 `return`（项目把 void 函数返回当错误）。
  - **结构断言**：`tools/test_xmind_diag.gd` 现改为校验启用的 `_relation_tree_layout`（XMIND_DIAG3）——注入多链 `_relations`，断言整链沿树向外逐列外扩(列x单调)、同列不重叠(≥30)、树完整、全在画布内、方向随人物自适应。旧 `_xmind_layout` 单测已废弃。
  - 坑：match 的类型分支写字符串 pattern 时**勿加多余冒号**（曾写成 `":conclusion":` 导致结论落入默认层 4）。可复用 `tools/test_xmind_diag.gd` 校验该结构（覆盖默认/人物在左/人物在右三态）。
  - **节点卡配色（对照华生示范）**：人物=红框+浅色字（`font_col`/`sub_col` 置浅色）、结论=浅棕（`Color(0.82,0.68,0.42)`+棕金边，不再用 `_verdict_color()` 染色）、推断(hypo)=浅蓝、线索=浅绿（常量 `COL_CLUE_*`/`COL_HYPO_*`，注释标“对照示范”）。sub 标签用 `sub_col` 而非固定 `COL_GREY`。
  - **线索放置唯一性（placed-clue 模型）**：线索在两个锚点间存在唯一性——左侧「已收集线索」栏与图谱节点互斥。落地：
    - `_placed_clues: Array`（图谱成员）经 `_state_store["graph_placed_clues"]` 持久化，`build`/`_persist_view` 加载与写回（共享 `_state_store`，reasoning_wall 直接读该键判断）。
    - 放置时机：`_add_edge` 在端点是线索时调用 `_mark_clue_placed`（关系创建即视为“放入图谱”）。`_remove_edge`（删除关系）**不**解放置——满足「删除线索-推断关系不回收线索」。
    - **孤立线索保留（需求1）**：`_node_list` MODE_C 除关系线索外，另把 `_placed_clues` 中未进列表的线索追加为节点，即便无人物关联、无关系也显示为孤立节点。
    - **唯一解放置路径**：详情卡「从图谱移除（归还线索）」→ `_unplace_clue_from_graph(cid, card)`：删全部涉及该线索的关系边、`_unmark_clue_placed`、归还左栏、`_persist_view`+重建+toast。按钮显示门控 `_clue_placed(id)`。
    - **左栏过滤（需求3）**：`reasoning_wall._refresh_clue_list` 跳过 `_state_store.get("graph_placed_clues",[])` 中的线索；`_gv_relations_changed` 回调末尾补 `_refresh_clue_list()` 使放置即时反映到左栏。初始全在左栏、由玩家拖入图谱。
    - 详情「线索」分支按钮必须在 `if _state == State.EDITABLE:` 块内按正确缩进追加（曾因 g1 补丁缩进错位导致 `rmv_btn`/`cid` 未声明解析错误）。
  - **场景切换自动折叠（需求2）**：`setup(... , auto_fold: bool)` 尾部新参、`build` 收 `auto_fold`；`detective_scene._open_wall` 传 `use_case_wide`（场景二+ 案件级大墙=自动折叠，场景一教学墙不折叠）。`graph build` 在折叠状态恢复后，若 `auto_fold` 且 `_folded_nodes` 为空且已有 `_relations`，把关系端点中深度0的根（conclusion/person/chain）批量写入 `_folded_nodes` 并 `_persist_view`——收起已确立的推理主干，聚焦最新线索/推断；玩家手动展开/折叠会覆盖，重开不再重复播种。
  - **折叠隐藏连线（需求4批）**：`_on_edge_draw` 顶部 `_fh = _compute_hidden()`，任一端点在折叠集合的边一律 `continue` 不绘制——彻底避免“折叠后连线残留”。折叠盒本身经 `_node_list` 过滤隐藏节点后在画布上消失，此守卫兜住可能的残留中心（如拖动/持久化带回）。
  - **垂直 15px 间距与自适应宽度（需求4批）**：
    - 节点卡宽度上限 `_MAX_W = 420 = 15×font28`，单行最多 15 汉字，超出换行（自适应宽度取 `max(natural, 420)`）。`_make_node` 先读 `lab.get_minimum_size()`（≤420 用自然宽），再 `size = registered_now` 自适应高；无字体时 fallback 到 `_est_node_h`（fs28、line_h=28×1.35、sub=22×1.35，`_est_node_h` 与真实 `_nh≈inner_h+12` 基准一致）。
    - **15px 不重叠的「硬保证」**：布局层的 `_subtree_span_est`/`_assign_subtree` 只保证「子树带」间 ≥15px，对同级卡片成立，但**不同子树/父与子/多人物之间的同列卡片仍可能过近甚至重叠**（含估高误差、卡片实际比带宽高等）。因此在 `_rebuild_graph` 建完所有节点视图后调用 `_apply_column_overlap_fix()`：按列（round x/4）分组、按 y 排序，用**每张卡片真实高度** `_view_height(id)`（view.size.y，fallback 估高）强制相邻卡片中心距 `≥ (h_prev+h_cur)/2 + 15`，任一不满足就把后者整体下推（排序保证级联传递），再写回 `_node_center` 并重设 view.position。这是无论布局算法/估高/多根/游离都不重叠的兜底。代价：同列节点可能被下推，已靠 `_clamp_to_canvas` 兜住右下。
    - **回归覆盖**：`test_xmind_diag.gd` 现在布局后**真实调用 `_apply_column_overlap_fix()`**（注入 `out→_node_center`、置空 `_node_views` 使走估高 fallback），并新增断言「同列卡片垂直**边缘**间距 ≥15px」（此前只断言中心距 ≥30，对 ~80 高卡片其实仍重叠约 50px，覆盖不了需求）。三态（默认/人物居左/居右）均 PASS。

  - **导出模板非持久坑**：Web 导出模板软链在 `/root/.local/share/godot/export_templates/4.7.1.stable/`（非持久），沙箱回收 `/root` 后模板丢失，`--export-release` 会报 `_fs_changed`/No export template found。持久源在 `tools/godot/web_*.zip`，导出前失败先跑 `bash tools/godot/setup_godot.sh` 幂等重建软链。`RM` 判断导出进程是否成功：`GODOT ... --export-release "Web" > /tmp/e.log 2>&1; echo $?`，不要用 `| grep` 的退出码。
    - 布局按**子树所需垂直带长（span）**分配，不再按节点估高 `seg` 切分（旧法：父带过窄时子带 `seg < _req` 钳制到 `_req` 会溢出进邻子树，导致两链推断同列同 y 重叠，如 `test_xmind_diag` XMIND_DIAG3 曾 FAIL）。落地：`_subtree_span_est()` 后序算 `span(u)=max(est_h[u], Σspan(child)+15×(n-1))`；根带高 `= span(root)`；`_assign_subtree` 按 `span(child)` 精确切子带、`cur += span+15`、剩余空间居中，保证兄弟/后代不交叠、上下≥15px。
  - **人物焦点不串墙（需求4批）**：`reasoning_wall._on_open_graph_view` 里 focus 取 `_state_store["graph_focus"]` 后，若为空或**不在本墙 persons 集合**（`_persons_contain`），回退到 `persons[0]` 并写回 `_state_store["graph_focus"]`——杜绝共享 `_wall_state` 里上一墙残留焦点污染下一墙（如信使墙显示成华生）。场景一华生/信使 hypo 各自声明 `persons`（watson→`NPC_WT`，messenger→`NPC_MSG`），`_NPC_DISPLAY_NAMES` 新增 `"NPC_MSG": "信使"`。
  - **详情弹窗盖左栏（需求1）**：详情卡 `card.z_index` 只在其父 graph_view（整树 z=5）内部生效，**盖不过** reasoning_wall 左栏「已收集线索」（z=20）——被遮挡看不到内容也关不掉。修复：`_show_detail` 把 card 挂到 `get_parent()`（reasoning_wall 顶层）= 左栏的兄弟容器，`card.z_index=30`（>20 盖左栏、<100 顶栏仍可点）。挂载做了空父 fallback（仍 `add_child(card)`）。位置 `Vector2(40,80)` 仍是视口坐标，父容器不影响。
  - **身份揭示门控 / 凶手名不提前暴露（需求2）**：场景三墙走 `use_case_wide`（全案池），会把现场线索（`data/clues/clue_c203~206.tres` 的 `related_npcs=["NPC_HOP"]`）拉成人物中心，导致推理阶段直接显示「霍普」——剧情上只有收到从美国来的电报（`C_SOTCB_501` 马车公司信息 / `C_SOTCB_502` 霍普身份，均场景五后）后福尔摩斯才得知真名。落地：`graph_view_controller.gd` 与 `reasoning_wall.gd` 各自新增常量 `_IDENTITY_REVEAL_GATES={NPC_HOP:[C_SOTCB_501,C_SOTCB_502]}` + 函数 `_identity_revealed(pid,live)——live=当前已收集线索`，在 `build` 兜底与 `_derive_persons` 收集人物时过滤未揭示者。回归方向：无电报时 `NPC_WT/DRE` 仍显示而 `NPC_HOP` 隐藏，收电报后全部显示。
  - **拖到下级文本自动建边（需求3）**：`_commit_move` 已现成满足——拖「线索1」到「推断1」等 hypo/clue/conclusion 落点 → `_add_edge(id, drop, key_to_kind(_pen_color_key), _pen_color_key, _pen_dashed)`，默认 `_pen_color_key="green"`、`_pen_dashed=false` = 绿实线 support。无需改动；仅当拖到 person 时语义变为打标签 `_tag_person`。
  - **顶栏「添文本框」工具（2026-08-24）**：`reasoning_wall._create_top_bar` 的 row2（次要工具行）新增「➕ 添加」组，含四个按钮（🧾线索 / 💡推断 / 🏁结论 / 🧑人物），点击调 `_on_add_text_node(kind)` → `_graph_view.add_text_node(kind)`。`graph_view_controller.add_text_node(kind)` 生成唯一 id（`note_<kind>_<seq>`，据 `_node_center` 判定唯一）、`kind∈{clue,hypo,conclusion,person}` 走 `_make_node` 对应配色、写 `_graph_nodes`（持久化键 `state_store["graph_nodes"]`）+ 初始位置写 `graph_node_positions` + persist + rebuild。`_graph_nodes` 在 `_node_list` MODE_C 的 conclusion 之后、折叠过滤之前统一 append 为独立节点（无 relation 边时按 `saved_pos` 作为孤立节点搁置，可手动连线/移动）。
  - **拖动放开区域（2026-08-24）**：新增 `_clamp_free(p)`（允许节点中心超画布±120px，即约半张卡），拖动 move 分支用 `_clamp_free` 替换原 `_clamp_to_canvas`（margin 60）；`_commit_move` 本就不 clamp，仅做建边/记录 `graph_node_positions`。布局收尾仍用 `_clamp_to_canvas`（margin 60），避免布局自动排到画布外。
  - **读档阶段对齐（2026-08-24）**：场景二结束档此前 phase=TRANSITION，读档走 `_enter_transition()` **重放过场对话**；而场景一终局 COMPLETE 用自定义 `_restore_saved_state` 直接 `_show_rating()` 展示结束面板——同一读档机制两种结果。修复：scene2 `_apply_restored_phase` 的 TRANSITION 分支改为直接 `_show_scene_rating("场景二 完成 · 侦破过程", "res://scenes/scene3.tscn", Callable(self,"_save_and_transition").bind("scene2","res://scenes/scene3.tscn"))`。基类 `_is_terminal_phase(TRANSITION)=true` 已置 `_suppress_terminal_save`，点「继续推进」不重复存档直接切入 scene3。场景三及以后如有同样终局读档诉求照此模式对齐。
  - **读档跨场景关系回归（2026-08-24）**：P12 是内存内连续路径，不覆盖「读档→场景三开墙」链路。新增 `tools/p16_save_scene3_wall_relations.gd`：scene2 建立关系 → `SaveSystem.request_save` 落盘 → 清空 `ClueSystem.case_wall_state` → `SaveSystem.load_game` 读档 → 断言 `case_wall_state.graph_relations` 从磁盘完整还原（P16_E2E_OK）。⚠️ slot 范围 `0..SLOT_COUNT-1`（当前 SLOT_COUNT=3），越界读档静默失败（load_ok=false，曾误判为关系丢失）。新注册 `tools/test_top_addtext.gd`（TXT_E2E：add_text_node 唯一 id/default kind / graph_nodes 持久化恢复 / _clamp_free 放开 vs _clamp_to_canvas 收紧）。
  - **拖动可建边实时提示（2026-08）**：move 拖拽分支实时调 `_drop_node_except(mouse_canvas,_drag_id)`，命中目标时把拖动节点 `n.modulate.a=0.5` 半透明 + `n.scale=0.9` 缩小 + `n.z_index=20` 置顶，非命中复原——让玩家直观看出"拖到框上可建边"，与松手 `_commit_move` 建边判定一致（都用鼠标画布坐标）。
  - **详情窗口滚动（2026-08）**：`_show_detail` 内容包进 `ScrollContainer(vb)`，卡片内容多时可滚动到底选到下部按钮；定位改「中部偏左 1/4」（视口宽 23% + 垂直居中）避开顶部功能栏（z=100）。
  - **自定义文本框删除/回收（2026-08）**：详情卡「🗑 删除文本框」`graph_view_controller._delete_text_node(id)`：从 `_graph_nodes` 移除、删除相关关系边、若被折叠则 `_folded_nodes.erase(id)`、记入 `state_store["graph_deleted_nodes"]`（`_graph_deleted`）+ persist + rebuild；顶栏「🚮 回收站」`_on_recycle_pressed` 弹滚动列表列出已删节点，点选 `_graph_view.restore_text_node(id)` 从回收站放回 `_graph_nodes` 重建，防误删。`_state_store` 是共享 dict，deleted_nodes 经它自然持久化不需 build 单独加载。
  - **Details 文本编辑（2026-08）**：详情卡「编辑内容」存 `state_store["graph_edited_texts"]`（`_edited_texts`），渲染 label 统一优先取 override，跨重开恢复。
  - **线上登录 token 持久化（2026-08）**：`auth_manager._save_session` 现同时存 `token` + `mode`；`_restore_session` 读到 session 含 token 时直接恢复在线会话（设 `session_token`、`APIManager.auth_token`、user_data），不再要求本地账号库匹配——修复"线上账号刷新后必须重新输入"。⚠️ auth_manager 用 `APIManager.is_online`（不是 BoardSession）。
  - **登录/注册输入框粘贴（2026-08）**：`auth_panel._make_field` 给 LineEdit 连接 gui_input，Ctrl+V 用 `DisplayServer.clipboard_get()` 插入光标处（Godot 默认不支持粘贴）。

#### 2026-09 存档读档线索恢复（detective_scene.gd）
- **游客不可存档是我们确定的设计**（鼓励注册），`_do_save`/`_do_load` 对 `GameManager.is_guest` 直接 `_ui.show_notification` 拒绝并 return——**勿改回游客可存档**。
- **读档后线索显示未收集的根因**：`_restore_saved_state` 原来内联 `_get_hotspot(cid)` 只重建「热点线索」，对话/工具授予的非热点线索读档后丢失。已改为统一调 `_restore_clues_from_ids(saved_ids)`——它会用存档 ids + `ClueSystem` 已恢复的 collected(`prior`) 一并回收热点与非热点线索。**读档恢复线索务必走该方法，勿用奄试 `_get_hotspot` 单点重建**。
- 回归：`p12`(P12_E2E_OK)、`p16`(P16_E2E_OK，登录态存档→读档→场景三墙还原 scene2 线索与关系)。

#### 2026-09 修复：图谱画布让出顶栏/左栏 + 场景一教学墙线索默认进左栏

用户反馈三处：①场景一默认线索仍在画布（场景二正确）；②左栏看到但不可点，拖动变画布平移；③顶栏按钮仅上 1/5 可点，下部 4/5 点按拖动为画布移动。

- **根因①：非 case_wide（场景一教学墙）仍平铺线索上画布。** `graph_view_controller._node_list` MODE_C 的 case_wide 分支早已改为只取 `_placed_clues`（已放置线索）；但**非 case_wide 分支**仍用 `_data._clues_for_person(_focus_person)` 平铺，且兜底 `if clues.is_empty() and not _case_wide: clues = _clues` **无条件把全部线索塞进画布** → 场景一线索仍在画布。修复：非 case_wide 改走与 case_wide 一致的「仅 `_placed_clues` 已放置线索进画布」，并**移除该兜底**（未放置线索默认留左栏，由下方「关联线索」「已放置线索」两段补入已介入节点）。回归：`tools/q5_scene1_leftbar.gd`（Q5_OK：画布无线索、线索在左栏，需先 `await process_frame` 再 load 墙脚本否则 ClueSystem autoload 未注册编译失败）。
- **根因②③：图谱画布 `_clip` 全屏 STOP 覆盖顶栏/左栏。** `graph_view_controller_gd._create_ui` 中 `_clip`（负责平移/滚轮，`mouse_filter=STOP`）原 `PRESET_FULL_RECT + offset_top=64`，从 y=64 往下全屏拦截——正好盖住顶栏按钮下部（row2 约 y54~104）与整个左栏「已收集线索」栏，故点击落到 `_clip`（画布平移）而不是顶栏/左栏。修复：`_clip.offset_top=64→110`（让出顶栏，正好在顶栏底之下）并新增 `_clip.offset_left=540`（让出左栏宽）。图谱坐标转换一律用 `_canvas.get_global_transform() * viewport_pos`（`_on_canvas_left_click`/`_zoom_at`），改 `_clip` rect 不影响平移/缩放/命中的坐标系；`_canvas`/节点锚 FULL_RECT 跟随 `_clip`,世界坐标起点=clip 左上 (540,110)。**拖节点 `_clamp_free` 允许超界 ±120 会把节点拖进左栏下被 z=20 左栏盖住（视觉），可接受（UI 优先），不要回退此改动。**

- **游客本地存档（#1：收集后存档→读档线索显示未收集）**：`detective_scene.gd` 的 `_do_save` 里 `if GameManager and GameManager.is_guest:` 分支此前直接 `show_notification("游客模式暂不支持存档") + return`——游客存档被拒、读档自然全部丢失。改为游客跳过云同步但**仍落本地盘**（走 `clue_ids`- 快照 + `request_save`），仅提示“未登录，已保存到本地”。存档按 `_user_namespace()` 区分游客/登录玩家互不串档。回归：`Q1_OK`（scene2 收集→`_do_save`→`load_game`→`collected 恢复 N`）。
- **全案墙线索默认进左栏（#2：默认已收集线索放左栏不放画布）**：`graph_view_controller._node_list` 的 MODE_C 在 `case_wide` 分支此前 `clues := _clues` 无条件把**全部已收集线索平铺进画布**。改为 `clues := _placed_clues` 过滤（仅已放置的线索作为图谱节点）+ 已有关系线索；未放置线索留在左栏由 `_refresh_clue_list` 展示、玩家拖入。自定义文本节点（`_graph_nodes`，含 `add_text_node` 创建）不受影响走单独追加。回归：`tools/q2_leftbar.gd`（Q2_OK：case_wide 下人物平铺、线索默认不在画布、左栏可显示）。⚠️ 语义变更后，**已建关系/已放置的线索仍会进画布**（`_placed_clues` 跨场景经 `case_wall_state["graph_placed_clues"]` 持久化），未放置线索仅在左栏。
- **折叠时一并收起关系子树（#3：新推断/线索建边后点击折叠无法把线索折叠，只隐藏连线）**：`graph_view_fold.gd` 的 `_set_folded` 在折叠一个节点时，仅把它记入 `_folded_nodes`，但未把它的**关系子树（邻接 BFS 中的更深层节点，如推断下的线索）**一并加入折叠集合，导致折叠只隐藏连线、线索节点仍在画布。修复：折叠根节点时用 `_compute_hidden` 收集其关系子树中「层级更深的节点」一并写入 `_folded_nodes`（展开时不清除子树折叠，保留用户折叠深度）。回归：`test_case_panorama.gd` 折叠断言 PASS（折叠推断→线索被折叠隐藏）。⚠️ 测试「无人物注入」FAIL 为注入数据差异，非产品 bug。
- **测试注意**：graph 重构为组合架构后组件在 `_ready` 初始化，**SceneTree `--script` 直跑的测试若 new `GraphViewController` 后直接 `build()` 会因 `_edge/_fold/_data` 组件 Nil 报 `Nonexistent function`**。需把 graph 先 `add_child` 进树触发 `_ready`，或经 `ReasoningWall` 打开。`test_case_panorama` 的 2 项 FAIL（自定义 note 建边、无人物注入）是注入数据/运行环境差异，**非产品 bug**——真实路径由 `p12`（P12_E2E_OK）/`p16`（P16_E2E_OK）覆盖。

### 推理墙重构后（组合架构）的测试/脚本 API 适配

2026-08 拉取远端重构：`graph_view_controller.gd` → `scripts/clue/graph/`（data/dock/edge/fold/layout）；`reasoning_wall.gd` → `scripts/clue/wall/`（clue_library/state/battlefield/comparison/history/hypothesis/relations/verify）。类从「继承」改为「组合」——ReasoningWall 通过 `_clue_ctl`/`_verify_ctl` 等组件实例转发 API。**旧 e2e 测试（tools/*.gd）若直接调原推理墙方法会报 Nonexistent function 并触发 WATCHDOG 超时挂死**，必须按下列新访问路径改写：

- `_toggle_association`（线索关联）→ `wall._clue_ctl._toggle_association(cid)`（原 `wall._toggle_association`）
- `_on_verify_pressed` / `_on_verify_confirm(v)` → `wall._verify_ctl._on_verify_pressed()` / `wall._verify_ctl._on_verify_confirm(v)`
- 仍留在 ReasoningWall 可用：`get_verdict()`、`_clues`、`_state_store`
- 场景侧不变：`s2._obs._record(h.id, desc)`、`s2._open_wall()`、`wall2._clue_ctl`、窗口取 `s2.find_child("ReasoningWall", true, false)`

适配完成后回归通道：`p12_scene2_to_scene3_e2e.gd`（P12_E2E_OK：场景二→三真实路径）、`p16_save_scene3_wall_relations.gd`（P16_E2E_OK：读档→场景三墙还原 scene2 关系）、`p15_architecture_unification.gd`、`p0_smoke_test.gd`、`smoke_load_check.gd`。改完推理墙源码后必须 `--export-release "Web"` 重导 pck，否则预览仍旧版。

### 推理墙图谱 · 功能架构基线 + 改动前 Gate 规范（2026-08，必须遵守）

**定位**：本模块是同类别里最容易"修一坏一片"的耦合点（多次出现改一个点带出三四个新问题）。下列是整理出来的**权威功能架构基线**与**规范性要求**。**任何对推理墙图谱（graph_view_controller.gd / scripts/clue/graph/ 组件 / reasoning_wall.gd 图谱相关部分）的改动，必须先对照本节；违背规范的改动必须先给建议并请用户确认，不能直接动。**

**A. 功能架构基线**
1. **组合架构**：`graph_view_controller.gd` 拆为 `scripts/clue/graph/`（data/dock/edge/fold/layout）；`reasoning_wall.gd` 拆为 `scripts/clue/wall/`。组件在 `_ready` 初始化，改 API 走 `owner._xxx` 组件转发，别直接 new 后即调（组件会 Nil）。
2. **显示/命中（契入让出）**：图谱根 `mouse_filter=IGNORE`；`_clip` 用 offset 让出左栏(540)/顶栏(110)（契入=单源 `hit_off_left/top`），`clip_contents=true`；`_clip` 与 `_canvas` 均 `STOP + gui_input(_on_canvas_gui)` 承担平移/滚轮/空白点击/shift 建边/折叠命中。**禁止命中分离层 `_hit_layer`**，禁止把 `_on_canvas_gui` 从 `_clip`/`_canvas` 摘走（否则 shift 建边/折叠失效）。
3. **世界坐标**：契入后 world 原点=图谱区左上；一切命中/坐标换算统一用 `_canvas.get_global_transform().affine_inverse()`（自带 clip 偏移）。仅手工写 `_canvas.position` 的 `_zoom_at`/`fit_view` 才需按 `_clip.get_global_transform().origin` 校正，其它（`_pan` 增量）不用。契入只用 `_clip` 裁显示+命中，**不把 `_canvas` 布局基准改成契入区**（反补 offset 保持整墙画布，防止重排挤压/覆盖）。
4. **布局**：默认 `_relation_tree_layout`（按关系建树：人物根 col0、结论→推断→线索逐层，父居中子树带、列对齐防重叠）；显式“自动排列”按钮走 `_auto_rank_layout`（BFS 深度分列 + barycenter 同层减交叉）→ `_use_rank_layout` 标志切换；`_apply_column_overlap_fix` 兜底防同列重叠。**布局只在「建/删边、拖关系、自动排列」时机整图重排**。
5. **折叠**：`_folded_nodes` 存折叠根 + 整棵子树；`_compute_hidden` 隐藏深一层子树；折叠根仍显示为文件夹（暗金框）并保留折叠圆圈；**只有“存在更低一级(有下级)”的节点才显示折叠圆圈**，无下级节点不显示（线索=证据最底层，通常无圆圈）。折叠/展开走 `_fold_keep_layout` **保持局部性**：只隐/显自己的下级子树，不重排上级/无关文本框。
6. **折叠对称性**：展开必须把折叠根**连同整棵子树**从 `_folded_nodes` 移除并还原位置（否则线索/下级展开后仍隐藏）。
7. **契约束守卫**：`tools/q6_contract_guard.gd`（源码断言：clip/canvas STOP+gui、契入用 hit_off、无 `_hit_layer`、`_zoom_at`/`fit_view` 含 `_clip` 原点校正、auto_layout/use_rank 契约）。改过相关源码后必跑 Q6。

**B. 规范性要求（改动 gate 条款）**
1. **先对照再动手**：本模块任何改动前，先读本节 + `q6_contract_guard.gd`，判断改动是否违背上述基线。违背 → 暂停，给出建议 + 影响评估 + 请确认后再改；不违背 → 直接改。
2. **最小局部改动**：修 bug 不顺手重构、不扩大联动面；只改任务所需的点。
3. **折叠遵守“局部 visibility”**：不得让折叠/展开触发整图重排；不得让无关/上级文本框位置变化。
4. **圆圈显隐遵守“有下级才显示”**：无下级不建圈；不得为隐藏后代画圈（防悬空圆）。
5. **契入遵守“让出不动坐标系”**：契入只裁显示/命中，布局基准保持整墙画布。
6. **防回归必跑**：改完运行 `q6_contract_guard.gd` + 相关回归（`test_auto_layout.gd`、`test_case_panorama.gd`、`q5_scene1_leftbar.gd`、`p12`/`p16`），通过后才声称完成。
7. **改源码必重导 pck**：改过 `scripts/clue/*` 后必须 `rm -rf .godot && --import && --export-release "Web"`，否则预览仍旧版。
8. **破坏性/结构性改动先确认**：涉及折叠语义、契入几何、布局时机、世界坐标基准等核心契约的改动，一律先给方案征求确认。

**C. 改动流程（口诀）**：读基线 → 判违背？违背则先确认再改，不违背直接改 → 跑 Q6+回归 → 重导 pck → 回报。

### 候选推断采纳机制（2026-09）

**定位**：让"收集线索 → 归纳推断 → 相互印证 → 结论指向人物/事件"的目标逻辑能落地。核心思想：候选推断（battlefield.hypotheses）**本就自动渲染为图谱的 hypo 节点**，所以"采纳"不是新建节点，而是**按候选自动连上其支撑证据线索、并给出详细文案**。

- **数据（难度驱动，放各场景 `reasoning_hypothesis().battlefield.hypotheses` 统一区块）**：每条扩展字段：

| 字段 | 含义 |
|---|---|
| `id` | 假设 id（如 `H2-01`），即图谱 hypo 节点 id |
| `text` | 推断原文 |
| `kind` | `"true"`（正确候选）/ `"mislead"`（误导项，仅普通难度混入）|
| `correct` | `bool`，兼容旧逻辑的核心参考 |
| `gate_clue_ids` | 支撑证据线索 id 数组（候选被采纳时，这些已收集线索会被自动连到此推断）|
| `adopt_desc` | 采纳详细文案（为何成立 + 指向谁 + 下一步）|
| `reject_desc` | 排除（误导向）时的详细文案 |
| `new_clue_hint` | 这条链缺哪环、去哪找的新线索指引 |

  ⚠️ `gate_clue_ids` **必须与实际线索 id 对应**（线索 `relation_tags` 已表达"该线索支撑哪些假设"，可交叉核对——scene2 实例：`H2-01`↔`[c201,c202,c204]`、`H2-02`↔`[c206]`、`H2-03`↔`[c205]`、`C2-03`↔`[c203]`）。

- **图谱侧 `graph_view_controller.adopt_candidate(cand: Dictionary)`**：`_state != EDITABLE` 直接提示返回；`cand.id` 空/已是 `_node_center` 中推断则 toasts。对 `cand.gate_clue_ids` 每个 id，用 `_data._id_is_clue(cid)` 校验是线索后才 `_edge._add_edge(cid, hid, "support","green",false)`（`_add_edge` 内部对线索端 `_mark_clue_placed`）。末尾 `_persist_view()`+`_rebuild_graph()`+`_ui_toast(adopt_desc)`。**不新建节点**（假设本就是 hypo 节点），只建边+给文案。配套新增 `_ui_toast(msg)`：有真实 toast 方法走它，否则 `print` 兜底（headless 环境安全）；新增 `any_edge(from_id,to_id)` 查 `_edge_list` 判断已有 support 边。

- **推理墙侧（reasoning_wall.gd）**：
  - 顶栏 row2 新增「🧠 候选」按钮 → `_on_candidates_pressed` → `_show_candidate_panel()`。
  - `_show_candidate_panel`：构造居中 PanelContainer（`_candidate_panel`，z=40），按难度过滤 `battlefield.hypotheses`：EASY 只列 `kind=="true"`；NORMAL 列 `true + mislead`；HARD 空提示"困难模式请自行添加推断"。空列表给出引导文案。关闭走 `queue_free`。
  - 每张候选卡：`gate_clue_ids` 中有、且未与推断建 support 边的已收集线索 → 展示支持线索卡；否则提示"暂无已收集的支撑线索，可手动拖线"。按钮行：`kind=="mislead"` 时给「排除 ✗」（`_reject_candidate`，展示 reject_desc toast），否则/同时给「采纳 ✓」（`_adopt_candidate` → `_graph_view.adopt_candidate(cand)`）。
  - `_adopt_candidate(cand)`：先弹确认（`owner._mk_notice` → `_graph_view.adopt_candidate(cand)`；`_mk_notice(title,msg,yes=...)` 创建独立 Window 弹确认，简化版 create_instance+add_child）。
  - 依赖链：面板数据源是 `_hypothesis.get("battlefield",{})`，难度是成员 `_difficulty`（`Diff` 枚举，autoload 或 scene.gd 定义，EASY=0/NORMAL=1/HARD=2）。
  - `_mk_hint_box(true)` 返回 StyleBoxFlat 用作提示卡样式（无重名，本轮新增）。

- **回归**：`p12`/`p16`/`q6`/`test_auto_layout`/`p0` 全过；`q5`（Q5_OK，exit=99 是非零标记 PASS 惯例）；`test_case_panorama` 的"无人物注入 FAIL"为注入数据差异，非产品 bug。改 multi `scripts/clue/*` + scene 数据后必须 `rm .godot && --import && --export-release "Web"`。

#### 2026-09 场景二三图背景重构（detective 双观察器）

- **背景三图（完全替换旧合成图 `sc_02_garden.png`）**：`assets/scenes/sc02_street.png`(1024×576)、`sc02_facade.png`(2303×1631)、`sc02_path.png`(1024×576)；原件已备份为 `sc02_*_raw.png`（勿删）。三张均为真实照片。
- **观察流程两段**：`_street_obs`(sc02_street, c201-204 车辙/马蹄印) → 收满 → **房屋正面转场**（`set_scene_background(sc02_facade)` + 福尔摩斯旁白，`await 5.0s`）→ `_path_obs`(sc02_path, c205-206 脚印) → 收满 → `_on_observe_complete()` 推理。
- **scene2.gd 覆盖点**：`_create_observers`（建 `_street_obs`/`_path_obs`，地点类 setup + `_ui.get_world_layer()/get_world_offset()`，label 用基类 `_obs_text_lbl`/`_obs_speaker_lbl`）；`_current_observer`（按 `_stage` 返回）；`_begin_observe`（重置 `_stage`+背景）；`_on_all_done`（street→await 转场+切 path 背景+`_path_obs.show()`；path→`_on_observe_complete`）；`_apply_restored_phase` OBSERVE 按 `_clues.size()>=STREET.size()` 分 street/path 恢复并切背景 + `restore_observer` 喂各自 id 子集。
- **常量改动**：旧 `HOTSPOTS` 已拆为 `STREET_HOTSPOTS`/`PATH_HOTSPOTS`，`hotspots()` 返回拼接；任何用到"总线索数"处必须写 `STREET_HOTSPOTS.size() + PATH_HOTSPOTS.size()`，勿引用已删除的 `HOTSPOTS`。
- **坐标基准**：16:9 裁剪图经 `set_scene_background`(STRETCH_KEEP_ASPECT_COVERED) 铺满 1920×1080 无裁切 → 锚点归一化 cx*1920/cy*1080 即场景坐标。热点 cx,cy：c201(0.72,0.70) c202(0.50,0.62) c203(0.56,0.78) c204(0.44,0.75) c205(0.42,0.56) c206(0.52,0.70)。⚠️ c201（碾轧花草）原误标在左侧房屋上，用户反馈后改到右下角草坪花朵处（临近路面）——scene2.gd 热点 `x:1307,y:735` 与锚点 cx0.72/cy0.70 已同步。
- **转场到第三张的坑（2026-09 实测）**：`_on_all_done`(street)→`_street_to_path_transition()` 先 `set_scene_background(facade)`+旁白 `await 5.0s`→`_stage=STAGE_PATH`→`set_scene_background(path)`+`_path_obs.show()`。此前用户反馈"停在第二张(facade)收集脚印"，经 headless 端到端复现（`tools/t_scene2_transition.gd`，T2T：stage=path、bg=sc02_path、path_active=true）确认**源码转场正确**——根因是预览取的 `web_build/index.pck` 为旧导出。改过场景脚本/素材后**必须 `rm -rf .godot && --import && --export-release "Web"` 重导 pck**，否则预览仍旧版（沙箱 `/root` 模板软链被回收时先跑 `bash tools/godot/setup_godot.sh`）。
- **锚点表**（`data/clue_image_anchors.gd`）新增 `sc02_street.png`{c201-204} 与 `sc02_path.png`{c205-206}（cx/cy 同热点，w/h≈0.20）。印痕为真实照片地面纹理，热点按语义估算，预览若偏移可微调 cx/cy。
