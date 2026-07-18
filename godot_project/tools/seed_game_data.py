#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-2 种子数据生成器：把《血字的研究》(A Study in Scarlet) 的真实线索与案件
写成 Godot 4 的 .tres 资源，供 ClueSystem / CaseManager 真实解析。

产物：
  res://data/clues/<id>.tres   —— 每条线索一个 ClueData 资源
  res://data/cases/blood_study.tres —— 案件 CaseData 资源

运行（在 godot_project 目录下）：
  python3 tools/seed_game_data.py
重新运行会覆盖已有 .tres（幂等）。
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLUE_DIR = os.path.join(ROOT, "data", "clues")
CASE_DIR = os.path.join(ROOT, "data", "cases")
CLUE_SCRIPT = "res://data/clue_data.gd"
CASE_SCRIPT = "res://data/case_data.gd"


def esc(v: str) -> str:
    """转义 Godot .tres 字符串值中的双引号与反斜杠。"""
    return v.replace("\\", "\\\\").replace('"', '\\"')


def write_clue(c: dict) -> None:
    path = os.path.join(CLUE_DIR, c["id"] + ".tres")
    lines = [
        '[gd_resource type="Resource" script_class="ClueData" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="%s" id="1_clue"]' % CLUE_SCRIPT,
        "",
        "[resource]",
        'script = ExtResource("1_clue")',
        'id = "%s"' % esc(c["id"]),
        'name = "%s"' % esc(c["name"]),
        'description = "%s"' % esc(c["description"]),
        'category = "%s"' % esc(c["category"]),
        'location = "%s"' % esc(c["location"]),
        'discovery_condition = "%s"' % esc(c["discovery_condition"]),
        'observation = "%s"' % esc(c["observation"]),
        'analysis = "%s"' % esc(c["analysis"]),
        "related_clues = [%s]" % ", ".join('"%s"' % esc(x) for x in c["related_clues"]),
        "related_npcs = [%s]" % ", ".join('"%s"' % esc(x) for x in c["related_npcs"]),
        "timeline_position = %s" % c["timeline_position"],
        "importance = %s" % c["importance"],
        "is_key_evidence = %s" % ("true" if c["is_key_evidence"] else "false"),
        "state = %s" % c["state"],
        'discovery_time = ""',
        "",
    ]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("  wrote clue:", c["id"])


def write_case(case: dict) -> None:
    path = os.path.join(CASE_DIR, case["id"] + ".tres")
    lines = [
        '[gd_resource type="Resource" script_class="CaseData" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="%s" id="1_case"]' % CASE_SCRIPT,
        "",
        "[resource]",
        'script = ExtResource("1_case")',
        'id = "%s"' % esc(case["id"]),
        'title = "%s"' % esc(case["title"]),
        "scenes = [%s]" % ", ".join('"%s"' % esc(x) for x in case["scenes"]),
        "clues = [%s]" % ", ".join('"%s"' % esc(x) for x in case["clues"]),
        "npcs = [%s]" % ", ".join('"%s"' % esc(x) for x in case["npcs"]),
        "",
    ]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("  wrote case:", case["id"])


