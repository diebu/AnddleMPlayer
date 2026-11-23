#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

archive_path="build/AnddleMPlayer.xcarchive"
export_path="build/AppStoreExport"
derived_data="$(mktemp -d "${TMPDIR:-/tmp}/AnddleMPlayer-archive.XXXXXX")"
module_cache="$(mktemp -d "${TMPDIR:-/tmp}/AnddleMPlayer-archive-cache.XXXXXX")"

cleanup() {
  rm -rf "$derived_data" "$module_cache"
}
trap cleanup EXIT INT TERM

mkdir -p build
rm -rf "$archive_path" "$export_path"

xcodebuild \
  -project AnddleMPlayer.xcodeproj \
  -scheme AnddleMPlayer \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  archive \
  OTHER_SWIFT_FLAGS=-disable-sandbox \
  CLANG_MODULE_CACHE_PATH="$module_cache" \
  SWIFT_MODULECACHE_PATH="$module_cache"

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist Docs/AppStoreExportOptions.plist \
  -allowProvisioningUpdates

echo "App Store IPA: $project_dir/$export_path"
