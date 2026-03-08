#!/bin/bash
# hadith-reminder.sh <slot 1-10>
# CLEAN MODEL:
#   pointer     = tracks sequential auto-delivery (only this script touches it)
#   learnedGids = ONLY manual marks from dashboard (never touched here)
# Learned set  = {gids 0..pointer-1} + learnedGids - unlearnedGids
# Script skips any candidate already in learnedSet, then advances pointer.

SLOT=${1:-1}

# Find project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env file not found at $PROJECT_ROOT/.env"
  exit 1
fi

# Load .env
set -a
source "$ENV_FILE"
set +a

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ "$TELEGRAM_BOT_TOKEN" = "your_bot_token_here" ]; then
  echo "❌ TELEGRAM_BOT_TOKEN is not set in .env"
  exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ] || [ "$TELEGRAM_CHAT_ID" = "your_chat_id_here" ]; then
  echo "❌ TELEGRAM_CHAT_ID is not set in .env"
  exit 1
fi

DB_DIR="${DB_DIR:-$PROJECT_ROOT/data}"

node -e "
const fs   = require('fs');
const https = require('https');
const slot  = parseInt('$SLOT');
const botToken = process.env.TELEGRAM_BOT_TOKEN || '$TELEGRAM_BOT_TOKEN';
const chatId   = process.env.TELEGRAM_CHAT_ID   || '$TELEGRAM_CHAT_ID';
const masterFile = '$DB_DIR/master-index.json';
const sentFile   = '$DB_DIR/sent-db.json';

let db = { pointer: 0, totalSent: 0, learnedGids: [], unlearnedGids: [] };
try { db = JSON.parse(fs.readFileSync(sentFile, 'utf8')); } catch(e) {}

const master = JSON.parse(fs.readFileSync(masterFile, 'utf8'));
const total = master.length;

// Build learned set: pointer range + manual marks - manual unmarks
const learnedSet = new Set();
for (let i = 0; i < (db.pointer || 0); i++) learnedSet.add(master[i].gid);
for (const g of (db.learnedGids   || [])) learnedSet.add(g);
for (const g of (db.unlearnedGids || [])) learnedSet.delete(g);

// Walk forward from pointer, skipping anything already learned
let idx = db.pointer || 0;
let skipped = 0;
while (skipped < total) {
  if (idx >= total) idx = 0;
  if (!learnedSet.has(master[idx].gid)) break;
  idx++;
  skipped++;
}

if (skipped >= total) {
  sendTelegram(botToken, chatId, '🎉 *MashaAllah!*\n\nYou have learned all ' + total.toLocaleString() + ' hadiths!\n\nMay Allah grant you the ability to act upon every single one. Ameen. 🤲');
  process.exit(0);
}

const h = master[idx];

// Advance pointer ONLY (never touch learnedGids — that's the dashboard's job)
db.pointer    = idx + 1;
db.totalSent  = (db.totalSent || 0) + 1;
db.lastSentAt = new Date().toISOString();
db.lastGid    = h.gid;
if (!db.learnedGids)   db.learnedGids   = [];
if (!db.unlearnedGids) db.unlearnedGids = [];

fs.writeFileSync(sentFile, JSON.stringify(db, null, 2));

const remaining = total - learnedSet.size - 1;

const icons = ['🌅','☀️','🌤️','🕛','🌞','🌇','🌆','🌃','🌙','⭐'];
const icon  = icons[slot - 1] || '📿';

let msg = icon + ' *Hadith ' + db.totalSent + ' of ' + total.toLocaleString() + '*\n';
msg += '━━━━━━━━━━━━━━━━━━━━━━\n';
msg += '📖 *' + h.book + ' — Hadith #' + h.id + '*\n\n';

if (h.arabic) {
  let ar = h.arabic.trim();
  if (ar.length > 500) ar = ar.slice(0, 500) + '...';
  msg += ar + '\n\n';
}

msg += '💬 ' + h.text.trim() + '\n\n';

if (h.narrator) msg += '📜 *' + h.narrator.trim() + '*\n\n';

msg += '─────────────────────\n';
msg += '📊 ' + db.totalSent.toLocaleString() + ' learned • ' + Math.max(remaining, 0).toLocaleString() + ' remaining\n';
msg += '🤲 _Reflect. Remember. Act._';

sendTelegram(botToken, chatId, msg);

function sendTelegram(token, chat, text) {
  const body = JSON.stringify({ chat_id: chat, text: text, parse_mode: 'Markdown' });
  const options = {
    hostname: 'api.telegram.org',
    path: '/bot' + token + '/sendMessage',
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
  };
  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      const parsed = JSON.parse(data);
      if (!parsed.ok) {
        console.error('Telegram error:', parsed.description);
        process.exit(1);
      } else {
        console.log('✅ Hadith sent (slot ' + slot + ')');
      }
    });
  });
  req.on('error', (e) => { console.error('Request error:', e.message); process.exit(1); });
  req.write(body);
  req.end();
}
"
