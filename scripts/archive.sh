#!/usr/bin/env bash
set -euo pipefail

# VoiceFlow — Archive + IPA export
# Produces a signed .ipa under build/ for upload to TestFlight via Organizer
# or `xcrun altool / xcrun notarytool`.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Regenerate Xcode project from canonical project.yml
xcodegen generate

ARCHIVE_PATH="build/VoiceFlow.xcarchive"
EXPORT_PATH="build"
EXPORT_OPTIONS="scripts/ExportOptions.plist"

echo "▶ Archiving..."
xcodebuild \
  -project VoiceFlow.xcodeproj \
  -scheme VoiceFlow \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "▶ Exporting IPA..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

echo "✓ Done."
echo "  Archive: $ARCHIVE_PATH"
echo "  IPA:     $EXPORT_PATH/VoiceFlow.ipa"
echo
echo "Next: open Xcode → Window → Organizer → Distribute App → App Store Connect"
echo "  or: xcrun altool --upload-app -f $EXPORT_PATH/VoiceFlow.ipa \\"
echo "       --apiKey 546FUCYC9Z --apiIssuer <issuer-uuid>"
