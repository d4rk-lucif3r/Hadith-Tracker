#!/bin/bash
# Download all 17 hadith books and build the master index

set -e

# Find project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

DIR="${DB_DIR:-$PROJECT_ROOT/data}"
mkdir -p "$DIR"
BASE="https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/by_book"

echo "📥 Downloading 17 hadith books to $DIR ..."

curl -s "$BASE/the_9_books/bukhari.json"    -o "$DIR/bukhari.json" &
curl -s "$BASE/the_9_books/muslim.json"     -o "$DIR/muslim.json" &
curl -s "$BASE/the_9_books/tirmidhi.json"   -o "$DIR/tirmidhi.json" &
curl -s "$BASE/the_9_books/abudawud.json"   -o "$DIR/abudawud.json" &
curl -s "$BASE/the_9_books/nasai.json"      -o "$DIR/nasai.json" &
curl -s "$BASE/the_9_books/ibnmajah.json"   -o "$DIR/ibnmajah.json" &
curl -s "$BASE/the_9_books/malik.json"      -o "$DIR/malik.json" &
curl -s "$BASE/the_9_books/ahmed.json"      -o "$DIR/ahmed.json" &
curl -s "$BASE/the_9_books/darimi.json"     -o "$DIR/darimi.json" &
curl -s "$BASE/other_books/riyad_assalihin.json"      -o "$DIR/riyad.json" &
curl -s "$BASE/other_books/mishkat_almasabih.json"    -o "$DIR/mishkat.json" &
curl -s "$BASE/other_books/bulugh_almaram.json"       -o "$DIR/bulugh.json" &
curl -s "$BASE/other_books/aladab_almufrad.json"      -o "$DIR/aladab.json" &
curl -s "$BASE/other_books/shamail_muhammadiyah.json" -o "$DIR/shamail.json" &
curl -s "$BASE/forties/nawawi40.json"         -o "$DIR/nawawi40.json" &
curl -s "$BASE/forties/qudsi40.json"          -o "$DIR/qudsi40.json" &
curl -s "$BASE/forties/shahwaliullah40.json"  -o "$DIR/shahwali40.json" &

wait
echo "✅ All books downloaded."

echo "🔨 Building master index..."
node -e "
const fs = require('fs');
const dir = '$DIR/';
const books = [
  { file: 'bukhari.json',   name: 'Sahih al-Bukhari',               short: 'Bukhari',      priority: 1 },
  { file: 'muslim.json',    name: 'Sahih Muslim',                   short: 'Muslim',       priority: 2 },
  { file: 'tirmidhi.json',  name: 'Jami at-Tirmidhi',               short: 'Tirmidhi',     priority: 3 },
  { file: 'abudawud.json',  name: 'Sunan Abi Dawud',                short: 'Abu Dawud',    priority: 4 },
  { file: 'nasai.json',     name: \"Sunan an-Nasa'i\",               short: \"Nasa'i\",      priority: 5 },
  { file: 'ibnmajah.json',  name: 'Sunan Ibn Majah',                short: 'Ibn Majah',    priority: 6 },
  { file: 'malik.json',     name: 'Muwatta Malik',                  short: 'Malik',        priority: 7 },
  { file: 'ahmed.json',     name: 'Musnad Ahmad',                   short: 'Ahmad',        priority: 8 },
  { file: 'darimi.json',    name: 'Sunan ad-Darimi',                short: 'Darimi',       priority: 9 },
  { file: 'riyad.json',     name: 'Riyad as-Salihin',               short: 'Riyad',        priority: 10 },
  { file: 'mishkat.json',   name: 'Mishkat al-Masabih',             short: 'Mishkat',      priority: 11 },
  { file: 'bulugh.json',    name: 'Bulugh al-Maram',                short: 'Bulugh',       priority: 12 },
  { file: 'aladab.json',    name: 'Al-Adab Al-Mufrad',              short: 'Al-Adab',      priority: 13 },
  { file: 'shamail.json',   name: 'Shamail al-Muhammadiyah',        short: 'Shamail',      priority: 14 },
  { file: 'nawawi40.json',  name: 'The 40 Hadith of Imam Nawawi',   short: 'Nawawi 40',    priority: 15 },
  { file: 'qudsi40.json',   name: 'The 40 Hadith Qudsi',            short: 'Qudsi 40',     priority: 16 },
  { file: 'shahwali40.json',name: 'The 40 Hadith of Shah Waliullah',short: 'Shah Wali 40', priority: 17 },
];
let index = [], gid = 0;
for (const book of books) {
  const raw = JSON.parse(fs.readFileSync(dir + book.file, 'utf8'));
  const hadiths = raw.hadiths || [];
  let count = 0;
  for (const h of hadiths) {
    const engText = h.english && h.english.text ? h.english.text.trim() : '';
    if (!engText || engText.length < 15) continue;
    index.push({ gid: gid++, bookId: h.bookId, id: h.id, book: book.name, short: book.short,
      priority: book.priority, arabic: h.arabic ? h.arabic.trim() : '',
      narrator: h.english && h.english.narrator ? h.english.narrator.trim() : '', text: engText });
    count++;
  }
  console.log(book.short + ': ' + count + ' hadiths');
}
console.log('\nTotal:', index.length, 'hadiths');
fs.writeFileSync(dir + 'master-index.json', JSON.stringify(index));
if (!fs.existsSync(dir + 'sent-db.json')) {
  fs.writeFileSync(dir + 'sent-db.json', JSON.stringify({ pointer: 0, totalSent: 0, lastSentAt: null }));
  console.log('sent-db.json initialized');
}
console.log('✅ Done! master-index.json ready.');
"
