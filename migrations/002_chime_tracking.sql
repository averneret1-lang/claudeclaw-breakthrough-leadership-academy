-- BLTA AI Operating System — Chime Tracking Layer
-- Run once: sqlite3 store/claudeclaw.db < migrations/002_chime_tracking.sql
-- This is run automatically by install.sh

-- Add context_key and chime_seq to existing suggestions table
-- (safe to run even if columns already exist — errors are suppressed by install.sh)
ALTER TABLE proactive_suggestions ADD COLUMN context_key TEXT DEFAULT 'general';
ALTER TABLE proactive_suggestions ADD COLUMN chime_seq INTEGER DEFAULT 1;

-- Tracks how many times each agent has chimed per context.
-- Agents check this before writing a suggestion — max 3 unless paused=0 after Eunos resets.
CREATE TABLE IF NOT EXISTS agent_chime_state (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id    TEXT    NOT NULL,
  context_key TEXT    NOT NULL DEFAULT 'general',
  chime_count INTEGER NOT NULL DEFAULT 0,
  paused      INTEGER NOT NULL DEFAULT 0,  -- 1 = hit the cap, waiting for Eunos to say "continue"
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  UNIQUE(agent_id, context_key)
);

CREATE INDEX IF NOT EXISTS idx_chime_state_agent   ON agent_chime_state(agent_id);
CREATE INDEX IF NOT EXISTS idx_chime_state_context ON agent_chime_state(context_key);
