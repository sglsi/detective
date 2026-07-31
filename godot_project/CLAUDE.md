# 项目规则（CLAUDE.md）—《谁是大侦探 / 贝克街侦探事务所》

> 本文件是工程的**铁律清单**。任何改动、重构、新功能、调试脚本都必须遵守。
> 违反任一条即视为严重缺陷，必须在其被引入的同一轮内修复。
> 本文件由用户（思傅）于 2026-07-28 明确要求建立，核心诉求：**用户数据与存档绝对不可丢失**。

---

## 1. 【最高优先级】用户信息与存档：绝对不可删除 / 重置

用户注册信息（账号、密码哈希、邮箱、用户 id）与游戏存档是玩家**最最最重要**的数据，
**绝不允许以任何方式被删除、清空或重置**。用户已两次反馈"注册信息被删除"，这是信任底线。

### 1.1 明确禁止
- ❌ 删除 `user://accounts.json` 中的任何账号条目。
- ❌ 删除 `user://saves/` 下的任何用户存档文件。
- ❌ 任何"清空全部用户 / 重置游戏 / 清缓存 / 清理空间"类功能或脚本触碰以上两个目录。
- ❌ 在"调试 / 数据迁移 / 版本升级"脚本里批量移除用户数据。
- ❌ 即便检测到本地账号 id 重复，也**只可保留并复用旧数据，绝不可"先删后建"**。
- ❌ 退出登录时删除账号（退出只清 `session.json`，绝不碰 `accounts.json`）。

### 1.2 必须做到
- **存档按用户隔离**：命名空间 = `AuthManager.get_user_id()`，落 `user://saves/<namespace>/slot_N.json`。
- **跨用户不可互读**：不同用户之间绝对不可读取/写入彼此存档。
  隔离回归测试 `scripts/test_user_isolation.gd` 必须始终 **15/15 PASS**（改动后必跑）。
- **Web 持久化**：Web 构建必须在 `AuthManager._ready()` 调用 `navigator.storage.persist()`，
  请求浏览器将本站存储（IndexedDB，含账号与存档）标记为持久化，防止被浏览器自动清理导致"账号消失"。
- **会话自动恢复**：启动时 `_restore_session()` 按 `session.json` 记住的邮箱自动恢复上次登录，
  避免重载/重启后退化为游客（guest 共享命名空间）而串档。
- **账号 id 唯一**：本地 id 用 `"local_<时间戳>_<随机数>"`，防同秒碰撞。

### 1.3 串档根因（历史教训，禁止回退）
`Dictionary.merge(user)` 在 Godot 4.7 **默认不覆盖已有键** → 重新登录后 `user_data`
残留上一账号 id，导致读错存档命名空间、不同用户互相看到彼此存档。
**修复：`user_data.merge(user, true)`（覆盖式合并）。任何合并用户数据的地方都必须用 `true`。**

---

## 2. 改动后验证 SOP（改完必跑，顺序重要）
1. **全量编译**：`godot --headless --check-only` → 零 SCRIPT/Compile/Parse Error。
   ⚠️ 盲区：`--check-only` 不扫描仅被 `load()` 动态引用的脚本，需靠下一步兜底。
2. **逐场景加载**：`godot --headless "res://scenes/<s>.tscn" --quit`
   （main_menu + scene1-8 + prototype_procedural_bg，共 10 个）→ 全 EXIT=0 且零 "SCRIPT ERROR"。
3. **隔离回归**：`godot --headless` 跑 `scenes/test_user_isolation.tscn` → **PASS=15 FAIL=0**。
4. **Web 导出**：`godot --headless --export-release "Web" "D:/AI/detective/godot_project/web_build/index.html"` → EXIT=0。
   ⚠️ 导出目标路径必须 Windows 风格；且导出不重解析 .gd 源码（可能用旧缓存），真实验证以 1/2/3 为准。

---

## 3. 其他铁律
- **GDScript warnings-as-errors**：任何裸 Variant 推断（`var x := dict.get(...)` / `dict[key]`）
  判 Parse Error。须显式标注类型（`String`/`bool`/`int`）。
- **弹窗/面板单例 + toggle**：每次 `add_child` 无互斥会"点几次叠几个"；
  用 `_modal_panel`/`_wall_instance` 引用 + 同名再点关闭。
- **CanvasLayer 层级**：ToolBar=CanvasLayer(layer=128) 常驻主视口之上；推理墙是主视口子节点，
  开墙须 `hide_toolbar()` 才置顶。
- **立绘映射**：`scripts/dialogue/portrait_library.gd` 的 `NPC_PORTRAITS` 按对话 `speaker`
  字段映射半身像路径；新增说话人必须同步补映射键，否则对话框半身像缺失。
- **背景图**：场景背景为 `assets/scenes/sc_0N_*.jpg`（已压缩），脚本经 `sceneN.gd` 的
  `scene_background()` 动态 `load()`；删除/替换须同步改 `scene_controller.gd` 的映射表。
- **提交风格**：中文 `feat:`/`fix:`/`chore:` 前缀，message 写清根因 + 验证结果；
  改完必跑 §2 SOP 再提交。

---

## 4. 环境约束（本机）
- Godot 固定 `D:\AI\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe`（4.7.stable）。
- 沙箱无 GitHub 写凭据：本 agent 只负责提交，push 由思傅在本机 `git push origin main`。

---

## 5. 暂缓项（Deferred · MVP 不做）

> 见设计文档 `docs/设计文档/架构比对与修正建议.md` §6。以下项在 E-25 中曾标「已接受」，
> 经架构比对确认当前阶段不做；**禁止在 MVP 阶段引入对应模块/SDK**，避免范围蔓延。

- **C#**：保持纯 GDScript。当前 2D 体量无性能瓶颈，不引入 .NET 运行时与编译链。
- **i18n（国际化）**：未建 LocalizationManager / CSV / PO 体系。MVP 面向单一语种，出海前再做（记为技术债）。
- **广告 SDK**（AdMob / AppLovin / Pangle）：MVP 不接入。
- **分析 SDK**（Firebase 等）：MVP 不接入。

