const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 7777;

// Load .env from project root if present
const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) {
  const lines = fs.readFileSync(envFile, 'utf8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const val = trimmed.slice(eqIdx + 1).trim();
    if (!process.env[key]) process.env[key] = val;
  }
}

const DB_DIR = process.env.DB_DIR || path.join(__dirname, '..', 'data');

app.use(express.json());

// Cache master index in memory
let masterIndex = null;
function getMaster() {
  if (!masterIndex) {
    console.log('Loading master index...');
    masterIndex = JSON.parse(fs.readFileSync(path.join(DB_DIR, 'master-index.json'), 'utf8'));
    console.log('Loaded', masterIndex.length, 'hadiths');
  }
  return masterIndex;
}

function getSentDb() {
  try {
    return JSON.parse(fs.readFileSync(path.join(DB_DIR, 'sent-db.json'), 'utf8'));
  } catch(e) {
    return { pointer: 0, totalSent: 0, learnedGids: [] };
  }
}

function saveSentDb(db) {
  fs.writeFileSync(path.join(DB_DIR, 'sent-db.json'), JSON.stringify(db, null, 2));
}

function getLearnedSet(db) {
  // Learned = pointer-based (auto reminders) + manually marked
  const master = getMaster();
  const set = new Set();
  // Everything up to pointer is learned from reminders
  for (let i = 0; i < (db.pointer || 0); i++) {
    set.add(master[i].gid);
  }
  // Plus any manually marked
  for (const gid of (db.learnedGids || [])) {
    set.add(gid);
  }
  // Minus any manually unmarked
  for (const gid of (db.unlearnedGids || [])) {
    set.delete(gid);
  }
  return set;
}

// API: stats
app.get('/api/stats', (req, res) => {
  const master = getMaster();
  const db = getSentDb();
  const learnedSet = getLearnedSet(db);
  const total = master.length;
  const learned = learnedSet.size;
  const remaining = total - learned;
  const pct = ((learned / total) * 100).toFixed(2);

  const bookStats = {};
  for (const h of master) {
    if (!bookStats[h.book]) bookStats[h.book] = { total: 0, learned: 0, short: h.short };
    bookStats[h.book].total++;
    if (learnedSet.has(h.gid)) bookStats[h.book].learned++;
  }

  res.json({
    total, learned, remaining, pct,
    lastSentAt: db.lastSentAt,
    totalSent: db.totalSent || 0,
    daysAt10: Math.round(remaining / 10),
    bookStats
  });
});

// API: learned hadiths (paginated, full text)
app.get('/api/learned', (req, res) => {
  const master = getMaster();
  const db = getSentDb();
  const learnedSet = getLearnedSet(db);
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;
  const book = req.query.book || '';
  const search = (req.query.search || '').toLowerCase();

  let items = master.filter(h => learnedSet.has(h.gid));
  if (book) items = items.filter(h => h.book === book || h.short === book);
  if (search) items = items.filter(h =>
    h.text.toLowerCase().includes(search) ||
    (h.narrator && h.narrator.toLowerCase().includes(search))
  );

  // Most recent first (reverse of order learned = reverse of index order)
  items = items.slice().reverse();

  const total = items.length;
  const pages = Math.ceil(total / limit) || 1;
  const start = (page - 1) * limit;
  const data = items.slice(start, start + limit).map(h => ({
    gid: h.gid, book: h.book, short: h.short, id: h.id,
    narrator: h.narrator, text: h.text, arabic: h.arabic  // full text, no truncation
  }));

  res.json({ total, page, pages, limit, data });
});

// API: remaining hadiths (paginated, full text)
app.get('/api/remaining', (req, res) => {
  const master = getMaster();
  const db = getSentDb();
  const learnedSet = getLearnedSet(db);
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;
  const book = req.query.book || '';
  const search = (req.query.search || '').toLowerCase();

  let items = master.filter(h => !learnedSet.has(h.gid));
  if (book) items = items.filter(h => h.book === book || h.short === book);
  if (search) items = items.filter(h =>
    h.text.toLowerCase().includes(search) ||
    (h.narrator && h.narrator.toLowerCase().includes(search))
  );

  const total = items.length;
  const pages = Math.ceil(total / limit) || 1;
  const start = (page - 1) * limit;
  const data = items.slice(start, start + limit).map(h => ({
    gid: h.gid, book: h.book, short: h.short, id: h.id,
    narrator: h.narrator, text: h.text, arabic: h.arabic  // full text
  }));

  res.json({ total, page, pages, limit, data });
});

// API: mark / unmark a hadith
app.post('/api/mark', (req, res) => {
  const { gid, learned } = req.body;
  if (gid === undefined || learned === undefined) {
    return res.status(400).json({ error: 'gid and learned required' });
  }

  const db = getSentDb();
  if (!db.learnedGids) db.learnedGids = [];
  if (!db.unlearnedGids) db.unlearnedGids = [];

  if (learned) {
    // Add to learned, remove from unlearned
    if (!db.learnedGids.includes(gid)) db.learnedGids.push(gid);
    db.unlearnedGids = db.unlearnedGids.filter(g => g !== gid);
  } else {
    // Add to unlearned, remove from learned
    if (!db.unlearnedGids.includes(gid)) db.unlearnedGids.push(gid);
    db.learnedGids = db.learnedGids.filter(g => g !== gid);
  }

  saveSentDb(db);
  res.json({ ok: true, gid, learned });
});

app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index.html')));

getMaster();
app.listen(PORT, '0.0.0.0', () => console.log(`Hadith Dashboard running at http://localhost:${PORT}`));
