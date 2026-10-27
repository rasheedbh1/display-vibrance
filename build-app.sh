#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
OUT="$ROOT/.build/Display Vibrance.app"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache"
export XDG_CACHE_HOME="$ROOT/.build/cache"
swift build -c release --package-path "$ROOT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$ROOT/.build/release/DisplayVibrance" "$OUT/Contents/MacOS/DisplayVibrance"
cp "$ROOT/Resources/Info.plist" "$OUT/Contents/Info.plist"
codesign --force --deep --sign - "$OUT"
ditto -c -k --keepParent "$OUT" "$ROOT/.build/Display-Vibrance.zip"
echo "$OUT"
