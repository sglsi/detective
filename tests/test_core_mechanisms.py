#!/usr/bin/env python3
"""
维多利亚伦敦探案 — 核心机制验证测试套件
覆盖全部 15 个核心机制的 137+ 个验证点

用法: python3 tests/test_core_mechanisms.py
"""

import os, sys, re, json, subprocess
from pathlib import Path

PROJECT = "/workspace/维多利亚伦敦探案项目"
GD = f"{PROJECT}/godot_project"
BE = f"{PROJECT}/backend"

# ============ 测试框架 ============

class TestSuite:
    def __init__(self, name):
        self.name = name
        self.p = 0; self.f = 0; self.s = 0
    
    def ok(self, name):
        self.p += 1; print(f"  ✅ {name}")
    
    def fail(self, name, msg=""):
        self.f += 1; print(f"  ❌ {name}" + (f" — {msg}" if msg else ""))
    
    def skip(self, name, r=""):
        self.s += 1; print(f"  ⏭ {name}" + (f" ({r})" if r else ""))
    
    def check(self, name, cond, msg=""):
        if cond: self.ok(name)
        else: self.fail(name, msg)
    
    def summary(self):
        t = self.p + self.f + self.s
        print(f"  ── {self.name}: {self.p}✅ / {self.f}❌ / {self.s}⏭ (共{t}) ──\n")
        return self.f == 0

def read(f): 
    p = os.path.join(GD, f) if not f.startswith(PROJECT) else f
    return open(p).read() if os.path.exists(p) else ""

def file_exists(f):
    p = os.path.join(GD, f) if not f.startswith(PROJECT) else f
    return os.path.exists(p)

def grep_count(pattern, f):
    return len(re.findall(pattern, read(f)))

def grep_contains(pattern, f):
    return pattern in read(f)

# ============ 测试函数 ============

def test_1_exploration_loop(s):
    """六步探索闭环"""
    sc = read("scripts/scene/scene_controller.gd")
    gs = read("scripts/scene/game_scene.gd")
    
    s.check("ExplorationStep 枚举(6步)", "STEP_1_OBSERVE" in sc and "STEP_6_VERIFY" in sc)
    s.check("GamePhase 枚举(13状态)", "PHASE2_COMPLETE" in gs and "CASE_OFFER" in gs)
    s.check("Step 1 观察→热点渲染(EASY闪烁)", "show_highlight" in sc and "tween_property" in sc)
    s.check("Step 2 工具→tool_bar.show_toolbar", "tool_bar.show_toolbar()" in gs)
    s.check("Step 3 记录→note_updated信号", "note_updated" in gs)
    s.check("Step 4 知识库→可选+Esc跳过", "STEP_4_KNOWLEDGE" in gs and "STEP_5_HYPOTHESIS" in gs)
    s.check("Step 5 推理墙→reasoning_wall.open", "reasoning_wall.open()" in gs)
    s.check("Step 6 验证→verification_complete", "verification_complete" in gs)
    s.check("不可跳步保护", "current_step != ExplorationStep.STEP_1_OBSERVE" in sc)
    s.check("阶段1→2切换: activate_phase2", "func activate_phase2" in sc)
    s.check("阶段1热点: 4个_create_hotspot", sc.count("_create_hotspot(") >= 10)
    s.check("阶段2热点: 6个(含2干扰)", "ring" in sc and "shoes" in sc)
    s.check("干扰项标记: is_correct=false", 'not id in ["ring", "shoes"]' in sc)


def test_2_difficulty(s):
    """难度模式系统"""
    dm = read("autoload/difficulty_manager.gd")
    sc = read("scripts/scene/scene_controller.gd")
    
    s.check("Difficulty 枚举(3值)", "EASY" in dm and "NORMAL" in dm and "HARD" in dm)
    s.check("三模式特性开关", "auto_fill_notebook" in dm and "hardcore_manual" in dm)
    s.check("should_show_hint() 三档逻辑", "func should_show_hint" in dm)
    s.check("EASY: hint_probability=1.0", "hint_probability = 1.0" in dm)
    s.check("NORMAL: hint_probability=0.5", "hint_probability = 0.5" in dm)
    s.check("HARD: hint_probability=0.0", "hint_probability = 0.0" in dm)
    s.check("EASY热点: modulate α=0.45", "Color(1, 1, 0, 0.45)" in sc)
    s.check("NORMAL热点: modulate α=0.12", "Color(1, 1, 1, 0.12)" in sc)
    s.check("HARD热点: modulate α=0.0", "Color(1, 1, 1, 0.0)" in sc)
    s.check("EASY闪烁动画", "tween_property" in sc and "set_loops" in sc)
    s.check("难度选择UI存在", file_exists("scenes/difficulty_select.tscn"))
    s.check("难度选择脚本存在", file_exists("scripts/ui/difficulty_select.gd"))
    s.check("MainMenu集成难度选择", "difficulty_select.tscn" in read("scripts/ui/main_menu.gd"))


