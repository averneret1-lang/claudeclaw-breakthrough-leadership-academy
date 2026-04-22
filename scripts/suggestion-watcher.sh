#!/bin/bash
# suggestion-watcher.sh — delivers agent proactive suggestions to Eunos via Alex's bot.
# Runs every 2 minutes via launchd. Installed automatically by install.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB="$PROJECT_ROOT/store/claudeclaw.db"
AGENT_YAML="$PROJECT_ROOT/agents/alex/agent.yaml"

if [ ! -f "$AGENT_YAML" ]; then
  echo "suggestion-watcher: agents/alex/agent.yaml not found — run install.sh first" >&2
  exit 1
fi

# Read token and allowed_users from Alex's agent.yaml
TOKEN=$(grep 'telegram_bot_token:' "$AGENT_YAML" | awk '{print $2}' | tr -d '"' | tr -d "'")
CHAT_ID=$(grep -A2 'allowed_users:' "$AGENT_YAML" | grep '  - ' | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")

if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ] || [ "$TOKEN" = "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
  echo "suggestion-watcher: Alex agent not configured yet — run install.sh" >&2
  exit 0
fi

export SUGGESTION_TOKEN="$TOKEN"
export SUGGESTION_CHAT_ID="$CHAT_ID"
export SUGGESTION_DB="$DB"

python3 "$SCRIPT_DIR/suggestion-watcher.py"
