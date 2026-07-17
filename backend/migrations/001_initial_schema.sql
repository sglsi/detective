-- 维多利亚伦敦探案项目 — 数据库 Schema
-- 目标: Supabase PostgreSQL

-- ============================================
-- 1. 用户表 (扩展 Supabase auth.users)
-- ============================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  email TEXT,
  phone TEXT,
  avatar_url TEXT,
  is_guest BOOLEAN DEFAULT TRUE,
  guest_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: 用户只能读写自己的 profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 2. 游戏存档表
-- ============================================
CREATE TABLE IF NOT EXISTS public.game_saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  save_version INTEGER DEFAULT 1,
  case_id TEXT NOT NULL,
  scene_id TEXT,
  difficulty INTEGER DEFAULT 1,  -- 0=EASY, 1=NORMAL, 2=HARD
  clue_count INTEGER DEFAULT 0,
  observation_score INTEGER DEFAULT 0,
  reasoning_score INTEGER DEFAULT 0,
  insight_score INTEGER DEFAULT 0,
  unlocked_locations JSONB DEFAULT '[]',
  completed_milestones JSONB DEFAULT '[]',
  dialogue_progress JSONB DEFAULT '{}',
  clue_states JSONB DEFAULT '{}',
  game_time INTEGER DEFAULT 0,  -- 游戏内时间戳
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引：按用户+案件+更新时间查询最新存档
CREATE INDEX IF NOT EXISTS idx_saves_user_case_time
  ON public.game_saves(user_id, case_id, updated_at DESC);

ALTER TABLE public.game_saves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own saves"
  ON public.game_saves FOR ALL
  USING (auth.uid() = user_id);

-- ============================================
-- 3. 案件进度表
-- ============================================
CREATE TABLE IF NOT EXISTS public.case_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  case_id TEXT NOT NULL,
  status TEXT DEFAULT 'not_started',  -- not_started/in_progress/completed
  scenes_completed JSONB DEFAULT '[]',
  clues_found INTEGER DEFAULT 0,
  clues_total INTEGER DEFAULT 0,
  reasoning_chains_completed INTEGER DEFAULT 0,
  observation_stars INTEGER DEFAULT 0,
  reasoning_stars INTEGER DEFAULT 0,
  insight_stars INTEGER DEFAULT 0,
  badges_earned JSONB DEFAULT '[]',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, case_id)
);

CREATE INDEX IF NOT EXISTS idx_progress_user_case
  ON public.case_progress(user_id, case_id);

ALTER TABLE public.case_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own progress"
  ON public.case_progress FOR ALL
  USING (auth.uid() = user_id);

-- ============================================
-- 4. 线索同步表 (可选，M2+)
-- ============================================
CREATE TABLE IF NOT EXISTS public.clue_sync (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  case_id TEXT NOT NULL,
  clue_id TEXT NOT NULL,
  state TEXT DEFAULT 'discovered',  -- discovered/recorded/analyzed/linked
  observation_notes TEXT,
  linked_clues JSONB DEFAULT '[]',
  discovered_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, case_id, clue_id)
);

ALTER TABLE public.clue_sync ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own clues"
  ON public.clue_sync FOR ALL
  USING (auth.uid() = user_id);

-- ============================================
-- 5. 游戏设置表 (跨设备同步)
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_settings (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  master_volume REAL DEFAULT 1.0,
  music_volume REAL DEFAULT 0.8,
  sfx_volume REAL DEFAULT 1.0,
  voice_volume REAL DEFAULT 0.7,
  interface_language TEXT DEFAULT 'zh_CN',
  subtitle_language TEXT DEFAULT 'zh_CN',
  default_difficulty INTEGER DEFAULT 1,
  auto_save_enabled BOOLEAN DEFAULT TRUE,
  dialogue_speed REAL DEFAULT 1.0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own settings"
  ON public.user_settings FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can upsert own settings"
  ON public.user_settings FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own settings"
  ON public.user_settings FOR UPDATE
  USING (auth.uid() = id);

-- ============================================
-- 函数: 自动更新 updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表添加触发器
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename IN ('profiles', 'game_saves', 'case_progress', 'clue_sync', 'user_settings')
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS trg_%s_updated_at ON public.%I;
      CREATE TRIGGER trg_%s_updated_at
        BEFORE UPDATE ON public.%I
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    ', t, t, t, t);
  END LOOP;
END;
$$;
