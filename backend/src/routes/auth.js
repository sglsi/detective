// 认证路由: 注册 / 登录 / 游客
const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { getStorage } = require('../db/storage');
const { guestMiddleware } = require('../middleware/auth');

// POST /api/auth/register — 用户注册
router.post('/register', async (req, res) => {
  try {
    const { username, email, password, phone } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: '邮箱和密码为必填项' });
    }

    const storage = getStorage();
    const user = await storage.registerUser({ username, email, password, phone });

    res.status(201).json({
      message: '注册成功',
      user,
    });
  } catch (err) {
    if (err.status) return res.status(err.status).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/login — 用户登录
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: '邮箱和密码为必填项' });
    }

    const storage = getStorage();
    const result = await storage.loginUser({ email, password });

    res.json({
      message: '登录成功',
      token: result.token,
      refresh_token: result.refresh_token,
      user: result.user,
    });
  } catch (err) {
    if (err.status) return res.status(err.status).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/guest — 创建游客会话
router.post('/guest', guestMiddleware, async (req, res) => {
  try {
    const guestId = req.guestId || uuidv4();
    const storage = getStorage();
    const r = await storage.createGuest(guestId, parseInt(process.env.GUEST_EXPIRE_HOURS) || 24);

    res.json({
      message: '游客会话已创建',
      guest_id: r.guest_id,
      expires_at: r.expires_at,
      note: '游客数据仅保存在本地，退出即清除。注册后可同步到云端。',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
