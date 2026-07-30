# 华生（Watson）可绑骨肢体部件素材规格书

> 用途：交给「其他 AI 生图工具」按此规格产出华生的可绑骨肢体部件图，使素材能**直接**进入本项目的 `SkeletonCharacter2D` 骨架动画管线（与福尔摩斯同一套机制），无需手工调参。
>
> 配套脚本：`tools/gen_character_rig.py`（生成 rig 定义）+ 既有 `SkeletonCharacter2D`（`scripts/characters/skeleton_character.gd`）。
> 接入点：`scripts/dialogue/portrait_library.gd` 的 `get_rig("华生")`。

---

## 0. 为什么有这些硬约束（踩坑结论）

福尔摩斯部件最初用「绿幕图 → 抠图」产出，结果 `contact_sheet` 整片空白。根因：

1. 抠图后大量半透明光晕残留 → 单张图 98% 面积是不透明/半透明像素 → 整图被当作「内容」→ 部件被缩到骨长的几十分之一 → 不可见。
2. 肢体内容没有顶满画布、近端关节不在顶边正中 → 缩放比与 pivot 算错 → 部件偏移/脱节。

**因此本规格强制：真·透明 PNG + 硬边缘 + 内容顶满画布 + 关节在顶边正中 + 竖直不预摆 pose。** 满足这五条，生成器算出的 `scale`/`pivot` 即为正确值，可直接用。

---

## 1. 交付物总览

目录：`godot_project/assets/characters/watson/rig/`

| 文件名 | 对应骨架骨 | 是否必需 |
|---|---|---|
| `watson_head.png` | head（含颈根） | 必需 |
| `watson_torso.png` | torso（肩→胯） | 必需 |
| `watson_upperarm_L.png` | upperarm_L | 必需 |
| `watson_upperarm_R.png` | upperarm_R | 必需 |
| `watson_forearm_L.png` | forearm_L | 必需 |
| `watson_forearm_R.png` | forearm_R | 必需 |
| `watson_thigh_L.png` | thigh_L | 必需 |
| `watson_thigh_R.png` | thigh_R | 必需 |
| `watson_shin_L.png` | shin_L | 必需 |
| `watson_shin_R.png` | shin_R | 必需 |
| `watson_hat.png` | hat（圆顶礼帽/bowler，可选） | 可选 |

> 共 10 个必需 + 1 个可选。左右件（`_L`/`_R`）为同一肢体的镜像版本（见 §3.4）。

---

## 2. 骨架拓扑（部件如何连接）

```
                 head ── hat(可选)
                  │
                neck
                  │
               torso ── shoulder_L ── upperarm_L ── forearm_L
                  │      shoulder_R ── upperarm_R ── forearm_R
                hip
               ┌──┴──┐
         thigh_L     thigh_R
            │           │
         shin_L       shin_R
```

骨长（Godot 单位，决定各部件相对比例，**华生与福尔摩斯必须一致**，否则 `apply_pose` 的摆动幅度会错位）：

| 骨 | 长度 | 骨 | 长度 |
|---|---|---|---|
| head | 80 | upperarm | 60 |
| neck | 18（无贴图，画进 head） | forearm | 55 |
| torso | 110 | thigh | 80 |
| hip | 16（无贴图，画进 torso） | shin | 80 |

---

## 3. 每个部件的绘制规范（最关键）

### 3.1 朝向：竖直、近端关节在顶边正中
- 每个肢体部件**竖直绘制**：近端关节（与父骨连接的那一端）位于图片**顶边水平正中央**，部件向**正下方**延伸到**底边**。
- 例：`upperarm` 的肩端在顶边中央、肘端在底边中央；`thigh` 的胯端在顶边中央、膝端在底边中央。
- 禁止把肢体画成斜的或已外展的 A-pose——**pose 由骨架旋转去摆**，AI 画斜了会双重旋转导致脱节。

### 3.2 内容必须顶满画布高度（留白 ≤ 5%）
- 部件实物应**从顶边延伸到接近底边**，上下留白合计 ≤ 5% 高度。
- 原因：生成器用 `scale = 骨长 / 整图高度`。若实物只占画布中间 30%，渲染后肢体长度只有骨长的 30%，关节之间会出现大段空隙（福尔摩斯当初的空白即源于此）。

