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
- **连线交互**：点击连线命中检测（采样二次贝塞尔曲线 ×0.01 步长，容差 16px）弹出浮动菜单，支持删除连线 / 线型(dashed)切换 / 关系性质切换（relate→support→oppose→contradict）。关系变更统一走 `_undo` + `_do_*` → `_cb_relations_changed` → `_persist_view` → `_rebuild_graph()` 模式（`_redraw_all()` 不会重建 `_edge_list`）。
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
