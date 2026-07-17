// 存档路由: 上传 / 下载 / 列表
const express = require('express');
const router = express.Router();
const { getStorage } = require('../db/storage');
const { authRequired, guestMiddleware } = require('../middleware/auth');

const SAVE_FIELDS = [
  'save_version', 'scene_id', 'difficulty', 'clue_count',
  'observation_score', 'reasoning_score', 'insight_score',
  'unlocked_locations', 'completed_milestones', 'dialogue_progress',
  'clue_states', 'game_time', 'metadata',
];

function pickSave(body) {
  const out = {};
  for (const f of SAVE_FIELDS) {
    if (body[f] !== undefined) out[f] = body[f];
  }
  return out;
}

// GET /api/saves — 获取存档列表
router.get('/', authRequired, async (req, res) => {
  try {
    const storage = getStorage();
    const saves = await storage.listSaves(req.userId);
    res.json({ saves, count: saves.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/saves/latest — 获取最新存档
router.get('/latest', authRequired, async (req, res) => {
  try {
    const storage = getStorage();
    const save = await storage.getLatestSave(req.userId, req.query.case_id);
    if (!save) {
      return res.status(404).json({ error: '没有找到存档' });
    }
    res.json({ save });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/saves — 上传存档（M1 策略：同用户+同案覆盖最新）
router.post('/', authRequired, async (req, res) => {
  try {
    const saveData = req.body;
    if (!saveData.case_id) {
      return res.status(400).json({ error: '缺少 case_id' });
    }
    const storage = getStorage();
    const result = await storage.upsertSave(req.userId, saveData);
    res.json({
      message: '存档已同步',
      save_id: result.save_id,
      updated_at: result.updated_at,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