### 3.3 近端关节必须在顶边水平正中央
- 生成器取「顶部 6% 行」不透明像素的**水平质心**作为 pivot。若关节偏左/偏右，部件会整体横移。
- 躯干、头：左右大致对称，顶边中央即脊柱/颈中线。
- 四肢：肩/肘/胯/膝关节画在顶边正中央。

### 3.4 左右件互为水平镜像
- 正面视角下，角色左臂出现在画面右侧。`upperarm_L`/`upperarm_R` 等是**同一肢体的左右镜像**，请分别产出两幅（可先画一幅再水平翻转得到另一幅）。
- 管线对四肢**不做翻转**（仅帽子翻转），所以左右必须各自是正确朝向的成品图。

### 3.5 帽子（可选）特殊约定
- 若提供 `watson_hat.png`：正常绘制（**帽檐在下、帽顶在上**，内容顶满画布），翻转由管线自动处理。
- 华生建议戴圆顶硬礼帽（bowler），也可不戴（则不提供该图，骨架自动跳过）。

---

## 4. 图片格式硬性要求

| 项 | 要求 |
|---|---|
| 容器格式 | **PNG-24（RGBA）**，`res://...png` 直接 `load` 可用 |
| 背景 | **真·透明**（alpha 通道透明），**禁止绿幕/蓝幕/纯色背景**；禁止依赖后期抠图 |
| 透明边缘 | **硬边缘**（alpha 0/255 为主，抗锯齿过渡 ≤ 1~2 px）。**禁止柔光晕、禁止半透明雾化、禁止投影光环**——这些会被当成「内容」撑满画布导致不可见 |
| 色彩空间 | sRGB，8 bit/通道 |
| 压缩 | 无 JPEG 压缩、无有损重压缩（保存为无损 PNG） |
| 分辨率 | 长边 ≤ 2048 px；建议长边 ≥ 512 px（保证贴图清晰）。各部件按 §5 尺寸紧裁 |
| 命名 | 严格按 §1 文件名（小写、下划线、`watson_` 前缀） |
| 朝向 | 已按 §3 竖直、关节在顶；不要预旋转 |

> 若生图工具**只能**出绿幕/纯色底，请改工具或换工具——本项目 `cutout_rig.py` 虽能抠，但半透明光晕无法完美去除（福尔摩斯即教训）。优先原生透明。

---

## 5. 尺寸与比例限制

参考身高：站立约 7.5 头身。取像素比 **1 Godot 单位 ≈ 2.6 px**（保证清晰且可控）。

| 部件 | 建议紧裁画布 (宽×高, px) | 顶边=近端 | 底边=远端 |
|---|---|---|---|
| head（含颈根） | 160 × 210 | 颈根（顶中） | 下巴 |
| torso（肩→胯） | 130 × 290 | 肩/锁骨（顶中） | 胯（底中） |
| upperarm_L / R | 70 × 160 | 肩（顶中） | 肘（底中） |
| forearm_L / R | 60 × 145 | 肘（顶中） | 腕（底中） |
| thigh_L / R | 90 × 210 | 胯（顶中） | 膝（底中） |
| shin_L / R | 75 × 210 | 膝（顶中） | 踝（底中） |
| hat（可选） | 300 × 120 | — | 帽檐在下 |

- 宽度为建议值，按自然肢体粗细绘制即可；关键是**高度方向内容顶满**（§3.2）。
- 各部件高度比应近似 §2 骨长比（head:torso:upperarm:forearm:thigh:shin ≈ 80:110:60:55:80:80）。

---

## 6. 美术风格

- 维多利亚时代（贝克街侦探事务所背景），与现有福尔摩斯立绘**成对的写实/插画风**。
- 华生特征：军人气质、左臂可能有旧伤痕迹（可体现在 posture 或细微差别，但部件图仍按标准肢体画）、常着深褐/暗红外套与马甲、圆顶礼帽。
- 配色（生成器已内置 watson palette，无需图内特殊处理）：外套褐 `Color(0.30,0.26,0.22)`、外套亮部 `Color(0.40,0.34,0.28)`、肤色同上、帽子 `Color(0.45,0.36,0.26)`、裤 `Color(0.12,0.12,0.16)`。
- 与福尔摩斯保持同一线宽、同一光影方向，使二者同框不违和。

---

## 7. 可选方案：Spine / Live2D 工程

