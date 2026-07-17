// 数据库迁移脚本
//
// 用法:
//   npm run migrate           # 按 STORAGE_MODE 初始化存储
//   node src/db/migrate.js     # 同上
//
// 本地模式 (STORAGE_MODE=local 或 auto+无 Supabase): 创建 SQLite 表
// Supabase 模式: 打印 SQL 供用户在 Supabase SQL Editor 执行

require('dotenv').config();

const fs = require('fs');
const path = require('path');

async function runMigrations() {
  const mode = (process.env.STORAGE_MODE || 'auto').toLowerCase();
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;
  const useSupabase = mode === 'supabase' ||
    (mode !== 'local' && url && key && !url.includes('your-project') && !key.includes('your-service'));

  if (useSupabase) {
    console.log('📦 Supabase 模式：请在 Supabase SQL Editor 中执行 migrations/001_initial_schema.sql');
    console.log('   路径:', path.join(__dirname, '..', '..', 'migrations', '001_initial_schema.sql'));
    return;
  }

  console.log('📦 本地 SQLite 模式：初始化数据库...');
  const { SQLiteStorage } = require('./storage');
  // 实例化即自动建表
  new SQLiteStorage();
  const dataDir = path.join(__dirname, '..', '..', 'data');
  console.log('   ✅ 数据库已就绪:', path.join(dataDir, 'local_dev.db'));
}

runMigrations().then(() => process.exit(0)).catch(e => {
  console.error('❌ 迁移失败:', e.message);
  process.exit(1);
});
