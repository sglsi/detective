# 测试说明（headless 回归）

> 设计文档对应： `docs/设计文档/架构比对与修正建议.md` §5
> 现状：无 GUT。现有测试为 headless 脚本，分两类。

## 一、测试分类

### 标准测试（`tests/`）
| 文件 | 类型 | 说明 | 依赖 |
|---|---|---|---|
| `test_save_load.gd` | `--script`（SceneTree） | 存/读档端到端：槽位=3、自动分配、时间倒序、阶段恢复 | 无（离线） |
| `test_api_integration.gd` | 场景 `_ready` | APIManager/AuthManager/SaveManager 与后端通信 | **需后端 3001 运行** |

### 核心回归（`tools/`、`scripts/`）
| 文件 | 运行方式 | 期望结果 |
|---|---|---|
| `tools/test_tool_system.gd` | `--script` | 打印 `P1_RESULT: PASS` |
| `scripts/test_user_isolation.gd`（场景 `scenes/test_user_isolation.tscn`） | `--headless "res://scenes/test_user_isolation.tscn" --quit` | `PASS=15 FAIL=0` |

### ad-hoc 复现（`tools/p*.gd`）
一次性问题复现脚本（如 `p13_observer_guard_test.gd` → `P13_GUARD_OK`、`p15_architecture_unification.gd` → `P15_STRUCT_OK`、`p16_lance_wall_repro.gd` → 推理墙卡片无空白）。**不进回归套件**，按需手动跑。

## 二、统一运行入口（离线）

```bash
bash tools/run_headless_tests.sh
```

跑核心离线回归：工具系统、账号隔离（15/15）、存/读档端到端。约 1–2 分钟。

## 三、手动命令

```bash
GODOT="/d/AI/godot/Godot_v4.7-stable_win64/Godot_v4.7-stable_win64.exe"
cd /d/AI/detective/godot_project

# 工具系统
"$GODOT" --headless --script tools/test_tool_system.gd

# 账号隔离（场景）
"$GODOT" --headless "res://scenes/test_user_isolation.tscn" --quit

# 存/读档端到端
"$GODOT" --headless --script tests/test_save_load.gd

# API 集成（需先启动后端 3001；--ci 退出码=失败数）
"$GODOT" --headless --script tests/test_api_integration.gd --ci
```

## 四、后续演进

- 按节奏引入 **GUT** 跑关键路径（存档 / 账号隔离 / 推理墙 / 工具系统）。
- 不强行追 60% 覆盖；以关键路径稳定为先。
- 接入 CI 时，把 `run_headless_tests.sh` 作为 pre-push / 流水线一步。
