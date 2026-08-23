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
- **ESC 关闭修复**：关闭处理用 `call_deferred("_on_close_pressed")`，避免在 `_input()` 里销毁节点卡死。
- **提交验证按钮**：由 reasoning_wall 的常驻顶部栏（z=100，始终盖在图谱之上）提供，图谱自身工具栏默认 `_show_toolbar=false`，避免重复工具栏。
- **连线交互**：点击连线命中检测（采样二次贝塞尔曲线 ×0.01 步长，容差 16px）弹出浮动菜单，支持删除连线 / 线型(dashed)切换 / 关系性质切换（relate→support→oppose→contradict）。关系变更统一走 `_undo` + `_do_*` → `_cb_relations_changed` → `_persist_view` → `_rebuild_graph()` 模式（`_redraw_all()` 不会重建 `_edge_list`）。
- **约束**：GDScript 只要关系字典就用 `r.get(...)`/`r["..."]`；`_relations` 元素是 Dictionary，可用 `e.dashed` 点读、写用 `e["dashed"]=...` 更稳妥。
- **响应式顶栏**：`reasoning_wall._create_top_bar` 用 VBoxContainer(col) 拆两行——row1 关键控件（标题/难度/线型/性质/人物星型/推理链/焦点/撤销/重做/提交验证/求助/关闭）、row2 次要工具（搜索/过滤/折叠/导出/连线）。顶栏 `offset_bottom=110`，图谱 `mid.offset_top=110`；`_mk_top_btn` 字号 16/最小 64x42，`_mk_sep`=6x40。此前单条 HBox 合计约 2450px 超出窗口导致「人物星型/推理链/提交验证」被挤出屏幕。
- **字号统一**：顶栏按钮 16、左栏“已收集线索”线索卡 18、连线说明 16；图谱节点 name≈40/sub≈20 为展示级字号，未改。「推理墙-血字的研究」标题保持原样（38）。
- **「已收集线索」只保留一套（reasoning_wall 左栏）**：`_create_ui` 不再把 `_left_panel` 放进 `mid`，改移动 `reasoning_wall` 顶层并 `z_index=20`（> 图谱 gv.z=5 < 顶栏100），且不隐藏——推理墙打开时左侧「已收集线索」常驻图谱之上，是**唯一**的线索列表（graph 自带的可折叠 `_create_clue_dock` 已废弃：`build()` 中不调用，避免两套系统；`_dock` 相关方法保留为死代码）。卡片显示、可点击/拖拽、拖入图谱后即消失（唯一性）。拖拽：`_make_clue_card` 额外 `card.gui_input.connect(_on_clue_drag.bind(clue["id"]))`；`_on_clue_drag` 用 Godot 粘性 gui_input 捕获（按下→移动>12px 起 ghost Label→抬起），若抬起点不在左栏矩形内（即落入图谱画布）则调 `_graph_view.place_clue(cid)`；图谱新增公开 `place_clue(cid)`（`_mark_clue_placed`+`_persist_view`+`_rebuild_graph`）。放置后 `_refresh_clue_list()` 即时隐藏该线索（独一性），细节卡「从图谱移除（归还线索）」`_unplace_clue_from_graph` 末尾补 `_cb_relations_changed.call(_relations.duplicate())` 使孤立线索（无关系边）也即时归还左栏。左栏提升后左上会出现覆盖图谱画布左 540px 的浮层（不会缩放图形，避免节点坐标溢出）。
- **验证命令**：`GODOT --headless --path . --script res://tools/test_wall_interact.gd`（顶栏按钮）与 `res://tools/test_wall_relations.gd`（边/关系链路）均 PASS；`test_wall_drag.gd` 在 headless 下因卡片重叠存在环境性失败。
- **节点卡片自适应（#1）**：`graph_view_controller._make_node` 不再用固定尺寸，据 `label` 长度自适应卡片宽（约 28px/字，封顶 480）并按换行数扩高；位置由 620 行 `position=center-size*0.5` 重新居中，边/菜单锚 `_node_center` 不受影响。name 标签加了 `autowrap_mode=WORD_SMART`。
- **教学线索不进入真实案件（#3）**：场景一示范为 source `watson`/`messenger`，`detective_scene._open_wall` 在 `use_case_wide`（场景二后全案池）时过滤掉这两个 source，避免华生/信使教学线索混入后续案件图谱。
- **每堵墙独立验证（#2）**：scene1 的华生与信使墙共享 `_wall_state`，华生墙验证后 `verified=true` 会泄漏进信使墙导致图谱锁定不可拖动；`_show_messenger_reasoning_wall` 打开前重置 `_wall_state["verified"]=false`。
- **双级存储（#4）**：`reasoning_wall._on_back_pressed` 退出墙只调 `_persist_state()`（内存态 `_state_store`，即临时存储），不再调用 `_on_persist`（落盘）。长期存储（写档）只由 ①手动存档（side_panel）②场景结束自动存档（`_save_and_transition`/`_save_and_continue`）触发，二者会快照当前内存态。场景二后的基类 `_do_save` 目前只写 `clue_ids`，wall 布局只在 scene1 的 `_do_save` 写入存档。
- **按关系驱动的横向阶梯树布局**（`_compute_layout` 的 MODE_C 调 `_relation_tree_layout`，它是当前启用的布局；旧 `_xmind_layout` 仅作参考保留，不再调用）。核心语义（对照用户 华生示范：人物→结论→推断→线索 整条推理链阶梯树）：
  - **以关系（`_relations`/`_edge_list`/人物-线索元数据边）为驱动建树**，不再按 kind 一次性横排：`_build_adjacency` 取邻居，人物=根(col0)，从根 BFS，邻居"性质层更深者"作子（conclusion→1、chain/hypo→2、clue→3，person→0），每节点只承接一次防环；同父子树归组（`_collect_high` 靠后序统计子带高 `high`），父居中于其子树纵向带（`_assign_subtree` 叶子累计、`top2/bot2` 分配）。
  - **方向不硬性统一**：人物居中/偏右/偏左时树自动朝画布空余侧生长（`dirv` 由 `saved_pos` 与空余空间决定）；人物可自由移动、位置保存位优先；多人物各自一棵独立子树、纵向带独立互不交叉。
  - **每次增删关系自动重排**：`_rebuild_graph`→`_compute_layout` 每次对整棵树重排（非根节点不用 `saved_pos` 沿用），孤儿/孤立线索留在外围按 `saved_pos` 鼻孔放置。
  - **拖动时先折叠子树再移动**：`_on_node_gui` move 分支调 `_fold_subtree_for_drag(id)`，对带子树的节点用 `_subtree_ids`（沿邻接按性质层更深 BFS）收集后代 → `_apply_fold_subtree` 把本体+后代写入 `_folded_nodes` 并 `_persist_view`+`_rebuild_graph`（`call_deferred` 避免拖拽中重建卡死），移动只带该节点、子树折叠成摘要。
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
