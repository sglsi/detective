#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把外部生成的 BGM 处理为可直接用于游戏的**无缝循环** WAV。

背景：AI 音乐工具（Suno/Udio 等）生成的曲子有两个通病：
  1. 结尾常带一段孤立的"发报式"结束音（静音数秒后突然一记短音）；
  2. 首尾不可能相位连续，直接 loop 会有咔哒声或明显停顿。
本脚本链式解决：

  ① 尾部清理：以能量回看窗口自动定位"音乐主体"真正结束点，
     裁掉其后的自然衰减长尾 + 孤立结束音（孤立音因持续时间短、
     回看窗口均值低而自动被排除）。
  ② 重采样到 44.1kHz（标准采样率，减少 Web 端二次重采样环节）。
  ③ 峰值归一化到 -3 dBFS（统一各曲响度，避免切歌时忽大忽小）。
  ④ 首尾等功率交叉淡化（cos/sin），生成真正无缝的循环点。

用法：
  python tools/prepare_bgm.py <源WAV> <输出WAV> [交叉淡化秒数，默认2.5]
"""
import sys
import wave

import numpy as np

TARGET_SR = 44100
TAIL_WINDOW = 1.5        # 判定"音乐主体"的回看窗口（秒）
TAIL_THRESH_DB = -40.0   # 回看窗口内平均能量低于此值即认为音乐已结束
TAIL_PAD = 0.25          # 结束点之后额外保留的余量（秒）
DEFAULT_FADE = 2.5       # 首尾交叉淡化长度（秒）
TARGET_PEAK = 10.0 ** (-3.0 / 20.0)   # -3 dBFS


def read_wav(path):
    w = wave.open(path, "rb")
    sr = w.getframerate()
    ch = w.getnchannels()
    sw = w.getsampwidth()
    if sw != 2:
        raise SystemExit("仅支持 16bit WAV，当前 sampwidth=%d" % sw)
    raw = w.readframes(w.getnframes())
    w.close()
    a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    a = a.reshape(-1, ch)
    return a, sr, ch


def write_wav(path, a, sr):
    x = np.clip(a, -1.0, 1.0)
    pcm = (x * 32767.0).astype("<i2")
    w = wave.open(path, "wb")
    w.setnchannels(pcm.shape[1])
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(pcm.tobytes())
    w.close()


def find_music_end(a, sr):
    """返回音乐主体结束的采样下标（其后为衰减长尾 / 孤立结束音）。"""
    mono = a.mean(axis=1) if a.ndim == 2 else a
    win = max(1, int(sr * 0.1))
    steps = len(mono) // win
    if steps == 0:
        return len(mono)
    blocks = mono[: steps * win].reshape(steps, win)
    ms = (blocks ** 2).mean(axis=1)
    look = max(1, int(TAIL_WINDOW / 0.1))
    thr_ms = 10.0 ** (TAIL_THRESH_DB / 10.0)
    # ⚠️ 必须用「窗口内达标块占比」而非「窗口平均能量」：
    # 结尾那记孤立的发报式短音能量可达 -24dB，仅 1~2 块（0.1~0.2s），
    # 却能把 1.5s 窗口的平均能量拉过阈值，导致误判"音乐仍在"而裁不掉。
    # 改用占比判定后，孤立音占比 <10% 会被自动排除。
    for i in range(steps - 1, -1, -1):
        seg = ms[max(0, i - look + 1): i + 1]
        ratio = float((seg > thr_ms).sum()) / float(len(seg))
        if ratio >= 0.5:
            return min(len(mono), (i + 1) * win + int(TAIL_PAD * sr))
    return len(mono)


def resample(a, sr, target_sr):
    if sr == target_sr:
        return a
    n = a.shape[0]
    m = int(round(n * target_sr / float(sr)))
    idx = np.linspace(0.0, n - 1.0, m, dtype=np.float64)
    src = np.arange(n, dtype=np.float64)
    if a.ndim == 2:
        out = np.empty((m, a.shape[1]), dtype=np.float32)
        for c in range(a.shape[1]):
            out[:, c] = np.interp(idx, src, a[:, c]).astype(np.float32)
        return out
    return np.interp(idx, src, a).astype(np.float32)


def make_seamless_loop(a, sr, fade_sec):
    """等功率交叉淡化，构造真正无缝的循环。

    ⚠️ 正确方向是「把**尾部**折回叠加到**开头**」，而不是把开头混进尾部：
        out[i]   = a[i] * (i/F)      + a[L+i] * (1 - i/F)      (i < F)
        out[j]   = a[j]                                        (F <= j < L)
    于是 out[0] = a[L]，而 out[L-1] = a[L-1] —— 两者在原始音频中**相邻**，
    循环点自然连续。若反向（把开头混进尾部），out[-1] 会等于 a[F-1]、
    out[0] 仍是 a[0]，二者相隔整段 fade，曲子开头若有渐强就会明显咔哒。
    """
    fade = int(fade_sec * sr)
    total = a.shape[0]
    if total <= fade * 2:
        return a
    loop_len = total - fade
    out = a[:loop_len].copy()
    head = a[:fade]
    tail = a[loop_len:loop_len + fade]
    t = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    w_head = t                  # 0 -> 1
    w_tail = 1.0 - t            # 1 -> 0
    if out.ndim == 2:
        out[:fade] = head * w_head[:, None] + tail * w_tail[:, None]
    else:
        out[:fade] = head * w_head + tail * w_tail
    return out


def normalize_peak(a, target=TARGET_PEAK):
    peak = float(np.max(np.abs(a)))
    if peak <= 1e-9:
        return a
    return (a * (target / peak)).astype(np.float32)


def process(src, dst, fade_sec=DEFAULT_FADE):
    a, sr, ch = read_wav(src)
    dur0 = a.shape[0] / float(sr)
    end = find_music_end(a, sr)
    a = a[:end]
    print("  主体结束点 %.2fs / 原长 %.2fs（裁掉 %.2fs 尾部）"
          % (end / float(sr), dur0, dur0 - end / float(sr)))
    a = resample(a, sr, TARGET_SR)
    a = make_seamless_loop(a, TARGET_SR, fade_sec)
    a = normalize_peak(a)
    write_wav(dst, a, TARGET_SR)
    print("  输出 %s  时长 %.2fs  %dch @ %dHz" % (dst, a.shape[0] / float(TARGET_SR), ch, TARGET_SR))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        raise SystemExit(1)
    fade = float(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_FADE
    print("处理 %s" % sys.argv[1])
    process(sys.argv[1], sys.argv[2], fade)
