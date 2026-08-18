#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

swift test --package-path "$ROOT_DIR/Packages/LinkScopeKit"

for scheme in "LinkScope" "LinkScope Lite"; do
  xcodebuild \
    -quiet \
    -project "$ROOT_DIR/LinkScope.xcodeproj" \
    -scheme "$scheme" \
    -configuration Debug \
    -destination "platform=macOS" \
    -derivedDataPath "$ROOT_DIR/DerivedData" \
    build

  codesign --verify --deep --strict --verbose=2 \
    "$ROOT_DIR/DerivedData/Build/Products/Debug/$scheme.app"
done

plutil -lint \
  "$ROOT_DIR/Apps/LinkScope/LinkScope.entitlements" \
  "$ROOT_DIR/Apps/LinkScopeLite/LinkScopeLite.entitlements"

echo "LinkScope checks passed."
