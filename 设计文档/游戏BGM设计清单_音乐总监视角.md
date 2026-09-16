# 《谁是大侦探》场景音乐素材生成需求清单（音乐总监视角）

> **版本**：v1.0（音乐总监稿，2026-09-15） ｜ 用途：**直接交由外部 AI 音乐工具（Suno / Udio / Mureka / 海绵音乐等）按章节生成**
> **上游**：`设计文档/游戏音乐设计方案.md`（系统架构 + 6 态自适应状态机） ｜ `设计文档/游戏音乐素材生成需求清单.md` v1.2（**工具级 prompt 速查表**，可并行参考）
> **本文档定位**：v1.2 是「单首 prompt 汇编」，**本文是「音乐蓝图」**——以总监视角把全剧 9 首场景 BGM 视为**一条贯穿 8 幕的情绪河流**而不是 9 段独立音频。从声音身份单一性、动机网络、分幕式结构、场景接续四个维度，把 v1.2 升级为可执行的全剧配乐蓝图。
> **案件原型**：《血字的研究》德雷伯谋杀案 ｜ 时代：维多利亚伦敦
> **目标读者**：① 实际生成素材的 AI 音乐工具（按章节任务包执行）；② 项目组审核交付物的对照基准；③ 后续接手的作曲/混音者

---

## 〇、为什么"再写一份"

v1.2 把每首场景 BGM 作为**独立的循环单元**罗列，每首一段 prompt，工具友好但**全局性缺失**：

- 9 首曲子之间没有**情绪连贯**——听感上像是"AI 拼盘"而不是"一部作品"；
- 5 条主导动机被孤立描述，没有**派生关系与对位规则**——同一角色在不同场景出现时听感差很大；
- 每首只有单一循环结构，没有**分幕式内部叙事**——长场景里听 90 秒会"无变化地疲劳"；
- 没有**福尔摩斯氛围的纲领**——风格约束分散在每首的负向词里，缺少总纲；
- 缺一个核心主题：**温情主题（victim-past theme）**——scene6 卡彭蒂耶公寓的"温情回落"在 v1.2 里用一段现成 prompt 含糊带过，没有独立动机。

本文档**不替代 v1.2**——v1.2 的逐首 prompt 与调参建议继续有效，是「工具级速查表」。本文补的是**总蓝图层**的缺失：动机网络、情绪河流、声音身份、分幕结构、场景接续。

---

## 一、总监宣言：福尔摩斯氛围的本质

> 一句话：**智力感的庄严 + 室内乐的克制 + 维多利亚的潮湿**——不是动作片的紧迫、不是惊悚片的惊吓、不是哥特的阴森、也不是古典乐的"古老感"。

**6 个本质特征**（按重要性排序）：

1. **节奏来自「思考」而非「行动」**。本游戏的节奏是**钟摆、怀表、马蹄、车轮、翻书页**——没有鼓组。AI 生成时若听到鼓组，**整个氛围就毁了**。
2. **悬疑来自「半音」而非「全音阶外的不协和」**。本剧极少用增四/减五/tritone 张力，而是用**半音邻近**（C→C#、D♭→D）与**复合功能**（同一句里 D 小调+ F 大调和弦重叠）制造"想不通"的智力焦虑。
3. **动机是可被记住的「短句」**。每个角色/概念对应 5–10 秒的短动机——AI 不需要生成长篇旋律，但**必须能反复识别**同一条动机。
4. **独奏乐器的"对话感"**。不是独奏炫技，而是**乐器间的应答**——小提琴问、中提琴答；大提琴陈述、钢琴应和——这是"福尔摩斯与华生"的音乐隐喻。
5. **室内乐编制即氛围本身**。4–8 人弦乐 + 钢琴 + 竖琴 + 钟琴，**不加人声不加电子**——编制本身就是维多利亚时代最直接的"时代质感"。
6. **大调转段=真相时刻**。全剧只有**两次**完整的大调破雾：scene3 尸体发现的瞬间（短暂）、scene8 揭晓后（完整）。其余时间**小调为家**。这是本剧**最重要的色彩规则**。

**3 个绝对禁忌**（与 v1.2 同源，强化）：

- ❌ **任何带 vocal 的素材**——哼唱、人声采样、AI "feat. 歌手"——出戏且版权风险。
- ❌ **任何现代鼓组**——电鼓、808、trap、EDM kick——即使是"柔和的"lo-fi 鼓 loop 也禁用。本剧节奏全部由**弦乐拨奏 / 钟摆 / 木质敲击**承担。
- ❌ **任何 jump scare 写法**——突然的重音、弦乐 gliss 尖叫、电影 trailer hit——本剧核心是观察→推理的智力闭环，**焦虑感会破坏沉浸**。

---

## 二、三条铁律（继承 + 强化）

### 2.1 三条铁律（继承自 v1.2，本节为强化版）

| 序号 | 内容 | 与 v1.2 差异 |
|---|---|---|
| 1 | **纯器乐、无人声** | 同 v1.2 |
| 2 | **不要现代鼓组与电子音色** | 同 v1.2 |
| 3 | **悬疑来自"未知"，不是"惊吓"** | 同 v1.2 |

### 2.2 新增三条"声音身份"铁律（本剧独有）

| 序号 | 内容 |
|---|---|
| 4 | **同源乐器**：所有曲子都来自同一个 4–8 人室内乐队（一把独奏小提琴 + 一把中提琴 + 一把大提琴 + 一把低音提琴 + 毡化钢琴 + 竖琴 + 钟琴 + 木质敲击）。禁止在某些曲子用合成弦乐、在另一些曲子用真实弦乐；禁止某首突然出现管乐。 |
| 5 | **同源混响空间**：所有曲子都"录"在同一个虚拟空间——维多利亚伦敦的 221B 起居室（约 80 m³，温暖木质反射）。混响 tail 1.8–2.4 秒，predelay 20–35 ms。禁止某些曲子像大教堂（尾音 4 秒+）、某些曲子像录音棚（干声死）。 |
| 6 | **同源动态范围**：全剧集成响度 **−14 LUFS ±1**，true peak ≤ −1 dBTP，动态范围 **8–14 dB**（不超过 14 dB，否则就不"室内乐"了）。在生成阶段就要校验响度，不靠后期强行压限。 |

### 2.3 通用负向词（在 v1.2 基础上合并）

```
vocals, lyrics, choir, rap, humming, speech,
EDM, dubstep, trap, 808, drum machine, synth lead, synth pad,
electric guitar, distortion, heavy percussion, trailer hits, brass fanfare,
lo-fi hip hop, modern pop, choir, chant, siren,
epic orchestral tutti, film trailer, action movie, battle music,
church organ, full pipe organ, harp glissando cliché
```

---

## 三、虚拟乐队 & 录音棚规格（新增）

> AI 工具没有"乐队成员"，但每首 prompt 必须给工具足够的**音色锚点**，让生成出来的曲子听感像"同一组人录的"。

### 3.1 乐器清单（按"是否必出现"分三档）

**核心编制（每首都必须有 ≥3 件）**：

- **毡化钢琴（Felt Piano）**：律动骨架/和声层。**这是本剧最具标志性的乐器**——绝不用普通三角钢琴（太亮）。毡化钢琴在中低频自带一层温暖的"绒毛感"，是本剧声音身份的支柱。
- **独奏小提琴**：旋律层，承担**福尔摩斯动机 + 揭晓段高音**。
- **中提琴**：副旋律层 / **华生动机** / 和声填充（与独奏小提琴的"应答"）。
- **大提琴**：低音 + **真凶动机** + 不协和长音。

**色彩乐器（按需出现，不每首都用）**：

- **低音提琴**：极轻铺底（scene5/6）、拨弦脉冲（scene4/5）。
- **竖琴**：段落过渡（scene1/4/5）、泛音（WALL）。
- **钟琴（Glockenspiel）**：句尾点缀、**血字动机的标识**。
- **单簧管**：极少数场景用——scene1 暗示福尔摩斯动机；scene8 揭晓段——其它场景几乎不用。
- **音乐盒 / 手摇风琴 / 古钢琴（fortepiano）**：作为**时代色彩点缀**，每个场景只出现 ≤3 秒（不抢戏）。

**打击乐（绝对不能用鼓组，只能用以下"非鼓组"打击）**：

- **钟摆/怀表滴答**（最常用，承担节奏）
- **木质敲击**（手指叩桌、小声关门、椅子响）
- **定音鼓低滚奏**（只在 scene3 / scene8 高点）
- **远雷**（scene2/3 室外）
- **三角铁**（极轻，scene4 调查推进）

**绝对禁用清单**：

