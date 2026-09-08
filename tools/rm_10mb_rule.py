#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 一次性脚本：按用户 2026-09-08 要求，移除推送规则中的 ">10MB 文件不入库" 限制
import io

P = 'AGENTS.md'
s = io.open(P, 'r', encoding='utf-8').read()

old1 = '①工具类二进制（Godot 编辑器本体、导出模板 zip/tpz、editor_extract/、任何 >10MB 文件——GitHub 单文件硬限 100MB）'
new1 = '①工具类二进制（Godot 编辑器本体、导出模板 zip/tpz、editor_extract/——GitHub 单文件硬限 100MB）'
assert old1 in s, 'old1 not found'
s = s.replace(old1, new1, 1)

old2 = "awk '$1>10000000'"
new2 = "awk '$1>100000000'"
assert old2 in s, 'old2 not found'
s = s.replace(old2, new2, 1)

io.open(P, 'w', encoding='utf-8').write(s)
print('OK')
