#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p dist
touch dist/.gdignore
npm --prefix tools/assets install --no-audit --no-fund --ignore-scripts
npm --prefix tools/assets run generate | tee dist/assets.log
cp assets/generated/catalog.json dist/ASSET_CATALOG.json
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
# Never let Godot scan generated Gradle resources or build outputs.
mkdir -p android dist
touch android/.gdignore dist/.gdignore
prepare_android() {
  rm -rf "$ROOT/android/build"
  mkdir -p "$ROOT/android/build"
  unzip -oq "$TEMPLATES/android_source.zip" -d "$ROOT/android/build"
  printf '%s.stable\n' "$VERSION" > "$ROOT/android/.build_version"
  touch "$ROOT/android/.gdignore" "$ROOT/android/build/.gdignore"
}
prepare_android
# Protected release key is optional for lab builds and mandatory for release builds.
MODE="${XR_SIGNING_MODE:-debug}"
EXPORT_FLAG=--export-debug
if [ "$MODE" = release ]; then
  : "${XR_KEYSTORE_B64:?Missing protected keystore secret}"
  : "${XR_KEY_ALIAS:?Missing key alias}"
  : "${XR_KEY_PASSWORD:?Missing keystore password}"
  : "${XR_CERT_SHA256:?Missing expected signer fingerprint}"
  RELEASE_KEY="$TMP/release.keystore"
  umask 077
  printf '%s' "$XR_KEYSTORE_B64" | base64 -d > "$RELEASE_KEY"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RELEASE_KEY"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$XR_KEY_ALIAS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$XR_KEY_PASSWORD"
  EXPORT_FLAG=--export-release
elif [ "$MODE" != debug ]; then
  echo "Invalid signing mode"; exit 1
fi
printf '%s\n' "$MODE" > dist/SIGNING_MODE.txt
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
grep -q XR001_SMOKE_PASS dist/smoke.log
grep -q XR002_SMOKE_PASS dist/smoke.log
if grep -Eq "SCRIPT ERROR|Parse Error" dist/import.log dist/smoke.log; then exit 1; fi
for entry in 'Quest 3|quest3' 'Focus 3|focus3'; do
  IFS='|' read -r preset slug <<< "$entry"
  apk="$ROOT/dist/BAT_RUNNING_XR002_$slug.apk"
  rm -f "$apk"
  prepare_android
  "$GODOT" --headless --path "$ROOT" "$EXPORT_FLAG" "$preset" "$apk" 2>&1 | tee "dist/$slug-build.log"
  test -s "$apk"
  python3 tools/check_apk.py "$apk" "$SDK" "$slug" 3 "$MODE" | tee "dist/$slug-verify.log"
done
python3 tools/check_update_pair.py dist/quest3-verify.log dist/focus3-verify.log
(cd dist && sha256sum *.apk > SHA256SUMS.txt)
