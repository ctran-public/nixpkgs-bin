#!/usr/bin/env bash
# Update sources/<name>.json to a GitHub release (default: the latest),
# refreshing the per-platform SRI hashes.
#
# Usage: scripts/update.sh            # update every tool in sources/
#        scripts/update.sh NAME       # update one tool to its latest release
#        scripts/update.sh NAME VER   # pin one tool to version VER
#
# Env:   SOURCES_DIR   directory with <name>.json files (default: repo sources/)
#        GITHUB_TOKEN  optional, raises the GitHub API rate limit
#        GITHUB_OUTPUT when set, receives updated=true|false, version=X,
#                      release_url=URL and compare_url=URL (single-tool mode only)
#
# Hashes come from the release's checksum file when the source names one
# ("checksums"), otherwise each asset is downloaded and hashed.
set -euo pipefail

sources_dir="${SOURCES_DIR:-$(cd "$(dirname "$0")/.." && pwd)/sources}"

curl_gh() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -sSfL -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
  else
    curl -sSfL "$@"
  fi
}

sha256_hex() {
  if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1
  fi
}

hex_to_sri() {
  printf 'sha256-%s' "$(printf '%s' "$1" | xxd -r -p | base64 | tr -d '\n')"
}

output() {
  if [ -n "${GITHUB_OUTPUT:-}" ] && [ "$single" = true ]; then
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  fi
}

# fill TEMPLATE VERSION [PLATFORM]
fill() {
  local s="${1//\{version\}/$2}"
  printf '%s' "${s//\{platform\}/${3:-}}"
}

update_one() {
  local name="$1" want="${2:-}"
  local file="$sources_dir/$name.json"
  [ -f "$file" ] || { echo "error: $file not found" >&2; return 1; }

  local repo tag_tpl asset_tpl sums_tpl current version tag
  repo="$(jq -r .repo "$file")"
  tag_tpl="$(jq -r .tag "$file")"
  asset_tpl="$(jq -r .asset "$file")"
  sums_tpl="$(jq -r '.checksums // empty' "$file")"
  current="$(jq -r .version "$file")"

  if [ -n "$want" ]; then
    version="${want#v}"
  else
    tag="$(curl_gh "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)"
    # Strip the tag template's prefix/suffix around {version}.
    version="${tag#"${tag_tpl%%\{version\}*}"}"
    version="${version%"${tag_tpl#*\{version\}}"}"
  fi
  tag="$(fill "$tag_tpl" "$version")"
  output version "$version"
  output release_url "https://github.com/$repo/releases/tag/$tag"
  output compare_url "https://github.com/$repo/compare/$(fill "$tag_tpl" "$current")...$tag"

  if [ "$current" = "$version" ] && ! jq -e '.platforms[] | select(.hash == "")' "$file" >/dev/null; then
    echo "$name: already at $version"
    output updated false
    return 0
  fi

  echo "$name: ${current} -> $version"
  local base="https://github.com/$repo/releases/download/$tag"
  local sums=""
  [ -n "$sums_tpl" ] && sums="$(curl -sSfL "$base/$(fill "$sums_tpl" "$version")")"

  local json system platform asset hex sri
  json="$(jq --arg v "$version" '.version = $v' "$file")"
  for system in $(jq -r '.platforms | keys[]' "$file"); do
    platform="$(jq -r --arg s "$system" '.platforms[$s].platform' "$file")"
    asset="$(fill "$asset_tpl" "$version" "$platform")"

    if [ -n "$sums" ]; then
      hex="$(printf '%s\n' "$sums" | awk -v a="$asset" '{ f = $2; sub(/^\*/, "", f); sub(/^\.\//, "", f) } f == a { print $1; exit }')"
      [ -n "$hex" ] || { echo "error: no checksum for $asset" >&2; return 1; }
    else
      hex="$(curl -sSfL "$base/$asset" | sha256_hex)"
    fi
    sri="$(hex_to_sri "$hex")"
    echo "  $system: $sri"
    json="$(printf '%s' "$json" | jq --arg s "$system" --arg h "$sri" '.platforms[$s].hash = $h')"
  done

  printf '%s\n' "$json" > "$file.tmp" && mv "$file.tmp" "$file"
  output updated true
}

if [ $# -ge 1 ]; then
  single=true
  update_one "$1" "${2:-}"
else
  single=false
  for f in "$sources_dir"/*.json; do
    update_one "$(basename "$f" .json)"
  done
fi
