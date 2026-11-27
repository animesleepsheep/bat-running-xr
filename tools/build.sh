#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION=4.6.1
GODOT="${GODOT_BIN:-$HOME/.local/bin/godot-xr000}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
: "${SDK:?Android SDK must be provisioned by the runner}"
: "${JAVA_HOME:?JDK 17 must be provisioned by the runner}"
mkdir -p "$(dirname "$GODOT")" "$HOME/.local/share/godot/export_templates/$VERSION.stable" "$HOME/.config/godot" "$ROOT/dist"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
BASE="https://github.com/godotengine/godot/releases/download/$VERSION-stable"
if [ ! -x "$GODOT" ]; then
  curl --fail --location --retry 3 "$BASE/Godot_v${VERSION}-stable_linux.x86_64.zip" -o "$TMP/editor.zip"
  unzip -q "$TMP/editor.zip" -d "$TMP/editor"
  install -m 755 "$TMP/editor/Godot_v${VERSION}-stable_linux.x86_64" "$GODOT"
fi
"$GODOT" --version | grep -F "$VERSION.stable"
TEMPLATES="$HOME/.local/share/godot/export_templates/$VERSION.stable"
if [ ! -f "$TEMPLATES/android_source.zip" ]; then
  curl --fail --location --retry 3 "$BASE/Godot_v${VERSION}-stable_export_templates.tpz" -o "$TMP/templates.tpz"
  unzip -q "$TMP/templates.tpz" -d "$TMP/templates"
  cp -a "$TMP/templates/templates/." "$TEMPLATES/"
fi
mkdir -p android/build
unzip -oq "$TEMPLATES/android_source.zip" -d android/build
printf '%s.stable\n' "$VERSION" > android/.build_version
KEY="$HOME/.android/debug.keystore"
mkdir -p "$(dirname "$KEY")"
if [ ! -f "$KEY" ]; then
  keytool -genkeypair -keystore "$KEY" -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'
fi
cat > "$HOME/.config/godot/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$KEY"
SETTINGS
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEY"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
timeout 180 "$GODOT" --headless --path "$ROOT" --editor --import --quit 2>&1 | tee dist/import.log
timeout 60 "$GODOT" --headless --path "$ROOT" --xr-mode off -- --smoke 2>&1 | tee dist/smoke.log
grep -q XR000_SMOKE_PASS dist/smoke.log
if grep -Eq "SCRIPT ERROR|Parse Error" dist/import.log dist/smoke.log; then exit 1; fi
for entry in 'Quest 3|quest3' 'Focus 3|focus3'; do
  IFS='|' read -r preset slug <<< "$entry"
  apk="$ROOT/dist/BAT_RUNNING_XR000_$slug.apk"
  rm -f "$apk"
  "$GODOT" --headless --path "$ROOT" --export-debug "$preset" "$apk" 2>&1 | tee "dist/$slug-build.log"
  test -s "$apk"
  python3 tools/check_apk.py "$apk" "$SDK" "$slug" | tee "dist/$slug-verify.log"
done
(cd dist && sha256sum *.apk > SHA256SUMS.txt)