- ❌ 鼓组（任何形式）、电鼓垫、采样鼓 loop
- ❌ 电子合成器（synth lead / synth pad / 808 / sub-bass）
- ❌ 失真吉他（任何电吉他）、失真贝斯
- ❌ 嘻哈/Trap 节奏元素（hi-hat / 808 kick）
- ❌ 大型管弦全奏（epic tutti）
- ❌ 教堂管风琴（full pipe organ）
- ❌ 弦乐齐奏的"电影预告片"式写法

### 3.2 录音棚空间规格（约束混响）

**统一虚拟空间**：221B 起居室，约 80 m³，木质装饰，温暖的中频反射。

| 参数 | 数值 | 备注 |
|---|---|---|
| RT60（混响衰减时间） | 1.8 – 2.4 秒 | 比干声略湿，比教堂短得多 |
| Pre-delay | 20 – 35 ms | 营造"房间感"而非"大厅感" |
| 早期反射密度 | 中等 | 维多利亚起居室四面木板 + 书架 |
| 低频吸收 | 强 | 壁炉地毯吸低频，避免糊 |
| 高频衰减 | 轻微 | 略暗，但**不**暗到像恐怖片 |

**提示**：若工具提供 "Room / Hall / Cathedral / Studio" 选项，**强制选 Room 或 Studio（Wet）**——不要 Cathedral，不要 Arena。

---

## 四、全剧情绪河流图（核心抓手）

> 这张图是**整个文档最重要的单一工具**——AI 生成前必须看一眼。

### 4.1 情绪河流图（二维定位）

```
色温（暖 ←────→ 冷）

  ◢ 暖─────────────────────────────────────────────◣
  │                                                │
S │            SETTLEMENT（暖尾）                   │
C │                              SCENE 6（温情回落）│
E │                                                │
N │  MENU           SCENE 1                         │
E │  （警觉+邀请）  （温暖引导）                     │
5 │                                                │
  │        SCENE 5（思考空间）                      │
  │        （壁炉暖+冷思考）                        │
  │                                                │
  ├────────────────────────────────────────────────┤
  │        SCENE 4（智性推进）                      │
  │                                                │
  │                        SCENE 2（雾里悬疑）      │
  │                                                │
  │                                    SCENE 7（危机│
低 │                                    /旅馆压抑）  │
紧 │                                                │
张 │                                                │
↑ │        SCENE 3（发现尸体——首个高点）            │
  │                                                │
  │                                    SCENE 8（终局│
  │                                    /揭示高潮）   │
  │                                                │
  ◣ 冷─────────────────────────────────────────────◢

  低紧张度 ───────────────────────────→ 高紧张度
```

### 4.2 9 首的位置与"剧情位置"

| ID | 紧张度 (1-5) | 色温 (冷→暖) | 主导情绪 | 在全剧中的角色 |
|---|---|---|---|---|
| MENU | 2 | 偏冷 | 警觉、蓄势、邀请 | **开场**——建立声音身份、引出动机 |
| SCENE 1 | 1.5 | 偏暖 | 温暖引导、安全 | **教学**——让玩家熟悉配乐语言 |
| SCENE 2 | 2 | 冷 | 雾里悬疑 | **第一次不安**——发现之前的悬疑 |
| SCENE 3 | **5** | 冷 | 冲击、震惊 | **第一个高点**——尸体发现 |
| SCENE 4 | 3 | 中性偏冷 | 智性推进 | **调查节奏**——破案的"运动感" |
| SCENE 5 | 1.5 | 暖 | 思考、安宁 | **沉思空间**——壁炉前的纯思考 |
| SCENE 6 | 1 | **最暖** | 温情、哀伤、回味 | **情感回落**——受害者的过去 |
| SCENE 7 | 4 | 冷 | 危机、逼近 | **逼近真相**——危险第一次真实浮现 |
| SCENE 8 | **5+** | 冷→暖（破雾） | 揭示、悲悯、收束 | **全剧高潮**——动机交织→大调破雾 |
| SETTLEMENT | 2 | 暖 | 成果兑现 | **收束**——与 scene8_resolve 同空间 |

### 4.3 关键设计取舍**（AI 必看）**：

1. **不要把相邻场景写得情绪色温相同**——scene4 (冷/调查) 和 scene5 (暖/思考) 必须有明确色温差，让玩家在切换场景时有"换房间"的体感。
2. **高点不超过 2 个**——scene3 与 scene8 是仅有的两个高紧张度场景（5 级）。其它场景**全部低于 4 级**。这是本剧的"节奏纪律"。
3. **scene5 必须是"全剧最低点"之一**——它是壁炉前的纯思考（紧张度 1.5），是节奏中必要的"呼吸"。若 AI 把它写成 3 级，就破坏了情绪河流的呼吸感。
4. **scene6 是"全剧最暖"**——紧张度 1 + 色温最暖——这是唯一的"情感场景"，必须让玩家感受到"侦探也有人文关怀"。

---

## 五、主导动机网络（Motif Network）

> 6 条主动机 + 1 条新温情动机——全剧所有 BGM 都是这 7 条动机的**展开 / 变奏 / 组合 / 对位**。

### 5.1 7 条主动机谱系

| ID | 名字 | 乐器 | 调性家 | 核心音型 | 情绪 | 出现场景 |
|---|---|---|---|---|---|---|
| M_SH | 福尔摩斯 | 独奏小提琴 | D 小调 | 小三度+纯五度上行跳进，附点节奏 | 智性、跳跃、敏锐 | 1(轻) / 4(展) / 5(主场) / 8(交织) |
| M_WT | 华生 | 中提琴 | F 大调 | 温暖三度伴行，级进 | 陪伴、叙事、可靠 | 1(主导) / 5 / 6 / 8(交织) |
| M_RA | 血字 / RACHE | 低音弦 + 钟琴 | E 小调 | **不祥半音下行** | 死亡、未解的恨 | 2(远景) / 3(爆发) / 7(回响) / 8(交织) |
| M_VP | **温情 / 受害者往事** | 独奏大提琴 + 钢琴 | B♭ 大调 | 级进下行的温柔短句，附点延长 | 温情、追忆、哀而不伤 | **6(主导)** / 8(悲悯段) |
| M_CU | 真凶（复仇） | 大提琴长音 + 不协和下二度 | G 小调 | 压抑长音+下二度碰撞 | 隐忍、悲剧性 | 7(隐现) / 8(交织→转悲悯) |
| M_LN | 伦敦雾 | 风声 + 远汽笛 + 极低弦乐 | （无明确调性，环境母题） | 持续低频风声 + 远处汽笛间歇 | 城市纹理、永恒背景 | 全剧 A 层底色（除 MENU/5/6 暂退） |
| M_FP | 壁炉 / 家 | 火焰噼啪 + 木质敲击 | （环境母题） | 间歇噼啪 | 温暖、回归、归属 | 5(主导) / 6(轻) / 8_resolve(收尾) |

### 5.2 派生关系图（"动机谱系"）

```
                          ┌── M_VP（温情，scene6 主导）
                          │
           M_LN ──┬───────┤
                  │       │
              （环境母题）  └── M_RA（血字，scene3 主导）
                  │
                  └── M_FP（壁炉，scene5 主导）

     ┌── M_SH（智性） ─── 对位 ──→ M_RA（死亡）
     │       │                        │
     │       └── scene8 交织 ────────→│
     │                                │
     └── M_WT（陪伴） ─── 应答 ──→ M_SH（智性）
                  │
                  └── scene8 交织

                          M_CU（真凶）
                          └─ scene7 隐现 → scene8 交织 → 大调转段（悲悯）
```

### 5.3 对位与变形规则

| 规则 | 说明 |
|---|---|
| **对位规则** | M_SH 与 M_RA 在 scene3 / scene8 必须**对位出现**——智性 vs 死亡，福尔摩斯 vs 血字。 |
| **变形规则** | 同一动机在不同场景用**不同配器 / 不同密度**呈现（如 M_RA 在 scene2 是远景钟琴点缀，scene3 是低音弦爆发，scene7 是回响）。 |
| **退场规则** | M_LN 在 scene5 / 6 短暂退场——让"室内"真正"室内"，避免雾感污染温情。 |
| **收束规则** | M_FP 在 scene8_resolve 收尾独占——大提琴/小提琴陈述完全消失，只剩钢琴 + 壁炉，**给人"案件结束、人散、火还在烧"的体感**。 |

### 5.4 主动机短样（Prompt 形式，可直接生成 8–20 秒短 motif）

**M_SH 福尔摩斯动机**

```
Short solo violin detective motif, D minor ascending leap of minor third
then perfect fifth, dotted rhythm, 8 seconds, instrumental only,
no accompaniment, no drums, no synth, brilliant and analytical,
a detective's signature theme
```

