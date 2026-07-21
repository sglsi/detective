// 存储适配层 (Storage Adapter)
//
// 设计目标：解耦业务路由与底层存储，支持两种后端：
//   1. SupabaseStorage  — 生产环境，使用 @supabase/supabase-js（真实部署时填 .env 凭据）
//   2. SQLiteStorage    — 本地开发/CI，使用 Node 内置 node:sqlite（零外部依赖，开箱即用）
//
// 路由层只依赖 StorageAdapter 接口，通过 getStorage() 工厂按 .env 自动选择后端，
// 无需在业务代码中判断当前环境。

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

// ============================================================
// 抽象基类
// ============================================================
class StorageAdapter {
  // --- Auth ---
  async registerUser({ email, password, username, phone }) { throw new Error('not implemented'); }
  async loginUser({ email, password }) { throw new Error('not implemented'); }
  async createGuest(guestId, expiresHours) { throw new Error('not implemented'); }

  // --- Saves ---
  async upsertSave(userId, saveData) { throw new Error('not implemented'); }
  async listSaves(userId) { throw new Error('not implemented'); }
  async getLatestSave(userId, caseId) { throw new Error('not implemented'); }

  // --- Progress ---
  async getProgress(userId, caseId) { throw new Error('not implemented'); }
  async upsertProgress(userId, caseId, updates) { throw new Error('not implemented'); }
  async listProgress(userId) { throw new Error('not implemented'); }
}

