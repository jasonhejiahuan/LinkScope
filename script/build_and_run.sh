#!/usr/bin/env bash
set -euo pipefail

MODE="run"
EDITION="full"

for argument in "$@"; do
  case "$argument" in
    run)
      MODE="run"
      ;;
    --debug|debug)
      MODE="debug"
      ;;
    --logs|logs)
      MODE="logs"
      ;;
    --telemetry|telemetry)
      MODE="telemetry"
      ;;
    --verify|verify)
      MODE="verify"
      ;;
    --lite|lite)
      EDITION="lite"
      ;;
    --full|full)
      EDITION="full"
      ;;
    *)
      echo "usage: $0 [--full|--lite] [run|--debug|--logs|--telemetry|--verify]" >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedData"

if [[ "$EDITION" == "lite" ]]; then
  SCHEME="LinkScope Lite"
  APP_NAME="LinkScope Lite"
else
  SCHEME="LinkScope"
  APP_NAME="LinkScope"
fi

APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="cc.jasonstu.linkscope"

if [[ "$EDITION" == "lite" ]]; then
  BUNDLE_ID="cc.jasonstu.linkscope.lite"
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/LinkScope.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  debug)
    lldb -- "$APP_BINARY"
    ;;
  logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched successfully."
    ;;
esac
