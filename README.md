# Breakthrough Leadership Transformation Academy — AI Operating System

> 12 specialized AI agents running on your Mac, each accessible via its own Telegram bot.

This is not a chatbot. Each agent spawns the actual `claude` CLI on your machine and routes results to a dedicated Telegram chat. Everything that works in your terminal works from your phone.

---

## Agents

### Core (Deploy Day 1)

| Agent | Role | Model | Bot name (suggested) |
|-------|------|-------|----------------------|
| Alex | System Architect & Orchestrator | claude-opus-4-6 | `@blta_alex_bot` |
| Guernsy | Operations — registration, logistics, CRM | claude-sonnet-4-6 | `@blta_guernsy_bot` |
| Anne Christie | Finance — cohort economics, invoicing, cash flow | claude-sonnet-4-6 | `@blta_finance_bot` |
| Angie | Marketing — campaigns, social, lead gen | claude-sonnet-4-6 | `@blta_marketing_bot` |
| Facilitator | Program delivery — serves Eunos & Saurel directly | claude-sonnet-4-6 | `@blta_facilitator_bot` |
| Daniel | Developer — infrastructure, tools, integrations | claude-sonnet-4-6 | `@blta_daniel_bot` |

### Extended (Deploy Day 1)

| Agent | Role | Model | Bot name (suggested) |
|-------|------|-------|----------------------|
| Participant Intel | Engagement tracking, re-enrollment signals | claude-haiku-4-5 | `@blta_intel_bot` |
| Fulfillment Coach | Pre/post-seminar participant preparation | claude-haiku-4-5 | `@blta_coach_bot` |
| Alumni | Community, re-engagement, testimonials | claude-haiku-4-5 | `@blta_alumni_bot` |
| Analytics | Cross-domain performance reporting | claude-sonnet-4-6 | `@blta_analytics_bot` |
| Legal | Contracts, waivers, compliance drafting | claude-sonnet-4-6 | `@blta_legal_bot` |
| Librarian | Google Drive indexing and knowledge retrieval | claude-haiku-4-5 | `@blta_librarian_bot` |

---

## What you need before anything else

