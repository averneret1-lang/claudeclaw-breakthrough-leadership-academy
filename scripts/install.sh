#!/usr/bin/env bash
set -e

AGENTS=(alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian scout)
AGENT_NAMES=("Alex (Orchestrator)" "Guernsy (Operations)" "Anne Christie (Finance)" "Angie (Marketing)" "Facilitator (Eunos & Saurel)" "Daniel (Developer)" "Participant Intel" "Fulfillment Coach" "Alumni" "Analytics" "Legal" "Librarian" "Scout (Research — background only)")

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

# BLTA custom scripts (overlay onto framework scripts/)
if [ -d "$BLTA_DIR/scripts" ]; then
  mkdir -p "$FRAMEWORK_DIR/scripts"
  for f in "$BLTA_DIR/scripts/"*.sh "$BLTA_DIR/scripts/"*.py; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    # Don't overwrite install.sh itself
    [ "$fname" = "install.sh" ] && continue
    cp "$f" "$FRAMEWORK_DIR/scripts/$fname"
    chmod +x "$FRAMEWORK_DIR/scripts/$fname"
  done
fi

echo "BLTA configuration applied."
echo ""

# Work from framework directory for the rest of setup
cd "$FRAMEWORK_DIR"

if [ ! -f .env ]; then
  cp .env.example .env 2>/dev/null || touch .env
  chmod 600 .env
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

# Helper: write or update a key=value in .env (bash 3 compatible)
set_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" .env && rm -f .env.bak
  else
    echo "${key}=${val}" >> .env
  fi
}

# Derive .env token var name from agent id (bash 3 compatible, no declare -A)
get_token_var() {
  case "$1" in
    daniel) echo "BLTA_DANIEL_BOT_TOKEN" ;;
    *) echo "$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_')_BOT_TOKEN" ;;
  esac
}

echo "Now configure each agent. You need one Telegram bot token per agent."
echo "Create bots at https://t.me/BotFather — send /newbot for each one."
echo ""
echo "Your Telegram user ID (Alex — get from https://t.me/userinfobot):"
read -r ADMIN_ID
set_env "ADMIN_TELEGRAM_ID" "$ADMIN_ID"

for i in "${!AGENTS[@]}"; do
  agent="${AGENTS[$i]}"
  name="${AGENT_NAMES[$i]}"

  echo ""
  echo "--- ${name} ---"

  # Always copy example to actual yaml (tokens live in .env, not yaml)
  cp "agents/${agent}/agent.yaml.example" "agents/${agent}/agent.yaml"

  # Scout is background-only — no bot token
  if [ "$agent" = "scout" ]; then
    echo "Scout configured (background research agent — no bot token needed)."
    continue
  fi

  echo "Telegram bot token for ${name}:"
  read -r TOKEN

  TOKEN_VAR="$(get_token_var "$agent")"
  set_env "$TOKEN_VAR" "$TOKEN"

  # Facilitator: collect Eunos + Saurel IDs
  if [ "$agent" = "facilitator" ]; then
    echo "Eunos's Telegram user ID:"
    read -r EUNOS_ID
    echo "Saurel's Telegram user ID:"
    read -r SAUREL_ID
    set_env "FACILITATOR_ALLOWED_IDS" "${EUNOS_ID},${SAUREL_ID}"
  fi

  echo "${name} configured."
done

# ─── Install & build ──────────────────────────────────────────────────────────

echo ""
echo "Installing dependencies..."
node -e "
var fs = require('fs');
var pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
pkg.devDependencies = pkg.devDependencies || {};
pkg.devDependencies['@types/js-yaml'] = '^4.0.9';
pkg.devDependencies['@types/better-sqlite3'] = '^7.6.12';
pkg.devDependencies['@types/qrcode-terminal'] = '^0.12.2';
pkg.devDependencies['vitest'] = '^2.0.0';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('package.json patched');
"
# NODE_ENV=development ensures devDependencies (type packages) are installed
NODE_ENV=development npm install

echo "Building project..."
npm run build

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

OS=$(uname)
if [ "$OS" = "Darwin" ]; then
  echo ""
  echo "Registering background services (macOS)..."
  mkdir -p "$HOME/Library/Logs/blta"
  mkdir -p "$(pwd)/logs"

  PROJECT_DIR="$(pwd)"
  NODE_BIN="/opt/homebrew/bin/node"
  [ -f "$NODE_BIN" ] || NODE_BIN="$(which node)"

  # Remove any stale engine plists from LaunchAgents (main/comms/content/ops/research
  # are engine defaults — BLTA does not use them)
  for stale in main comms content ops research; do
    STALE_DEST="$HOME/Library/LaunchAgents/com.claudeclaw.${stale}.plist"
    launchctl unload "$STALE_DEST" 2>/dev/null || true
    rm -f "$STALE_DEST"
  done

  # Generate and load a plist for each BLTA agent
  BLTA_AGENTS=(alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian)
  for agent in "${BLTA_AGENTS[@]}"; do
    LABEL="com.blta.agent.${agent}"
    DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
    cat > "$DEST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NODE_BIN}</string>
    <string>${PROJECT_DIR}/dist/index.js</string>
    <string>--agent</string>
    <string>${agent}</string>
  </array>
  <key>WorkingDirectory</key><string>${PROJECT_DIR}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>${HOME}</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>NODE_ENV</key><string>production</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>${PROJECT_DIR}/logs/${agent}.log</string>
  <key>StandardErrorPath</key><string>${PROJECT_DIR}/logs/${agent}.log</string>
</dict>
</plist>
PLIST
    launchctl unload "$DEST" 2>/dev/null || true
    launchctl load "$DEST" 2>/dev/null || true
    echo "  Loaded agent: $agent"
  done

  # Load BLTA helper plists (scout, suggestion-watcher) from repo
  for plist in launchd/com.blta.*.plist; do
    [ -f "$plist" ] || continue
    DEST="$HOME/Library/LaunchAgents/$(basename $plist)"
    sed "s|__PROJECT_DIR__|${PROJECT_DIR}|g; s|__HOME__|${HOME}|g" "$plist" > "$DEST"
    launchctl unload "$DEST" 2>/dev/null || true
    launchctl load "$DEST" 2>/dev/null || true
    echo "  Loaded helper: $(basename $plist)"
  done
fi

FINAL_TOKEN=$(grep "^DASHBOARD_TOKEN=" .env | cut -d'=' -f2)
echo ""
echo "================================================"
echo "  Installation complete."
echo "  System installed at: $(pwd)"
echo "  12 agents running + Scout (background research)."
echo ""
echo "  Agents start automatically on login via launchd."
echo ""
echo "  Mission Control Dashboard:"
echo "    http://localhost:3141/dashboard?token=$FINAL_TOKEN"
echo ""
echo "  Check agent status:"
echo "    launchctl list | grep com.blta.agent"
echo "================================================"
echo ""