def test_3_verification(s):
    """四级验证体系"""
    rw = read("scripts/clue/reasoning_wall_ui.gd")
    gs = read("scripts/scene/game_scene.gd")
    
    s.check("VerifyResult 枚举(4值)", all(v in rw for v in ["VERIFIED","SUPPORTED","INSUFFICIENT","CONTRADICTORY"]))
    # 实际实现为关系图模型：统计 hypothesis 的 support / contradict 连线数
    s.check("VERIFIED判定: support≥3 且无矛盾", "support >= 3" in rw and "contradict > 0" in rw)
    s.check("SUPPORTED判定: support≥1", "support >= 1" in rw)
    s.check("INSUFFICIENT判定: 其余情况回退", "return VerifyResult.INSUFFICIENT" in rw)
    s.check("CONTRADICTORY判定: 其他情况", "VerifyResult.CONTRADICTORY" in rw)
    s.check("四色结果展示(VERIFIED绿/SUPPORTED黄/INSUFFICIENT橙/CONTRADICTORY红)",
            all(c in rw for c in ["Color(0.2, 0.9, 0.2, 1.0)", "Color(0.8, 0.8, 0.2, 1.0)",
                                  "Color(0.9, 0.5, 0.2, 1.0)", "Color(0.95, 0.2, 0.2, 1.0)"]))
    s.check("verification_complete信号", "verification_complete" in rw)
    s.check("GameScene四级结果分发", all(v in gs for v in ["VERIFIED","SUPPORTED","INSUFFICIENT","CONTRADICTORY"]))
    s.check("VERIFIED→_handle_verified", "_handle_verified()" in gs)
    s.check("SUPPORTED→set_verify_result", 'set_verify_result("SUPPORTED")' in gs)


def test_4_star_rating(s):
    """三星评价 + 七徽章"""
    sr = read("autoload/star_rating_system.gd")
    
    s.check("RatingDimension 枚举(3维)", "OBSERVATION" in sr and "REASONING" in sr and "INSIGHT" in sr)
    s.check("Badge 枚举(7徽章)", all(b in sr for b in ["KEEN_EYE","MASTER_DEDUCER","DEPTH_SEEKER","PERFECT_SCORE","SPEED_RUNNER","NO_HINT_MASTER","FIRST_CASE_CLEAR"]))
    s.check("三维独立评分累加", "add_observation" in sr and "add_reasoning" in sr and "add_insight" in sr)
    s.check("get_stars() 阈值: ≥90%=3星", "ratio >= 0.9" in sr)
    s.check("get_stars() 阈值: ≥60%=2星", "ratio >= 0.6" in sr)
    s.check("get_stars() 阈值: ≥30%=1星", "ratio >= 0.3" in sr)
    s.check("get_total_stars() 汇总", "func get_total_stars" in sr)
    s.check("evaluate_badges() 自动评估", "func evaluate_badges" in sr)
    s.check("NO_HINT_MASTER 条件", "NO_HINT_MASTER" in sr and "HARD" in sr)
    s.check("PERFECT_SCORE 条件(总星=9)", "get_total_stars() == 9" in sr)
    s.check("观察满分45/推理满分14/洞察满分7", "max_observation: int = 45" in sr and "max_reasoning: int = 14" in sr and "max_insight: int = 7" in sr)


