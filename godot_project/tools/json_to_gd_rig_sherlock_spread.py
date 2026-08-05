#!/usr/bin/env python3
"""把 sherlock_spread 的 _rig_spec.json 转成 Godot class_name SherlockSpreadRig 脚本。"""
import json
import sys
from pathlib import Path

JSON_PATH = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock_spread\rig\_rig_spec.json")
OUT_PATH = Path(r"D:\AI\detective\godot_project\scripts\rig\sherlock_spread_rig.gd")


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
        f"# 自动生成：tools/json_to_gd_rig_sherlock_spread.py",
        f"class_name SherlockSpreadRig",
        f"const DEF := {{",
        f'\t"bones": [',
    ]

    for b in bones:
        sc = b["scale"]
        tex = b["tex"]
        tex_path = f'"{parts_dir}{tex}"' if tex else '""'
        world_len = b["len"] * sc
        world_wid = b["wid"] * sc
        world_pos = [b["pos"][0], b["pos"][1]]

        entry = (
            f'\t\t{{"name":"{b["name"]}","parent":"{b["parent"]}",'
            f'"pos":{vec2_str(world_pos)},"rot":{b["rot"]},'
            f'"len":{world_len:.4f},"wid":{world_wid:.4f},'
            f'"dir":{b["dir"]},"color":{color_str(b["color"])},'
            f'"tex":{tex_path},"pivot":{vec2_str(b["pivot"])},'
            f'"scale":{sc:.10f}}}'
        )
        lines.append(entry + ",")

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
