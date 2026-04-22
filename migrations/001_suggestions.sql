-- BLTA AI Operating System — Proactive Suggestion Layer
-- Run once: sqlite3 store/claudeclaw.db < migrations/001_suggestions.sql
-- This is run automatically by install.sh

-- Proactive suggestions from domain agents to Alex (orchestrator).
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

-- Hive mind for cross-agent awareness
CREATE TABLE IF NOT EXISTS hive_mind (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id   TEXT NOT NULL,
  action     TEXT NOT NULL,
  summary    TEXT NOT NULL,
  artifacts  TEXT,
  flag_type  TEXT,
  resolved   INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hive_mind_agent   ON hive_mind(agent_id);
CREATE INDEX IF NOT EXISTS idx_hive_mind_created ON hive_mind(created_at DESC);

-- Conversation log (used by agents for proactive scanning)
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