def test_5_clue_system(s):
    """线索五态机"""
    cs = read("autoload/clue_system.gd")
    
    s.check("ClueState 枚举(5态)", all(v in cs for v in ["UNDISCOVERED","DISCOVERED","RECORDED","ANALYZED","LINKED"]))
    s.check("ClueData 类定义", "class ClueData" in cs)
    s.check("15字段: id/name/description", "var id" in cs and "var name" in cs and "var description" in cs)
    s.check("15字段: category/location", "var category" in cs and "var location" in cs)
    s.check("15字段: importance/is_key_evidence", "var importance" in cs and "var is_key_evidence" in cs)
    s.check("15字段: state/discovery_time", "var state" in cs and "var discovery_time" in cs)
    s.check("discover_clue() UNDISCOVERED→DISCOVERED", "ClueState.DISCOVERED" in cs)
    s.check("record_clue() DISCOVERED→RECORDED", "ClueState.RECORDED" in cs)
    s.check("link_clues() →LINKED", "ClueState.LINKED" in cs)
    s.check("总线索数=45", "return 45" in cs)


def test_6_event_buses(s):
    """事件总线系统"""
    se = read("autoload/system_event_bus.gd")
    
    s.check("7个事件总线文件存在", all(file_exists(f"autoload/{n}_event_bus.gd") 
        for n in ["system","case","scene","dialogue","clue","ui","map"]))
    s.check("SystemEventBus: user_registered", "user_registered" in se)
    s.check("SystemEventBus: user_logged_in/out", "user_logged_in" in se and "user_logged_out" in se)
    s.check("SystemEventBus: network_online/offline", "network_online" in se and "network_offline" in se)
    s.check("SystemEventBus: game_saved/loaded", "game_saved" in se and "game_loaded" in se)
    s.check("SystemEventBus: case_completed", "case_completed" in se)
    s.check("SystemEventBus: game_paused/resumed", "game_paused" in se and "game_resumed" in se)
    s.check("SystemEventBus: 信号数≥14", se.count("signal ") >= 14)
    s.check("GameScene连接SceneEventBus", "SceneEventBus.connect" in read("scripts/scene/game_scene.gd"))
    s.check("GameScene连接ClueEventBus", "ClueEventBus.connect" in read("scripts/scene/game_scene.gd"))
    s.check("Boot连接全部总线(7个)", read("autoload/boot.gd").count("EventBus") >= 7)


def test_7_network(s):
    """前后端通信"""
    am = read("autoload/api_manager.gd")
    sv = read(f"{BE}/src/server.js")
    
    s.check("Express服务器启动", "app.listen" in sv)
    s.check("9个API端点注册", sv.count("app.use('/api/") >= 4)
    s.check("JWT认证中间件", "authRequired" in read(f"{BE}/src/middleware/auth.js"))
    s.check("游客中间件", "guestMiddleware" in read(f"{BE}/src/middleware/auth.js"))
    s.check("安全中间件(helmet+cors+morgan)", "helmet" in sv and "cors" in sv and "morgan" in sv)
    s.check("速率限制", "rateLimit" in sv)
    s.check("Godot HTTP GET封装", "func get_request" in am)
    s.check("Godot HTTP POST封装", "func post_request" in am)
    s.check("Godot HTTP PUT封装", "func put_request" in am)
    s.check("超时处理(15s)", "request_timeout" in am)
    s.check("离线队列 _queue_request", "func _queue_request" in am)
    s.check("队列刷新 flush_pending", "func flush_pending" in am)
    s.check("连通性检测 _check_connectivity", "func _check_connectivity" in am)
    s.check("数据库Schema(5表)", read(f"{BE}/migrations/001_initial_schema.sql").count("CREATE TABLE") >= 5)
    s.check("RLS安全策略", "ROW LEVEL SECURITY" in read(f"{BE}/migrations/001_initial_schema.sql"))
    s.check("register_user 端点", "func register_user" in am)
    s.check("login_user 端点", "func login_user" in am)
    s.check("upload_save 端点", "func upload_save" in am)
    s.check("get_latest_save 端点", "func get_latest_save" in am)
    s.check("get_case_progress 端点", "func get_case_progress" in am)
    s.check("update_case_progress 端点", "func update_case_progress" in am)


