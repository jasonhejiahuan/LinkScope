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
EXPECTED_TEAM_ID="WBU2AFY549"
EXPECTED_DISPLAY_NAME="LinkScope DEBUG"

if [[ "$EDITION" == "lite" ]]; then
  BUNDLE_ID="cc.jasonstu.linkscope.lite"
  EXPECTED_DISPLAY_NAME="LinkScope Lite DEBUG"
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

xcodebuild \
  -project "$ROOT_DIR/LinkScope.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$DERIVED_DATA" \
  build

verify_signed_bundle() {
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

  local signing_details
  signing_details="$(codesign -dvvv "$APP_BUNDLE" 2>&1)"
  if ! grep -Fq "Authority=Apple Development:" <<<"$signing_details"; then
    echo "$APP_NAME is not signed with an Apple Development identity." >&2
    return 1
  fi
  if ! grep -Fq "TeamIdentifier=$EXPECTED_TEAM_ID" <<<"$signing_details"; then
    echo "$APP_NAME is not signed by team $EXPECTED_TEAM_ID." >&2
    return 1
  fi
  if grep -Fq "Signature=adhoc" <<<"$signing_details"; then
    echo "$APP_NAME has an ad-hoc signature." >&2
    return 1
  fi

  local actual_bundle_id actual_display_name
  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")"
  if [[ "$actual_bundle_id" != "$BUNDLE_ID" ]]; then
    echo "$APP_NAME bundle identifier is $actual_bundle_id, expected $BUNDLE_ID." >&2
    return 1
  fi
  actual_display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP_BUNDLE/Contents/Info.plist")"
  if [[ "$actual_display_name" != "$EXPECTED_DISPLAY_NAME" ]]; then
    echo "$APP_NAME display name is $actual_display_name, expected $EXPECTED_DISPLAY_NAME." >&2
    return 1
  fi

  local entitlements app_identifier access_group
  entitlements="$(codesign -d --entitlements :- "$APP_BUNDLE" 2>/dev/null)"
  app_identifier="$(xmllint --xpath 'string(/plist/dict/key[text()="com.apple.application-identifier"]/following-sibling::string[1])' - <<<"$entitlements")"
  access_group="$(xmllint --xpath 'string(/plist/dict/key[text()="keychain-access-groups"]/following-sibling::array[1]/string[1])' - <<<"$entitlements")"
  if [[ "$app_identifier" != "$EXPECTED_TEAM_ID.$BUNDLE_ID" || "$access_group" != "$app_identifier" ]]; then
    echo "$APP_NAME is missing its exact Data Protection Keychain access group." >&2
    return 1
  fi
  if [[ ! -f "$APP_BUNDLE/Contents/embedded.provisionprofile" ]]; then
    echo "$APP_NAME has no embedded provisioning profile for its keychain entitlement." >&2
    return 1
  fi
}

verify_signed_bundle

open_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  debug)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
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
