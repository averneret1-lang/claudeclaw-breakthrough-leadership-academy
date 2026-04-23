#!/bin/bash
# suggestion-watcher.sh — delivers agent proactive suggestions to Eunos via Alex's bot.
# Runs every 2 minutes via launchd. Installed automatically by install.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB="$PROJECT_ROOT/store/claudeclaw.db"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "suggestion-watcher: .env not found — run install.sh first" >&2
  exit 1
fi

# Read token and admin chat ID from .env (tokens live there, not in agent.yaml)
TOKEN=$(grep '^ALEX_BOT_TOKEN=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
CHAT_ID=$(grep '^ADMIN_TELEGRAM_ID=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")

if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "suggestion-watcher: ALEX_BOT_TOKEN or ADMIN_TELEGRAM_ID not set in .env — run install.sh" >&2
  exit 0
fi

export SUGGESTION_TOKEN="$TOKEN"
export SUGGESTION_CHAT_ID="$CHAT_ID"
export SUGGESTION_DB="$DB"

python3 "$SCRIPT_DIR/suggestion-watcher.py"
