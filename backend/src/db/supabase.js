// Supabase 客户端初始化
//
// 凭据来源优先级：SUPABASE_*（自有 .env）→ COZE_SUPABASE_*（平台注入）。
// 沙箱/部署环境由平台注入 COZE_SUPABASE_URL / COZE_SUPABASE_SERVICE_ROLE_KEY /
// COZE_SUPABASE_ANON_KEY，此处做兜底映射，使 getStorage() 的 auto 模式能识别到
// 托管数据库（否则会静默退回本地 SQLite —— 沙箱重建即丢存档）。
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || process.env.COZE_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || process.env.COZE_SUPABASE_SERVICE_ROLE_KEY;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.COZE_SUPABASE_ANON_KEY;

let supabaseAdmin = null;
let supabaseAnon = null;

function getSupabaseAdmin() {
  if (!supabaseAdmin) {
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase 未配置。请设置 SUPABASE_URL 和 SUPABASE_SERVICE_KEY 环境变量');
    }
    supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });
  }
  return supabaseAdmin;
}

function getSupabaseAnon() {
  if (!supabaseAnon) {
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Supabase 未配置。请设置 SUPABASE_URL 和 SUPABASE_ANON_KEY 环境变量');
    }
    supabaseAnon = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false },
    });
  }
  return supabaseAnon;
}

module.exports = { getSupabaseAdmin, getSupabaseAnon };
