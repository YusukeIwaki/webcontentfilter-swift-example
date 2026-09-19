#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_SPEC_PATH="$REPO_ROOT/project.yml"
PROJECT_PATH="$REPO_ROOT/ContentFilter.xcodeproj"
BUILD_ROOT="$REPO_ROOT/build/adhoc"
ARCHIVE_PATH="$BUILD_ROOT/ContentFilter.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
EXPORT_OPTIONS_PLIST="$BUILD_ROOT/ExportOptions.plist"
IPA_PATH="$EXPORT_PATH/FilterApp.ipa"

TEAM_ID="${TEAM_ID:-6KG5EF3BN2}"
APP_BUNDLE_ID="io.github.yusukeiwaki.exampleswiftwebcontentfilter"
BUNDLE_IDS=(
  "$APP_BUNDLE_ID"
  "$APP_BUNDLE_ID.data"
  "$APP_BUNDLE_ID.control"
)
# NOTE: Xcode 26 deprecated the "ad-hoc" export method name ("Use
# release-testing instead"). release-testing produces the same
# device-registered test IPA. Override with EXPORT_METHOD=ad-hoc if needed.
EXPORT_METHOD="${EXPORT_METHOD:-release-testing}"

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "Usage: $0"
      echo "Environment: TEAM_ID (default $TEAM_ID), EXPORT_METHOD (default $EXPORT_METHOD)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0" >&2
      exit 1
      ;;
  esac
done

generate_xcode_project() {
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required to generate $PROJECT_PATH before building." >&2
    return 1
  fi

  xcodegen --spec "$PROJECT_SPEC_PATH" --project "$REPO_ROOT" >/dev/null
}

cleanup_cached_profiles() {
  local matches
  matches="$(
    /usr/bin/python3 - "$TEAM_ID" "${BUNDLE_IDS[@]}" <<'PY'
import os
import plistlib
import subprocess
import sys

team_id = sys.argv[1]
target_app_ids = {f"{team_id}.{bundle_id}" for bundle_id in sys.argv[2:]}
profile_dirs = [
    os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles"),
    os.path.expanduser("~/Library/Developer/Xcode/UserData/Provisioning Profiles"),
]

for profiles_dir in profile_dirs:
    if not os.path.isdir(profiles_dir):
        continue
    for entry in sorted(os.listdir(profiles_dir)):
        if not entry.endswith(".mobileprovision"):
            continue
        path = os.path.join(profiles_dir, entry)
        try:
            decoded = subprocess.check_output(["security", "cms", "-D", "-i", path], stderr=subprocess.DEVNULL)
            payload = plistlib.loads(decoded)
        except Exception:
            continue

        entitlements = payload.get("Entitlements", {})
        app_id = entitlements.get("application-identifier")
        is_xcode_managed = bool(payload.get("IsXcodeManaged"))
        if app_id not in target_app_ids or not is_xcode_managed:
            continue

        name = payload.get("Name", "")
        uuid = payload.get("UUID", "")
        print(f"{path}\t{name}\t{uuid}")
PY
  )"

  if [ -z "$matches" ]; then
    return 0
  fi

  while IFS=$'\t' read -r profile_path profile_name profile_uuid; do
    [ -n "$profile_path" ] || continue
    echo "Removing cached provisioning profile: ${profile_name:-Unknown} (${profile_uuid:-no-uuid})"
    rm -f "$profile_path"
  done <<< "$matches"
}

write_export_options_plist() {
  mkdir -p "$BUILD_ROOT"
  cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>${EXPORT_METHOD}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
}

declare_capabilities() {
  # xcodegen cannot express SystemCapabilities, so declare them here to match
  # the *.entitlements files (what Xcode's Signing & Capabilities editor would
  # write). Without this, GUI and CLI builds disagree about capabilities.
  /usr/bin/python3 - "$PROJECT_PATH/project.pbxproj" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

anchor = "ProvisioningStyle = Automatic;"
inject = """ProvisioningStyle = Automatic;
\t\t\t\t\t\tSystemCapabilities = {
\t\t\t\t\t\t\tcom.apple.ApplicationGroups.iOS = {
\t\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t\t};
\t\t\t\t\t\t\tcom.apple.NetworkExtensions.iOS = {
\t\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t\t};
\t\t\t\t\t\t};"""

count = content.count(anchor)
content = content.replace(anchor, inject)
with open(path, "w") as f:
    f.write(content)
print(f"Declared NetworkExtensions+ApplicationGroups on {count} target(s).")
PY
}

generate_xcode_project
declare_capabilities
cleanup_cached_profiles

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
write_export_options_plist

xcodebuild -project "$PROJECT_PATH" \
  -scheme FilterApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -allowProvisioningUpdates \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates

if [ ! -f "$IPA_PATH" ]; then
  echo "IPA was not generated at $IPA_PATH" >&2
  exit 1
fi

echo "IPA generated: $IPA_PATH"