# ============ 线索数据（《血字的研究》） ============
CLUES = [
    {
        "id": "clue_rache",
        "name": "墙上的血字RACHE",
        "description": "死者身旁的墙壁上，用鲜血写成的德文单词 RACHE（复仇）。",
        "category": "痕迹",
        "location": "劳瑞斯顿花园街3号",
        "discovery_condition": "进入案发现场主厅",
        "observation": "血字位置低于常人肩部，笔迹歪斜，似由矮个子仰头书写。",
        "analysis": "RACHE 是德文复仇之意；书写高度暗示凶手身材矮小，且刻意留下标记。",
        "related_clues": ["clue_ring", "clue_footprint"],
        "related_npcs": ["jefferson_hope"],
        "timeline_position": 1.0,
        "importance": 5,
        "is_key_evidence": True,
        "state": 0,
    },
    {
        "id": "clue_ring",
        "name": "现场女子戒指",
        "description": "死者身旁发现的一枚刻字女子戒指，内侧有名字缩写。",
        "category": "物证",
        "location": "劳瑞斯顿花园街3号",
        "discovery_condition": "勘验尸体周围地面",
        "observation": "戒指崭新，尺寸偏小，内侧刻有 L.F. 缩写。",
        "analysis": "戒指暗示死者与某位女性（露西·费里尔）的婚姻关联，可能是凶手掉落。",
        "related_clues": ["clue_rache", "clue_lucy"],
        "related_npcs": ["lucy_ferrier"],
        "timeline_position": 1.5,
        "importance": 4,
        "is_key_evidence": True,
        "state": 0,
    },
    {
        "id": "clue_footprint",
        "name": "方头靴脚印",
        "description": "现场泥地上的一串方头靴脚印，伴有一名矮个男子的步伐痕迹。",
        "category": "痕迹",
        "location": "劳瑞斯顿花园街3号门外",
        "discovery_condition": "勘验门外泥地",
        "observation": "脚印为方头靴，步幅短，同行的还有另一双大码靴印。",
        "analysis": "矮个方头靴者即书写血字之人；另一双大码靴指向受害者同行者。",
        "related_clues": ["clue_rache", "clue_stick"],
        "related_npcs": ["jefferson_hope"],
        "timeline_position": 2.0,
        "importance": 4,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_stick",
        "name": "墙边小木棍",
        "description": "血字旁倚墙放置的一截小木棍，似用来够高书写。",
        "category": "痕迹",
        "location": "劳瑞斯顿花园街3号",
        "discovery_condition": "勘验血字附近",
        "observation": "木棍顶端沾有少量血迹，长度恰可够到血字高度。",
        "analysis": "佐证血字由矮个者借助木棍书写，进一步坐实凶手身材特征。",
        "related_clues": ["clue_footprint"],
        "related_npcs": ["jefferson_hope"],
        "timeline_position": 2.2,
        "importance": 2,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_drebber_body",
        "name": "德雷伯尸体",
        "description": "伊诺克·德雷伯仰面死于屋内，面容扭曲，无明显外伤。",
        "category": "物证",
        "location": "劳瑞斯顿花园街3号",
        "discovery_condition": "进入主厅",
        "observation": "尸体无刀伤枪伤，表情惊惧，地上有翻倒的毒药瓶。",
        "analysis": "死因疑似中毒；与斯坦格森之死手法不同，但同出一人之手。",
        "related_clues": ["clue_watch", "clue_pill"],
        "related_npcs": ["enoch_drebber"],
        "timeline_position": 1.0,
        "importance": 3,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_stangerson_body",
        "name": "斯坦格森尸体",
        "description": "约瑟夫·斯坦格森死于旅馆，喉部一刀，墙上同样有血字。",
        "category": "物证",
        "location": "博斯科姆比旅馆",
        "discovery_condition": "勘查第二现场",
        "observation": "喉部利刃伤，身旁散落药丸盒，墙上血字 RACHE 再现。",
        "analysis": "与德雷伯案为同一凶手；药丸盒指向以毒丸择一杀人。",
        "related_clues": ["clue_pill"],
        "related_npcs": ["joseph_stangerson"],
        "timeline_position": 3.0,
        "importance": 3,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_pill",
        "name": "两粒药丸",
        "description": "现场发现一只盒子，内装两粒外观相同的药丸，其中一粒含毒。",
        "category": "物证",
        "location": "博斯科姆比旅馆",
        "discovery_condition": "勘查斯坦格森房间",
        "observation": "一粒遇试剂变红（有毒），另一粒无毒，凶手令受害者自选。",
        "analysis": "体现凶手的报复仪式感——以命运抉择方式行凶，对应盐湖城旧怨。",
        "related_clues": ["clue_stangerson_body"],
        "related_npcs": ["jefferson_hope"],
        "timeline_position": 3.2,
        "importance": 5,
        "is_key_evidence": True,
        "state": 0,
    },
    {
        "id": "clue_note",
        "name": "报纸婚姻启事",
        "description": "剪报上刊登的寻人/婚姻启事，与盐湖城摩门教社群相关。",
        "category": "文件",
        "location": "案卷档案",
        "discovery_condition": "查阅旧报纸档案",
        "observation": "启事署名指向摩门教长老，征婚对象为年轻女子。",
        "analysis": "串联起盐湖城的逼婚旧事，为动机溯源提供文献线索。",
        "related_clues": ["clue_lucy", "clue_mormon"],
        "related_npcs": ["lucy_ferrier"],
        "timeline_position": 4.0,
        "importance": 2,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_lucy",
        "name": "露西之死",
        "description": "证词：露西·费里尔被迫嫁入摩门教长老家庭后郁郁而终。",
        "category": "证言",
        "location": "盐湖城（回忆）",
        "discovery_condition": "听取霍普供述",
        "observation": "露西婚前已心属猎人杰斐逊·霍普，婚后不久病逝。",
        "analysis": "构成霍普复仇的核心动机——为爱人向摩门教势力追讨血债。",
        "related_clues": ["clue_mormon", "clue_hope", "clue_ring"],
        "related_npcs": ["lucy_ferrier", "jefferson_hope"],
        "timeline_position": 4.5,
        "importance": 4,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_hope",
        "name": "车夫杰斐逊·霍普",
        "description": "证词与追踪：马车夫霍普正是复仇者，尾随两名受害者到伦敦。",
        "category": "证言",
        "location": "伦敦街头",
        "discovery_condition": "锁定并讯问车夫",
        "observation": "霍普熟悉两名死者行程，且对盐湖城往事了如指掌。",
        "analysis": "真相收束：霍普即书写血字之人，动机源于露西之死的旧恨。",
        "related_clues": ["clue_lucy", "clue_rache", "clue_pill"],
        "related_npcs": ["jefferson_hope"],
        "timeline_position": 5.0,
        "importance": 5,
        "is_key_evidence": True,
        "state": 0,
    },
    {
        "id": "clue_mormon",
        "name": "摩门教逼婚",
        "description": "证词：盐湖城摩门教长老团强制将女子许配给长老子弟。",
        "category": "证言",
        "location": "盐湖城（回忆）",
        "discovery_condition": "听取霍普供述",
        "observation": "长老团以驱逐相胁，逼迫露西之父就范。",
        "analysis": "揭示旧案根源——宗教势力酿成的私仇，隔洋延续到伦敦。",
        "related_clues": ["clue_lucy", "clue_note"],
        "related_npcs": ["lucy_ferrier"],
        "timeline_position": 4.2,
        "importance": 3,
        "is_key_evidence": False,
        "state": 0,
    },
    {
        "id": "clue_watch",
        "name": "德雷伯的怀表",
        "description": "死者怀表停在案发时刻，表壳内侧藏有女子小像。",
        "category": "物证",
        "location": "劳瑞斯顿花园街3号",
        "discovery_condition": "勘验尸体随身物",
        "observation": "表针停在某一时刻，内盖小像为一年轻女子。",
        "analysis": "怀表时间可校准案发时序；女子小像呼应戒指上的 L.F.。",
        "related_clues": ["clue_drebber_body", "clue_ring"],
        "related_npcs": ["enoch_drebber"],
        "timeline_position": 1.2,
        "importance": 2,
        "is_key_evidence": False,
        "state": 0,
    },
]

CASE = {
    "id": "blood_study",
    "title": "血字的研究",
    "scenes": [
        "scene_01", "scene_02", "scene_03", "scene_04",
        "scene_05", "scene_06", "scene_07", "scene_08",
    ],
    "clues": [c["id"] for c in CLUES],
    "npcs": [
        "jefferson_hope", "lucy_ferrier", "enoch_drebber",
        "joseph_stangerson", "sherlock_holmes", "john_watson",
        "gregson", "lestrade",
    ],
}


def main() -> None:
    os.makedirs(CLUE_DIR, exist_ok=True)
    os.makedirs(CASE_DIR, exist_ok=True)
    print("生成线索资源 ->", CLUE_DIR)
    for c in CLUES:
        write_clue(c)
    print("生成案件资源 ->", CASE_DIR)
    write_case(CASE)
    print("完成：%d 条线索 + 1 个案件" % len(CLUES))


if __name__ == "__main__":
    main()
