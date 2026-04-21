# Breakthrough Leadership Transformation Academy — AI Operating System

Powered by [ClaudeClaw](https://github.com/alexverneret/claudeclaw). A 12-agent AI system built for BLTA to automate operations, finance, marketing, facilitation, participant engagement, and knowledge management.

---

## Agents

### Core (Deploy Day 1)

| Agent | Role | Model |
|-------|------|-------|
| Alex | System Architect & Orchestrator | claude-opus-4-6 |
| Guernsy | Operations — registration, logistics, CRM | claude-sonnet-4-6 |
| Anne Christie | Finance — cohort economics, invoicing, cash flow | claude-sonnet-4-6 |
| Angie | Marketing — campaigns, social, lead gen | claude-sonnet-4-6 |
| Facilitator | Program delivery — serves Eunos & Saurel | claude-sonnet-4-6 |
| Daniel | Developer — infrastructure, tools, integrations | claude-sonnet-4-6 |

### Extended (Deploy Day 1)

| Agent | Role | Model |
|-------|------|-------|
| Participant Intel | Engagement tracking, re-enrollment signals | claude-haiku-4-5 |
| Fulfillment Coach | Pre/post-seminar participant preparation | claude-haiku-4-5 |
| Alumni | Community, re-engagement, testimonials | claude-haiku-4-5 |
| Analytics | Cross-domain performance reporting | claude-sonnet-4-6 |
| Legal | Contracts, waivers, compliance drafting | claude-sonnet-4-6 |
| Librarian | Google Drive indexing and knowledge retrieval | claude-haiku-4-5 |

---

## Prerequisites

- macOS 12+ or Ubuntu 20+
- Node.js 20+
- Git
- An Anthropic API key — [console.anthropic.com](https://console.anthropic.com)
- 12 Telegram bots — create each via [@BotFather](https://t.me/BotFather)
- Your Telegram user ID — get it from [@userinfobot](https://t.me/userinfobot)
- Google Drive MCP access (optional but recommended for Librarian, Legal, Facilitator, Alex)

---

## Installation

### 1. Clone this repo

```bash
git clone https://github.com/alexverneret/claudeclaw-breakthrough-leadership-academy.git
cd claudeclaw-breakthrough-leadership-academy
```

### 2. Run the installer

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

The installer will:
- Verify all prerequisites are installed
- Copy `.env.example` to `.env` and prompt for your Anthropic API key
- Walk you through entering each agent's Telegram bot token
- Copy all `agent.yaml.example` files to `agent.yaml`
- Run `npm install` and build the project
- Register all 12 agents as background services

### 3. Verify agents are running

```bash
npm run status
```

---

## Monthly Cost Estimate

| Tier | Cost |
|------|------|
| Core 6 agents (typical usage) | ~$60–90/mo |
| All 12 agents (full load) | ~$100–150/mo |
| Google Drive MCP (included in Anthropic API) | $0 extra |

Based on claude-sonnet-4-6 at ~$3/M input tokens. Alex (Opus) adds ~$15–30/mo depending on orchestration volume.

---

## Support

Contact your system administrator or raise an issue on this repo.
