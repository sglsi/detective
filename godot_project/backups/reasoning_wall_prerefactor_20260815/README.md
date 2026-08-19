# 推理墙架构备份（大改前快照）

> 用途：在「案件级一张大墙 + 推理墙代码架构重构」大改前，留存当前（2026-08-15）推理墙的完整实现，供大改过程中回查对照。
>
> 对应 git 提交：`5d44a88`（HEAD）；其中 `reasoning_wall.gd` 本体最近改动提交 `3c38ad7`。
> **不可变恢复方式**：`git show backup/reasoning-wall-prerefactor-20260815:godot_project/scripts/clue/reasoning_wall.gd`
> （本目录文件副本便于在 IDE 中直接阅读，但 `git clean -fd` 会删掉未跟踪副本，git tag 才是真正的安全网。）

---

## 一、文件清单与角色

| 文件 | 角色 | 关键行 |
|---|---|---|
| `src/reasoning_wall.gd` | **推理墙主体**：1733 行 UI 单体（extends Control），五区布局+线索库+假设树+四级验证+三星+跨重开持久化 | 全文 |
| `src/detective_scene.gd` | **场景接入点**：全项目唯一开墙入口 `_open_wall`；持有 `_wall_state` 持久化字典 | `_open_wall` L363；`get_collected(src)` L396；`setup` 调用 L403 |
| `autoload/clue_event_bus.gd` | 线索事件总线（**仅 4 信号**：clue_discovered / clue_recorded / clues_linked / verification_complete） | 全文 |
| `autoload/clue_system.gd` | **线索后端**：`get_collected(src)` 按场景取已收集线索——「分场景孤岛」的源头 | `get_collected` |
| `autoload/difficulty_manager.gd` | 难度 autoload（EASY/NORMAL/HARD），墙内 11 处引用（hint_level / auto_reveal 等） | — |
| `data/clue_data.gd` | 线索数据模型（**15 字段，缺三级标签**） | 全文 |
| `docs/06_推理墙运行机制.md` | 设计文档：推理墙正式规格（五区/标签体系/人证物证/跨线索交互） | — |
| `docs/一致性校验/*` | 推理墙一致性审查报告（现状与文档偏差记录） | — |
| `tests/*` | 推理墙回归测试（行为契约）：`test_reasoning_wall` / `_verdict` / `test_wall_persist`(跨重开) / `test_wall_auto_trap`(场景二卡死) / `test_early_wall_submit` / `p11/p12/p14/p16`(场景流转) 等 | — |

---

## 二、数据流（当前实现）

```
场景 dialogue "think" 动作
   └─ DetectiveScene._open_wall(source, hypothesis, on_verify, on_continue)   [detective_scene.gd:363]
        ├─ clues = ClueSystem.get_collected(src)        ← ⚠️ 只取【本场景】线索（分场景孤岛）
        ├─ wall = load(reasoning_wall.gd).new()
        └─ wall.setup(clues, hypo, cb, _, _difficulty, on_continue, _wall_state, advance, true)  [L403]
             ├─ 五区 UI 构建：_create_ui → 顶/底栏 + 左(线索库)中(假设树+关联)右(战场) + 三星/里程碑
             ├─ 玩家勾选线索关联假设：_toggle_association(cid)   [L1111]
             ├─ 提交验证：_on_verify_pressed [L1155] → _on_verify_confirm [L1274]
             │     └─ get_verdict() [L111] → 四级判定 → on_advance 回调推进剧情
             └─ 跨重开持久化：状态写回 _state_store(=场景._wall_state)，关墙重开可恢复 [L126/L155]
```

---

## 三、方法地图（reasoning_wall.gd，含行号）

**生命周期**
- `setup` L90 · `get_verdict` L111 · `close_wall` L118 · `_restore_state` L126 · `_persist_state` L155

**UI 构建**
- `_create_ui` L177 · `_create_top_bar` L222 · `_create_bottom_bar` L279 · `_create_left_panel`(线索库) L315 · `_create_center_panel`(假设树+关联) L443 · `_create_right_panel`(战场) L561

