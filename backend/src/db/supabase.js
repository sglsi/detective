// Supabase 客户端初始化
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

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
