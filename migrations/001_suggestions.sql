-- BLTA AI Operating System — Core Schema
-- Run once: sqlite3 store/claudeclaw.db < migrations/001_suggestions.sql
-- This is run automatically by install.sh

-- ─── Proactive Suggestions ────────────────────────────────────────────────────
-- Agents insert here when they spot relevant work in their domain.
-- The suggestion-watcher delivers these to Eunos via Alex's Telegram bot every 2 minutes.
CREATE TABLE IF NOT EXISTS proactive_suggestions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  from_agent   TEXT NOT NULL,       -- e.g. 'guernsy', 'angie', 'daniel'
  domain       TEXT,                -- 'operations','finance','marketing','facilitation','tech','participant','cross'
  content      TEXT NOT NULL,       -- the actual suggestion (2-4 sentences max)
  context      TEXT,                -- what triggered it (topic, project, document)
  status       TEXT DEFAULT 'pending' CHECK(status IN ('pending','delivered','dismissed')),
  created_at   INTEGER NOT NULL,
  delivered_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_suggestions_status ON proactive_suggestions(status, created_at);
CREATE INDEX IF NOT EXISTS idx_suggestions_agent  ON proactive_suggestions(from_agent);

-- ─── Hive Mind ────────────────────────────────────────────────────────────────
-- Cross-agent awareness log. Every meaningful agent action gets logged here.
CREATE TABLE IF NOT EXISTS hive_mind (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id   TEXT NOT NULL,
  chat_id    TEXT,                  -- Telegram chat ID of the session
  action     TEXT NOT NULL,
  summary    TEXT NOT NULL,
  artifacts  TEXT,
  flag_type  TEXT,
  resolved   INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hive_mind_agent   ON hive_mind(agent_id);
CREATE INDEX IF NOT EXISTS idx_hive_mind_created ON hive_mind(created_at DESC);

-- ─── Conversation Log ─────────────────────────────────────────────────────────
-- Full message history per agent session. Used for memory injection and proactive scanning.
CREATE TABLE IF NOT EXISTS conversation_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT,
  agent_id   TEXT NOT NULL,
  role       TEXT NOT NULL CHECK(role IN ('user','assistant','system')),
  content    TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_conv_agent   ON conversation_log(agent_id, created_at);
CREATE INDEX IF NOT EXISTS idx_conv_created ON conversation_log(created_at DESC);

-- ─── Sessions ─────────────────────────────────────────────────────────────────
-- Active and historical Claude Code sessions per agent/chat.
CREATE TABLE IF NOT EXISTS sessions (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT UNIQUE,
  chat_id    TEXT,
  agent_id   TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_agent   ON sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_sessions_chat    ON sessions(chat_id);
CREATE INDEX IF NOT EXISTS idx_sessions_created ON sessions(created_at DESC);

-- ─── Memories ─────────────────────────────────────────────────────────────────
-- Persistent semantic memory extracted from conversations.
-- Used for memory context injection at the top of each message.
CREATE TABLE IF NOT EXISTS memories (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id     TEXT,
  agent_id    TEXT,
  content     TEXT NOT NULL,
  sector      TEXT,                -- 'semantic', 'episodic', 'procedural'
  salience    REAL DEFAULT 1.0,    -- relevance score, higher = more important
  created_at  INTEGER NOT NULL,
  accessed_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_memories_chat    ON memories(chat_id);
CREATE INDEX IF NOT EXISTS idx_memories_agent   ON memories(agent_id);
CREATE INDEX IF NOT EXISTS idx_memories_salience ON memories(salience DESC);

-- ─── Token Usage ──────────────────────────────────────────────────────────────
-- Per-turn API cost and context tracking for convolife and budget monitoring.
CREATE TABLE IF NOT EXISTS token_usage (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id     TEXT,
  agent_id       TEXT,
  context_tokens INTEGER DEFAULT 0,
  output_tokens  INTEGER DEFAULT 0,
  cost_usd       REAL DEFAULT 0,
  did_compact    INTEGER DEFAULT 0,
  created_at     INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_token_session ON token_usage(session_id);
CREATE INDEX IF NOT EXISTS idx_token_agent   ON token_usage(agent_id);

-- ─── Scheduled Tasks ──────────────────────────────────────────────────────────
-- Cron-style scheduled prompts managed via schedule-cli.
CREATE TABLE IF NOT EXISTS scheduled_tasks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id   TEXT NOT NULL,
  prompt     TEXT NOT NULL,
  cron       TEXT NOT NULL,
  status     TEXT DEFAULT 'active' CHECK(status IN ('active','paused','deleted')),
  last_run   INTEGER,
  next_run   INTEGER,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_scheduled_agent  ON scheduled_tasks(agent_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_status ON scheduled_tasks(status, next_run);