**M_WT 华生动机**

```
Short viola companion motif, F major stepwise with gentle parallel thirds,
12 seconds, instrumental only, no drums, no synth, warm and reassuring,
the loyal friend and chronicler
```

**M_RA 血字动机**

```
Dark low strings motif with cold glockenspiel, E minor descending
chromatic half-step phrase, 10 seconds, instrumental only, no drums,
no synth, the unresolved letter R-A-C-H-E written in blood,
ominous and mournful
```

**M_VP 温情动机**（新）

```
Bittersweet solo cello with intimate felt piano, Bb major descending
stepwise motif with dotted lengthening on phrase endings, 12 seconds,
instrumental only, no drums, no synth, tender and human, memory of
a broken engagement, Victorian parlor at dusk
```

**M_CU 真凶动机**

```
Low cello sustained note with dissonant minor second below, G minor,
10 seconds, instrumental only, no drums, no synth, restrained fury
that hides grief, a wronged man plotting justice
```

**M_LN 伦敦雾母题**

```
London fog atmospheric texture, low wind drone, distant muffled
foghorn at 30 and 55 seconds, very faint low contrabass,
60 seconds, seamless loop, no melody, no rhythm, no percussion,
no synth, the city breathing through the mist
```

**M_FP 壁炉母题**

```
Fireplace ambience, soft wood crackling at irregular intervals,
very faint warmth, 60 seconds, seamless loop, no melody, no rhythm,
no percussion, no synth, the heart of 221B Baker Street
```

---

## 六、场景 BGM 任务包（9 首）

> 每首给「任务包」格式：**剧情定位 → 情绪曲线（含时间线）→ 主导动机组合 → 内部"分幕"结构 → 与前后场景的接续 → 编制 → 参数 → 总编制 Prompt（英文）→ 中文自然语言 Prompt（备选）→ 调参建议**。

> 与 v1.2 关系：本节每首的「总编制 Prompt」是 v1.2 对应章节的**升级版**——加入了「分幕结构」「动机组合」「接续规则」。v1.2 的原版 prompt 仍然有效作 fallback。

---

### 6.1 MENU — 主菜单 / 案件主界面

**剧情定位**：游戏入口。**声音身份的"自我介绍"**——玩家在这里第一次听到本剧的"声音长相"。

**情绪曲线**（90 秒）：
- 0:00 – 0:10 极暗引子：低音提琴泛音 + 远处雾声（M_LN 简版）
- 0:10 – 0:40 暗色框 A：毡化钢琴八分固定音型 + 大提琴 G 踏板半音邻近（F#↔G）
- 0:40 – 0:55 主题 B：**M_SH 短句闪现 1 次**（5 秒）+ M_WT 短句闪现 1 次（5 秒）——让玩家**认识两条核心动机**
- 0:55 – 1:10 推进 C：密度上升，加入钟琴点缀
- 1:10 – 1:30 回到 A，无缝接回 0

**主导动机组合**：M_LN（环境底色）+ M_SH（闪现）+ M_WT（闪现）——**为后文"埋线"**

**与前后场景的接续**：
- ← 接续：玩家从外部世界（无音乐）进入——需要 1.5 秒淡入
- → 接续：进入 scene1（教学关）需要无缝——MENU 末尾是 A 段（毡化钢琴固定音型 + G 踏板），scene1 开头是 C 大调琶音——**自然衰减 + 1 秒静音缓冲**（不要硬接）

**编制**：毡化钢琴（八分固定音型）+ 大提琴拨奏（G 踏板 + F# 半音邻近）+ 中提琴（G 持音）+ 竖琴（段落过渡滑奏）+ 钟琴（句尾极轻点缀）+ 单簧管（仅主题 B 段暗示 M_SH，5 秒即收）

**参数**：G 中心（主和弦 G–B–D）+ 低音 F# 半音邻近 ｜ 89 BPM ｜ 90 秒循环 ｜ 动态范围 ≤ 12 dB

**总编制 Prompt（英文）**：

```
Chamber neo-classical mystery underscore, felt piano eighth-note ostinato
as the rhythmic backbone, viola and cello holding a low G pedal with a
half-step neighbour F# rocking underneath, pizzicato cello accenting
instead of percussion, harp glissandi as section transitions,
sparse glockenspiel on phrase endings, one quiet clarinet line hinting
the detective motif for 5 seconds only, G tonal centre in mixed
Ionian-Dorian colour, major tonic triad but semitone tension in the bass,
89 BPM, 90 seconds, seamless loop, instrumental only, no vocals,
no drums, no synth, steady and gripping yet restrained, alert and
forward-driving, quietly suspenseful, Victorian London before dawn,
fog not yet lifted, gas lamps burning down, a hansom cab out of sight,
near-constant loudness with a single dark breakdown dip,
background underscore, film score quality, 221B Baker Street drawing room
```

**中文自然语言 Prompt（备选）**：

> 室内乐新古典悬疑开场。毡化钢琴用稳定的八分固定音型作律动骨架；中提琴与大提琴持低音 G 长音踏板，底下用半音邻近的 F# 来回摇动；大提琴拨奏在拍上给重音代替鼓组；竖琴滑奏作段落过渡；钟琴只在句尾极少点缀。**第 40-55 秒**插入一句很轻的单簧管（暗示"侦探"主题），5 秒即收。整体以 G 为中心，主和弦是明亮的大三和弦，但低音的半音张力带来锐利与不安——要"亮而不欢、紧而不丧"。速度 89 BPM，做成 90 秒可无缝循环的单元。混音整体压暗（不写镲片与高频亮片），响度几乎恒定，只留一处短暂的"暗色凹谷"。画面是黎明前的贝克街：雾没散、煤气灯将熄、远处有马蹄与车轮——冷静、警觉、蓄势待发。整体听感要像**221B 起居室**里录出来的——温暖的中频反射、混响 2 秒左右。

**调参建议**：
- 若嫌"不够紧"：把大提琴的 F# 半音邻近改为更不协和的 F♮（小七度）→ G，形成"擦边"不协和
- 若嫌"太欢快"：去掉单簧管 M_SH 闪现的旋律起伏，仅保留静止长音
- 若嫌"太闷"：在主题 B 段加大提琴拨弦的音量 1–2 dB，让"心跳感"更明显

---

### 6.2 SCENE 1 — 教学关（华生 / 信使推理墙）

**剧情定位**：玩家的"听力入门"——第一首长时间暴露的曲子，**必须给玩家安全感**（这是全剧最安全的场景）。同时**复现 MENU 的两条线索动机**，让玩家潜意识里建立"这声音=福尔摩斯游戏"的映射。

**情绪曲线**（100 秒）：
- 0:00 – 0:15 暖色起：钢琴分解和弦 + M_WT 完整陈述
- 0:15 – 0:50 中段：加入 M_SH 极轻呼应（不是完整陈述，只是"知道它在"）
- 0:50 – 1:10 收束：留白多，回归纯钢琴
- 1:10 – 1:40 段 B：M_WT 变形（降八度）— 给"陪伴感"
- 1:40 – 1:55 回到起句，无缝接回 0

**主导动机组合**：M_WT（主导）+ M_SH（轻呼应）+ M_FP（轻，壁炉点缀）

**与前后场景的接续**：
- ← 接续：从 MENU 的 G 中心转到 C/A 小调——**需要 2 秒静音缓冲**（避免调性突兀）
- → 接续：scene2（劳瑞斯顿花园街室外）需要色温急剧转冷——scene1 末尾留 1.5 秒静止，留给 scene2 雾声环境音独占 1 秒后再进入主调

**编制**：中提琴主导（M_WT 完整陈述）+ 钢琴分解和弦 + 竖琴轻拨 + 怀表滴答（B 律动层）+ 极轻壁炉声（M_FP）

**参数**：C 大调 / A 小调交替 ｜ 76 BPM ｜ 100 秒循环 ｜ 中高频明亮 ｜ 动态范围 ≤ 10 dB（最平稳的一首）

**总编制 Prompt（英文）**：

```
Gentle chamber teaching underscore, warm viola lead presenting the
Watson motif in full statement, gentle felt piano arpeggios and light
harp plucks, very faint pocket watch ticking as soft pulse,
a hint of solo violin on the violin side only for 5 seconds as an
echo, fireplace crackling very faintly underneath, C major drifting
to A minor and back, 76 BPM, 100 seconds, seamless loop,
instrumental only, no vocals, no drums, no synth, mentoring and
reassuring, curious but safe, a tutor standing beside you,
Victorian study room daylight, warm midrange, 221B parlor acoustic,
film score quality
```

**中文自然语言 Prompt（备选）**：

