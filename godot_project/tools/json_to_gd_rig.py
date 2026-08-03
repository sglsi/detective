#!/usr/bin/env python3
"""把 _rig_spec.json 转成 Godot 的 class_name Rig 脚本。"""
import json
import sys
from pathlib import Path

JSON_PATH = Path(r"D:\AI\detective\godot_project\assets\characters\test_rig_character\rig\_rig_spec.json")
OUT_PATH = Path(r"D:\AI\detective\godot_project\scripts\rig\test_rig_character.gd")


def color_str(c):
    return f"Color({c[0]:.4f}, {c[1]:.4f}, {c[2]:.4f})"


def vec2_str(v):
    return f"Vector2({v[0]:.4f}, {v[1]:.4f})"


def main() -> int:
    if not JSON_PATH.exists():
        print(f"[ERR] {JSON_PATH} not found", file=sys.stderr)
        return 1

    spec = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    bones = spec["bones"]
    parts_dir = spec["parts_dir"]

    lines = [
        f"# 自动生成：tools/json_to_gd_rig.py",
        f"class_name TestRigCharacter",
        f"const DEF := {{",
        f'\t"bones": [',
    ]

    for b in bones:
        sc = b["scale"]
        tex = b["tex"]
        tex_path = f'"{parts_dir}{tex}"' if tex else '""'
        # len/wid 从像素换算到世界单位
        world_len = b["len"] * sc
        world_wid = b["wid"] * sc
        world_pos = [b["pos"][0], b["pos"][1]]  # 已经是世界单位

        entry = (
            f'\t\t{{"name":"{b["name"]}","parent":"{b["parent"]}",'
            f'"pos":{vec2_str(world_pos)},"rot":{b["rot"]},'
            f'"len":{world_len:.4f},"wid":{world_wid:.4f},'
            f'"dir":{b["dir"]},"color":{color_str(b["color"])},'
            f'"tex":{tex_path},"pivot":{vec2_str(b["pivot"])},'
            f'"scale":{sc:.10f}}}'
        )
        lines.append(entry + ",")

    # 去掉最后一个逗号
    if len(lines) > 3:
        lines[-1] = lines[-1].rstrip(",")

    lines.extend([
        "\t]",
        "}",
        "static func rig_def() -> Dictionary:",
        "\treturn DEF",
    ])

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"[INFO] wrote {OUT_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
