#!/usr/bin/env python3
"""解析 Godot 4 PCK 文件列表，检查 data/clues 与脚本是否打包。"""
import struct, sys, os

def list_pck(path):
    with open(path, "rb") as f:
        magic = f.read(4)
        if magic != b"GDPC":
            print("NOT A PCK:", magic); return
        ver, = struct.unpack("<i", f.read(4))
        gmajor, = struct.unpack("<i", f.read(4))
        gminor, = struct.unpack("<i", f.read(4))
        gpatch, = struct.unpack("<i", f.read(4))
        slen, = struct.unpack("<i", f.read(4))
        ver_str = f.read(slen).decode("utf-8", "replace")
        blen, = struct.unpack("<i", f.read(4))
        fbase = f.read(blen).decode("utf-8", "replace")
        reserved, = struct.unpack("<i", f.read(4))
        fcount, = struct.unpack("<i", f.read(4))
        print(f"PCK v{ver} godot {gmajor}.{gminor}.{gpatch} ({ver_str}) base='{fbase}' files={fcount}")
        print("=" * 60)
        names = []
        for i in range(fcount):
            plen, = struct.unpack("<i", f.read(4))
            pname = f.read(plen).decode("utf-8", "replace")
            off, size = struct.unpack("<qq", f.read(16))
            md5 = f.read(16)
            names.append((pname, size))
        # 过滤输出
        print("--- data/ 相关 ---")
        for n, s in names:
            if n.startswith("data/"):
                print(f"  {n} ({s}B)")
        print("--- backups/ 相关（应全排除或仅 README） ---")
        for n, s in names:
            if n.startswith("backups/"):
                print(f"  {n} ({s}B)")
        print("--- tools/ 相关 ---")
        for n, s in names:
            if n.startswith("tools/"):
                print(f"  {n} ({s}B)")
        print("--- 总数 ---")
        print(f"  files={len(names)}  data/clues .tres 数={sum(1 for n,_ in names if n.startswith('data/clues/'))}")

if __name__ == "__main__":
    list_pck(sys.argv[1] if len(sys.argv) > 1 else "web_build/index.pck")
