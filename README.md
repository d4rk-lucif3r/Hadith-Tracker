# 📿 Hadith Tracker

A self-hosted Hadith learning system that sends you **10 authentic hadith reminders daily** via Telegram and tracks your progress through a beautiful web dashboard — until you've learned all 47,406+ hadiths from 17 books of the Sunnah.

> Built by [Arsh Anwar](https://github.com/d4rk-lucif3r).  
> May Allah make it a source of benefit for the Ummah. 🤲
---

## App Dashboard

<img width="1866" height="1004" alt="image" src="https://github.com/user-attachments/assets/beb05a0c-aca7-435b-bf34-a8bab1e37831" />

---

## ✨ Features

- 📬 **10 Telegram reminders/day** — one hadith at a time, spread across the day
- 🔁 **Zero repetition, ever** — sequential pointer through 47,406 hadiths
- 📚 **17 authentic books** — Kutub al-Sittah + Musnad Ahmad, Riyad as-Salihin, Mishkat, Nawawi 40, and more
- 🌐 **Web dashboard** — track what you've learned, what's remaining, by book
- 🔍 **Search + filter** — find any hadith by text, narrator, or book
- 🌙 **Arabic + English** — expandable Arabic text on every hadith card
- 📊 **Progress tracking** — per-book progress bars, total stats, days remaining

---

## 📚 Books Included

| Priority | Book | Hadiths |
|----------|------|---------|
| 1 | Sahih al-Bukhari | 7,273 |
| 2 | Sahih Muslim | 7,451 |
| 3 | Jami at-Tirmidhi | 4,052 |
| 4 | Sunan Abi Dawud | 5,274 |
| 5 | Sunan an-Nasa'i | 5,765 |
| 6 | Sunan Ibn Majah | 4,344 |
| 7 | Muwatta Malik | 1,973 |
| 8 | Musnad Ahmad | 1,358 |
| 9 | Riyad as-Salihin | 1,896 |
| 10 | Mishkat al-Masabih | 4,428 |
| 11 | Bulugh al-Maram | 1,764 |
| 12 | Al-Adab Al-Mufrad | 1,304 |
| 13 | Shamail al-Muhammadiyah | 402 |
| 14 | The 40 Hadith of Imam Nawawi | 42 |
| 15 | The 40 Hadith Qudsi | 40 |
| 16 | The 40 Hadith of Shah Waliullah | 40 |

**Total: 47,406 hadiths** — at 10/day that's ~13 years of unique learning.

---

## 🛠️ Prerequisites

- **Node.js** v18+ — [nodejs.org](https://nodejs.org)
- **Telegram Bot** — create one via [@BotFather](https://t.me/BotFather) and get your bot token
- Your **Telegram Chat ID** — send any message to your bot, then visit `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates` to find your `chat_id`
- A Linux/macOS machine (VPS, Raspberry Pi, local server, etc.) — ideally always-on

---

## 🚀 Setup

### 1. Clone the repo

```bash
git clone https://github.com/d4rk-lucif3r/Hadith-Tracker
cd Hadith-Tracker
```

### 2. Configure your environment

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGhIJKlmNoPQRsTUVwxYZ
TELEGRAM_CHAT_ID=526773531
DB_DIR=/absolute/path/to/Hadith-Tracker/data
TZ=America/New_York
```

| Variable | Description |
|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Your bot token from [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_CHAT_ID` | Your personal Telegram chat ID |
| `DB_DIR` | Absolute path to the `data/` directory (defaults to `./data`) |
| `TZ` | Your IANA timezone (e.g. `America/New_York`, `Europe/London`, `Asia/Dubai`) — see [full list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) |

### 3. Download the hadith database

```bash
bash scripts/download-books.sh
```

This downloads all 17 books (~51MB total) from the [hadith-json](https://github.com/AhmedBaset/hadith-json) project and builds the master index.

Expected output:
```
Bukhari: 7273 hadiths
Muslim: 7451 hadiths
...
Total: 47406 hadiths
master-index.json written: 69MB
```

### 4. Install dashboard dependencies

```bash
cd dashboard
npm install
cd ..
```

### 5. Start the dashboard

```bash
bash dashboard/start.sh
```

Dashboard runs at `http://localhost:7777` by default.

### 6. Set up daily reminders

```bash
bash scripts/setup-cron.sh
```

This installs 10 daily cron jobs that fire throughout the day:

🌅 6 AM · ☀️ 8 AM · 🌤️ 10 AM · 🕛 12 PM · 🌞 2 PM · 🌇 4 PM · 🌆 6 PM · 🌃 8 PM · 🌙 9:30 PM · ⭐ 11 PM

> Times are in the timezone you set in `TZ`. Make sure your system timezone matches:
> ```bash
> sudo timedatectl set-timezone America/New_York   # Linux
> ```

Each cron job calls `hadith-reminder.sh`, which picks the next hadith, formats it, and sends it directly to your Telegram via the Bot API — no third-party services required.

---

## 📁 Project Structure

```
Hadith-Tracker/
├── .env.example              # Template — copy to .env and fill in values
├── data/
│   ├── bukhari.json          # Raw book data (downloaded)
│   ├── muslim.json
│   ├── ... (17 books)
│   ├── master-index.json     # Flat index of all 47,406 hadiths
│   └── sent-db.json          # Your progress tracker (pointer + stats)
├── scripts/
│   ├── download-books.sh     # Download + index all books
│   ├── setup-cron.sh         # Install 10 daily system cron jobs
│   └── hadith-reminder.sh    # Called by each cron job — picks next hadith & sends via Telegram
├── dashboard/
│   ├── server.js             # Express API server
│   ├── index.html            # Dashboard UI
│   ├── start.sh              # Start server persistently
│   └── package.json
└── README.md
```

---

## 🔌 API Reference

The dashboard server exposes a simple REST API:

| Endpoint | Description |
|----------|-------------|
| `GET /api/stats` | Overall stats: learned, remaining, per-book breakdown |
| `GET /api/learned?page=1&limit=20&book=&search=` | Paginated learned hadiths |
| `GET /api/remaining?page=1&limit=20&book=` | Paginated remaining hadiths |

---

## 🎯 How It Works

1. **Master index** — all 47,406 hadiths are stored in `data/master-index.json`, ordered by book priority (most authentic first).
2. **Pointer** — `sent-db.json` keeps a sequential pointer. Each reminder advances it by 1 — no randomness, no repeats, ever.
3. **Cron jobs** — 10 system cron jobs fire throughout the day. Each runs `hadith-reminder.sh <slot>`, which reads the next hadith at the pointer, formats it, sends it to Telegram via the Bot API, and saves state.
4. **Dashboard** — reads from the same files in real-time to show your progress.

---

## 📊 Dashboard Preview

- **Stats bar** — Learned / Remaining / Total / Days at 10/day
- **Progress bar** — overall % with gradient fill
- **Book cards** — click any book to filter hadiths; shows per-book progress
- **Learned / Remaining tabs** — switch between what you've seen and what's next
- **Expandable cards** — click any hadith to expand full text + Arabic
- **Search** — full-text search across learned or remaining hadiths

---

## 🔧 Customization

**Change reminder times** — edit the cron expressions in `scripts/setup-cron.sh`, then re-run it.

**Change number of daily reminders** — add/remove slots in `setup-cron.sh`. Each calls `hadith-reminder.sh` with its slot number.

**Change book order** — edit the `books` array in `scripts/download-books.sh` to reorder priority.

**Change timezone** — update `TZ` in your `.env` file and re-run `setup-cron.sh`.

---

## 📖 Data Source

Hadith data sourced from [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json), which was scraped from [sunnah.com](https://sunnah.com). All credit for the data goes to the scholars and teams behind Sunnah.com.

---

## 🤲 Dua

*"Seeking knowledge is an obligation upon every Muslim."*  
— Sunan Ibn Majah, Hadith #224, narrated by Anas ibn Malik (RA)

May Allah grant us the ability to act upon what we learn. Ameen.

---

## 📄 License

MIT — use it, share it, build upon it. Barakallahu feekum.
