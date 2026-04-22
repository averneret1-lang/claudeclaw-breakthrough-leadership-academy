#!/usr/bin/env bash
set -e

AGENTS=(alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian)
AGENT_NAMES=("Alex (Orchestrator)" "Guernsy (Operations)" "Anne Christie (Finance)" "Angie (Marketing)" "Facilitator (Eunos & Saurel)" "Daniel (Developer)" "Participant Intel" "Fulfillment Coach" "Alumni" "Analytics" "Legal" "Librarian")

BLTA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAMEWORK_DIR="$HOME/claudeclaw-blta"

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

echo "Prerequisites OK."
echo ""

# ─── ClaudeClaw base framework ────────────────────────────────────────────────

echo "Setting up ClaudeClaw framework..."

if [ -d "$FRAMEWORK_DIR/.git" ]; then
  echo "Updating existing framework..."
  git -C "$FRAMEWORK_DIR" pull --ff-only 2>/dev/null || echo "Could not auto-update — continuing with existing version."
elif [ -f "$FRAMEWORK_DIR/package.json" ]; then
  echo "Framework already present at $FRAMEWORK_DIR"
else
  if command -v git &>/dev/null; then
    echo "Cloning ClaudeClaw framework..."
    git clone https://github.com/earlyaidopters/claudeclaw.git "$FRAMEWORK_DIR"
  else
    echo "Downloading ClaudeClaw framework — please wait..."
    mkdir -p "$FRAMEWORK_DIR"
    curl -L --retry 3 --retry-delay 5 \
      "https://github.com/earlyaidopters/claudeclaw/archive/refs/heads/main.zip" \
      -o /tmp/claudeclaw-base.zip
    unzip -q /tmp/claudeclaw-base.zip -d /tmp/claudeclaw-extract/
    cp -r /tmp/claudeclaw-extract/claudeclaw-main/. "$FRAMEWORK_DIR/"
    rm -rf /tmp/claudeclaw-base.zip /tmp/claudeclaw-extract
  fi
fi

echo "Framework ready at $FRAMEWORK_DIR"
echo ""

# ─── Overlay BLTA agent configs ───────────────────────────────────────────────

echo "Applying BLTA configuration..."

# Agent folders
for src_agent in "$BLTA_DIR/agents"/*/; do
  [ -d "$src_agent" ] || continue
  agent_name=$(basename "$src_agent")
  mkdir -p "$FRAMEWORK_DIR/agents/$agent_name"
  cp -r "$src_agent". "$FRAMEWORK_DIR/agents/$agent_name/"
done

# Launchd plists
if [ -d "$BLTA_DIR/launchd" ]; then
  mkdir -p "$FRAMEWORK_DIR/launchd"
  cp "$BLTA_DIR/launchd/"*.plist "$FRAMEWORK_DIR/launchd/" 2>/dev/null || true
fi

# Extra migrations (don't overwrite existing)
if [ -d "$BLTA_DIR/migrations" ]; then
  mkdir -p "$FRAMEWORK_DIR/migrations"
  for f in "$BLTA_DIR/migrations/"*.sql; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    [ -f "$FRAMEWORK_DIR/migrations/$fname" ] || cp "$f" "$FRAMEWORK_DIR/migrations/"
  done
fi

# .env.example
[ -f "$BLTA_DIR/.env.example" ] && cp "$BLTA_DIR/.env.example" "$FRAMEWORK_DIR/.env.example"

echo "BLTA configuration applied."
echo ""

# Work from framework directory for the rest of setup
cd "$FRAMEWORK_DIR"

if [ ! -f .env ]; then
  cp .env.example .env 2>/dev/null || touch .env
fi

# ─── Anthropic auth (OAuth) ───────────────────────────────────────────────────

echo "Setting up Anthropic authentication..."
echo ""

if ! command -v claude &>/dev/null; then
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
  echo "A browser window will open — sign in with your Anthropic account."
  echo "If no browser opens, copy and paste the URL that appears below."
  echo ""
  claude auth login
fi

echo "Anthropic auth complete."
echo ""

# ─── Telegram bots ────────────────────────────────────────────────────────────

echo "Now configure each agent. You need one Telegram bot token per agent."
echo "Create bots at https://t.me/BotFather — send /newbot for each one."
echo ""
echo "Enter your Telegram user ID (get it from https://t.me/userinfobot):"
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

# ─── Install & build ──────────────────────────────────────────────────────────

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
echo "  System installed at: $FRAMEWORK_DIR"
echo "  All 12 agents configured."
echo ""
echo "  Start all agents:"
echo "    cd $FRAMEWORK_DIR && npm run start:all"
echo ""
echo "  Check status:"
echo "    cd $FRAMEWORK_DIR && npm run status"
echo "================================================"
echo ""
