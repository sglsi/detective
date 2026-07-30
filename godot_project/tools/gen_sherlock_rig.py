#!/usr/bin/env python3
"""兼容薄封装：福尔摩斯 rig 现统一由 gen_character_rig.py 生成。

历史调用方若仍指向本文件，行为不变（等价于 `python gen_character_rig.py sherlock`）。
单一代码源：tools/gen_character_rig.py
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_character_rig as _gen


def main():
    sys.argv = [sys.argv[0], "sherlock"]
    _gen.main()


if __name__ == "__main__":
    main()