> 温暖引导的室内乐教学场景。中提琴担任主奏，把"华生"主题完整陈述一次（12 秒左右）；毡化钢琴用分解和弦铺底；竖琴轻拨做色彩；极轻的怀表滴答声作节奏层（不要听到明显的鼓点）；中段有 5 秒独奏小提琴的极轻呼应（**不要抢中提琴戏**）；壁炉噼啪声作为环境母题铺在最底层。调性在 C 大调与 A 小调之间温和交替。76 BPM，100 秒循环。画面是 221B 起居室日景：阳光透过百叶窗、木地板、华生站在扶手椅旁教玩家怎么观察——安全感、陪伴感、"学得会"。纯器乐，无人声，无鼓，无电子音色。

**调参建议**：
- 若嫌"不够安全"：把竖琴去掉（竖琴偏"仙气"），改用中提琴的泛音呼应
- 若嫌"太温馨"：把怀表滴答的音量提高 2 dB——"节奏=警惕"，让"思考正在发生"的体感更明显
- 若 M_SH 呼应被 AI 生成了"完整旋律"：强制改 prompt 为 "only a faint violin harmonic, no melody, no rhythm, just a sustained high note"

---

### 6.3 SCENE 2 — 劳瑞斯顿花园街 3 号（室外凶案现场）｜ DAY 1 上午 11:15

**剧情定位**：玩家第一次接触命案现场——**"发现之前"的悬疑**。**雾=悬疑**（低频厚、高频暗）。本曲不应有冲击感，只应让玩家觉得"安静得不对劲"。

**情绪曲线**（100 秒）：
- 0:00 – 0:20 雾底色：低音提琴长音（M_LN）+ 远处汽笛 + 风声
- 0:20 – 0:45 钟琴零星：D 音 + E♭ 半音（暗示 M_RA 但不暴露）
- 0:45 – 1:05 钢琴稀疏单音：每 8 秒一个，像"想不通"的钟摆
- 1:05 – 1:20 钟琴稍密：D + E♭ + D 半音下行小句（**M_RA 远景化**）
- 1:20 – 1:40 回到雾底色，无缝接回 0

**主导动机组合**：M_LN（主导，铺底）+ M_RA（远景，未爆发的暗示）

**与前后场景的接续**：
- ← 接续：从 scene1（C 大调暖）切到 D 小调冷——**2 秒静音缓冲** + 1 秒纯 M_LN 雾声
- → 接续：scene3（尸体发现）需要明显的紧张度跃迁——scene2 末尾**故意维持在低紧张度**，让玩家进入 scene3 时的"突变"更明显

**编制**：低音提琴长音 + 极轻风声/远汽笛（环境纹理）+ 钟琴零星点缀 + 钢琴稀疏单音 + 大提琴不祥半音下行（**仅在最后 15 秒出现，作为"危险预告"**）

**参数**：D 小调 ｜ 60 BPM（最慢之一）｜ 100 秒循环 ｜ 低频厚、高频暗（**明确低通感**）｜ 动态范围 ≤ 10 dB

**总编制 Prompt（英文）**：

```
Slow atmospheric mystery underscore, low sustained contrabass drone,
distant foghorn and wind texture, sparse glockenspiel with semitone
clicks hinting the RACHE motif, sparse felt piano single notes every
8 seconds like a stuck clock, a low cello descending chromatic phrase
in the final 15 seconds as foreshadowing, D minor, 60 BPM,
100 seconds, seamless loop, instrumental only, no vocals,
no drums, no synth, foggy Victorian London street at morning,
an empty house watched from outside, quiet dread and curiosity,
dark muted highs, low-pass filtered, muffled acoustic, film score
```

**中文自然语言 Prompt（备选）**：

> 极慢的雾中悬疑铺底。低音提琴持续低音长音作主家；环境纹理用极轻的风声和远处雾汽笛（**不是雨！不要雨声**）；钟琴每 15-20 秒敲一个半音（D 和 E♭），暗示"血字"动机但**不暴露完整旋律**；钢琴每 8 秒一个单音，像钟摆卡住的"想不通"；**只在最后 15 秒**加入大提琴的半音下行小句，作为进入室内的"危险预告"。D 小调，60 BPM（极慢），100 秒循环。整体混音**低通滤波感**——高音要闷、暗、厚，像雾把所有高频都吞掉了。画面是劳瑞斯顿花园街的空宅外：上午 11 点，雾未散，玩家第一次站在凶案现场门外——**不是发现之后的冲击，是发现之前的安静**。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 生成了"鼓组"或"恐怖片弦乐"：强制改成 "no percussion at all, no string tremolo, no orchestral hits, only sustained tones and sparse piano"
- 若嫌"太静"：在第 0:20 加入一个非常轻的马车轮声（**不是马蹄，是木轮在石板路的滚动**）——维多利亚伦敦的标志声
- 若嫌"太悬疑"：去掉最后的 M_RA 远景化——把"危险预告"留给 scene3

---

### 6.4 SCENE 3 — 劳瑞斯顿花园街 3 号·室内（尸体发现）｜ DAY 1 正午 12:05

**剧情定位**：**全剧第一个高点**——玩家发现德雷伯尸体，墙上血字 RACHE。这首曲子需要**支撑冲击瞬间**而不抢戏。

**情绪曲线**（110 秒）：
- 0:00 – 0:30 张力积累：A 段——大提琴不祥半音下行（M_RA 远景）→ 中段加入弦乐 tremolo → 定音鼓低滚奏进入
- 0:30 – 0:50 紧张高点：B 段——上行 ostinato + M_SH 反向（大提琴陈述 M_SH 的反向：下行而非上行——暗示"案发现场是智性挑战的反面")
- 0:50 – 1:10 余震：C 段——所有元素**同时衰退**（动态压缩到极弱），只留钢琴高音区冷色单音
- 1:10 – 1:50 反复 A→B 段（**这是可循环部分**）

**主导动机组合**：M_RA（爆发，主导）+ M_SH（反向变形）+ M_LN（保留环境底色但已被覆盖）

**与前后场景的接续**：
- ← 接续：从 scene2（D 小调）——**无缝**，scene2 末尾的 M_RA 半音下行直接接到本曲 A 段
- → 接续：scene4（奥德利大院调查）需要明显色温变暖（转向"破案推进"的智性节奏）——本曲末尾留 3 秒静态（**强烈余震后的寂静**），让玩家进入 scene4 时有"案件开始了"的体感

**编制**：大提琴不祥半音下行 + 弦乐 tremolo + 定音鼓低滚奏 + 钟琴冷色点缀 + 钢琴高音区稀疏单音 + 极低音提琴长音（垫底）

**参数**：E 小调 / 半音化 ｜ 80 BPM（中速）｜ 110 秒循环 ｜ 动态范围 12 dB（**全剧最大**）

**总编制 Prompt（英文）**：

```
Dark chamber suspense cue, cello chromatic descending RACHE motif
in full statement, tremolo strings, low timpani roll,
cold glockenspiel, rising ostinato building dread, a brief violin
phrase inverted (descending instead of ascending) suggesting the
detective motif being shattered, E minor with chromatic tension,
80 BPM, 110 seconds, seamless loop, instrumental only, no vocals,
no synth, no drum machine, discovering a murder scene in a Victorian
empty house, dread and shock, blood-red atmosphere, but restraint,
no jump scare, no orchestral hit, no trailer music, film score
```

**中文自然语言 Prompt（备选）**：

> 室内乐悬疑高点（大提琴主导）。**"血字"动机完整陈述**——大提琴半音下行，10 秒左右，配钟琴冷色点缀（不要"恐怖片"的尖锐钟琴，要"冷但不刺"）；弦乐用 tremolo（颤抖）做紧张层；定音鼓**低滚奏**（不是敲击！是滚动），制造"胸腔压迫感"；中段加入八分 ostinato（半音上行），不协和但**不刺**，是"压迫感"而非"惊吓感"；**关键变形**：独奏小提琴陈述一段下行的短句（与"福尔摩斯动机"的上行相反）——暗示"智性被反转"。E 小调，80 BPM，110 秒循环。**绝对不要** jump scare、不要 trailer hit、不要电影预告片式重音——只是"压迫+冷+暗"。**末尾 3 秒**进入寂静（所有乐器退场，只留极低音提琴一个长音），作为发现尸体后"余震"的体感。画面：玩家推开门，看到德雷伯的尸体和墙上血字 RACHE。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 生成了"惊吓片"风格的尖锐弦乐：去掉 tremolo，改成 "low sustained strings only, no tremolo, no staccato"
- 若嫌"不够冲击"：在 0:50 的 B 段加入一次**单次定音鼓重击**（piano-forte-piano），不要反复重击
- 若 M_SH 反向变形被 AI 写得"明显是完整动机"：把 prompt 改为 "only a 3-note descending fragment, not a full statement"

