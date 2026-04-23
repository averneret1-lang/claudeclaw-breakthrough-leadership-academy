#!/usr/bin/env bash
# add-agent.sh — Activate a BLTA agent after the base install.
# Usage:
#   ./scripts/add-agent.sh              (interactive — picks from menu)
#   ./scripts/add-agent.sh guernsy      (activate specific agent by ID)
#   ./scripts/add-agent.sh --all        (activate all remaining agents)
set -e

AGENTS=(alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian)
AGENT_NAMES=(
  "Alex (Orchestrator)"
  "Guernsy (Operations)"
  "Anne Christie (Finance)"
  "Angie (Marketing)"
  "Facilitator (Eunos & Saurel)"
  "Daniel (Developer)"
  "Participant Intel"
  "Fulfillment Coach"
  "Alumni"
  "Analytics"
  "Legal"
  "Librarian"
)

# ─── Resolve project root ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Load env ──────────────────────────────────────────────────────────────────
if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo "ERROR: .env not found. Run install.sh first."
  exit 1
fi
set -a; source "$PROJECT_DIR/.env"; set +a

ANTHROPIC_KEY="${ANTHROPIC_API_KEY:-}"
DB_KEY="${DB_ENCRYPTION_KEY:-}"
NODE_BIN="$(which node)"

if [ -z "$ANTHROPIC_KEY" ] || [ "$ANTHROPIC_KEY" = "ANTHROPIC_API_KEY=" ]; then
  echo "ERROR: ANTHROPIC_API_KEY not set in .env. Run install.sh first."
  exit 1
fi

