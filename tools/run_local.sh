#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
cp web/field-backdrop.jpg build/web/field-backdrop.jpg
cp assets/Fredoka-Semibold.ttf assets/ZenMaruGothic-Bold.ttf build/web/
godot --headless --path . -- --server &
room_pid=$!
python3 -m http.server 8087 --bind 127.0.0.1 --directory build/web &
web_pid=$!
trap 'kill "$room_pid" "$web_pid" 2>/dev/null || true' EXIT INT TERM
printf 'Open http://localhost:8087\n'
wait