---

### 6.5 SCENE 4 — 奥德利大院四十六号（追查戒指线索）｜ DAY 1 下午

**剧情定位**：**调查推进的"运动感"**——智性节奏比恐惧感强。这首曲子要让玩家感到"在破案"——节奏型要明显（但仍是钟摆/拨弦承担，不是鼓组）。

**情绪曲线**（100 秒）：
- 0:00 – 0:20 起：A 段——拨弦脉冲（pizzicato）+ 怀表滴答（B 律动层最明显）
- 0:20 – 0:40 主：B 段——M_SH **完整展开**（独奏小提琴陈述完整动机 + 1 次变奏）
- 0:40 – 1:00 推：C 段——加入低音提琴拨弦行走低音 + 钢琴点缀（M_SH 进入智性推进）
- 1:00 – 1:20 收：M_SH 短句收尾，留 1.5 秒怀表单独滴答
- 1:20 – 1:40 回到 A

**主导动机组合**：M_SH（主导，完整展开）+ M_RA（轻，残影钟琴）+ M_LN（远汽笛偶发）

**与前后场景的接续**：
- ← 接续：从 scene3 的余震寂静开始——1.5 秒怀表单独滴答作为"过渡"，让玩家感受到"案件开始推进"
- → 接续：scene5（221B 会客厅思考）需要明显从"行动"转"思考"——本曲末尾的怀表单独滴答自然延续到 scene5 的壁炉声（**接续逻辑**：钟摆→壁炉=从"破案"到"沉淀"）

**编制**：拨弦脉冲（pizzicato cellos）+ 怀表滴答（强 B 律动层）+ 独奏小提琴（M_SH 完整陈述）+ 钢琴点缀 + 低音提琴行走低音 + 残影钟琴（M_RA 远景化）

**参数**：A 小调 ｜ 88 BPM（明显比 scene3 快）｜ 100 秒循环 ｜ 动态范围 ≤ 11 dB

**总编制 Prompt（英文）**：

```
Investigative chamber underscore with forward motion, pizzicato strings
pulse with pocket watch ticking as the rhythm layer (no drums),
solo violin presenting the detective motif in full statement with one
variation, walking contrabass line, light piano accents on offbeats,
faint cold glockenspiel every 12 seconds hinting the past murder,
A minor, 88 BPM, 100 seconds, seamless loop, instrumental only,
no vocals, no drums, no synth, deductive reasoning in progress,
clues connecting, alert and methodical, Victorian London afternoon,
221B parlor acoustic, film score quality
```

**中文自然语言 Prompt（备选）**：

> 调查推进感强的室内乐（拨弦 + 怀表）。**弦乐拨奏**（pizzicato）做律动骨架——四把弦乐每两拍拨一下，配合**怀表滴答**声（这是节奏的关键！不要听到任何鼓组！）；独奏小提琴陈述**完整的"福尔摩斯"动机**（约 12 秒）+ 一次下三度变奏；低音提琴用拨弦走低音（像 walking bass）；钢琴在反拍点轻点缀；钟琴每 12 秒敲一下（M_RA 残影，提示"谋杀未完"）。A 小调，88 BPM（明显比命案现场快），100 秒循环。画面：玩家在奥德利大院四十六号调查戒指线索，**理性推进**——不是恐怖片，是"破案的爽感"。整体听感要像 221B 起居室里录出来的温暖室内乐。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 生成了"鼓组"或"打击乐"：强制改 "no percussion of any kind, only pizzicato strings and pocket watch"
- 若 M_SH 变奏被 AI 写成"完全不同"：把"variation"改为 "slightly ornamented restatement in the same key, same contour, only rhythm slightly varied"
- 若嫌"太满"：去掉钢琴点缀——让拨弦 + 怀表 + 小提琴独奏构成极简三层

---

### 6.6 SCENE 5 — 贝克街 221B 会客厅｜ DAY 1 晚 20:00–21:00

**剧情定位**：**全剧最低点之一**——壁炉前的纯思考时间。**没有血字、没有追踪、只有火与思考**。这首曲子是"呼吸空间"——动态范围最平稳、织体最稀疏。

**情绪曲线**（120 秒，最长一首）：
- 0:00 – 0:30 极静：A 段——钢琴 + 中提琴（M_WT 完整陈述）+ 壁炉声（M_FP 主导）
- 0:30 – 0:50 思考中段：B 段——极轻 M_SH 闪现（仅 3 秒）——"他在想"
- 0:50 – 1:10 留白段：C 段——只留壁炉 + 钢琴高音区极轻泛音（**织体最稀疏**）
- 1:10 – 1:30 回归 A
- 1:30 – 2:00 静止收尾

**主导动机组合**：M_WT（主导）+ M_FP（主导，环境母题）+ M_SH（极轻闪现）+ M_LN（退场）

**与前后场景的接续**：
- ← 接续：从 scene4 的怀表滴答自然过渡——本曲开头的壁炉声把"怀表滴答"无缝替换为"火焰噼啪"，保持"滴答"的体感但不机械
- → 接续：scene6（卡彭蒂耶公寓温情）需要色温保持暖——本曲末尾留 2 秒静止壁炉声，让玩家感受到"家的延续"

**编制**：毡化钢琴 + 中提琴（M_WT 完整陈述）+ 竖琴极轻拨弦 + 怀表滴答（极弱）+ 壁炉噼啪（M_FP 主导）+ 远雷（**可选**，室外场景时加入）

**参数**：F 大调 / D 小调交替 ｜ 70 BPM ｜ 120 秒循环 ｜ 动态范围 ≤ 8 dB（**全剧最窄**）

**总编制 Prompt（英文）**：

```
Contemplative chamber piece, felt piano with viola presenting the
Watson motif, very gentle harp plucks, fireplace crackling as the
dominant ambient layer, faint pocket watch ticking underneath,
a single 3-second solo violin fragment at minute 1 hinting the
detective is thinking, very sparse texture with lots of silence
in the last 20 seconds, F major and D minor alternating, 70 BPM,
120 seconds, seamless loop, instrumental only, no vocals,
no drums, no synth, cozy Victorian parlor at night, fireplace
warmth, deep concentration, thinking music, minimal and unobtrusive,
221B parlor acoustic, film score quality
```

**中文自然语言 Prompt（备选）**：

> 最稀疏的"思考空间"室内乐。毡化钢琴与中提琴构成和声层（**中提琴陈述完整的"华生"主题**，12 秒左右）；竖琴极轻拨弦点缀；**壁炉噼啪声是主导环境层**（这是与其它场景最大的区别——火是这里的主角）；极轻的怀表滴答声垫底（注意：滴答比 scene4 弱得多）；中段（约第 50-53 秒）有 3 秒独奏小提琴的极轻闪现（**只是"他在想"，不是"开始思考"**）；**最后 20 秒**进入留白——只留钢琴高音区的极轻泛音与壁炉声，其它全部退场。F 大调与 D 小调温和交替，70 BPM，120 秒循环（**全剧最长一首**）。整体听感要像坐在 221B 起居室壁炉前的扶手椅里，**没有案件发生，只有思考**。动态范围 ≤ 8 dB（**全剧最平稳**）。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 写得太"温暖/舒适"：把 M_WT 完整陈述改为"陈述后立即淡出"，让中提琴不是"主角"而是"氛围"
- 若嫌"太空"：加入竖琴极轻的滑奏，每 30 秒一次（不要更频繁）
- 若壁炉声被 AI 处理得太"立体/前置"：在 prompt 里强调 "fireplace should sound like background ambience, not foreground, like a soft texture layer"

---

### 6.7 SCENE 6 — 卡彭蒂耶公寓｜ DAY 2 上午

**剧情定位**：**全剧最暖**——探访受害者的过去（婚约、背叛、往事），触及情感层面。**M_VP（温情动机）的首次也是主导出现**。本曲不该有"案件"感，只有"人"的体感。

**情绪曲线**（100 秒）：
- 0:00 – 0:30 暖色起：独奏大提琴（M_VP 主导陈述）+ 钢琴琶音
- 0:30 – 0:50 中段：中提琴加入（M_WT 三度伴行——温情主题被"陪伴"动机支撑）
- 0:50 – 1:10 B♭ 大调转段：所有元素上升一个八度 + 竖琴滑奏——"温情到达高点"
- 1:10 – 1:40 回落：转回 G 小调短句——"温情散去，留下回味"
- 1:40 – 1:55 留白 5 秒——给玩家"哀而不伤"的安静

**主导动机组合**：M_VP（主导，本曲首次完整陈述）+ M_WT（伴行）+ M_FP（轻，壁炉延续）