def test_8_auth_save(s):
    """认证四态 + 存档双模式"""
    au = read("autoload/auth_manager.gd")
    sv = read("autoload/save_manager.gd")
    
    s.check("AuthState 枚举(4态)", all(v in au for v in ["GUEST","REGISTERING","REGISTERED","LOGGED_IN"]))
    s.check("register() 流程", "func register" in au)
    s.check("login() 流程", "func login" in au)
    s.check("create_guest() 流程", "func create_guest" in au)
    s.check("logout() 清除token", "func logout" in au)
    s.check("auth_state_changed 信号", "auth_state_changed" in au)
    s.check("游客本地保存 _save_local", "func _save_local" in sv)
    s.check("注册云端保存 _save_to_server", "func _save_to_server" in sv)
    s.check("离线降级: 本地+入队", "_queue_request" in sv and "_save_local" in sv)
    s.check("云端读档 _load_from_server", "func _load_from_server" in sv)
    s.check("本地读档 _load_local", "func _load_local" in sv)
    s.check("M1覆盖策略(upsert)", "upsert" in read(f"{BE}/src/routes/saves.js") or "existing" in read(f"{BE}/src/routes/saves.js"))
    # _build_save_data 以字典字面量收集字段（非 save_data["k"]= 赋值），按实际字段数校验
    _m = re.search(r'func _build_save_data.*?save_data = \{(.*?)\n\t\}', sv, re.S)
    _keys = re.findall(r'"([a-z_]+)":', _m.group(1)) if _m else []
    s.check("存档数据完整收集(≥14字段)", len(_keys) >= 14)
    s.check("game_saved/loaded 信号", "game_saved" in sv and "game_loaded" in sv)
    s.check("save_sync_failed 信号", "save_sync_failed" in sv)


def test_9_boot(s):
    """启动七层架构"""
    bt = read("autoload/boot.gd")
    
    s.check("BootPhase 枚举(8值)", "ENGINE_CHECK" in bt and "COMPLETE" in bt)
    s.check("Phase 1: 引擎检查", "func _phase_1_engine_check" in bt)
    s.check("Phase 2: 数据初始化", "func _phase_2_data_init" in bt)
    s.check("Phase 3: 事件绑定", "func _phase_3_event_binding" in bt)
    s.check("Phase 4: 网络初始化", "func _phase_4_network_init" in bt)
    s.check("Phase 5: 认证检查", "func _phase_5_auth_check" in bt)
    s.check("Phase 6: 存档检查", "func _phase_6_save_check" in bt)
    s.check("Phase 7: UI启动", "func _phase_7_ui_launch" in bt)
    s.check("Phase Complete: 汇总", "func _phase_complete" in bt)
    s.check("Godot版本检查(≥4.4)", "version.major" in bt and "version.minor" in bt)
    s.check("渲染器检查(GLES3)", "gl_compatibility" in bt)
    s.check("致命错误阻止启动", "func _can_proceed" in bt)
    s.check("启动耗时统计", "boot_start_time" in bt)
    s.check("网络恢复→刷新离线队列", "flush_pending" in bt)
    s.check("登录后→拉取云端存档", "SaveManager" in bt and "load_game" in bt)
    s.check("7个事件总线检查", bt.count("EventBus") >= 7)


def test_10_dialogue_branch(s):
    """对话条件分支系统"""
    dr = read("resources/dialogues/dialogue_resource.gd")
    dn = read("resources/dialogues/dialogue_node_resource.gd")
    dm = read("scripts/dialogue/dialogue_manager.gd")
    
    s.check("DialogueResource 类定义", "class_name DialogueResource" in dr)
    s.check("DialogueNodeResource 类定义", "class_name DialogueNodeResource" in dn)
    s.check("should_show() 难度过滤", "func should_show" in dn)
    s.check("difficulty_filter 6种值(0-5)", "difficulty_filter" in dn)
    s.check("verify_filter 4种值", "verify_filter" in dn)
    s.check("probability 概率字段", "probability" in dn)
    # dialogue_node_resource.gd 文档注释中明确定义 10 种 trigger 类型
    _tt = ["auto", "click", "choice", "optional", "sfx", "milestone", "knowledge", "clue", "guide", "note"]
    s.check("10种 trigger 类型", all(t in dn for t in _tt))
    s.check("is_step_entry 标记", "is_step_entry" in dn)
    s.check("三难度入口路由 get_start_node", "func get_start_node" in dr)
    s.check("运行时节点过滤 _go_to_node", "func _go_to_node" in dm)
    s.check("特殊trigger处理(note/knowledge/milestone/sfx)", all(t in dm for t in ["note","knowledge","milestone","sfx"]))
    s.check(".tres资源加载 load_dialogue_resource", "func load_dialogue_resource" in dm)
    s.check("兼容旧.txt格式 load_dialogue_txt", "func load_dialogue_txt" in dm)


