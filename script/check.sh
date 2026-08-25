#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_TEAM_ID="WBU2AFY549"
EXPECTED_MARKETING_VERSION="2.0.0"
EXPECTED_BUILD_NUMBER="9"
LAST_VERIFIED_AUTHORITY=""

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

swift test --package-path "$ROOT_DIR/Packages/LinkScopeKit"

verify_signed_bundle() {
  local app_bundle="$1"
  local expected_bundle_id="$2"
  local expected_display_name="$3"

  codesign --verify --deep --strict --verbose=2 "$app_bundle"

  local signing_details
  signing_details="$(codesign -dvvv "$app_bundle" 2>&1)"
  LAST_VERIFIED_AUTHORITY="$(sed -n 's/^Authority=\(Apple Development:.*\)$/\1/p' <<<"$signing_details" | head -1)"
  if [[ -z "$LAST_VERIFIED_AUTHORITY" ]]; then
    echo "$app_bundle is not signed with an Apple Development identity." >&2
    return 1
  fi
  if ! grep -Fq "TeamIdentifier=$EXPECTED_TEAM_ID" <<<"$signing_details"; then
    echo "$app_bundle is not signed by team $EXPECTED_TEAM_ID." >&2
    return 1
  fi
  if grep -Fq "Signature=adhoc" <<<"$signing_details"; then
    echo "$app_bundle has an ad-hoc signature." >&2
    return 1
  fi

  local actual_bundle_id actual_display_name actual_marketing_version actual_build_number
  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_bundle/Contents/Info.plist")"
  if [[ "$actual_bundle_id" != "$expected_bundle_id" ]]; then
    echo "$app_bundle bundle identifier is $actual_bundle_id, expected $expected_bundle_id." >&2
    return 1
  fi
  actual_display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app_bundle/Contents/Info.plist")"
  if [[ "$actual_display_name" != "$expected_display_name" ]]; then
    echo "$app_bundle display name is $actual_display_name, expected $expected_display_name." >&2
    return 1
  fi
  actual_marketing_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")"
  actual_build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_bundle/Contents/Info.plist")"
  if [[ "$actual_marketing_version" != "$EXPECTED_MARKETING_VERSION" || "$actual_build_number" != "$EXPECTED_BUILD_NUMBER" ]]; then
    echo "$app_bundle is version $actual_marketing_version ($actual_build_number), expected $EXPECTED_MARKETING_VERSION ($EXPECTED_BUILD_NUMBER)." >&2
    return 1
  fi

  local entitlements app_identifier access_group usage_description
  entitlements="$(codesign -d --entitlements :- "$app_bundle" 2>/dev/null)"
  app_identifier="$(xmllint --xpath 'string(/plist/dict/key[text()="com.apple.application-identifier"]/following-sibling::string[1])' - <<<"$entitlements")"
  access_group="$(xmllint --xpath 'string(/plist/dict/key[text()="keychain-access-groups"]/following-sibling::array[1]/string[1])' - <<<"$entitlements")"
  if [[ "$app_identifier" != "$EXPECTED_TEAM_ID.$expected_bundle_id" || "$access_group" != "$app_identifier" ]]; then
    echo "$app_bundle is missing its exact Data Protection Keychain access group." >&2
    return 1
  fi
  if [[ ! -f "$app_bundle/Contents/embedded.provisionprofile" ]]; then
    echo "$app_bundle has no embedded provisioning profile for its keychain entitlement." >&2
    return 1
  fi

  usage_description="$(/usr/libexec/PlistBuddy -c 'Print :NSBluetoothAlwaysUsageDescription' "$app_bundle/Contents/Info.plist")"
  if [[ -z "$usage_description" ]]; then
    echo "$app_bundle has no Bluetooth usage description." >&2
    return 1
  fi
}

full_authority=""
lite_authority=""

for scheme in "LinkScope" "LinkScope Lite"; do
  xcodebuild \
    -quiet \
    -project "$ROOT_DIR/LinkScope.xcodeproj" \
    -scheme "$scheme" \
    -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$ROOT_DIR/DerivedData" \
    build

  if [[ "$scheme" == "LinkScope Lite" ]]; then
    expected_bundle_id="cc.jasonstu.linkscope.lite"
    expected_display_name="LinkScope Lite DEBUG"
  else
    expected_bundle_id="cc.jasonstu.linkscope"
    expected_display_name="LinkScope DEBUG"
  fi
  verify_signed_bundle \
    "$ROOT_DIR/DerivedData/Build/Products/Debug/$scheme.app" \
    "$expected_bundle_id" \
    "$expected_display_name"
  if [[ "$scheme" == "LinkScope Lite" ]]; then
    lite_authority="$LAST_VERIFIED_AUTHORITY"
  else
    full_authority="$LAST_VERIFIED_AUTHORITY"
  fi
done

if [[ "$full_authority" != "$lite_authority" ]]; then
  echo "Full and Lite were signed by different Apple Development identities." >&2
  exit 1
fi

plutil -lint \
  "$ROOT_DIR/Apps/LinkScope/LinkScope.entitlements" \
  "$ROOT_DIR/Apps/LinkScopeLite/LinkScopeLite.entitlements"

echo "LinkScope checks passed."
