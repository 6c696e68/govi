#!/bin/bash
# Build Govi.app + Govi.dmg vào thư mục build/.
# Chữ ký lấy từ biến môi trường GOVI_SIGN_ID (không hardcode trong repo).
#   security find-identity -v -p codesigning   # xem danh sách
#   export GOVI_SIGN_ID="<hash hoặc tên cert>"
#   ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Govi"
OUT="build"
APP="$OUT/$APP_NAME.app"
DMG="$OUT/$APP_NAME.dmg"

if [[ -z "${GOVI_SIGN_ID:-}" ]]; then
  echo "Lỗi: chưa đặt GOVI_SIGN_ID." >&2
  echo "  security find-identity -v -p codesigning" >&2
  echo "  export GOVI_SIGN_ID=\"<hash hoặc tên cert>\"" >&2
  exit 1
fi

# 1) Đóng gói .app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -wmo -target arm64-apple-macos14.0 \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  $(find Sources -name '*.swift')

strip -x "$APP/Contents/MacOS/$APP_NAME"
# Developer ID cần secure timestamp để notarize; ad-hoc ("-") thì không gắn timestamp.
if [[ "$GOVI_SIGN_ID" == "-" ]]; then
  codesign --force --options runtime --sign "-" "$APP"
else
  codesign --force --options runtime --timestamp --sign "$GOVI_SIGN_ID" "$APP"
fi
echo "Built $APP ($(du -h "$APP/Contents/MacOS/$APP_NAME" | cut -f1))"

# 2) Tạo .dmg có shortcut /Applications để kéo-thả cài đặt
STAGE="$OUT/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Built $DMG"

# 3) Notarize + staple (chỉ khi đặt GOVI_NOTARY_PROFILE = tên keychain profile của notarytool)
if [[ -n "${GOVI_NOTARY_PROFILE:-}" ]]; then
  echo "Notarizing $DMG ..."
  xcrun notarytool submit "$DMG" --keychain-profile "$GOVI_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  echo "Notarized + stapled $DMG"
fi
