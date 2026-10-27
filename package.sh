#!/bin/bash
# 打包：构建 动薪.app + 源码 + 文档，输出到 workspace/outputs/动薪
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$ROOT/../../outputs/动薪}"
APP_NAME=动薪
if [ "${SKIP_BUILD:-0}" != "1" ]; then APP_NAME="$APP_NAME" "$ROOT/build.sh"; fi
rm -rf "$DEST"
mkdir -p "$DEST/源码"
cp -R "${BUILD_DIR:-$ROOT/build}/$APP_NAME.app" "$DEST/"
cp -R "$ROOT/Sources" "$DEST/源码/"
cp "$ROOT/build.sh" "$ROOT/package.sh" "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/Info.plist" "$DEST/源码/"
cp -R "$ROOT/assets" "$DEST/源码/"
cp "$ROOT/tools_make_icon.py" "$DEST/源码/"
cp "$ROOT/README.md" "$DEST/README.md"
mkdir -p "$DEST/screenshots"
cp "$ROOT"/screenshots/*.png "$DEST/screenshots/" 2>/dev/null || true
# 去掉 quarantine，方便直接打开
xattr -dr com.apple.quarantine "$DEST/$APP_NAME.app" 2>/dev/null || true
cd "$DEST" && zip -qry "DongXin-macos-$(date +%Y%m%d).zip" "$APP_NAME.app"
echo "packaged: $DEST"
du -sh "$DEST" "$DEST/$APP_NAME.app"
