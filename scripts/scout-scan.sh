#!/bin/bash
# scout-scan.sh — triggers Scout's research scan via the claudeclaw mission system.
# Runs every 15 minutes via launchd. Scout checks the hive mind and chimes if relevant.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB="$PROJECT_ROOT/store/claudeclaw.db"

if [ ! -f "$DB" ]; then
  echo "scout-scan: DB not found — system not installed yet" >&2
  exit 0
fi

# Pull the last 10 hive mind entries so Scout has context for what's active
RECENT=$(sqlite3 "$DB" "
  SELECT agent_id || ': ' || action || ' — ' || summary
  FROM hive_mind
  ORDER BY created_at DESC
  LIMIT 10;
" 2>/dev/null)

if [ -z "$RECENT" ]; then
  echo "scout-scan: no hive mind activity yet" >&2
  exit 0
fi

PROMPT="You are Scout, BLTA's research agent. Here is recent activity from the agent team:

$RECENT

Review this activity. For each item where external research would sharpen the outcome (benchmarks, competitor data, compliance updates, best practices), check your chime state and write a proactive suggestion if you are under the 3-chime cap for that context. Follow the chime protocol in your CLAUDE.md exactly. If nothing needs research right now, log to hive mind that you scanned and found nothing actionable."

# Trigger Scout via mission
node "$PROJECT_ROOT/dist/mission-cli.js" create --agent scout --title "Research scan" "$PROMPT" 2>/dev/null \
  && echo "scout-scan: mission queued" \
  || echo "scout-scan: mission-cli not available yet"
