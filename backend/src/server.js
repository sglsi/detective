// 维多利亚伦敦探案项目 — 后端 API 服务器入口
// Godot 客户端通过 RESTful API 与此服务通信

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth');
const saveRoutes = require('./routes/saves');
const progressRoutes = require('./routes/progress');
const healthRoutes = require('./routes/health');
const editorRoutes = require('./routes/editor');

const app = express();
const PORT = process.env.PORT || 3000;

// ===== 中间件 =====
app.use(helmet());
app.use(cors({
  origin: '*',  // Godot HTTPRequest 跨域
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(morgan('dev'));
app.use(express.json({ limit: '1mb' }));

// 速率限制
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 200,                  // 最多200次请求
  message: { error: '请求过于频繁，请稍后再试' },
});
app.use('/api/', limiter);

// ===== 路由 =====
app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/saves', saveRoutes);
app.use('/api/progress', progressRoutes);
app.use('/api/editor', editorRoutes);

// ===== 404 =====
app.use((req, res) => {
  res.status(404).json({ error: '接口不存在' });
});

// ===== 错误处理 =====
app.use((err, req, res, next) => {
  console.error('[Error]', err.message);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'development' ? err.message : '服务器内部错误',
  });
});

// ===== 启动 =====
app.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(50));
  console.log('  维多利亚伦敦探案 — 后端 API 服务');
  console.log('='.repeat(50));
  console.log(`  地址: http://0.0.0.0:${PORT}`);
  console.log(`  环境: ${process.env.NODE_ENV || 'development'}`);
  console.log(`  Supabase: ${process.env.SUPABASE_URL ? '已配置' : '未配置'}`);
  console.log('='.repeat(50));
});

module.exports = app;
