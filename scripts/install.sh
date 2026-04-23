#!/usr/bin/env bash
set -e

AGENTS=(alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian)
AGENT_NAMES=("Alex (Orchestrator)" "Guernsy (Operations)" "Anne Christie (Finance)" "Angie (Marketing)" "Facilitator (Eunos & Saurel)" "Daniel (Developer)" "Participant Intel" "Fulfillment Coach" "Alumni" "Analytics" "Legal" "Librarian")

echo ""
echo "================================================"
echo "  BLTA AI Operating System — Installer"
echo "================================================"
echo ""

# ─── Prerequisites ────────────────────────────────────────────────────────────

echo "Checking prerequisites..."

if ! command -v node &>/dev/null; then
  echo "ERROR: Node.js not found. Install from https://nodejs.org"
  exit 1
fi

NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VER" -lt 20 ]; then
  echo "ERROR: Node.js 20+ required. Current: $(node -v)"
  exit 1
fi

if ! command -v git &>/dev/null; then
  echo "ERROR: git not found."
  exit 1
fi

echo "Prerequisites OK."
echo ""

# ─── Engine ───────────────────────────────────────────────────────────────────

echo "Pulling ClaudeClaw engine..."
if [ ! -d engine ]; then
  git clone --depth 1 https://github.com/earlyaidopters/claudeclaw engine
else
  echo "  Engine directory exists. Pulling latest..."
  cd engine && git pull --ff-only 2>/dev/null || echo "  (already up to date or skipped)" && cd ..
fi

echo "Installing engine dependencies..."
cd engine
npm install --legacy-peer-deps --timeout=120000
echo "Building engine..."
npm run build
cd ..

echo "Engine ready."
echo ""

# ─── Environment ──────────────────────────────────────────────────────────────

if [ ! -f .env ]; then
  cp .env.example .env
fi

PROJECT_DIR=$(pwd)

# Write CLAUDECLAW_CONFIG so the engine finds this repo's agents/
if grep -q "^CLAUDECLAW_CONFIG" .env 2>/dev/null; then
  sed -i.bak "s|^CLAUDECLAW_CONFIG=.*|CLAUDECLAW_CONFIG=$PROJECT_DIR|" .env && rm -f .env.bak
elif grep -q "CLAUDECLAW_CONFIG" .env 2>/dev/null; then
  sed -i.bak "s|.*CLAUDECLAW_CONFIG.*|CLAUDECLAW_CONFIG=$PROJECT_DIR|" .env && rm -f .env.bak
else
  echo "CLAUDECLAW_CONFIG=$PROJECT_DIR" >> .env
fi

echo "Enter your Anthropic API key:"
read -r ANTHROPIC_KEY
sed -i.bak "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_KEY|" .env
rm -f .env.bak

echo ""
echo "Now configure each agent. You need one Telegram bot token per agent."
echo "Create bots at https://t.me/BotFather"
echo ""
echo "Enter your Telegram user ID (same for all agents unless specified):"
read -r DEFAULT_USER_ID

for i in "${!AGENTS[@]}"; do
  agent="${AGENTS[$i]}"
  name="${AGENT_NAMES[$i]}"

  echo ""
  echo "--- ${name} ---"
  echo "Telegram bot token for ${name}:"
  read -r TOKEN

  cp "agents/${agent}/agent.yaml.example" "agents/${agent}/agent.yaml"
  sed -i.bak "s|YOUR_TELEGRAM_BOT_TOKEN_HERE|$TOKEN|g" "agents/${agent}/agent.yaml"

  if [ "$agent" = "facilitator" ]; then
    echo "Eunos's Telegram user ID:"
    read -r EUNOS_ID
    echo "Saurel's Telegram user ID:"
    read -r SAUREL_ID
    sed -i.bak "s|EUNOS_TELEGRAM_USER_ID_HERE|$EUNOS_ID|g" "agents/${agent}/agent.yaml"
    sed -i.bak "s|SAUREL_TELEGRAM_USER_ID_HERE|$SAUREL_ID|g" "agents/${agent}/agent.yaml"
  else
    sed -i.bak "s|YOUR_TELEGRAM_USER_ID_HERE|$DEFAULT_USER_ID|g" "agents/${agent}/agent.yaml"
  fi

  rm -f "agents/${agent}/agent.yaml.bak"
  echo "  ${name} configured."
done

# ─── Database ─────────────────────────────────────────────────────────────────

echo ""
echo "Initializing database..."
mkdir -p store
chmod 700 store

if command -v sqlite3 &>/dev/null; then
  for sql in migrations/*.sql; do
    [ -f "$sql" ] || continue
    sqlite3 store/claudeclaw.db < "$sql" 2>/dev/null || true
    echo "  Applied $(basename $sql)"
  done
  chmod 600 store/claudeclaw.db
  echo "Database ready."
else
  echo "  sqlite3 not found — run migrations/*.sql manually after install."
fi

# ─── Launchd (macOS) ──────────────────────────────────────────────────────────

if [ "$(uname)" = "Darwin" ]; then
  echo ""
  echo "Registering background services (macOS)..."
  mkdir -p "$HOME/Library/Logs/blta"

  # Per-agent launchd plists (generated dynamically)
  for agent in "${AGENTS[@]}"; do
    LABEL="com.blta.$agent"
    DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

    cat > "$DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/node</string>
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
    echo "  Loaded $LABEL"
  done

  # Static plists (suggestion-watcher, etc.)
  if [ -d launchd ]; then
    for plist in launchd/*.plist; do
      [ -f "$plist" ] || continue
      DEST="$HOME/Library/LaunchAgents/$(basename $plist)"
      sed "s|__PROJECT_DIR__|$PROJECT_DIR|g; s|__HOME__|$HOME|g" "$plist" > "$DEST"
      launchctl unload "$DEST" 2>/dev/null || true
      launchctl load "$DEST" 2>/dev/null || true
      echo "  Loaded $(basename $plist)"
    done
  fi
fi

echo ""
echo "================================================"
echo "  Installation complete."
echo "  All 12 agents configured."
echo ""
echo "  Check agent status:"
echo "    launchctl list | grep com.blta"
echo ""
echo "  View agent logs:"
echo "    tail -f ~/Library/Logs/blta/alex.log"
echo ""
echo "  Restart a specific agent:"
echo "    launchctl kickstart -k gui/\$(id -u)/com.blta.alex"
echo ""
echo "  Stop all agents:"
echo "    for s in \$(launchctl list | grep com.blta | awk '{print \$3}'); do launchctl unload ~/Library/LaunchAgents/\$s.plist; done"
echo "================================================"
echo ""