**与前后场景的接续**：
- ← 接续：从 scene5 的壁炉声自然过渡——scene5 末尾的壁炉 + 本曲开头的钢琴琶音无缝衔接
- → 接续：scene7（郝黎代旅馆危机）需要**色温剧烈逆转**——本曲末尾的 5 秒留白是必要的"心理重置"——给玩家 3 秒静音缓冲后进入 scene7 的雾/冷

**编制**：独奏大提琴（**主导**，M_VP 完整陈述）+ 钢琴琶音 + 中提琴（M_WT 温暖三度伴行）+ 竖琴（滑奏，极轻）+ 壁炉声（**极轻**延续）

**参数**：G 小调 → B♭ 大调（温情段）｜ 64 BPM（**全剧最慢之一**）｜ 100 秒循环

**总编制 Prompt（英文）**：

```
Tender chamber elegy, solo cello presenting the victim-past motif in
full statement (Bb major stepwise descending with dotted lengthening),
intimate felt piano arpeggios supporting, later joined by warm viola
with parallel thirds (the Watson motif accompanying), harp glissando
at the Bb major climax, return to G minor in the last 15 seconds
leaving 5 seconds of silence, no percussion, G minor opening to
Bb major, 64 BPM, 100 seconds, seamless loop, instrumental only,
no vocals, no drums, no synth, a private apartment holding memories
of a broken engagement, melancholy but gentle, human and compassionate,
Victorian parlor acoustic, film score quality
```

**中文自然语言 Prompt（备选）**：

> 室内乐抒情挽歌（独奏大提琴主导）。**独奏大提琴陈述完整的"温情/受害者往事"主题**——B♭ 大调，级进下行，附点节奏延长，约 14 秒；毡化钢琴用琶音支撑；中后段加入中提琴（M_WT 温暖三度伴行，与"温情"主题形成"陪伴"层）；B♭ 大调段落（约 50-70 秒）所有元素上升一个八度 + 竖琴滑奏到达温情高点；最后 15 秒转回 G 小调，**最后 5 秒完全静音**——这是全剧唯一的"主动留白"，给玩家哀而不伤的安静。64 BPM（**全剧最慢之一**），100 秒循环。绝对不要打击乐。画面：玩家在卡彭蒂耶公寓，触摸到受害者的过去（婚约、背叛、回忆）——**没有人死亡、没有案件，只有"人"**。整体听感像 221B 起居室录出来的温暖室内乐，但比 scene5 更"私密"。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 让大提琴变得"催泪/过于悲情"：强制把 "melancholy" 改为 "bittersweet"——**哀而不伤**是关键
- 若 M_VP 陈述后没有"延续感"：在中提琴加入时让大提琴不要完全退场，而是降八度继续（**双层大提琴**）
- 若末段"转回 G 小调"被 AI 处理得太突然：在 prompt 加 "gradual fade of Bb major elements over 8 seconds"

---

### 6.8 SCENE 7 — 郝黎代旅馆｜ DAY 2 深夜

**剧情定位**：**危险第一次真实浮现**——深夜追踪嫌疑人踪迹，逼近真相。本曲是"压迫感"而非"恐惧感"——旅馆走廊的封闭空间 + 远处钟声。

**情绪曲线**（110 秒）：
- 0:00 – 0:20 走廊：A 段——低音提琴颤音（**M_CU 隐现**）+ 大提琴长音（不协和下二度）
- 0:20 – 0:45 逼近：B 段——弦乐不谐和 ostinato（半音化）+ 远处钟声（每 12 秒一次）
- 0:45 – 1:05 高频紧张：极轻的高频泛音（**像蜘蛛丝一样细的高频**——制造不安）
- 1:05 – 1:25 收：B 段简化版 + M_RA 回响（**血字动机的回响**——"这是上一案的延续"）
- 1:25 – 1:50 回到 A

**主导动机组合**：M_CU（隐现）+ M_RA（回响）+ M_LN（走廊里"封闭"的雾声变体）

**与前后场景的接续**：
- ← 接续：从 scene6 的 5 秒留白开始——1 秒静音缓冲后本曲的走廊压迫感直接进入
- → 接续：scene8（终局）需要明显"全面爆发"的色温跃迁——本曲末尾的 M_CU 长音自然延续到 scene8 开头的全奏（**接续逻辑**："压抑"→"爆发"）

**编制**：低音提琴颤音 + 大提琴长音（M_CU 不协和下二度）+ 弦乐不谐和 ostinato + 远处钟声 + 极轻高频泛音 + 低音管乐（**绝对不用完整声律**——只有单音长音）

**参数**：F# 小调 / 半音化 ｜ 76 BPM ｜ 110 秒循环 ｜ **低频加重、高频收紧**（**低通滤波感比 scene2 更强**）

**总编制 Prompt（英文）**：

```
Late-night suspense cue, contrabass tremolo and sustained low cello
with a dissonant minor second below (the culprit motif hinting),
dissonant string ostinato, distant bell tolls every 12 seconds,
faint high harmonic shimmer like spider silk, a cold glockenspiel
echo of the past murder motif in the last 20 seconds, F# minor with
chromatic unease, 76 BPM, 110 seconds, seamless loop,
instrumental only, no vocals, no synth, no drum machine,
stalking a suspect through a dark Victorian hotel corridor at midnight,
oppressive low end, muffled highs, low-pass filtered, danger closing in,
no jump scare, no trailer music, film score quality
```

**中文自然语言 Prompt（备选）**：

> 深夜旅馆的封闭压迫感。**低音提琴颤音**作主家（大提琴长音在它下方**不协和下二度**碰撞——这是"真凶"动机的隐现版，不要暴露完整旋律）；弦乐不谐和 ostinato（半音化、不协和但**不刺**）；远处钟声每 12 秒敲一次（**闷钟**，不是教堂大钟）；极轻高频泛音作不安感（**像蜘蛛丝一样细**，不要明显旋律）；**最后 20 秒**加入钟琴冷色点缀，回响"血字"动机（提示"这是上一案的延续"）。F# 小调 / 半音化，76 BPM，110 秒循环。**低频加重、高频收紧**——比 scene2 更明显的低通滤波感（旅馆走廊封闭空间）。画面：深夜 11 点，玩家在郝黎代旅馆走廊追踪嫌疑人——**不是恐怖片，是"侦探片的危险"**。绝对不要 jump scare、不要 trailer music、不要电影预告片式重音。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 生成了"恐怖片"：去掉 tremolo，改成 "only low sustained tones, no tremolo, no staccato, no high register"
- 若 M_CU 不协和下二度被 AI 处理得"太协和"：把 "dissonant" 改为 "strongly dissonant minor second, should sound uncomfortable"
- 若嫌"太静"：在第 0:45 加入一声"远处的门吱呀声"（**一次**，不重复）——维多利亚木门的标志声

---

### 6.9 SCENE 8 — 贝克街 221B 起居室·终局

**剧情定位**：**全剧最终高点**——真相大白、动机交织、悲悯揭晓、收束。**这首曲子需要"内部结构变化"——不能纯循环**。建议生成两段：
- `scene8.ogg`（揭晓前，90 秒，可循环）
- `scene8_resolve.ogg`（收束，45 秒，不循环）

#### 6.9.1 SCENE 8 主曲（揭晓前，循环）

**剧情定位**：真相揭晓前的紧张积累——所有动机汇聚但不爆发的时刻。

**情绪曲线**（90 秒）：
- 0:00 – 0:20 张力层：D 段——低音提琴颤音延续 + M_CU 长音（**真凶主导**）
- 0:20 – 0:45 交织：B 段——M_SH 与 M_RA 在中音区**对位**（小提琴上行跳进 vs 大提琴半音下行）——"智性 vs 死亡"的最终对峙
- 0:45 – 1:05 推进：A 段——所有元素齐鸣（包括 M_WT 中提琴、M_FP 壁炉声）——"所有线索汇合"
- 1:05 – 1:30 收敛回 D 段，留 5 秒静止（M_CU 长音悬停）

**主导动机组合**：M_CU（主导）+ M_SH（对位）+ M_RA（对位）+ M_WT（轻）+ M_FP（轻）

**与前后场景的接续**：
- ← 接续：从 scene7 的压迫感无缝——M_CU 长音自然延续
- → 接续：到 scene8_resolve 需要**色彩跃迁**（D 小调 → D 大调破雾）——本曲末尾的 5 秒静止是必要的"屏息瞬间"

**编制**：低音提琴颤音 + 大提琴长音（M_CU）+ 独奏小提琴（M_SH 对位）+ 大提琴半音下行（M_RA 对位）+ 中提琴（M_WT 轻）+ 钢琴 + 壁炉（M_FP 轻）

