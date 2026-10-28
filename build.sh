#!/bin/bash
# 薪跳 · 构建脚本（绕过 swiftc driver：本机 driver 在受限环境下会 SIGTRAP，
# 直接用 swift-frontend 编译 + clang 链接）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"; OUT="${BUILD_DIR:-$ROOT/build}"
APP_NAME="${APP_NAME:-动薪}"
APP="$OUT/$APP_NAME.app"
FE="${SWIFT_FRONTEND:-}"
SDK="${MACOS_SDK:-}"
if [ -z "$FE" ] && command -v xcrun >/dev/null 2>&1; then
  FE="$(xcrun -f swift-frontend 2>/dev/null || true)"
  SDK="$(xcrun --show-sdk-path 2>/dev/null || true)"
fi
FE="${FE:-/Library/Developer/CommandLineTools/usr/bin/swift-frontend}"
SDK="${SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}"
TARGET=arm64-apple-macos14.0
rm -rf "$OUT/obj" "$APP"
mkdir -p "$OUT/obj" "$OUT/tmp" "$OUT/cmc" "$OUT/smc" "$APP/Contents/MacOS" "$APP/Contents/Resources"
export TMPDIR="$OUT/tmp" CLANG_MODULE_CACHE_PATH="$OUT/cmc" SWIFT_MODULECACHE_PATH="$OUT/smc"

FILES=("$SRC"/*.swift)
for f in "${FILES[@]}"; do
  base="$(basename "$f" .swift)"
  others=()
  for x in "${FILES[@]}"; do [ "$x" != "$f" ] && others+=("$x"); done
  "$FE" -frontend -c -parse-as-library -primary-file "$f" "${others[@]}" \
    -target "$TARGET" -sdk "$SDK" -module-name SalaryPulse -swift-version 5 ${SWIFT_OPT:--O} \
    -o "$OUT/obj/$base.o"
done

clang "$OUT"/obj/*.o --sysroot "$SDK" --target="$TARGET" \
  -L /Library/Developer/CommandLineTools/usr/lib/swift/macosx -L "$SDK/usr/lib/swift" \
  -Xlinker -rpath -Xlinker /usr/lib/swift \
  -framework SwiftUI -framework AppKit -framework Foundation -framework CoreGraphics \
  -o "$APP/Contents/MacOS/SalaryPulse"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force -s - "$APP" >/dev/null 2>&1 || codesign --force --deep -s - "$APP"
echo "built: $APP"
