#!/usr/bin/env bash
# add-agent.sh — activate an additional BLTA agent after initial install
#
# Usage:
#   bash scripts/add-agent.sh <agent-id> <bot-token>
#
# Called by the Mission Control Dashboard when a new agent is configured,
# or run directly from the terminal.
#
# Agent IDs:
#   guernsy, anne-christie, angie, facilitator, daniel,
#   participant-intel, fulfillment-coach, alumni, analytics, legal, librarian

set -e

AGENT_ID="$1"
BOT_TOKEN="$2"

if [ -z "$AGENT_ID" ] || [ -z "$BOT_TOKEN" ]; then
  echo ""
  echo "Usage: bash scripts/add-agent.sh <agent-id> <bot-token>"
  echo ""
  echo "Agent IDs:"
  echo "  guernsy, anne-christie, angie, facilitator, daniel,"
  echo "  participant-intel, fulfillment-coach, alumni, analytics, legal, librarian"
  echo ""
  exit 1
fi

# ─── Map agent ID to .env token variable ────────────────────────────────────

get_token_var() {
  case "$1" in
    guernsy)           echo "GUERNSY_BOT_TOKEN" ;;
    anne-christie)     echo "ANNE_CHRISTIE_BOT_TOKEN" ;;
    angie)             echo "ANGIE_BOT_TOKEN" ;;
    facilitator)       echo "FACILITATOR_BOT_TOKEN" ;;
    daniel)            echo "BLTA_DANIEL_BOT_TOKEN" ;;
    participant-intel) echo "PARTICIPANT_INTEL_BOT_TOKEN" ;;
    fulfillment-coach) echo "FULFILLMENT_COACH_BOT_TOKEN" ;;
    alumni)            echo "ALUMNI_BOT_TOKEN" ;;
    analytics)         echo "ANALYTICS_BOT_TOKEN" ;;
    legal)             echo "LEGAL_BOT_TOKEN" ;;
    librarian)         echo "LIBRARIAN_BOT_TOKEN" ;;
    *)                 echo "" ;;
  esac
}

TOKEN_VAR=$(get_token_var "$AGENT_ID")
if [ -z "$TOKEN_VAR" ]; then
  echo "ERROR: Unknown agent ID: $AGENT_ID"
  echo "Valid IDs: guernsy, anne-christie, angie, facilitator, daniel, participant-intel, fulfillment-coach, alumni, analytics, legal, librarian"
  exit 1
fi

# ─── Write token to .env ─────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

set_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" .env && rm -f .env.bak
  else
    echo "${key}=${val}" >> .env
  fi
}

set_env "$TOKEN_VAR" "$BOT_TOKEN"
echo "Token saved: $TOKEN_VAR"

# ─── Start the agent via launchd (macOS) ────────────────────────────────────

OS=$(uname)
if [ "$OS" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/com.blta.agent.${AGENT_ID}.plist"
  if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
    echo "Agent started: $AGENT_ID"
    echo "Check status: launchctl list | grep com.blta.agent.${AGENT_ID}"
  else
    echo "ERROR: Plist not found at $PLIST"
    echo "Run scripts/install.sh first to generate all service plists."
    exit 1
  fi
else
  echo "Non-macOS detected."
  echo "Start the agent manually:"
  echo "  node dist/index.js --agent $AGENT_ID"
fi