**参数**：D 小调 ｜ 84 BPM ｜ 90 秒循环 ｜ 动态范围 12 dB

**总编制 Prompt（英文）**：

```
Tense chamber climax builder before revelation, cello culprit motif
in full sustained statement against solo violin detective motif in
contrary motion (ascending leap vs descending chromatic), timpani
roll underneath, all themes converging: viola Watson motif lightly,
felt piano supporting, faint fireplace crackling as the home remains,
D minor, 84 BPM, 90 seconds, seamless loop, instrumental only,
no vocals, no synth, no drum machine, the moment before truth is
revealed, all themes converging, no jump scare, no trailer music,
film score quality
```

#### 6.9.2 SCENE 8 RESOLVE（揭晓后收束，不循环）

**剧情定位**：真相揭晓后的**大调破雾 + 悲悯 + 收尾**。这是全剧唯一完整的 D 大调段落——**是"案件结束"的色彩标志**。

**情绪曲线**（45 秒）：
- 0:00 – 0:15 D 小调收束：所有元素在最后一秒完成 D 小调和弦
- 0:15 – 0:25 D 大调破雾：竖琴上行琶音（D 大调）+ 小提琴与大提琴的反向运动（M_CU 的"悲悯变形"）
- 0:25 – 0:40 钢琴独奏：M_VP 温情主题再现（**全曲最后的"人"的触感**）+ 壁炉声独留
- 0:40 – 0:45 静止：所有退场，只留壁炉——**火焰还在烧，人散了**

**主导动机组合**：M_CU（悲悯变形，**大调版本**）+ M_VP（再现）+ M_FP（收尾独占）

**编制**：竖琴（上行琶音）+ 小提琴 + 大提琴（悲悯反向运动）+ 钢琴（**独奏收尾**）+ 壁炉声（**收尾独占**）

**参数**：D 小调 → **D 大调（破雾）** ｜ 72 BPM ｜ 45 秒（**不循环**）｜ 动态范围 8 dB（**收尾平静**）

**总编制 Prompt（英文）**：

```
Resolution cue, D minor resolving into D major, harp ascending
arpeggio at the breakthrough moment, solo violin and cello in
bittersweet contrary motion (culprit motif transformed into compassion),
felt piano alone in the last 15 seconds playing the victim-past motif,
fireplace crackling as the only sound in the final 5 seconds,
72 BPM, 45 seconds, instrumental only, no vocals, no drums, no synth,
truth revealed with compassion, the case closes, warm fading outro,
no triumph fanfare, no celebration, just human warmth, film score quality
```

**中文自然语言 Prompt（合并版，备选）**：

> 终局收束的破雾时刻。前 15 秒仍是 D 小调，所有元素在最后一秒完成 D 小调和弦；第 15-25 秒是关键——**竖琴上行琶音 + 小提琴大提琴的反向运动**完成 D 小调 → D 大调的转段（M_CU 的"悲悯变形"）；第 25-40 秒**钢琴独奏**陈述 M_VP 温情主题再现（**这是案件结束后"人"的触感**）；**最后 5 秒**所有乐器退场，只留壁炉噼啪声——"案件结束，人散了，火焰还在烧"。72 BPM，45 秒，**不循环**。**绝对不要**凯旋号角、不要胜利 fanfare、不要喜庆——只是"人的温暖"。纯器乐，无人声，无鼓，无电子。

**调参建议**：
- 若 AI 在 D 大调段写成"明亮欢快"：把 "D major" 改为 "D major but bittersweet, not triumphant, like a sigh not a cheer"
- 若末段钢琴独奏被 AI 处理得太"短"：明确 "piano solo for at least 15 seconds, no other instruments"
- 若壁炉声在末尾被 AI 截断：明确 "fireplace crackling continues for 5 seconds after all other instruments stop"

---

## 七、流程节点 BGM（4 首）

> 流程节点 BGM 的核心原则：**与场景 BGM 共享声音身份，但不抢戏**。它们是"过场"，**应该让玩家潜意识里感觉到"还在同一个游戏里"**。

### 7.1 总体原则

| 节点 | 与场景 BGM 的关系 | 音量策略 | 时长策略 |
|---|---|---|---|
| WALL（推理墙） | 与 SCENE 5 / SCENE 6 同源（温暖的"思维空间"），但更抽象——只有高频泛音 + 极轻弦乐泛音 | **比场景 BGM 弱 3-4 dB**——推理墙界面停留时间长，音乐不能疲劳 | 90 秒循环 |
| SETTLEMENT（结算） | 与 scene8_resolve 同空间——温暖收束 | 中等音量——结算时间短（10-30 秒），需要"成就感" | 30-60 秒（不循环或循环均可） |
| DIFFICULTY（难度选择） | 与 MENU 同源（警觉+邀请）——**像 MENU 的低能量变体** | 中等音量 | 40 秒循环 |
| CLUE_LOG（线索记录） | 与 WALL 同源（思维空间）——**只是"翻卷宗"的体感** | **比场景 BGM 弱 5 dB**——线索记录是辅助操作 | 70 秒循环 |

### 7.2 4 首流程节点 Prompt（与场景 BGM 共享声音身份）

**WALL（推理墙 / 思维殿堂）**

```
Crystalline chamber underscore, harp harmonics, high-register piano,
faint string overtones, gentle sine pulses like thought forming,
A minor with lydian color, 68 BPM, 90 seconds, seamless loop,
instrumental only, no vocals, no drums, no synth lead,
entering a mind palace, lucid and elevated, spacious,
221B parlor acoustic, film score quality
```

**SETTLEMENT（结算）**

```
Warm achievement cue, string ensemble with piano and ascending harp,
gentle swell, C major, 80 BPM, 50 seconds, instrumental only,
no vocals, no drums, no synth, accomplishment and relief,
a case well reasoned, dignified not triumphant, 221B parlor acoustic,
film score quality
```

**DIFFICULTY（难度选择）**

```
Neutral anticipatory underscore, low piano chords with sustained
strings, a sense of weighing a decision, D minor, 72 BPM,
40 seconds, seamless loop, instrumental only, no vocals,
no drums, no synth, restrained, same acoustic as MENU,
film score quality
```

**CLUE_LOG（线索记录）**

```
Organizing underscore, pizzicato pulse with light piano and
soft strings, paper-turning rhythm, A minor, 80 BPM, 70 seconds,
seamless loop, instrumental only, no vocals, no drums, no synth,
orderly and calm, same acoustic as WALL, film score quality
```

---

## 八、Stinger / UI / 环境音（继承 v1.2 + 动机化原则）

> **核心升级**：v1.2 的 stinger 是"音效型"短音；本节升级为"**动机切片**"——每个 stinger 应该是某条主导动机的 1–3 秒切片。这样听感统一 + 强化记忆 + 降低生成成本。

### 8.1 8 条 Stinger 的动机来源

| ID | 触发 | **动机来源** | 时长 | 听感要求 |
|---|---|---|---|---|
| CLUE_FOUND | 收集到一条线索 | **M_SH 的 1 秒上行切片**（小提琴小三度跳进） | 0.8–1.2 s | 轻"啊哈"：拨弦上行 + 铃音，明亮不刺耳 |
| WALL_OPEN | 进入推理墙 | **M_WT 的 1 秒中提琴上行** | 1.5–2.5 s | 竖琴上行泛音，"思维殿堂"入场 |
| WALL_LINK_OK | 推理墙连线成立 | **M_SH 的尾音**（纯五度上行） | 0.8–1.2 s | 确认感：五度跳进，温暖肯定 |
| WALL_CONFLICT | 推理矛盾 / 判断错误 | **M_RA 的 2 秒半音下行**（钟琴） | 1.0–1.5 s | 低沉警示：半音撞音，闷不刺 |
| REVEAL | 真相大白 | **M_CU + M_SH 同时爆发的 2 秒切片** | 2.5–3.5 s | 全奏揭示，动机交织爆发后留余韵 |
| SHOCK | 惊吓 / 危机 | **M_RA 钟琴冷色 1.5 秒** + 极轻弦乐 glissando | 1.5–2.0 s | 急促但不刺 |
| STAR_UP | 结算星级上升 | **M_VP 上行变体**（B♭ 大调上行琶音） | 1.0–1.5 s | 上行琶音，变现式明亮 |
| STAR_DOWN | 结算星级下降 | **M_RA 半音下行的轻奏**（钟琴） | 1.0–1.5 s | 下行小二度，轻微失落不刻薄 |

### 8.2 Prompt 示例

**CLUE_FOUND（动机切片版）**

