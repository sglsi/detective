#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成占位音频资产（可重跑）。

设计要点：
1. 无缝循环：pad 层所有频率都 snapped 到 loop_len 倒数的整数倍，
   使相位在循环边界处连续（首尾不爆音、无间隙感）。
2. 音符采用 wrap 写入，跨循环边界的尾音自动绕回开头，彻底消除"间隔感"。
3. 输出 44.1kHz / 16bit / 单声道，峰值归一化到 -3 dBFS 左右。

产出：
  assets/audio/bgm/menu.wav, scene1.wav .. scene8.wav   （8 秒无缝循环 BGM）
  assets/audio/sfx/ui_click.wav, ui_hover.wav           （UI 按钮音效）
  assets/audio/sfx/clue_found.wav, wall_conflict.wav, reveal.wav（事件 stinger）
"""
import math
import os
import struct
import wave

SR = 44100
OUT_BGM = "assets/audio/bgm"
OUT_SFX = "assets/audio/sfx"

# 音名 -> 频率（十二平均律，A4=440）
NOTE_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name: str) -> float:
    """音名转频率，如 'A3' / 'C4' / 'F#3'"""
    letter = name[0].upper()
    i = 1
    accidental = 0
    while i < len(name) and name[i] in ("#", "b"):
        accidental += 1 if name[i] == "#" else -1
        i += 1
    octave = int(name[i:])
    semis = NOTE_BASE[letter] + accidental + (octave - 4) * 12
    return 440.0 * (2.0 ** (semis / 12.0))


def snap(f: float, loop_len: float) -> float:
    """把频率吸附到 loop_len 内的整数周期，保证循环首尾相位连续"""
    return round(f * loop_len) / loop_len


class Buf:
    def __init__(self, n: int):
        self.d = [0.0] * n

    def add_wrap(self, start: int, data) -> None:
        """按环形方式叠加，超出末尾的部分绕回开头（消除循环接缝）"""
        n = len(self.d)
        for i, v in enumerate(data):
            self.d[(start + i) % n] += v


def envelope(n: int, attack: float, release: float) -> list:
    """AD 包络（0->1->0），attack/release 为秒"""
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            out.append(max(0.0, 1.0 - (i - a) / r))
    return out


def tone(f: float, n: int, amp: float, harmonics=(1.0, 0.35, 0.12), env=None) -> list:
    """带轻微泛音的单音"""
    out = [0.0] * n
    for h, hw in enumerate(harmonics, start=1):
        w = 2 * math.pi * f * h
        for i in range(n):
            out[i] += hw * math.sin(w * i / SR)
    if env is not None:
        for i in range(n):
            out[i] *= env[i]
    return [v * amp for v in out]


def pad(f: float, n: int, amp: float) -> list:
    """持续 pad 层（无包络，靠频率吸附实现无缝）"""
    out = [0.0] * n
    for h, hw in ((1, 1.0), (2, 0.28), (3, 0.10)):
        w = 2 * math.pi * f * h
        for i in range(n):
            out[i] += hw * math.sin(w * i / SR)
    return [v * amp for v in out]


def build_bgm(path: str, chords, arp_pattern, bpm_note: float = 0.5, loop_len: float = 8.0) -> None:
    n = int(loop_len * SR)
    buf = Buf(n)
    chord_dur = loop_len / len(chords)

    for ci, chord in enumerate(chords):
        base = int(ci * chord_dur * SR)
        # --- pad：三和弦持续音 ---
        for note_name in chord:
            f = snap(freq(note_name), loop_len)
            buf.add_wrap(base, pad(f, int(chord_dur * SR), 0.16))
        # --- 低音线：根音低两个八度 ---
        root = chord[0]
        f_low = snap(freq(root[:-1] + str(int(root[-1]) - 2)), loop_len)
        buf.add_wrap(base, pad(f_low, int(chord_dur * SR), 0.10))
        # --- 琶音：每 bpm_note 秒一个和弦音，短衰减 ---
        t = 0.0
        k = 0
        while t < chord_dur - 0.01:
            note_name = chord[arp_pattern[k % len(arp_pattern)] % len(chord)]
            fn = snap(freq(note_name), loop_len)
            dur = 0.55
            nn = int(dur * SR)
            env = envelope(nn, 0.008, dur - 0.008)
            buf.add_wrap(base + int(t * SR), tone(fn, nn, 0.13, env=env))
            t += bpm_note
            k += 1

    write_wav(path, buf.d, target_peak=0.72)


def build_click(path: str) -> None:
    """UI 点击：短促清脆的双音点击"""
    n = int(0.07 * SR)
    out = [0.0] * n
    for f, a in ((880.0, 1.0), (1760.0, 0.45), (2640.0, 0.15)):
        w = 2 * math.pi * f
        for i in range(n):
            env = math.exp(-i / (0.018 * SR))
            out[i] += a * math.sin(w * i / SR) * env
    write_wav(path, out, target_peak=0.55)


def build_hover(path: str) -> None:
    """UI 悬停：极轻的高频 tick"""
    n = int(0.035 * SR)
    out = [0.0] * n
    w = 2 * math.pi * 1320.0
    for i in range(n):
        out[i] = math.sin(w * i / SR) * math.exp(-i / (0.010 * SR))
    write_wav(path, out, target_peak=0.30)


def build_stinger(path: str, notes, dur: float, bright: float = 1.0) -> None:
    """事件提示音：依次奏出若干音符"""
    n = int(dur * SR)
    buf = Buf(n)
    step = dur / len(notes)
    for i, note_name in enumerate(notes):
        nn = int(step * SR * 1.6)
        env = envelope(nn, 0.005, step * 1.5)
        buf.add_wrap(int(i * step * SR), tone(freq(note_name), nn, 0.28 * bright, env=env))
    write_wav(path, buf.d, target_peak=0.70)


def write_wav(path: str, data, target_peak: float = 0.7) -> None:
    peak = max(abs(v) for v in data) or 1.0
    k = target_peak / peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = bytearray()
    for v in data:
        s = max(-32768, min(32767, int(v * k * 32767)))
        frames += struct.pack("<h", s)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print("  WROTE", path, "dur=%.2fs" % (len(data) / SR))


# ---------------- 场景音乐设计 ----------------
# 每个场景：和弦进行（小调为主，营造维多利亚悬疑感）+ 琶音走向
SCENES = {
    "menu":    ([("A3", "C4", "E4"), ("F3", "A3", "C4"), ("C3", "E3", "G3"), ("G3", "B3", "D4")], [0, 1, 2, 1]),
    "scene1":  ([("D3", "F3", "A3"), ("A2", "C3", "E3"), ("E3", "G3", "B3"), ("A2", "C3", "E3")], [0, 1, 2, 2, 1]),
    "scene2":  ([("C3", "E3", "G3"), ("G2", "B2", "D3"), ("F3", "A3", "C4"), ("C3", "E3", "G3")], [0, 2, 1, 2]),
    "scene3":  ([("E3", "G3", "B3"), ("C3", "E3", "G3"), ("D3", "F3", "A3"), ("E3", "G3", "B3")], [0, 1, 2, 0]),
    "scene4":  ([("F3", "A3", "C4"), ("D3", "F3", "A3"), ("A2", "C3", "E3"), ("F3", "A3", "C4")], [1, 0, 2, 1]),
    "scene5":  ([("G3", "B3", "D4"), ("E3", "G3", "B3"), ("C3", "E3", "G3"), ("D3", "F3", "A3")], [2, 1, 0, 1]),
    "scene6":  ([("B2", "D3", "F3"), ("G2", "B2", "D3"), ("E3", "G3", "B3"), ("B2", "D3", "F3")], [0, 2, 1, 2]),
    "scene7":  ([("A3", "C4", "E4"), ("E3", "G3", "B3"), ("F3", "A3", "C4"), ("G3", "B3", "D4")], [0, 1, 2, 1, 2]),
    "scene8":  ([("D3", "F3", "A3"), ("B2", "D3", "F3"), ("G3", "B3", "D4"), ("A2", "C3", "E3")], [2, 0, 1, 0]),
}

if __name__ == "__main__":
    print("== 生成 BGM（8 秒无缝循环）==")
    for name, (chords, arp) in SCENES.items():
        build_bgm(os.path.join(OUT_BGM, "%s.wav" % name), chords, arp)
    print("== 生成 UI 音效 ==")
    build_click(os.path.join(OUT_SFX, "ui_click.wav"))
    build_hover(os.path.join(OUT_SFX, "ui_hover.wav"))
    print("== 生成事件 stinger ==")
    build_stinger(os.path.join(OUT_SFX, "clue_found.wav"), ["E5", "G5", "C6"], 0.45)
    build_stinger(os.path.join(OUT_SFX, "wall_conflict.wav"), ["A3", "Eb4", "A4"], 0.6, bright=0.9)
    build_stinger(os.path.join(OUT_SFX, "reveal.wav"), ["C4", "E4", "G4", "C5"], 1.0)
    print("DONE")
