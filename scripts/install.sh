#!/usr/bin/env bash
set -e

AGENTS=(alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian)
AGENT_NAMES=("Alex (Orchestrator)" "Guernsy (Operations)" "Anne Christie (Finance)" "Angie (Marketing)" "Facilitator (Eunos & Saurel)" "Daniel (Developer)" "Participant Intel" "Fulfillment Coach" "Alumni" "Analytics" "Legal" "Librarian")

echo ""
echo "================================================"
echo "  BLTA AI Operating System — Installer"
echo "================================================"
echo ""

# Check prerequisites
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
  echo "Note: git not found — that's OK if you downloaded via ZIP."
fi

echo "Prerequisites OK."
echo ""

# ─── Anthropic auth (OAuth) ───────────────────────────────────────────────────

if [ ! -f .env ]; then
  cp .env.example .env
fi

echo "Setting up Anthropic authentication..."
echo ""

# Try OAuth via claude CLI, fall back to API key if install fails
USING_OAUTH=false

if command -v claude &>/dev/null; then
  echo "Claude CLI already installed."
else
  echo "Installing Claude CLI (~200MB — please wait, do not close this window)..."
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global"
  npm install -g @anthropic-ai/claude-code \
    --fetch-timeout 600000 \
    --fetch-retry 5 \
    --fetch-retry-mintimeout 20000 \
    --fetch-retry-maxtimeout 120000
  export PATH="$HOME/.npm-global/bin:$PATH"
  PROFILE="$HOME/.zshrc"
  [ -f "$HOME/.bash_profile" ] && PROFILE="$HOME/.bash_profile"
  grep -q '.npm-global/bin' "$PROFILE" 2>/dev/null || \
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$PROFILE"
  echo "Claude CLI installed."
fi

if claude auth status &>/dev/null 2>&1; then
  echo "Already logged in to Anthropic."
else
  echo ""
  echo "A browser window will open — sign in with your Anthropic account."
  echo "If no browser opens, copy and paste the URL that appears below."
  echo ""
  claude auth login
fi

echo "Anthropic auth complete."

echo ""

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
  echo "${name} configured."
done

echo ""
echo "Installing dependencies..."
npm install

echo "Building project..."
npm run build

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

OS=$(uname)
if [ "$OS" = "Darwin" ] && [ -d launchd ]; then
  echo ""
  echo "Registering background services (macOS)..."
  mkdir -p "$HOME/Library/Logs/blta"
  for plist in launchd/*.plist; do
    [ -f "$plist" ] || continue
    DEST="$HOME/Library/LaunchAgents/$(basename $plist)"
    sed "s|__PROJECT_DIR__|$(pwd)|g; s|__HOME__|$HOME|g" "$plist" > "$DEST"
    launchctl unload "$DEST" 2>/dev/null || true
    launchctl load "$DEST" 2>/dev/null || true
    echo "  Loaded $(basename $plist)"
  done
fi

echo ""
echo "================================================"
echo "  Installation complete."
echo "  All 12 agents configured."
echo ""
echo "  Start all agents:"
echo "    npm run start:all"
echo ""
echo "  Check status:"
echo "    npm run status"
echo "================================================"
echo ""


