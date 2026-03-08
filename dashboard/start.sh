#!/bin/bash
# Start the hadith dashboard server (persistent)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$SCRIPT_DIR"
nohup node server.js >> "$SCRIPT_DIR/dashboard.log" 2>&1 &
echo $! > "$SCRIPT_DIR/dashboard.pid"
echo "Dashboard started, PID: $(cat "$SCRIPT_DIR/dashboard.pid")"
echo "Access at: http://localhost:7777"
