// 存档路由: 上传 / 下载 / 列表
const express = require('express');
const router = express.Router();
const { getStorage } = require('../db/storage');
const { authRequired } = require('../middleware/auth');

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

// GET /api/saves/slot/:slot — 获取指定槽位的完整存档
// 客户端本地缓存（Web 端 IndexedDB）随环境重建丢失时，用它把存档拉回本地。
router.get('/slot/:slot', authRequired, async (req, res) => {
  try {
    const slot = parseInt(req.params.slot, 10);
    if (!Number.isInteger(slot) || slot < 0 || slot > 2) {
      return res.status(400).json({ error: '无效存档槽位' });
    }
    const storage = getStorage();
    const save = await storage.getSaveSlot(req.userId, slot);
    if (!save) {
      return res.status(404).json({ error: '该槽位没有存档' });
    }
    res.json({ save });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/saves — 上传存档（按 user_id + slot 覆盖最新）
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
