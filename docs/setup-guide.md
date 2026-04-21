# BLTA AI System — Setup Guide

This guide walks you through setting up the BLTA AI Operating System from scratch. No technical background required.

---

## What You're Setting Up

You're deploying 12 AI agents, each accessible via their own Telegram bot. Each agent has a specific role in running BLTA's operations. Once set up, they run 24/7 in the background on your Mac or server.

---

## Step 1: Create Your Telegram Bots

You need 12 Telegram bots — one for each agent.

1. Open Telegram and search for **@BotFather**
2. Send the message `/newbot`
3. Follow the prompts — give it a name (e.g., "BLTA Alex") and a username (e.g., `blta_alex_bot`)
4. BotFather will give you a **bot token** — copy and save it
5. Repeat for all 12 agents:
   - Alex (Orchestrator)
   - Guernsy (Operations)
   - Anne Christie (Finance)
   - Angie (Marketing)
   - Facilitator (Eunos & Saurel)
   - Daniel (Developer)
   - Participant Intel
   - Fulfillment Coach
   - Alumni
   - Analytics
   - Legal
   - Librarian

---

## Step 2: Get Your Telegram User ID

1. Open Telegram and search for **@userinfobot**
2. Send any message to it
3. It will reply with your user ID — copy it

---

## Step 3: Get Your Anthropic API Key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign in or create an account
3. Go to **API Keys** and create a new key
4. Copy it — you'll enter it during installation

---

## Step 4: Run the Installer

Open Terminal and run:

```bash
cd claudeclaw-breakthrough-leadership-academy
chmod +x scripts/install.sh
./scripts/install.sh
```

The installer will ask you for:
- Your Anthropic API key
- Your Telegram user ID
- Each agent's bot token
- Eunos and Saurel's Telegram user IDs (for the Facilitator agent)

Follow the prompts. It takes about 5 minutes.

---

## Step 5: Start the Agents

```bash
npm run start:all
```

---

## Step 6: Test Each Agent

Open Telegram, find each bot, and send it a message. It should respond within a few seconds.

---

## Troubleshooting

**Agent not responding:**
- Check it's running: `npm run status`
- Check logs: `npm run logs -- --agent alex`
- Verify the bot token in `agents/alex/agent.yaml`

**"Unauthorized" error:**
- Your Telegram user ID isn't in the agent's `allowed_users` list
- Edit `agents/[agent]/agent.yaml` and add your ID

**Build fails:**
- Make sure Node.js 20+ is installed: `node -v`
- Run `npm install` again, then `npm run build`

---

## Getting Help

Raise an issue on the GitHub repo or contact your system administrator.