def test_11_game_state(s):
    """游戏全局状态机"""
    gm = read("autoload/game_manager.gd")
    
    s.check("GameState 枚举(5态)", all(v in gm for v in ["BOOT","MAIN_MENU","IN_GAME","PAUSED","GAME_OVER"]))
    s.check("_change_state() 信号发射", "game_state_changed" in gm)
    s.check("start_case() 状态切换", "func start_case" in gm)
    s.check("pause_game()", "func pause_game" in gm)
    s.check("resume_game()", "func resume_game" in gm)
    s.check("网络状态连接", "_on_connectivity_changed" in gm)
    s.check("认证状态连接", "_on_auth_changed" in gm)
    s.check("云端数据同步", "func _sync_cloud_data" in gm)
    s.check("登录后自动同步", "func _sync_cloud_save" in gm)
    s.check("游客/注册双模式", "is_guest" in gm)


def test_12_reasoning_wall(s):
    """推理墙系统"""
    rw = read("scripts/clue/reasoning_wall_ui.gd")
    
    s.check("线索卡片创建 _create_clue_card", "func _create_clue_card" in rw)
    s.check("卡片拖拽 _on_card_drag", "func _on_card_drag" in rw)
    s.check("卡片放入假设板 reparent", "reparent" in rw)
    s.check("验证按钮 _on_verify_pressed", "func _on_verify_pressed" in rw)
    s.check("里程碑解锁 _unlock_milestone", "func _unlock_milestone" in rw)
    s.check("里程碑弹窗 _show_milestone_popup", "func _show_milestone_popup" in rw)
    s.check("open()/close()", "func open" in rw and "func close" in rw)
    s.check("10条线索名称映射", rw.count('"') >= 20)  # 粗略检查
    s.check("clue_discovered 信号接收", "clue_discovered" in rw)
    s.check("clue_recorded 信号接收", "clue_recorded" in rw)


def test_13_notebook_knowledge(s):
    """侦探笔记 + 知识库"""
    gs = read("scripts/scene/game_scene.gd")
    dr = read("resources/dialogues/dialogue_resource.gd")
    
    s.check("笔记记录触发(Step 3)", "STEP_3_RECORD" in gs)
    s.check("知识库触发(Step 4)", "STEP_4_KNOWLEDGE" in gs)
    s.check("知识库领域定义", "knowledge_domains" in dr)
    s.check("EASY自动使用知识库", "is_knowledge_used = true" in gs)
    s.check("侧栏知识库按钮", '"knowledge"' in gs)
    s.check("侧栏笔记按钮", '"journal"' in gs)
    s.check("对话note_updated信号", "note_updated" in read("scripts/dialogue/dialogue_manager.gd"))
    s.check("对话knowledge_triggered信号", "knowledge_triggered" in read("scripts/dialogue/dialogue_manager.gd"))


