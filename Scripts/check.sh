#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

derived_data="$(mktemp -d "${TMPDIR:-/tmp}/AnddleMPlayer-check.XXXXXX")"
module_cache="$(mktemp -d "${TMPDIR:-/tmp}/AnddleMPlayer-module-cache.XXXXXX")"
mkdir -p "$derived_data" "$module_cache"

cleanup() {
  rm -rf "$derived_data" "$module_cache"
}
trap cleanup EXIT INT TERM

common_build_args=(
  -project AnddleMPlayer.xcodeproj
  -scheme AnddleMPlayer
  -derivedDataPath "$derived_data"
  CODE_SIGNING_ALLOWED=NO
  OTHER_SWIFT_FLAGS=-disable-sandbox
  CLANG_MODULE_CACHE_PATH="$module_cache"
  SWIFT_MODULECACHE_PATH="$module_cache"
)

for localization in AnddleMPlayer/*.lproj/Localizable.strings; do
  plutil -lint "$localization" >/dev/null
done

xcodebuild -quiet \
  "${common_build_args[@]}" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -destination-timeout 1 \
  build

xcodebuild -quiet \
  "${common_build_args[@]}" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -destination-timeout 1 \
  build

xcodebuild -quiet \
  "${common_build_args[@]}" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -destination-timeout 1 \
  analyze

xcodebuild -quiet \
  "${common_build_args[@]}" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -destination-timeout 1 \
  build-for-testing

simulator_id="$(
  xcrun simctl list devices available 2>/dev/null \
    | awk -F '[()]' '/iPhone/ { print $2; exit }' \
    || true
)"

if [[ -n "${simulator_id:-}" ]]; then
  xcodebuild -quiet \
    "${common_build_args[@]}" \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    test-without-building
else
  echo "No available iPhone simulator; test bundle was compiled but not executed."
fi