// ============================================================
// 工具：密码哈希 (scrypt, 零外部依赖)
// ============================================================
function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${derived}`;
}

function verifyPassword(password, stored) {
  if (!stored || !stored.includes(':')) return false;
  const [salt, hash] = stored.split(':');
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(derived, 'hex'));
}

function signJwt(payload) {
  const secret = process.env.JWT_SECRET || 'dev_local_secret_change_me_in_production';
  return jwt.sign(payload, secret, { expiresIn: '30d' });
}

// ============================================================
// SQLite 本地存储 (开发/CI)
// ============================================================
const { DatabaseSync } = require('node:sqlite');

class SQLiteStorage extends StorageAdapter {
  constructor() {
    super();
    const fs = require('fs');
    const path = require('path');
    const dataDir = path.join(__dirname, '..', '..', 'data');
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
    const dbPath = process.env.SQLITE_PATH || path.join(dataDir, 'local_dev.db');
    this.db = new DatabaseSync(dbPath);
    this.db.exec('PRAGMA journal_mode = WAL;');
    this._initSchema();
  }

  _initSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        email TEXT UNIQUE,
        password_hash TEXT,
        phone TEXT,
        is_guest BOOLEAN DEFAULT 0,
        guest_expires_at TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      );

      CREATE TABLE IF NOT EXISTS game_saves (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        save_version INTEGER DEFAULT 1,
        case_id TEXT NOT NULL,
        scene_id TEXT,
        difficulty INTEGER DEFAULT 1,
        clue_count INTEGER DEFAULT 0,
        observation_score INTEGER DEFAULT 0,
        reasoning_score INTEGER DEFAULT 0,
        insight_score INTEGER DEFAULT 0,
        unlocked_locations TEXT DEFAULT '[]',
        completed_milestones TEXT DEFAULT '[]',
        dialogue_progress TEXT DEFAULT '{}',
        clue_states TEXT DEFAULT '{}',
        game_time INTEGER DEFAULT 0,
        metadata TEXT DEFAULT '{}',
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      );

      CREATE INDEX IF NOT EXISTS idx_saves_user_case
        ON game_saves(user_id, case_id, updated_at DESC);

      CREATE TABLE IF NOT EXISTS case_progress (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        case_id TEXT NOT NULL,
        status TEXT DEFAULT 'not_started',
        scenes_completed TEXT DEFAULT '[]',
        clues_found INTEGER DEFAULT 0,
        clues_total INTEGER DEFAULT 0,
        reasoning_chains_completed INTEGER DEFAULT 0,
        observation_stars INTEGER DEFAULT 0,
        reasoning_stars INTEGER DEFAULT 0,
        insight_stars INTEGER DEFAULT 0,
        badges_earned TEXT DEFAULT '[]',
        started_at TEXT DEFAULT (datetime('now')),
        completed_at TEXT,
        updated_at TEXT DEFAULT (datetime('now')),
        UNIQUE(user_id, case_id)
      );
    `);
  }

  // --- Auth ---
  async registerUser({ email, password, username, phone }) {
    const id = crypto.randomUUID();
    const uname = username || email.split('@')[0];
    // 预检：明确区分「邮箱已注册」与「用户名被占用」两种冲突，给出可操作的提示
    const existing = this.db
      .prepare('SELECT email, username FROM profiles WHERE email = ? OR username = ?')
      .get(email, uname);
    if (existing) {
      if (existing.email === email) {
        throw { status: 409, message: '该邮箱已注册，请直接登录或更换邮箱' };
      }
      throw { status: 409, message: '该用户名已被占用，请更换用户名' };
    }
    const hash = hashPassword(password);
    this.db.prepare(
      `INSERT INTO profiles (id, username, email, password_hash, phone, is_guest)
       VALUES (?, ?, ?, ?, ?, 0)`
    ).run(id, uname, email, hash, phone || null);
    return { id, username: uname, email };
  }

  async loginUser({ email, password }) {
    const row = this.db.prepare('SELECT * FROM profiles WHERE email = ?').get(email);
    if (!row || !verifyPassword(password, row.password_hash)) {
      throw { status: 401, message: '邮箱或密码错误' };
    }
    const token = signJwt({ sub: row.id, email: row.email });
    return {
      token,
      refresh_token: token,
      user: { id: row.id, username: row.username, email: row.email },
    };
  }

  async createGuest(guestId, expiresHours) {
    const expires = new Date(Date.now() + (expiresHours || 24) * 3600000).toISOString();
    return { guest_id: guestId, expires_at: expires };
  }

  // --- Saves ---
  _rowToSave(row) {
    if (!row) return null;
    return {
      id: row.id,
      user_id: row.user_id,
      save_version: row.save_version,
      case_id: row.case_id,
      scene_id: row.scene_id,
      difficulty: row.difficulty,
      clue_count: row.clue_count,
      observation_score: row.observation_score,
      reasoning_score: row.reasoning_score,
      insight_score: row.insight_score,
      unlocked_locations: JSON.parse(row.unlocked_locations || '[]'),
      completed_milestones: JSON.parse(row.completed_milestones || '[]'),
      dialogue_progress: JSON.parse(row.dialogue_progress || '{}'),
      clue_states: JSON.parse(row.clue_states || '{}'),
      game_time: row.game_time,
      metadata: JSON.parse(row.metadata || '{}'),
      created_at: row.created_at,
      updated_at: row.updated_at,
    };
  }

  async upsertSave(userId, saveData) {
    const now = new Date().toISOString();
    const existing = this.db
      .prepare('SELECT id FROM game_saves WHERE user_id = ? AND case_id = ?')
      .get(userId, saveData.case_id);

    const id = existing ? existing.id : crypto.randomUUID();
    const json = (v, d) => JSON.stringify(v !== undefined ? v : d);

    if (existing) {
      this.db.prepare(`
        UPDATE game_saves SET
          save_version=?, scene_id=?, difficulty=?, clue_count=?,
          observation_score=?, reasoning_score=?, insight_score=?,
          unlocked_locations=?, completed_milestones=?, dialogue_progress=?,
          clue_states=?, game_time=?, metadata=?, updated_at=?
        WHERE id=?`)
        .run(
          saveData.save_version || 1, saveData.scene_id, saveData.difficulty || 1,
          saveData.clue_count || 0, saveData.observation_score || 0,
          saveData.reasoning_score || 0, saveData.insight_score || 0,
          json(saveData.unlocked_locations, []), json(saveData.completed_milestones, []),
          json(saveData.dialogue_progress, {}), json(saveData.clue_states, {}),
          saveData.game_time || 0, json(saveData.metadata, {}),
          now, id
        );
    } else {
      this.db.prepare(`
        INSERT INTO game_saves
          (id, user_id, save_version, case_id, scene_id, difficulty, clue_count,
           observation_score, reasoning_score, insight_score,
           unlocked_locations, completed_milestones, dialogue_progress,
           clue_states, game_time, metadata, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
        .run(
          id, userId,
          saveData.save_version || 1, saveData.case_id, saveData.scene_id, saveData.difficulty || 1,
          saveData.clue_count || 0, saveData.observation_score || 0,
          saveData.reasoning_score || 0, saveData.insight_score || 0,
          json(saveData.unlocked_locations, []), json(saveData.completed_milestones, []),
          json(saveData.dialogue_progress, {}), json(saveData.clue_states, {}),
          saveData.game_time || 0, json(saveData.metadata, {}),
          now, now
        );
    }
    return { save_id: id, updated_at: now };
  }

  async listSaves(userId) {
    const rows = this.db.prepare(
      `SELECT id, case_id, scene_id, difficulty, clue_count, updated_at
       FROM game_saves WHERE user_id = ? ORDER BY updated_at DESC LIMIT 20`
    ).all(userId);
    return rows;
  }

  async getLatestSave(userId, caseId) {
    let sql = 'SELECT * FROM game_saves WHERE user_id = ?';
    const args = [userId];
    if (caseId) { sql += ' AND case_id = ?'; args.push(caseId); }
    sql += ' ORDER BY updated_at DESC LIMIT 1';
    const row = this.db.prepare(sql).get(...args);
    return this._rowToSave(row);
  }

  // --- Progress ---
  _rowToProgress(row) {
    if (!row) return null;
    return {
      case_id: row.case_id,
      status: row.status,
      scenes_completed: JSON.parse(row.scenes_completed || '[]'),
      clues_found: row.clues_found,
      clues_total: row.clues_total,
      reasoning_chains_completed: row.reasoning_chains_completed,
      observation_stars: row.observation_stars,
      reasoning_stars: row.reasoning_stars,
      insight_stars: row.insight_stars,
      badges_earned: JSON.parse(row.badges_earned || '[]'),
      started_at: row.started_at,
      completed_at: row.completed_at,
      updated_at: row.updated_at,
    };
  }

  async getProgress(userId, caseId) {
    const row = this.db
      .prepare('SELECT * FROM case_progress WHERE user_id = ? AND case_id = ?')
      .get(userId, caseId);
    return this._rowToProgress(row);
  }

  async upsertProgress(userId, caseId, updates) {
    const now = new Date().toISOString();
    const existing = this.db
      .prepare('SELECT id FROM case_progress WHERE user_id = ? AND case_id = ?')
      .get(userId, caseId);

    const id = existing ? existing.id : crypto.randomUUID();
    const cols = ['status', 'scenes_completed', 'clues_found', 'clues_total',
      'reasoning_chains_completed', 'observation_stars', 'reasoning_stars',
      'insight_stars', 'badges_earned'];

    if (existing) {
      const sets = cols.map(c => `${c}=excluded_${c}`).join(', ');
      this.db.prepare(`
        INSERT INTO case_progress (id, user_id, case_id, updated_at, ${cols.join(', ')})
        VALUES (?, ?, ?, ?, ${cols.map(() => '?').join(', ')})
        ON CONFLICT(user_id, case_id) DO UPDATE SET ${sets}, updated_at=?
      `).run(id, userId, caseId, now,
        ...cols.map(c => {
          const v = updates[c];
          return (c.endsWith('s') || c === 'badges_earned') ? JSON.stringify(v !== undefined ? v : []) : (v || 0);
        }), now);
    } else {
      this.db.prepare(`
        INSERT INTO case_progress
          (id, user_id, case_id, status, scenes_completed, clues_found, clues_total,
           reasoning_chains_completed, observation_stars, reasoning_stars, insight_stars,
           badges_earned, started_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        id, userId, caseId, updates.status || 'not_started',
        JSON.stringify(updates.scenes_completed || []),
        updates.clues_found || 0, updates.clues_total || 0,
        updates.reasoning_chains_completed || 0,
        updates.observation_stars || 0, updates.reasoning_stars || 0,
        updates.insight_stars || 0, JSON.stringify(updates.badges_earned || []),
        now, now
      );
    }

    const row = this.db
      .prepare('SELECT * FROM case_progress WHERE id = ?')
      .get(id);
    return this._rowToProgress(row);
  }

  async listProgress(userId) {
    const rows = this.db.prepare(
      `SELECT case_id, status, observation_stars, reasoning_stars, insight_stars, badges_earned, completed_at
       FROM case_progress WHERE user_id = ? ORDER BY updated_at DESC`
    ).all(userId);
    return rows.map(r => ({
      case_id: r.case_id, status: r.status,
      observation_stars: r.observation_stars, reasoning_stars: r.reasoning_stars,
      insight_stars: r.insight_stars,
      badges_earned: JSON.parse(r.badges_earned || '[]'),
      completed_at: r.completed_at,
    }));
  }
}

