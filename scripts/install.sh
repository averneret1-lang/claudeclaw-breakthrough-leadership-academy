#!/usr/bin/env bash
set -e

BLTA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAMEWORK_DIR="$HOME/claudeclaw-blta"

echo ""
echo "================================================"
echo "  Breakthrough Leadership Transformation Academy"
echo "  AI Operating System — Installer"
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

# FIX: check for python3 — required by suggestion-watcher
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Install via: brew install python3"
  exit 1
fi

# FIX: detect node binary path dynamically (works on Intel + Apple Silicon)
NODE_BIN="$(which node)"

echo "Prerequisites OK."
echo ""

# ─── Engine ───────────────────────────────────────────────────────────────────

echo "Pulling ClaudeClaw engine..."
if [ ! -d engine ]; then
  git clone --depth 1 https://github.com/earlyaidopters/claudeclaw engine
else
  echo "  Engine directory exists. Pulling latest..."
  # FIX: run in a subshell so the cd does not affect the parent shell.
  # Without the subshell, a successful git pull leaves us inside engine/
  # and the subsequent unconditional `cd engine` would fail with set -e.
  (cd engine && git pull --ff-only 2>/dev/null || echo "  (already up to date or skipped)")
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

# FIX: auto-generate DB_ENCRYPTION_KEY if not already set
EXISTING_KEY=$(grep "^DB_ENCRYPTION_KEY=" .env 2>/dev/null | cut -d'=' -f2 | tr -d '"')
if [ -z "$EXISTING_KEY" ]; then
  DB_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
  if grep -q "^DB_ENCRYPTION_KEY" .env 2>/dev/null; then
    sed -i.bak "s|^DB_ENCRYPTION_KEY=.*|DB_ENCRYPTION_KEY=$DB_KEY|" .env && rm -f .env.bak
  elif grep -q "DB_ENCRYPTION_KEY" .env 2>/dev/null; then
    sed -i.bak "s|.*DB_ENCRYPTION_KEY.*|DB_ENCRYPTION_KEY=$DB_KEY|" .env && rm -f .env.bak
  else
    echo "DB_ENCRYPTION_KEY=$DB_KEY" >> .env
  fi
  echo "  Generated DB_ENCRYPTION_KEY."
else
  DB_KEY="$EXISTING_KEY"
  echo "  DB_ENCRYPTION_KEY already set."
fi

echo "Enter your Anthropic API key:"
read -r ANTHROPIC_KEY
sed -i.bak "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_KEY|" .env
rm -f .env.bak

# ─── Alex (Orchestrator) — required to start ──────────────────────────────────
echo ""
echo "Setting up Alex — your main orchestrator bot."
echo "Create a bot at https://t.me/BotFather and paste the token here."
echo ""
echo "Alex bot token:"
read -r ALEX_TOKEN

echo "Your Telegram user ID (find it at https://t.me/userinfobot):"
read -r DEFAULT_USER_ID

cp "agents/alex/agent.yaml.example" "agents/alex/agent.yaml"
sed -i.bak "s|YOUR_TELEGRAM_BOT_TOKEN_HERE|$ALEX_TOKEN|g" "agents/alex/agent.yaml"
sed -i.bak "s|YOUR_TELEGRAM_USER_ID_HERE|$DEFAULT_USER_ID|g" "agents/alex/agent.yaml"
rm -f "agents/alex/agent.yaml.bak"
echo "  Alex configured."
echo ""
echo "The remaining 11 agents (Guernsy, Anne Christie, Angie, etc.) can be"
echo "activated one-by-one after install using:"
echo "  ./scripts/add-agent.sh            (interactive menu)"
echo "  ./scripts/add-agent.sh guernsy    (activate a specific agent)"
echo "  ./scripts/add-agent.sh --all      (activate all at once)"

# ─── Dashboard token ──────────────────────────────────────────────────────────

if ! grep -q "^DASHBOARD_TOKEN=." .env 2>/dev/null; then
  DASH_TOKEN=$(node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")
  if grep -q "^DASHBOARD_TOKEN=" .env; then
    sed -i.bak "s|^DASHBOARD_TOKEN=.*|DASHBOARD_TOKEN=$DASH_TOKEN|" .env && rm -f .env.bak
  else
    echo "DASHBOARD_TOKEN=$DASH_TOKEN" >> .env
    echo "DASHBOARD_PORT=3141" >> .env
  fi
  echo "Dashboard token generated."
fi

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

  # Boot Alex only on first install. Other agents are activated via add-agent.sh.
  for agent in alex; do
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

FINAL_TOKEN=$(grep "^DASHBOARD_TOKEN=" .env | cut -d'=' -f2)
echo ""
echo "================================================"
echo "  Installation complete."
echo ""
echo "  Alex is running. Message your bot on Telegram."
echo ""
echo "  Activate more agents when ready:"
echo "    ./scripts/add-agent.sh            (interactive menu)"
echo "    ./scripts/add-agent.sh guernsy    (single agent)"
echo "    ./scripts/add-agent.sh --all      (all 11 remaining)"
echo ""
echo "  Check status:"
echo "    launchctl list | grep com.blta"
echo ""
echo "  View logs:"
echo "    tail -f ~/Library/Logs/blta/alex.log"
echo ""
echo "  Restart an agent:"
echo "    launchctl kickstart -k gui/\$(id -u)/com.blta.alex"
echo ""
echo "  Stop all agents:"
echo "    for s in \$(launchctl list | grep com.blta | awk '{print \$3}'); do launchctl unload ~/Library/LaunchAgents/\$s.plist; done"
echo "================================================"
echo ""
