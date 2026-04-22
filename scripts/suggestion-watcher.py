#!/usr/bin/env python3
"""
suggestion-watcher.py — BLTA AI Operating System
Delivers proactive agent suggestions to Eunos via Alex's Telegram bot.
Runs every 2 minutes via launchd (called by suggestion-watcher.sh).
"""
import os, sqlite3, subprocess, re, time, html

TOKEN   = os.environ.get('SUGGESTION_TOKEN', '')
CHAT_ID = os.environ.get('SUGGESTION_CHAT_ID', '')
DB_PATH = os.environ.get('SUGGESTION_DB', '')

AGENT_DISPLAY = {
    'alex':              'Alex',
    'guernsy':           'Guernsy (Ops)',
    'anne-christie':     'Anne Christie (Finance)',
    'angie':             'Angie (Marketing)',
    'facilitator':       'Facilitator',
    'daniel':            'Daniel (Dev)',
    'participant-intel': 'Participant Intel',
    'fulfillment-coach': 'Fulfillment Coach',
    'alumni':            'Alumni',
    'analytics':         'Analytics',
    'legal':             'Legal',
    'librarian':         'Librarian',
}

def display(agent_id: str) -> str:
    return AGENT_DISPLAY.get((agent_id or '').lower(), (agent_id or 'Agent').capitalize())

def clean(text: str, limit: int = 500) -> str:
    text = re.sub(r'<[^>]+>', '', text)
    text = html.unescape(text).strip()
    if len(text) > limit:
        text = text[:limit] + '...'
    return text

def send_telegram(msg: str) -> bool:
    r = subprocess.run(
        ['curl', '-s', '-X', 'POST',
         f'https://api.telegram.org/bot{TOKEN}/sendMessage',
         '--data-urlencode', f'chat_id={CHAT_ID}',
         '--data-urlencode', f'text={msg}',
         '--data-urlencode', 'parse_mode=HTML'],
        capture_output=True, text=True, timeout=15
    )
    return r.returncode == 0

def main():
    if not all([TOKEN, CHAT_ID, DB_PATH]):
        print('suggestion-watcher: missing env vars', flush=True)
        return

    if not os.path.exists(DB_PATH):
        print('suggestion-watcher: DB not found — system not installed yet', flush=True)
        return

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    now = int(time.time())
    delivered = 0

    try:
        rows = conn.execute("""
            SELECT id, from_agent, domain, content, context
            FROM proactive_suggestions
            WHERE status = 'pending'
            ORDER BY created_at ASC
            LIMIT 10
        """).fetchall()

        for row in rows:
            agent   = row['from_agent']
            content = (row['content'] or '').strip()
            context = (row['context'] or '').strip()
            if not content:
                continue

            name     = display(agent)
            body     = clean(content)
            ctx_line = f"\n<i>re: {context}</i>" if context else ''
            msg      = f"💡 <b>{name}:</b>{ctx_line}\n\n{body}"

            if send_telegram(msg):
                conn.execute(
                    "UPDATE proactive_suggestions SET status='delivered', delivered_at=? WHERE id=?",
                    (now, row['id'])
                )
                conn.commit()
                delivered += 1
                print(f"Delivered suggestion from {agent}", flush=True)

    except Exception as e:
        print(f"Error: {e}", flush=True)
    finally:
        conn.close()

    if delivered == 0:
        print('No new suggestions.', flush=True)

if __name__ == '__main__':
    main()