# ─── Helper: activate one agent ───────────────────────────────────────────────
activate_agent() {
  local agent="$1"
  local name="$2"

  # Check if agent.yaml.example exists
  if [ ! -f "$PROJECT_DIR/agents/$agent/agent.yaml.example" ]; then
    echo "  SKIP: No agent.yaml.example for $agent"
    return
  fi

  echo ""
  echo "─── $name ───────────────────────────────────────"

  # Check if already active
  if [ -f "$PROJECT_DIR/agents/$agent/agent.yaml" ]; then
    EXISTING_TOKEN=$(grep 'telegram_bot_token:' "$PROJECT_DIR/agents/$agent/agent.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
    if [ -n "$EXISTING_TOKEN" ] && [ "$EXISTING_TOKEN" != "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
      echo "  Already configured. Re-configure? (y/N):"
      read -r RECONFIG
      if [[ "$RECONFIG" != "y" && "$RECONFIG" != "Y" ]]; then
        echo "  Skipped."
        return
      fi
    fi
  fi

  echo "  Telegram bot token for $name:"
  read -r TOKEN

  if [ -z "$TOKEN" ]; then
    echo "  No token entered. Skipping $agent."
    return
  fi

  # Copy and fill template
  cp "$PROJECT_DIR/agents/$agent/agent.yaml.example" "$PROJECT_DIR/agents/$agent/agent.yaml"
  sed -i.bak "s|YOUR_TELEGRAM_BOT_TOKEN_HERE|$TOKEN|g" "$PROJECT_DIR/agents/$agent/agent.yaml"

  if [ "$agent" = "facilitator" ]; then
    echo "  Eunos's Telegram user ID:"
    read -r EUNOS_ID
    echo "  Saurel's Telegram user ID:"
    read -r SAUREL_ID
    sed -i.bak "s|EUNOS_TELEGRAM_USER_ID_HERE|$EUNOS_ID|g" "$PROJECT_DIR/agents/$agent/agent.yaml"
    sed -i.bak "s|SAUREL_TELEGRAM_USER_ID_HERE|$SAUREL_ID|g" "$PROJECT_DIR/agents/$agent/agent.yaml"
  else
    # Read allowed user from Alex's config if available, otherwise prompt
    ALEX_YAML="$PROJECT_DIR/agents/alex/agent.yaml"
    if [ -f "$ALEX_YAML" ]; then
      DEFAULT_USER=$(grep -A2 'allowed_users:' "$ALEX_YAML" | grep '  - ' | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
    fi
    if [ -z "$DEFAULT_USER" ] || [ "$DEFAULT_USER" = "YOUR_TELEGRAM_USER_ID_HERE" ]; then
      echo "  Telegram user ID for this bot:"
      read -r DEFAULT_USER
    else
      echo "  Using Telegram user ID from Alex's config: $DEFAULT_USER"
    fi
    sed -i.bak "s|YOUR_TELEGRAM_USER_ID_HERE|$DEFAULT_USER|g" "$PROJECT_DIR/agents/$agent/agent.yaml"
  fi

  rm -f "$PROJECT_DIR/agents/$agent/agent.yaml.bak"

  # Register launchd service (macOS only)
  if [ "$(uname)" = "Darwin" ]; then
    LABEL="com.blta.$agent"
    DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
    mkdir -p "$HOME/Library/Logs/blta"

    cat > "$DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$PROJECT_DIR/engine/dist/index.js</string>
    <string>--agent</string>
    <string>$agent</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$PROJECT_DIR</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>$HOME</string>
    <key>CLAUDECLAW_CONFIG</key>
    <string>$PROJECT_DIR</string>
    <key>CLAUDECLAW_AGENT_ID</key>
    <string>$agent</string>
    <key>ANTHROPIC_API_KEY</key>
    <string>$ANTHROPIC_KEY</string>
    <key>DB_ENCRYPTION_KEY</key>
    <string>$DB_KEY</string>
    <key>NODE_ENV</key>
    <string>production</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>30</integer>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/blta/$agent.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/blta/$agent.log</string>
</dict>
</plist>
PLIST

    launchctl unload "$DEST" 2>/dev/null || true
    launchctl load "$DEST" 2>/dev/null || true
    echo "  ✓ $name is live (com.blta.$agent)"
  else
    echo "  ✓ $name configured (non-macOS: start manually with node engine/dist/index.js --agent $agent)"
  fi
}

# ─── Mode: --all ──────────────────────────────────────────────────────────────
if [ "$1" = "--all" ]; then
  echo ""
  echo "Activating all BLTA agents..."
  echo "You need one Telegram bot token per agent. Create bots at https://t.me/BotFather"
  echo ""
  echo "Enter your Telegram user ID (used for all agents except Facilitator):"
  read -r GLOBAL_USER_ID

  for i in "${!AGENTS[@]}"; do
    agent="${AGENTS[$i]}"
    name="${AGENT_NAMES[$i]}"

    cp "$PROJECT_DIR/agents/$agent/agent.yaml.example" "$PROJECT_DIR/agents/$agent/agent.yaml"

    echo ""
    echo "--- $name ---"
    echo "Telegram bot token:"
    read -r TOKEN
    sed -i.bak "s|YOUR_TELEGRAM_BOT_TOKEN_HERE|$TOKEN|g" "$PROJECT_DIR/agents/$agent/agent.yaml"

    if [ "$agent" = "facilitator" ]; then
      echo "Eunos's Telegram user ID:"
      read -r EUNOS_ID
      echo "Saurel's Telegram user ID:"
      read -r SAUREL_ID
      sed -i.bak "s|EUNOS_TELEGRAM_USER_ID_HERE|$EUNOS_ID|g" "$PROJECT_DIR/agents/$agent/agent.yaml"
      sed -i.bak "s|SAUREL_TELEGRAM_USER_ID_HERE|$SAUREL_ID|g" "$PROJECT_DIR/agents/$agent/agent.yaml"
    else
      sed -i.bak "s|YOUR_TELEGRAM_USER_ID_HERE|$GLOBAL_USER_ID|g" "$PROJECT_DIR/agents/$agent/agent.yaml"
    fi

    rm -f "$PROJECT_DIR/agents/$agent/agent.yaml.bak"

    if [ "$(uname)" = "Darwin" ]; then
      LABEL="com.blta.$agent"
      DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
      mkdir -p "$HOME/Library/Logs/blta"
      # (plist written inline as in activate_agent above)
      cat > "$DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$NODE_BIN</string>
    <string>$PROJECT_DIR/engine/dist/index.js</string>
    <string>--agent</string><string>$agent</string>
  </array>
  <key>WorkingDirectory</key><string>$PROJECT_DIR</string>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <key>CLAUDECLAW_CONFIG</key><string>$PROJECT_DIR</string>
    <key>CLAUDECLAW_AGENT_ID</key><string>$agent</string>
    <key>ANTHROPIC_API_KEY</key><string>$ANTHROPIC_KEY</string>
    <key>DB_ENCRYPTION_KEY</key><string>$DB_KEY</string>
    <key>NODE_ENV</key><string>production</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/blta/$agent.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/blta/$agent.log</string>
</dict>
</plist>
PLIST
      launchctl unload "$DEST" 2>/dev/null || true
      launchctl load "$DEST" 2>/dev/null || true
      echo "  ✓ Loaded com.blta.$agent"
    fi
  done

  echo ""
  echo "All agents activated."
  echo "Check status: launchctl list | grep com.blta"
  exit 0
fi

# ─── Mode: specific agent by ID ───────────────────────────────────────────────
if [ -n "$1" ]; then
  TARGET="$1"
  for i in "${!AGENTS[@]}"; do
    if [ "${AGENTS[$i]}" = "$TARGET" ]; then
      activate_agent "$TARGET" "${AGENT_NAMES[$i]}"
      echo ""
      echo "Done. Check status:"
      echo "  launchctl list | grep com.blta.$TARGET"
      echo "  tail -f ~/Library/Logs/blta/$TARGET.log"
      exit 0
    fi
  done
  echo "ERROR: Unknown agent '$TARGET'"
  echo "Available: ${AGENTS[*]}"
  exit 1
fi

# ─── Mode: interactive menu ───────────────────────────────────────────────────
echo ""
echo "BLTA Agent Activator"
echo "──────────────────────────────────"
echo ""
echo "Active agents (have agent.yaml configured):"
for i in "${!AGENTS[@]}"; do
  agent="${AGENTS[$i]}"
  name="${AGENT_NAMES[$i]}"
  if [ -f "$PROJECT_DIR/agents/$agent/agent.yaml" ]; then
    TOKEN=$(grep 'telegram_bot_token:' "$PROJECT_DIR/agents/$agent/agent.yaml" 2>/dev/null | awk '{print $2}')
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
      echo "  ✓ [$i] $name"
    else
      echo "  ○ [$i] $name  (token not set)"
    fi
  else
    echo "  ○ [$i] $name"
  fi
done

echo ""
echo "Enter agent number to activate (0-11), 'all' for all, or q to quit:"
read -r CHOICE

if [ "$CHOICE" = "q" ] || [ "$CHOICE" = "Q" ]; then
  exit 0
fi

if [ "$CHOICE" = "all" ]; then
  exec "$0" --all
fi

if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -lt "${#AGENTS[@]}" ]; then
  activate_agent "${AGENTS[$CHOICE]}" "${AGENT_NAMES[$CHOICE]}"
  echo ""
  echo "Done."
else
  echo "Invalid selection."
  exit 1
fi
