#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_HOME="$ROOT/.tmp-home"
DERIVED_DATA="$ROOT/.build/DerivedData"
MODULE_CACHE="$ROOT/.build/module-cache"
CLANG_CACHE="$ROOT/.build/clang-module-cache"

mkdir -p "$TMP_HOME/.cache" "$DERIVED_DATA" "$MODULE_CACHE" "$CLANG_CACHE"

echo "==> SwiftPM tests"
env \
  HOME="$TMP_HOME" \
  XDG_CACHE_HOME="$TMP_HOME/.cache" \
  SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
  CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
  swift test

echo "==> Regenerate Xcode project"
ruby "$ROOT/Scripts/generate_xcodeproj.rb"

echo "==> Mac Catalyst build"
xcodebuild \
  -project "$ROOT/AdmitPath.xcodeproj" \
  -scheme AdmitPath \
  -destination "platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath "$DERIVED_DATA" \
  build

echo "==> iPhone simulator preflight"
if ! xcrun simctl list runtimes 2>/dev/null | grep -q "iOS"; then
  echo "Skipping iPhone simulator validation because no iOS simulator runtimes are currently available."
  exit 0
fi

SIMULATOR_NAME="$(
  xcrun simctl list devices available 2>/dev/null \
    | sed -n 's/^[[:space:]]*\(iPhone[^()]*\) (.*/\1/p' \
    | head -n 1
)"

if [[ -z "$SIMULATOR_NAME" ]]; then
  echo "Skipping iPhone simulator validation because no available iPhone simulator devices were found."
  exit 0
fi

echo "==> iPhone simulator build-for-testing on $SIMULATOR_NAME"
xcodebuild \
  -project "$ROOT/AdmitPath.xcodeproj" \
  -scheme AdmitPath \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  build-for-testing

echo "==> iPhone simulator UI smoke tests on $SIMULATOR_NAME"
xcodebuild \
  -project "$ROOT/AdmitPath.xcodeproj" \
  -scheme AdmitPath \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  test-without-building \
  -only-testing:AdmitPathUITests
