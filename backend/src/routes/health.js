// 健康检查路由
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: '维多利亚伦敦探案 — API',
    version: '0.1.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: 'GET  /api/health',
      auth_register: 'POST /api/auth/register',
      auth_login: 'POST /api/auth/login',
      auth_guest: 'POST /api/auth/guest',
      saves_list: 'GET  /api/saves',
      saves_upload: 'POST /api/saves',
      saves_download: 'GET  /api/saves/latest',
      progress_get: 'GET  /api/progress/:caseId',
      progress_update: 'PUT  /api/progress/:caseId',
    },
  });
});

module.exports = router;