- 本项目的 `SkeletonCharacter2D` 是**自研 2D 骨骼系统**（非 Spine/Live2D 运行时）。直接消费的是上表的**独立 PNG 图层 + 骨定义字典**，不读取 Spine `.skel`/`.json` 或 Live2D `.model3.json`。
- 若用 Spine/Live2D 产出：需另写导入器把其骨骼层级/贴图图集转成本项目的 `{bones:[...]}` 结构（工作量大于直接出独立图层）。**除非你已有 Spine/Live2D 美术管线且想复用动画**，否则推荐直接出 §1 的独立透明 PNG 图层。
- 若坚持 Spine/Live2D：骨骼层级必须严格对应 §2 拓扑（骨名、父子关系、骨长一致），导出的部件图仍需满足 §3/§4（透明、顶满、关节在顶中）。

---

## 8. 交付后接入项目（执行方 / 思傅）

1. 把 11(或 10) 张 PNG 放入 `godot_project/assets/characters/watson/rig/`。
2. 生成 rig 定义：
   ```bash
   cd godot_project
   python tools/gen_character_rig.py watson
   ```
   产出 `scripts/rig/watson_rig.gd` 与 `skeleton_frames/rig_watson_spec.json`。
3. 注册到对话系统 `scripts/dialogue/portrait_library.gd` 的 `get_rig()`：
   ```gdscript
   const WatsonRig = preload("res://scripts/rig/watson_rig.gd")
   static func get_rig(speaker: String) -> Dictionary:
       if speaker == "福尔摩斯":
           return SherlockRig.rig_def()
       if speaker == "华生":
           return WatsonRig.rig_def()
       return {}
   ```
4. 验证（headless，无需打开编辑器）：
   ```bash
   GODOT="D:/AI/godot/Godot_v4.7-stable_win64/Godot_v4.7-stable_win64.exe"
   "$GODOT" --headless --path . "res://scenes/test_skeleton_character.tscn" --quit   # 把场景里的 SherlockRig 临时换成 WatsonRig 跑一次
   "$GODOT" --headless --path . --script "res://tools/export_skeleton_poses.gd"      # 改其引用为 WatsonRig 导出 poses
   python skeleton_frames/draw_skeleton.py                                            # 生成 contact_sheet 肉眼核对
   ```
5. 肉眼核对 `skeleton_frames/contact_sheet.png`：华生应可见、四肢连贯、比例正常；若有部件偏移/翻转，调 `watson_rig.gd` 的 `pivot`/`scale`/`flip` 或回炉对应 PNG。

---

## 9. 可直接粘贴给生图 AI 的提示词模板

> 请为 19 世纪维多利亚背景侦探游戏角色「华生医生」生成 **11 张独立肢体部件透明 PNG**（用于 2D 骨骼绑定动画），严格满足：
>
> 1. 格式：PNG-24 **真透明背景**（alpha 通道），硬边缘（无柔光晕/无投影/无半透明雾化），sRGB，无损，长边 ≤ 2048px、建议 ≥ 512px。
> 2. 每一张**竖直绘制**：该肢体与身体连接的「近端关节」位于图片**顶边水平正中央**，肢体向正下方延伸到接近底边；**不要**预先摆成 A-pose 或外展。
> 3. 肢体实物必须**顶满画布高度**（上下留白合计 ≤ 5%），否则会被缩到不可见。
> 4. 左右成对部件互为水平镜像：`upperarm_L`/`upperarm_R`、`forearm_L`/`forearm_R`、`thigh_L`/`thigh_R`、`shin_L`/`shin_R`（先画一侧再水平翻转得另一侧）。
> 5. 文件名严格为：`watson_head.png`（含颈根）、`watson_torso.png`（肩到胯）、`watson_upperarm_L.png`、`watson_upperarm_R.png`、`watson_forearm_L.png`、`watson_forearm_R.png`、`watson_thigh_L.png`、`watson_thigh_R.png`、`watson_shin_L.png`、`watson_shin_R.png`，可选 `watson_hat.png`（圆顶礼帽，帽檐在下帽顶在上）。
> 6. 建议紧裁画布：head 160×210、torso 130×290、upperarm 70×160、forearm 60×145、thigh 90×210、shin 75×210、hat 300×120（单位 px；宽度可按自然粗细微调，高度必须顶满）。
> 7. 风格：维多利亚写实/插画风，与「福尔摩斯」成对的同伴形象——深褐外套、马甲、圆顶礼帽（可选）、军人站姿；肤色一致、同一光影方向。
> 8. **禁止**绿幕/纯色背景、禁止柔光边缘、禁止投影。
>
> 交付可直接 `load` 的透明 PNG，不要打包、不要合并到一张图。