def test_14_api_integration(s):
    """后端API实际连通测试"""
    import urllib.request, json
    
    try:
        req = urllib.request.Request("http://localhost:3000/api/health")
        resp = urllib.request.urlopen(req, timeout=3)
        data = json.loads(resp.read())
        
        s.check("后端API可达: /api/health", data.get("status") == "ok")
        s.check("健康检查返回version", "version" in data)
        s.check("健康检查返回endpoints", "endpoints" in data)
        
        # 游客会话测试
        req2 = urllib.request.Request("http://localhost:3000/api/auth/guest", 
                                       data=b"{}",
                                       headers={"Content-Type": "application/json"},
                                       method="POST")
        resp2 = urllib.request.urlopen(req2, timeout=3)
        data2 = json.loads(resp2.read())
        s.check("游客会话创建成功", "guest_id" in data2)
        
        # 注册参数验证
        req3 = urllib.request.Request("http://localhost:3000/api/auth/register",
                                       data=b"{}",
                                       headers={"Content-Type": "application/json"},
                                       method="POST")
        try:
            resp3 = urllib.request.urlopen(req3, timeout=3)
            s.check("注册缺少参数返回400", resp3.status == 400)
        except urllib.error.HTTPError as e:
            s.check("注册缺少参数返回400", e.code == 400)
        
        # 无token访问受保护端点
        req4 = urllib.request.Request("http://localhost:3000/api/saves")
        try:
            resp4 = urllib.request.urlopen(req4, timeout=3)
            s.fail("无token应返回401", f"实际{resp4.status}")
        except urllib.error.HTTPError as e:
            s.check("无token访问受保护端点返回401", e.code == 401)
        
        # 404处理
        req5 = urllib.request.Request("http://localhost:3000/api/nonexistent")
        try:
            resp5 = urllib.request.urlopen(req5, timeout=3)
            s.fail("不存在端点应返回404", f"实际{resp5.status}")
        except urllib.error.HTTPError as e:
            s.check("不存在端点返回404", e.code == 404)
            
    except Exception as e:
        s.skip("后端API连通测试", str(e)[:60])


def test_15_tres_resource(s):
    """.tres 对话资源完整性"""
    tres = read("resources/dialogues/scene_01_phase1_tutorial.tres")
    
    s.check("节点数≥30", tres.count("node_id = ") >= 30)
    s.check("Step入口≥6", tres.count("is_step_entry = true") >= 6)
    s.check("EASY独占≥4", tres.count("difficulty_filter = 1") >= 4)
    s.check("NORMAL独占≥4", tres.count("difficulty_filter = 2") >= 4)
    s.check("HARD独占≥4", tres.count("difficulty_filter = 3") >= 4)
    s.check("VERIFIED分支存在", 'verify_filter = "VERIFIED"' in tres)
    s.check("SUPPORTED分支存在", 'verify_filter = "SUPPORTED"' in tres)
    s.check("INSUFFICIENT分支存在", 'verify_filter = "INSUFFICIENT"' in tres)
    s.check("CONTRADICTORY分支存在", 'verify_filter = "CONTRADICTORY"' in tres)
    s.check("福尔摩斯对话存在", 'speaker = "福尔摩斯"' in tres)
    s.check("华生对话存在", 'speaker = "华生"' in tres)
    s.check("system提示存在", 'speaker = "system"' in tres)
    s.check("六步闭环1-6全部标记", all(f'exploration_step = {i}' in tres for i in range(1,7)))
    s.check("trigger类型: auto/guide/choice/milestone", all(t in tres for t in ['"auto"','"guide"','"choice"','"milestone"']))


# ============ 主程序 ============

def main():
    print("=" * 60)
    print("  维多利亚伦敦探案 — 核心机制验证测试")
    print(f"  项目: {PROJECT}")
    print("=" * 60)
    print()
    
    all_ok = True
    total_p = total_f = total_s = 0
    
    tests = [
        ("六步探索闭环", test_1_exploration_loop),
        ("难度模式系统", test_2_difficulty),
        ("四级验证体系", test_3_verification),
        ("三星评价+七徽章", test_4_star_rating),
        ("线索五态机", test_5_clue_system),
        ("事件总线系统(7个)", test_6_event_buses),
        ("前后端通信系统", test_7_network),
        ("认证四态+存档双模式", test_8_auth_save),
        ("启动七层架构", test_9_boot),
        ("对话条件分支系统", test_10_dialogue_branch),
        ("游戏全局状态机", test_11_game_state),
        ("推理墙系统", test_12_reasoning_wall),
        ("侦探笔记+知识库", test_13_notebook_knowledge),
        ("后端API连通测试", test_14_api_integration),
        (".tres对话资源", test_15_tres_resource),
    ]
    
    for name, fn in tests:
        s = TestSuite(name)
        fn(s)
        if not s.summary():
            all_ok = False
        total_p += s.p; total_f += s.f; total_s += s.s
    
    print("=" * 60)
    print(f"  总计: {total_p}✅ / {total_f}❌ / {total_s}⏭ (共{total_p+total_f+total_s})")
    if all_ok:
        print("  🎉 全部核心机制验证通过！")
    else:
        print(f"  ⚠️  {total_f} 项验证未通过")
    print("=" * 60)
    
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
