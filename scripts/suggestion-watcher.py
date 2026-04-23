#!/usr/bin/env python3
"""
suggestion-watcher.py — BLTA AI Operating System
Batches all pending agent chimes and delivers them to Eunos via Alex's Telegram bot.
Alex presents them as a single synthesized briefing — not individual agent pings.
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
    'scout':             'Scout (Research)',
}

def display(agent_id: str) -> str:
    return AGENT_DISPLAY.get((agent_id or '').lower(), (agent_id or 'Agent').capitalize())

def clean(text: str, limit: int = 400) -> str:
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

    try:
        rows = conn.execute("""
            SELECT id, from_agent, domain, content, context,
                   COALESCE(context_key, context, 'general') as context_key,
                   COALESCE(chime_seq, 1) as chime_seq
            FROM proactive_suggestions
            WHERE status = 'pending'
            ORDER BY created_at ASC
            LIMIT 15
        """).fetchall()

        if not rows:
            print('No new suggestions.', flush=True)
            return

        # Build a single batched message from Alex's perspective
        lines = ["<b>Alex:</b> Here's what the team is flagging:\n"]

        valid_rows = []
        for row in rows:
            content = (row['content'] or '').strip()
            if not content:
                continue

            agent    = row['from_agent']
            context  = (row['context'] or '').strip()
            seq      = row['chime_seq'] or 1
            name     = display(agent)
            body     = clean(content)
            ctx_line = f" <i>re: {context}</i>" if context else ''
            seq_note = f" [{seq}/3]"

            lines.append(f"• <b>{name}{seq_note}:</b>{ctx_line}\n{body}\n")
            valid_rows.append(row)

        if not valid_rows:
            print('No valid suggestions to deliver.', flush=True)
            return

        # Check if any agent hit the 3-chime cap
        try:
            capped = conn.execute("""
                SELECT agent_id, context_key
                FROM agent_chime_state
                WHERE paused = 1
            """).fetchall()

            if capped:
                cap_names = ', '.join(display(r['agent_id']) for r in capped)
                lines.append(f"\n<i>{cap_names} hit the 3-chime limit. Tell me if you want them to keep going.</i>")
        except Exception:
            pass  # table may not exist yet if migration hasn't run

        msg = '\n'.join(lines)

        if send_telegram(msg):
            ids = [row['id'] for row in valid_rows]
            placeholders = ','.join('?' for _ in ids)
            conn.execute(
                f"UPDATE proactive_suggestions SET status='delivered', delivered_at=? WHERE id IN ({placeholders})",
                [now] + ids
            )
            conn.commit()
            print(f"Delivered {len(valid_rows)} suggestion(s) in one Alex briefing.", flush=True)
        else:
            print("Failed to send Telegram message.", flush=True)

    except Exception as e:
        print(f"Error: {e}", flush=True)
    finally:
        conn.close()

if __name__ == '__main__':
    main()