**线索库**
- `_refresh_clue_list` L615 · `_current_filter` L635 · `_clue_state` L642 · `_make_clue_card` L648 · `_on_filter_pressed` L685 · `_on_search_changed` L694

**假设树 / 证据关联**
- `_refresh_hypothesis_tree` L699 · `_make_hypothesis_node` L720 · **`_evidence_for_hypothesis` L785 → ⚠️ L788 退化为「全部关联线索当全局证据」** · `_refresh_assoc_panel` L798

**战场（采纳/排除/矛盾）**
- `_refresh_battlefield` L833 · `_make_battle_hypo_card` L883 · `_make_battle_contra_card` L933 · `_on_battle_hypo_pressed` L982 · `_on_battle_contra_pressed` L994 · `_style_battle_btn` L1005 · `_battle_status_text` L1023 · `_refresh_battlefield_status_only` L1041

**详情 / 交互**
- `_show_clue_detail` L1050 · `_on_clue_card_pressed` L1107 · `_toggle_association` L1111 · `_update_all` L1135 · `_update_verdict_label` L1145

**验证 / 报告 / 推进**
- `_on_verify_pressed` L1155 · `_on_verify_confirm` L1274 · `_close_verify_win` L1287 · `_compute_report` L1303

**里程碑 / 三星**
- `_init_milestones` L1327 · `_update_milestone_ui` L1338 · `_update_star_rating` L1352

**历史面板 / 输入**
- `_on_investigate_pressed` L1407 · `_show_history_panel` L1412 · `_history_section` L1601 · `_input` L1639 · `_on_back_pressed` L1672 · `_on_help_pressed` L1687

**测试钩子**
- `get_milestone_state` L1705 · `get_last_report` L1715 · `get_difficulty` L1719 · `test_associate` L1723 · `_debug_ui_counts` L1727

---

## 四、大改前必须知道的「已知短板」（设计文档要求但代码未落地）

1. **分场景孤岛（跨场景关联被结构堵死）**
   `detective_scene.gd:396` `ClueSystem.get_collected(src)` 只传本场景线索；`_open_wall(source)` 随场景开关。
   设计文档 §2.1 要求「全案证据统一收纳中心」未实现。**案件级大墙首先要打通此处。**

2. **三级标签体系缺失**
   `data/clue_data.gd` 仅 15 字段，**无 `content_tags` / `attribute_tags` / `relation_tags`**（文档 08 框架要求）。
   导致：假设树无法按标签自动匹配线索、人证/物证无法区分。

3. **证据关联逻辑退化**
   `reasoning_wall.gd:788` 注释明写「scene1 当前数据未打 `relation_tags`，退化为：所有已关联线索都作为全局证据展示」。
   大改时用 `relation_tags` 重写此函数。

4. **跨线索交互 / 矛盾检测 UI 未实现**
   设计文档 §3.2「线索对比台」「矛盾疑点册」当前没有对应 UI（战场里的矛盾卡是手填假设数据，非玩家拖线索比对触发）。

5. **人证 / 物证资源无数据底座**
   仅有展示用 `category` 字符串，无 `attribute_tags`（直接物证/目击证词/二手传闻/嫌疑人陈述）与可信度评估。

---

## 五、大改方向（已与用户确认）

- **案件级一张大墙**：假设树与线索池升为「案件级」（一次开墙 = 全案看板，跨场景线索汇入同一推理墙），而非每场景独立一份。
- **代码架构重构**：在保留现有五区能力（线索库/假设树/战场/里程碑/三星/验证判定/跨重开持久化）前提下解耦。
- **参考但不照搬** `09_线索与推理系统进阶设计方案_v1.2.md`：该提案基于更早代码快照（误判难度/假设/验证引擎为待建，实际已内联），且其 6 组件大拆不交付「跨场景关联+人证物证」目标；v1.2 中仅 `VerificationEngine` 低配抽取（验证逻辑纯函数化+单测）性价比高，可采纳；`ReasoningGraph` 当前 YAGNI。
- **回归红线**：大改必须过 `tests/` 下现有推理墙回归套件（尤其 `test_wall_persist` 跨重开、`test_wall_auto_trap` 场景二卡死、`p11/p12/p14/p16` 场景流转），否则会复活已修的卡死点。
