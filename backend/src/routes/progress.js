// 案件进度路由
const express = require('express');
const router = express.Router();
const { getStorage } = require('../db/storage');
const { authRequired } = require('../middleware/auth');

// GET /api/progress/:caseId — 获取案件进度
router.get('/:caseId', authRequired, async (req, res) => {
  try {
    const storage = getStorage();
    let progress = await storage.getProgress(req.userId, req.params.caseId);
    if (!progress) {
      return res.json({
        progress: {
          case_id: req.params.caseId,
          status: 'not_started',
          scenes_completed: [],
          clues_found: 0,
          clues_total: 0,
        },
      });
    }
    res.json({ progress });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/progress/:caseId — 更新案件进度
router.put('/:caseId', authRequired, async (req, res) => {
  try {
    const storage = getStorage();
    const progress = await storage.upsertProgress(req.userId, req.params.caseId, req.body);
    res.json({ message: '进度已更新', progress });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/progress — 获取所有案件进度
router.get('/', authRequired, async (req, res) => {
  try {
    const storage = getStorage();
    const progress = await storage.listProgress(req.userId);
    res.json({ progress });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
