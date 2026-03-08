#!/bin/bash
# Setup 10 daily hadith reminder cron jobs using system cron + Telegram bot
# Reads config from .env file in the project root
# Usage: bash setup-cron.sh

set -e

# Find project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env file not found at $PROJECT_ROOT/.env"
  echo "   Copy .env.example to .env and fill in your values."
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

if [ -z "$TZ" ]; then
  echo "❌ TZ (timezone) is not set in .env"
  echo "   Example: TZ=America/New_York"
  exit 1
fi

REMINDER_SCRIPT="$SCRIPT_DIR/hadith-reminder.sh"

# 10 daily slots: [slot] [cron_min] [cron_hour] [label]
# Times are in the timezone set in TZ (cron uses local system time)
SLOTS=(
  "1  0  6  6:00 AM"
  "2  0  8  8:00 AM"
  "3  0  10 10:00 AM"
  "4  0  12 12:00 PM"
  "5  0  14 2:00 PM"
  "6  0  16 4:00 PM"
  "7  0  18 6:00 PM"
  "8  0  20 8:00 PM"
  "9  30 21 9:30 PM"
  "10 0  23 11:00 PM"
)

echo "📅 Setting up 10 daily hadith reminder cron jobs..."
echo "   Telegram Chat ID: $TELEGRAM_CHAT_ID"
echo "   Timezone: $TZ (make sure your system timezone matches)"
echo "   Reminder script: $REMINDER_SCRIPT"
echo ""

# Build crontab entries (remove old hadith-reminder entries first)
TMPFILE=$(mktemp)
crontab -l 2>/dev/null | grep -v "hadith-reminder.sh" > "$TMPFILE" || true

for entry in "${SLOTS[@]}"; do
  read -r SLOT MIN HOUR LABEL <<< "$entry"
  echo "$MIN $HOUR * * * bash $REMINDER_SCRIPT $SLOT" >> "$TMPFILE"
  echo "  ✅ Slot $SLOT — $LABEL"
done

crontab "$TMPFILE"
rm "$TMPFILE"

echo ""
echo "✅ All 10 cron jobs installed!"
echo "Run 'crontab -l' to verify."
echo ""
echo "⚠️  Make sure your system timezone is set to: $TZ"
echo "   On Linux: sudo timedatectl set-timezone $TZ"
