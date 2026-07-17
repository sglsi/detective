// JWT 认证中间件
//
// 支持两种 token 来源：
//   1. 本地模式：后端用 JWT_SECRET 签发并验证（StorageAdapter 本地模式）
//   2. Supabase 模式：验证 Supabase Auth 签发的 JWT（用 JWT_SECRET 或 SUPABASE_JWT_SECRET）
//
// 两种方式统一通过 jsonwebtoken 验证，payload.sub 即为 userId。
// 游客模式：从请求头 X-Guest-ID 提取 guestId，不要求 token。

const jwt = require('jsonwebtoken');

function _secret() {
  return process.env.JWT_SECRET || process.env.SUPABASE_JWT_SECRET || 'dev_local_secret_change_me_in_production';
}

function authRequired(req, res, next) {
  const authHeader = req.headers.authorization;

  // 游客模式：允许通过 X-Guest-ID 访问（受限接口）
  const guestId = req.headers['x-guest-id'];
  if (guestId && !authHeader) {
    req.guestId = guestId;
    req.isGuest = true;
    req.userId = `guest:${guestId}`;
    return next();
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: '未提供认证令牌' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, _secret());
    req.userId = decoded.sub || decoded.user_id;
    req.userEmail = decoded.email;
    req.isGuest = false;
    next();
  } catch (err) {
    return res.status(401).json({ error: '认证令牌无效或已过期' });
  }
}

// 游客模式：从请求头中提取 guest_id
function guestMiddleware(req, res, next) {
  const guestId = req.headers['x-guest-id'];
  if (guestId) {
    req.guestId = guestId;
    req.isGuest = true;
  } else {
    req.isGuest = false;
  }
  next();
}

module.exports = { authRequired, guestMiddleware };
