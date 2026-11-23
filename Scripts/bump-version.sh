#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
project_file="$project_dir/AnddleMPlayer.xcodeproj/project.pbxproj"
component="${1:-patch}"

marketing_version="$(
  awk '/MARKETING_VERSION = / {
    gsub(/;/, "", $3)
    print $3
    exit
  }' "$project_file"
)"
build_number="$(
  awk '/CURRENT_PROJECT_VERSION = / {
    gsub(/;/, "", $3)
    print $3
    exit
  }' "$project_file"
)"

if [[ ! "$marketing_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "Invalid marketing version: $marketing_version" >&2
  exit 1
fi
if [[ ! "$build_number" =~ '^[0-9]+$' ]]; then
  echo "Invalid build number: $build_number" >&2
  exit 1
fi

IFS=. read -r major minor patch <<< "$marketing_version"
case "$component" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  current)
    ;;
  *)
    echo "Usage: $0 [major|minor|patch|current]" >&2
    exit 1
    ;;
esac

next_version="$major.$minor.$patch"
next_build=$((build_number + 1))

perl -pi -e \
  "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $next_version;/g; s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $next_build;/g" \
  "$project_file"

echo "$marketing_version ($build_number) -> $next_version ($next_build)"
