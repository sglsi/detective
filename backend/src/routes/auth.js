// 认证路由: 注册 / 登录 / 游客
const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const { getStorage } = require('../db/storage');
const { guestMiddleware, getSecret } = require('../middleware/auth');

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
      token: user.token,
      user: { id: user.id, username: user.username, email: user.email },
      note: '注册即签发令牌，客户端可立即按登录用户使用云端存档/进度。',
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

// GET /api/auth/me — 校验当前令牌是否仍然有效，并返回其身份
//
// 用途：客户端启动时恢复了本地缓存的会话（token）后，先调此接口确认该令牌
// 是否仍被服务端接受，再决定维持「已登录」还是降级为游客。
// 若不做这个确认，客户端会带着失效令牌请求所有接口 —— 而带 Authorization 头时
// 游客回退会被跳过（见 middleware/auth.js），结果就是全站 401 且永不自愈。
//
// ⚠️ 刻意**不使用 authRequired**、恒定返回 200：
// 这是一个"探测"接口，令牌无效本身是可预期的正常结果，不是请求错误。
// 若返回 401，浏览器控制台会对每次启动都留下一条红色
// "Failed to load resource: 401"，用户会误以为程序坏了。
// 因此改为 200 + `valid` 布尔字段，由客户端自行判断。
router.get('/me', (req, res) => {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) {
    return res.json({ valid: false, reason: 'no_token', user_id: '', email: '', is_guest: false });
  }
  try {
    const decoded = jwt.verify(header.slice(7), getSecret());
    return res.json({
      valid: true,
      user_id: decoded.sub || decoded.user_id || '',
      email: decoded.email || '',
      is_guest: false,
    });
  } catch (err) {
    // 签名不符 / 已过期 —— 明确告知客户端"这枚令牌不再可用"
    return res.json({ valid: false, reason: 'invalid_token', user_id: '', email: '', is_guest: false });
  }
});

module.exports = router;
