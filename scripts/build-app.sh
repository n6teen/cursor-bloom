#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product CursorBloom

APP="${1:-$HOME/Applications/Bloom.app}"
mkdir -p "$(dirname "$APP")"

if pgrep -x CursorBloom >/dev/null; then
  pkill -x CursorBloom || true
  sleep 0.4
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/CursorBloom" "$APP/Contents/MacOS/CursorBloom"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Support/AppIcon.icns" ]]; then
  cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
if [[ -f "$ROOT/Support/cowboy-dog.jpg" ]]; then
  cp "$ROOT/Support/cowboy-dog.jpg" "$APP/Contents/Resources/cowboy-dog.jpg"
fi
if [[ -f "$ROOT/Support/app-icon.png" ]]; then
  cp "$ROOT/Support/app-icon.png" "$APP/Contents/Resources/app-icon.png"
fi
chmod +x "$APP/Contents/MacOS/CursorBloom"
codesign --force --sign - "$APP" >/dev/null
echo "$APP"