// ============================================================
// Supabase 生产存储 (保留现有逻辑)
// ============================================================
class SupabaseStorage extends StorageAdapter {
  constructor() {
    const { getSupabaseAdmin } = require('./supabase');
    this.getSupabase = getSupabaseAdmin;
  }

  async registerUser({ email, password, username, phone }) {
    const supabase = this.getSupabase();
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { username, phone },
    });
    if (authError) throw { status: 400, message: authError.message };
    await supabase.from('profiles').insert({
      id: authData.user.id,
      username: username || email.split('@')[0],
      email, phone: phone || null, is_guest: false,
    });
    return { id: authData.user.id, username: username || email.split('@')[0], email };
  }

  async loginUser({ email, password }) {
    const supabase = this.getSupabase();
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw { status: 401, message: '邮箱或密码错误' };
    const { data: profile } = await supabase
      .from('profiles').select('username, is_guest').eq('id', data.user.id).single();
    return {
      token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      user: { id: data.user.id, username: profile?.username || email.split('@')[0], email: data.user.email },
    };
  }

  async createGuest(guestId, expiresHours) {
    const expires = new Date(Date.now() + (expiresHours || 24) * 3600000).toISOString();
    return { guest_id: guestId, expires_at: expires };
  }

  async upsertSave(userId, saveData) {
    const supabase = this.getSupabase();
    const { data: existing } = await supabase
      .from('game_saves').select('id').eq('user_id', userId).eq('case_id', saveData.case_id)
      .order('updated_at', { ascending: false }).limit(1).single();

    const payload = {
      user_id: userId, case_id: saveData.case_id,
      save_version: saveData.save_version || 1, scene_id: saveData.scene_id,
      difficulty: saveData.difficulty || 1, clue_count: saveData.clue_count || 0,
      observation_score: saveData.observation_score || 0,
      reasoning_score: saveData.reasoning_score || 0,
      insight_score: saveData.insight_score || 0,
      unlocked_locations: saveData.unlocked_locations || [],
      completed_milestones: saveData.completed_milestones || [],
      dialogue_progress: saveData.dialogue_progress || {},
      clue_states: saveData.clue_states || {},
      game_time: saveData.game_time || 0, metadata: saveData.metadata || {},
    };

    let result;
    if (existing) {
      result = await supabase.from('game_saves').update(payload).eq('id', existing.id).select().single();
    } else {
      result = await supabase.from('game_saves').insert(payload).select().single();
    }
    if (result.error) throw result.error;
    return { save_id: result.data.id, updated_at: result.data.updated_at };
  }

  async listSaves(userId) {
    const supabase = this.getSupabase();
    const { data } = await supabase
      .from('game_saves').select('id, case_id, scene_id, difficulty, clue_count, updated_at')
      .eq('user_id', userId).order('updated_at', { ascending: false }).limit(20);
    return data;
  }

  async getLatestSave(userId, caseId) {
    const supabase = this.getSupabase();
    let query = supabase.from('game_saves').select('*')
      .eq('user_id', userId).order('updated_at', { ascending: false }).limit(1);
    if (caseId) query = query.eq('case_id', caseId);
    const { data, error } = await query.single();
    if (error) {
      if (error.code === 'PGRST116') return null;
      throw error;
    }
    return data;
  }

  async getProgress(userId, caseId) {
    const supabase = this.getSupabase();
    const { data, error } = await supabase
      .from('case_progress').select('*').eq('user_id', userId).eq('case_id', caseId).single();
    if (error) {
      if (error.code === 'PGRST116') return null;
      throw error;
    }
    return data;
  }

  async upsertProgress(userId, caseId, updates) {
    const supabase = this.getSupabase();
    const { data, error } = await supabase.from('case_progress').upsert({
      user_id: userId, case_id: caseId, ...updates, updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id,case_id' }).select().single();
    if (error) throw error;
    return data;
  }

  async listProgress(userId) {
    const supabase = this.getSupabase();
    const { data } = await supabase
      .from('case_progress')
      .select('case_id, status, observation_stars, reasoning_stars, insight_stars, badges_earned, completed_at')
      .eq('user_id', userId).order('updated_at', { ascending: false });
    return data;
  }
}

// ============================================================
// 工厂：按 .env 自动选择后端
// ============================================================
let _storage = null;

function getStorage() {
  if (_storage) return _storage;
  const mode = (process.env.STORAGE_MODE || 'auto').toLowerCase();
  let useSupabase;
  if (mode === 'local') {
    useSupabase = false;
  } else if (mode === 'supabase') {
    useSupabase = true;
  } else {
    // auto: 仅当 SUPABASE_URL 和 SERVICE_KEY 均为真实非空值时使用 Supabase
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_KEY;
    useSupabase = !!(url && key && !url.includes('your-project') && !key.includes('your-service'));
  }
  if (useSupabase) {
    console.log('  [storage] 使用 Supabase 后端');
    _storage = new SupabaseStorage();
  } else {
    console.log('  [storage] 使用本地 SQLite 后端（开发/CI 模式）');
    _storage = new SQLiteStorage();
  }
  return _storage;
}

function isLocalMode() {
  return !(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_KEY);
}

module.exports = { StorageAdapter, SQLiteStorage, SupabaseStorage, getStorage, isLocalMode, hashPassword, verifyPassword, signJwt };
