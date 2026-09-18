#!/bin/bash
set -euo pipefail
# Only run on an ephemeral GitHub-hosted macOS runner.
: "${APPLE_TEAM_ID:?Set the APPLE_TEAM_ID repository variable}"
: "${IOS_DISTRIBUTION_P12_BASE64:?Missing distribution certificate secret}"
: "${IOS_DISTRIBUTION_P12_PASSWORD:?Missing certificate password secret}"
: "${IOS_PROFILE_BASE64:?Missing App Store provisioning profile secret}"
: "${ASC_KEY_ID:?Missing App Store Connect key ID secret}"
: "${ASC_ISSUER_ID:?Missing App Store Connect issuer ID secret}"
: "${ASC_PRIVATE_KEY_BASE64:?Missing App Store Connect private key secret}"
: "${RUNNER_TEMP:?This script requires a GitHub macOS runner}"
export SIGNING_DIR="$RUNNER_TEMP/sausage-signing"
mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"
KEYCHAIN="$SIGNING_DIR/distribution.keychain-db"
PROFILE_PATH=""
PROFILE_LEGACY_PATH=""
cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  if [[ -n "$PROFILE_PATH" ]]; then rm -f "$PROFILE_PATH"; fi
  if [[ -n "$PROFILE_LEGACY_PATH" ]]; then rm -f "$PROFILE_LEGACY_PATH"; fi
  rm -rf "$SIGNING_DIR"
}
trap cleanup EXIT
python3 - <<'PY'
import base64, os, pathlib
p=pathlib.Path(os.environ['SIGNING_DIR'])
for key, filename in [('IOS_DISTRIBUTION_P12_BASE64','certificate.p12'),('IOS_PROFILE_BASE64','profile.mobileprovision'),('ASC_PRIVATE_KEY_BASE64','AuthKey_'+os.environ['ASC_KEY_ID']+'.p8')]:
    target=p/filename
    target.write_bytes(base64.b64decode(''.join(os.environ[key].split()),validate=True))
    target.chmod(0o600)
PY
security cms -D -i "$SIGNING_DIR/profile.mobileprovision" > "$SIGNING_DIR/profile.plist"
python3 - <<'PY'
import datetime, os, pathlib, plistlib
p=pathlib.Path(os.environ['SIGNING_DIR'])
profile=plistlib.loads((p/'profile.plist').read_bytes())
entitlements=profile['Entitlements']
assert entitlements['application-identifier'].endswith('.com.michaelwaters.sausagepanic'), 'Profile bundle ID mismatch'
assert profile['TeamIdentifier'][0] == os.environ['APPLE_TEAM_ID'], 'Profile team mismatch'
assert not entitlements.get('get-task-allow',False), 'Use a distribution profile'
assert not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'), 'Use an App Store Connect distribution profile'
assert profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Provisioning profile expired'
(p/'uuid').write_text(profile['UUID'])
options={'method':'app-store-connect','destination':'export','teamID':os.environ['APPLE_TEAM_ID'],'signingStyle':'manual','signingCertificate':'Apple Distribution','provisioningProfiles':{'com.michaelwaters.sausagepanic':profile['UUID']},'manageAppVersionAndBuildNumber':False,'uploadSymbols':True}
(p/'ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
PROFILE_UUID="$(cat "$SIGNING_DIR/uuid")"
PROFILE_PATH="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
PROFILE_LEGACY_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
mkdir -p "$(dirname "$PROFILE_PATH")" "$(dirname "$PROFILE_LEGACY_PATH")"
cp "$SIGNING_DIR/profile.mobileprovision" "$PROFILE_PATH"
cp "$SIGNING_DIR/profile.mobileprovision" "$PROFILE_LEGACY_PATH"
KEYCHAIN_PASSWORD="$(openssl rand -hex 24)"
echo "::add-mask::$KEYCHAIN_PASSWORD"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$SIGNING_DIR/certificate.p12" -k "$KEYCHAIN" -P "$IOS_DISTRIBUTION_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"
# A fresh monotonic number is generated per upload attempt, including workflow retries.
BUILD_NUMBER="${GITHUB_RUN_NUMBER}.${GITHUB_RUN_ATTEMPT}.0"
xcodebuild -project SausagePanic.xcodeproj -scheme SausagePanic -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$RUNNER_TEMP/SausagePanic.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_UUID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" archive
xcodebuild -exportArchive -archivePath "$RUNNER_TEMP/SausagePanic.xcarchive" \
  -exportPath "$RUNNER_TEMP/sausage-export" -exportOptionsPlist "$SIGNING_DIR/ExportOptions.plist"
export API_PRIVATE_KEYS_DIR="$SIGNING_DIR"
xcrun altool --validate-app -f "$RUNNER_TEMP/sausage-export/SausagePanic.ipa" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app -f "$RUNNER_TEMP/sausage-export/SausagePanic.ipa" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
