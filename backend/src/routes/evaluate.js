// 困难模式评价结果接收路由（方案 A）
// 评分在 Godot 客户端（hard_mode_evaluator.gd）完成；本路由只负责接收结果、做基础校验、
// 服务端缓存/审计，并预留未来 LLM 自由文本评审钩子（Track B）。
const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const MAX_CACHE = 1000;
const cache = [];

// 可选持久化目录（挂载卷时通过环境变量开启，方案A 仅审计用，不依赖数据库）
const DATA_DIR = process.env.EVAL_DATA_DIR || '';

function audit(record) {
  cache.push({ ts: new Date().toISOString(), ...record });
  if (cache.length > MAX_CACHE) cache.shift();
  if (DATA_DIR) {
    try {
      const f = path.join(DATA_DIR, `eval_${Date.now()}.json`);
      fs.writeFileSync(f, JSON.stringify(record, null, 2));
    } catch (e) {
      console.warn('[evaluate] 落盘失败（非阻塞）:', e.message);
    }
  }
}

function num(v, def) {
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
}

router.post('/', (req, res) => {
  const b = req.body || {};
  // 基础校验（宽松：缺失非核心字段不阻断，仅校验评分配送所需最小集）
  const required = ['scene_id', 'difficulty', 'ratio'];
  for (const k of required) {
    if (b[k] === undefined || b[k] === null) {
      return res.status(400).json({ error: `缺少字段: ${k}` });
    }
  }
  const ratio = num(b.ratio, 0);
  if (ratio < 0 || ratio > 1) {
    return res.status(400).json({ error: 'ratio 必须在 0~1 之间' });
  }
  const record = {
    scene_id: String(b.scene_id),
    difficulty: num(b.difficulty, 1),
    four_dim: Boolean(b.four_dim),
    ratio,
    grade: b.grade ? String(b.grade) : '',
    stars: num(b.stars, 0),
    conclusion_correct: Boolean(b.conclusion_correct),
    four: b.four && typeof b.four === 'object' ? b.four : {},
    reasons: Array.isArray(b.reasons) ? b.reasons.map(String) : [],
    summary: b.summary ? String(b.summary) : '',
    // 玩家图摘要（非完整图，仅用于后续离线分析人机差异）；方案A 不重算评分
    player_graph: b.player_graph && typeof b.player_graph === 'object' ? b.player_graph : {},
  };
  audit(record);
  // 预留：未来 Track B 将在服务端用 LLM 对 player_graph + four 做自由文本定性评审，
  // 并回写 qualitative 字段；本期只返回接收确认。
  res.json({ ok: true, received_at: new Date().toISOString(), cached: cache.length });
});

// 运维/调试：查看最近缓存（全局速率限制已生效）
router.get('/recent', (req, res) => {
  res.json({ count: cache.length, items: cache.slice(-50) });
});

module.exports = router;