| Requirement | How to check | How to get it |
|-------------|-------------|---------------|
| **macOS 12+** or Ubuntu 20+ | `sw_vers` | System update |
| **Node.js 20+** | `node --version` | [nodejs.org](https://nodejs.org) — click the green LTS button |
| **A Claude account** | `claude --version` | [claude.ai](https://claude.ai) — Pro or Max plan |
| **12 Telegram bots** | — | Create via [@BotFather](https://t.me/BotFather) (see Step 2) |
| **Your Telegram user ID** | — | Message [@userinfobot](https://t.me/userinfobot) |

**Which Claude plan works?** Any plan works (Free, Pro, Max). Complex multi-step reasoning performs significantly better on Max with Opus. The Facilitator, Legal, and Analytics agents in particular benefit from Max.

**New to the terminal?** Download [Warp](https://www.warp.dev) — it's a modern terminal with AI built in. If you hit any errors during setup, type `/agent` in Warp and describe what went wrong. It will walk you through fixing it.

**macOS permission dialogs:** After starting for the first time, your Mac may show "Node wants to access..." dialogs. Click Allow on each one or the agents will silently hang. Keep your screen on during the first run.

---

## Step 1: Download

### Option A — ZIP (no GitHub account needed, recommended)

1. [Download the ZIP](https://github.com/averneret1-lang/claudeclaw-breakthrough-leadership-academy/archive/refs/heads/main.zip)
2. Find it in your Downloads folder and double-click to extract it
3. A folder called `claudeclaw-breakthrough-leadership-academy-main` will appear

### Option B — Git clone

```bash
git clone https://github.com/averneret1-lang/claudeclaw-breakthrough-leadership-academy.git
```

---

## Step 2: Create your 12 Telegram bots

You need one bot per agent. Do this before running the installer — it'll ask for each token one by one.

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Give it a name (e.g. `BLTA Alex`) and a username ending in `_bot` (e.g. `blta_alex_bot`)
4. BotFather replies with a token like `1234567890:AAFxxxxxxx` — copy it
5. Repeat 11 more times, one for each agent in the table above

Keep all 12 tokens in a text file handy. The installer walks through each agent in order.

**Tip:** Name them clearly so you know which is which in Telegram. Example naming: `BLTA Alex`, `BLTA Guernsy`, `BLTA Finance`, etc.

---

## Step 3: Get your Telegram user ID

Your user ID locks each bot to you so no one else can use it.

1. Open Telegram and message **[@userinfobot](https://t.me/userinfobot)**
2. It replies with a number like `123456789` — that's your user ID
3. Keep it handy. The installer will ask for it.

The Facilitator agent also needs Eunos's and Saurel's user IDs if they'll be accessing it directly.

---

## Step 4: Run the installer

Open Terminal. Navigate into the folder:

```bash
# If you used Option A (ZIP):
cd ~/Downloads/claudeclaw-breakthrough-leadership-academy-main

# If you used Option B (git):
cd claudeclaw-breakthrough-leadership-academy
```

Then run:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

**What the installer does, in order:**

1. **Checks Node.js** — exits with a clear error if the version is wrong
2. **Downloads the ClaudeClaw engine** — clones [earlyaidopters/claudeclaw](https://github.com/earlyaidopters/claudeclaw) into `~/claudeclaw-blta` (or downloads via ZIP if git isn't available). This is the actual runtime that powers all 12 agents.
3. **Overlays BLTA configuration** — copies all 12 agent personas, launchd service files, and database migrations on top
4. **Authenticates with Anthropic** — installs the `claude` CLI and opens a browser for OAuth login (sign in with your existing Claude account — no API key needed)
5. **Configures Telegram bots** — walks through each of the 12 agents, asks for the bot token, and sets the correct user IDs
6. **Installs dependencies** — runs `npm install` and `npm run build`
7. **Initializes the database** — applies all migrations to create the SQLite database at `store/claudeclaw.db`
8. **Registers background services** — installs launchd agents on macOS so all 12 bots start automatically at login

The installer takes 10–15 minutes on first run (mostly waiting on the npm install and Claude CLI download).

**Do not close the Terminal window while it runs.**

---

## Step 5: Authenticate with Anthropic

During install, when you see:

```
A browser window will open — sign in with your Anthropic account.
```

A browser will open to Anthropic's login page. Sign in with the same account you use on claude.ai. Once you authorize, the window closes and the installer continues. No API key needed — it uses your existing account via OAuth.

If no browser opens automatically, the installer will print a URL. Copy it and paste it into your browser.

---

## Step 6: Verify everything is running

After the installer finishes, check status:

```bash
cd ~/claudeclaw-blta
npm run status
```

Output looks like:

```
  ✓  Node v22.x.x
  ✓  Claude CLI 2.x.x
  ✓  Agent [alex]:       running (PID 12345) — @blta_alex_bot
  ✓  Agent [guernsy]:    running (PID 12346) — @blta_guernsy_bot
  ✓  Agent [angie]:      running (PID 12347) — @blta_marketing_bot
  ...
  ✓  Database: 12 agents configured
  ─────────────────
  All systems go.
```

---

## Step 7: Send your first message

Open each agent's Telegram chat and send `/start`. They'll respond with their name and role.

From there, message them like you would any Telegram chat. They understand natural language. Try things like:

- To **Alex**: `What's the system status?` or `Give me an overview of all agents`
- To **Guernsy**: `Prepare a registration checklist for the next cohort`
- To **Anne Christie**: `Summarize the economics of the last cohort`
- To **Angie**: `Draft a LinkedIn post about our upcoming seminar`
- To **Legal**: `Generate a participant waiver for our next event`

---

## Background services (launchd)

The installer registers all 12 agents as macOS background services. They start automatically when you log in and restart themselves if they crash.

**Check running agents:**

```bash
launchctl list | grep claudeclaw
```

**View logs for a specific agent:**

```bash
tail -f ~/claudeclaw-blta/logs/alex.log
tail -f ~/claudeclaw-blta/logs/legal.log
```

**Restart a single agent** (e.g. after changing its CLAUDE.md):

```bash
launchctl unload ~/Library/LaunchAgents/com.claudeclaw.blta-alex.plist
launchctl load ~/Library/LaunchAgents/com.claudeclaw.blta-alex.plist
```

**Restart all agents** after a code update:

```bash
cd ~/claudeclaw-blta
npm run build
for agent in alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian; do
  launchctl unload ~/Library/LaunchAgents/com.claudeclaw.blta-$agent.plist 2>/dev/null
  launchctl load ~/Library/LaunchAgents/com.claudeclaw.blta-$agent.plist
done
```

**Stop everything:**

```bash
for agent in alex guernsy anne-christie angie facilitator daniel participant-intel fulfillment-coach alumni analytics legal librarian; do
  launchctl unload ~/Library/LaunchAgents/com.claudeclaw.blta-$agent.plist 2>/dev/null
done
```

---

## Bot commands

Every agent responds to these commands:

| Command | What it does |
|---------|-------------|
| `/start` | Confirms the agent is running, shows name and role |
| `/help` | Lists available commands |
| `/stop` | Cancels the current task mid-execution |
| `/model` | Switch model. `/model haiku` for speed, `/model sonnet` for balance, `/model opus` for full power |
| `/newchat` | Starts a fresh Claude session (clears context window) |
| `/respin` | After `/newchat`, pulls last 20 turns back in as background context |
| `/memory` | Shows what this agent remembers about your work |
| `/voice` | Toggle voice replies on/off |
| `/dashboard` | Get a link to the live monitoring dashboard |

---

## Dashboard

The system includes a live web dashboard showing all 12 agents, what they're doing, scheduled tasks, memory, and cost.

**Set it up:**

1. Generate a dashboard password:
   ```bash
   node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
   ```

2. Add it to `~/claudeclaw-blta/.env`:
   ```
   DASHBOARD_TOKEN=paste_the_long_string_here
   ```

3. Rebuild and restart:
   ```bash
   cd ~/claudeclaw-blta && npm run build
   ```

4. Send `/dashboard` to any agent in Telegram — it replies with a clickable link.

**What you'll see:**
- Status cards for all 12 agents (live/offline, model, today's activity, cost)
- Hive mind feed — real-time log of what every agent has been doing
- Mission Control — one-shot task creation and assignment
- Scheduled tasks — recurring automations per agent
- Memory landscape — what the system knows and how long it'll retain it
- Token & cost tracking — daily and all-time spend per agent

---

## Updating

When a new version is released:

```bash
cd ~/claudeclaw-blta
git pull
npm install
npm run build
```

Then restart all agents (see Background services above).

---

## Monthly Cost Estimate

| Tier | Agents | Estimated cost |
|------|--------|----------------|
| Light use (meetings + content) | Core 6 only | ~$30–60/mo |
| Standard operations | All 12, typical load | ~$80–130/mo |
| Heavy use (multiple active cohorts) | All 12, high volume | ~$150–200/mo |

Cost drivers:
- **Alex (Opus)** at ~$15/M input + $75/M output adds ~$20–40/mo depending on orchestration volume
- **Haiku agents** (Participant Intel, Fulfillment Coach, Alumni, Librarian) are ~10x cheaper than Sonnet — use them aggressively for high-volume tasks
- **Legal and Analytics** on Sonnet are mid-range — use Opus selectively via `/model opus` for complex document drafting

If your Anthropic account is on the Max plan ($200/mo), it covers this system entirely with no per-token billing.

---

## Troubleshooting

**Agent doesn't respond**
- Check that its launchd service is running: `launchctl list | grep claudeclaw`
- Check its log: `tail -f ~/claudeclaw-blta/logs/[agentname].log`
- Verify Claude auth: `claude --version` and `claude auth status`
- macOS: check if Node permission dialogs are waiting for your approval on screen

**"claude: command not found" after install**
- Run: `export PATH="$HOME/.npm-global/bin:$PATH"`
- Then restart your shell: close Terminal and reopen, or run `source ~/.zshrc`

**npm install timed out during setup**
- Your connection dropped partway through. Run `./scripts/install.sh` again — it picks up where it left off
- The Claude CLI download is ~200MB. On slow connections, let it run for up to 10 minutes before assuming failure

**"EACCES permission denied" on npm install**
- Run: `mkdir -p ~/.npm-global && npm config set prefix ~/.npm-global`
- Then retry: `./scripts/install.sh`

**Browser didn't open for Anthropic login**
- Copy the URL the installer prints and paste it manually into any browser
- After signing in, return to Terminal — the installer continues automatically

**Agent starts but ignores my messages**
- Your Telegram user ID in the agent's `agent.yaml` doesn't match your actual ID
- Get your real ID from [@userinfobot](https://t.me/userinfobot)
- Edit `~/claudeclaw-blta/agents/[agentname]/agent.yaml` and fix the `allowed_chat_id` value
- Restart the agent

**"409 Conflict: terminated by other getUpdates request"**
- Two instances of the same agent are running. Kill the old one:
  ```bash
  launchctl unload ~/Library/LaunchAgents/com.claudeclaw.blta-[agentname].plist
  launchctl load ~/Library/LaunchAgents/com.claudeclaw.blta-[agentname].plist
  ```

**Context feels stale or confused**
- Send `/newchat` to start a fresh session
- Send `/respin` immediately after to bring recent context back in without the full token weight

**Re-run the installer after fixing an issue**
- Safe to run `./scripts/install.sh` multiple times — it skips already-completed steps (framework already downloaded, auth already complete)

---

## File locations

After install, everything lives at:

```
~/claudeclaw-blta/               ← Main system directory
├── agents/                      ← 12 agent configs (CLAUDE.md + agent.yaml per agent)
├── store/claudeclaw.db          ← SQLite database (all memory, tasks, logs)
├── logs/                        ← Per-agent log files
├── .env                         ← Bot tokens and settings (never share this)
└── src/                         ← ClaudeClaw runtime source
```

---

## Support

Contact your system administrator or message the Alex agent directly in Telegram.
