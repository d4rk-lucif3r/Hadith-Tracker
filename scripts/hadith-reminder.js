#!/usr/bin/env node
// hadith-reminder.js <slot 1-10>
// Cross-platform reminder script (used by Windows Task Scheduler)
// Reads config from .env in project root, sends hadith via Telegram Bot API

const fs    = require('fs');
const https = require('https');
const path  = require('path');

const slot = parseInt(process.argv[2] || '1');

// Find project root (parent of scripts/)
const scriptDir   = __dirname;
const projectRoot = path.dirname(scriptDir);
const envFile     = path.join(projectRoot, '.env');

// Parse .env
const env = {};
if (fs.existsSync(envFile)) {
  fs.readFileSync(envFile, 'utf8').split('\n').forEach(line => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) return;
    env[trimmed.slice(0, eqIdx).trim()] = trimmed.slice(eqIdx + 1).trim();
  });
}

const botToken = env.TELEGRAM_BOT_TOKEN || process.env.TELEGRAM_BOT_TOKEN;
const chatId   = env.TELEGRAM_CHAT_ID   || process.env.TELEGRAM_CHAT_ID;
const dbDir    = env.DB_DIR             || process.env.DB_DIR || path.join(projectRoot, 'data');

if (!botToken || botToken === 'your_bot_token_here') {
  console.error('❌ TELEGRAM_BOT_TOKEN is not set in .env');
  process.exit(1);
}
if (!chatId || chatId === 'your_chat_id_here') {
  console.error('❌ TELEGRAM_CHAT_ID is not set in .env');
  process.exit(1);
}

const masterFile = path.join(dbDir, 'master-index.json');
const sentFile   = path.join(dbDir, 'sent-db.json');

let db = { pointer: 0, totalSent: 0, learnedGids: [], unlearnedGids: [] };
try { db = JSON.parse(fs.readFileSync(sentFile, 'utf8')); } catch(e) {}

const master = JSON.parse(fs.readFileSync(masterFile, 'utf8'));
const total  = master.length;

// Build learned set: pointer range + manual marks - manual unmarks
const learnedSet = new Set();
for (let i = 0; i < (db.pointer || 0); i++) learnedSet.add(master[i].gid);
for (const g of (db.learnedGids   || [])) learnedSet.add(g);
for (const g of (db.unlearnedGids || [])) learnedSet.delete(g);

// Walk forward from pointer, skipping anything already learned
let idx     = db.pointer || 0;
let skipped = 0;
while (skipped < total) {
  if (idx >= total) idx = 0;
  if (!learnedSet.has(master[idx].gid)) break;
  idx++;
  skipped++;
}

if (skipped >= total) {
  sendTelegram('🎉 *MashaAllah!*\n\nYou have learned all ' + total.toLocaleString() + ' hadiths!\n\nMay Allah grant you the ability to act upon every single one. Ameen. 🤲');
  return;
}

const h = master[idx];

// Advance pointer ONLY
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

sendTelegram(msg);

function sendTelegram(text) {
  const body = JSON.stringify({ chat_id: chatId, text, parse_mode: 'Markdown' });
  const options = {
    hostname: 'api.telegram.org',
    path: '/bot' + botToken + '/sendMessage',
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