```
Short UI stinger, solo violin ascending minor third leap (the
Sherlock motif fragment), 1 second, instrumental only, no drums,
no synth, bright but soft, the satisfying click of realizing
something, clean attack and quick decay
```

**REVEAL（动机交织爆发版）**

```
Short revelation stinger, full strings with the detective motif
ascending leap colliding with the culprit motif descending minor
second, 3 seconds, instrumental only, no drums, no synth,
no trailer hit, the moment of truth with bittersweet compassion,
not triumphant fanfare, film score quality
```

### 8.3 UI 音效（继承 v1.2，强化"动机化"）

| ID | 用途 | **动机来源** | 时长 |
|---|---|---|---|
| UI_CLICK | 按钮点击 | M_WT 的钢琴单音切片（中提琴三度伴行的钢琴化） | 40–80 ms |
| UI_HOVER | 按钮悬停 | M_LN 的极轻高频泛音切片 | 20–40 ms |
| UI_BACK | 返回 / 关闭面板 | M_RA 半音下行的钢琴化 | 150–250 ms |
| UI_CONFIRM | 确认 / 提交 | M_SH 的小三度跳进钢琴化 | 200–300 ms |

### 8.4 环境音（继承 v1.2，与场景接续强化）

| ID | 内容 | 与场景关系 |
|---|---|---|
| AMB_FOG_LONDON | 伦敦雾 / 远处城市底噪 | SCENE 2 / SCENE 3 / SCENE 7 的环境母题 |
| AMB_GASLAMP | 煤气灯嘶嘶声 | SCENE 2 / SCENE 7（室外夜景） |
| AMB_CARRIAGE | 远处马车 | MENU（建立时代感）/ SCENE 4（调查节奏） |
| AMB_RAIN_WINDOW | 窗上雨声 | 可选——SCENE 7（旅馆窗外雨声） |
| AMB_FIREPLACE | 壁炉 | SCENE 5 / SCENE 6 / SCENE 8_resolve（主导） |

---

## 九、声音身份的 QA 自检

> **生成后必须逐条核对**——这是"是不是同一首游戏"的最低保障。

### 9.1 单曲自检

- [ ] **乐器自检**：核心编制里至少 3 件在场（毡化钢琴 + 弦乐 + 钟琴/竖琴之一）？
- [ ] **打击乐自检**：频谱里 60-200 Hz 没有鼓 kick 的特征峰？没有 snare/hi-hat 元素？
- [ ] **人声自检**：1-5 kHz 没有 vowel formants？没有哼唱痕迹？
- [ ] **电子音自检**：频谱 > 8 kHz 没有 synth bell/digital sparkle 的谐波特征？
- [ ] **混响自检**：RT60 在 1.8-2.4 秒范围内？没有 > 3 秒的大厅混响？
- [ ] **响度自检**：集成响度 -14 LUFS ±1？true peak ≤ -1 dBTP？
- [ ] **循环自检**：首尾采样值连续，无爆音无静音间隙？

### 9.2 全局自检（关键）

- [ ] **跨曲听感一致性**：把 9 首按顺序播放——听起来像"同一组乐手在同一天录的"吗？
- [ ] **动机可识别性**：M_SH 在 MENU / SCENE 1 / SCENE 4 / SCENE 8 出现时，玩家能听出"是同一条旋律的不同变体"吗？
- [ ] **情绪河流顺序**：从 SCENE 1 (暖) → SCENE 2 (冷) → SCENE 3 (冲击) → SCENE 4 (推) → SCENE 5 (暖呼吸) → SCENE 6 (更暖) → SCENE 7 (冷危机) → SCENE 8 (爆发→破雾) 的情绪轨迹，听感是否清晰？
- [ ] **高点不超过 2 个**：SCENE 3 和 SCENE 8 是仅有的高紧张度点，其它场景是否都明显低于它们？
- [ ] **大调时刻不超过 2 个**：SCENE 3 的短暂暗示 + SCENE 8 的完整破雾——其它场景是否都维持小调为家？

---

## 十、制作管线与里程碑

### 10.1 与 M1/M2/M3 的对应关系（继承 v1.2 框架）

| 里程碑 | 范围 | 与本文档对应 |
|---|---|---|
| **M0（声音身份基线）**（新增） | 先生成 MENU + SCENE 5 + SCENE 8_resolve 三首——它们分别代表"警觉入口""壁炉空间""温暖收尾"三种**声音身份基准**。M0 通过后才能开始 M1。 |
| **M1（核心场景）** | MENU + SCENE 1 / 2 / 3 / 8（含 resolve）+ WALL + CLUE_FOUND + WALL_CONFLICT + REVEAL（10 首） |
| **M2（完整场景）** | 补齐 SCENE 4 / 5 / 6 / 7 + SETTLEMENT / DIFFICULTY / CLUE_LOG + 全部 8 stinger |
| **M3（质量打磨）** | 全部 UI 音效 + 全部 5 ambience + 母带统一 + QA 自检通过 |

### 10.2 M0 声音身份基线（关键里程碑）

> **为什么需要 M0**：如果先生成所有 9 首再统一声音身份，**很可能需要返工 70%**——AI 工具对"维多利亚室内乐"的诠释差异极大。M0 用 3 首代表三种身份基准，**通过后才允许生成其它曲子**。

**M0 通过标准**：
- [ ] 三首的核心乐器完全一致（同源）
- [ ] 三首的混响空间完全一致（同棚）
- [ ] 三首的响度一致（−14 LUFS ±1）
- [ ] 三首在频谱上的低频能量分布一致（都是"温暖木质室内"质感）
- [ ] 三首拼在一起播放 30 秒，玩家能感受到"同一首游戏的配乐"

### 10.3 全剧交付检查（最终）

- [ ] 9 首场景 BGM + 4 首流程曲 + 6 条主导动机 + 8 条 stinger + 4 条 UI + 5 条 ambience = **36 个音频资产**
- [ ] 全部 OGG 格式（Godot 原生），44.1/48 kHz
- [ ] 全部按 §三的命名落位到 `godot_project/assets/audio/`
- [ ] 全部通过 §九 的自检
- [ ] Web 导出后浏览器硬刷验证（替换 `tools/inject_pck_version.py` 时间戳）

---

## 附录 A：与原 v1.2 清单的差异点速查（迁移指南）

| 维度 | v1.2 | 本文档（v1.0 音乐总监稿） |
|---|---|---|
| 文档定位 | 单首 prompt 速查表 | 全剧音乐蓝图 |
| 总章节数 | 8 章（使用前必读 / 场景 / 流程 / 动机 / stinger / UI / 验收 / 优先级） | 10 章 + 附录 |
| 新增概念 | —— | 虚拟乐队 / 录音棚规格 / 情绪河流图 / 动机网络 / 分幕结构 / 接续规则 / M0 声音身份基线 |
| 主导动机数 | 5 条 | **7 条**（新增 M_VP 温情 / M_FP 壁炉两条环境母题） |
| 每首 prompt 长度 | 中等 | **长**（加入分幕结构 + 动机组合 + 接续规则） |
| 场景 BGM 数量 | 9 首 | 9 首（**SCENE 8 拆为 2 段：主曲 + resolve**） |
| 流程节点 BGM | 4 首 | 4 首（**强化"与场景 BGM 共享声音身份"原则**） |
| stinger 设计思路 | 听感型 | **动机切片型**（每条 stinger 对应一条主导动机） |
| UI 音效 | 4 条 | 4 条（**强化"动机化"——每条 UI 音对应一条主导动机的钢琴化**） |
| 优先级建议 | 8 段 | **M0/M1/M2/M3 里程碑** |

---

## 附录 B：使用本文档的步骤（工具操作）

1. **先生成 M0 三首**（MENU / SCENE 5 / SCENE 8_resolve）→ 自检 → 通过后再继续。
2. **按 §六 顺序生成 9 首场景 BGM**（每首两段 prompt：英文给工具 + 中文备选）。
3. **每首生成后跑 §九 的单曲自检** + **每 3 首跑一次全局自检**（"拼在一起是否同一首游戏的配乐"）。
4. **§七 4 首流程节点 BGM**（与场景 BGM 共享声音身份）。
5. **§八 stinger / UI / 环境音**——按"动机切片"思路生成。
6. **按 §10.3 全剧交付检查** → 替换占位 → 导出 → 验证。

---

**文档结束。**

**作者立场**：本剧配乐的核心是"**维多利亚室内乐 + 智力庄严 + 思考的节奏**"——AI 工具能生成"听起来像电影配乐"的曲子很容易，但能生成"听起来像维多利亚起居室里一组真实乐手正在为福尔摩斯案件演奏"的曲子很难。**这才是本剧配乐追求的质感**——不是"震撼"，不是"紧张"，是"亲密、庄严、思考"。