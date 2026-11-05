#!/usr/bin/env bash
# Update flake.nix to a mise release (default: latest) with hashes from
# the release's SHASUMS256.txt.
#
# Usage: scripts/update.sh [VERSION]
# Env:   FLAKE (path to flake.nix, default: repo root flake.nix)
#        GITHUB_OUTPUT (when set, writes updated=true|false and version=X)
set -euo pipefail

flake="${FLAKE:-$(cd "$(dirname "$0")/.." && pwd)/flake.nix}"

if [ $# -ge 1 ]; then
  version="$1"
else
  auth=()
  [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  version="$(curl -sSfL ${auth[@]+"${auth[@]}"} https://api.github.com/repos/jdx/mise/releases/latest | jq -r .tag_name)"
fi
version="${version#v}"

current="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "$flake" | head -n1)"

output() {
  [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  return 0
}
output version "$version"

if [ "$current" = "$version" ] && ! grep -q 'fakeHash' "$flake"; then
  echo "flake.nix already at mise $version"
  output updated false
  exit 0
fi

echo "Updating mise: ${current:-none} -> $version"
sums="$(curl -sSfL "https://github.com/jdx/mise/releases/download/v${version}/SHASUMS256.txt")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cp "$flake" "$tmp"

# nix system : release asset suffix
for pair in \
  aarch64-darwin:macos-arm64 \
  x86_64-darwin:macos-x64 \
  aarch64-linux:linux-arm64-musl \
  x86_64-linux:linux-x64-musl; do
  system="${pair%%:*}"
  asset="mise-v${version}-${pair#*:}"

  hex="$(printf '%s\n' "$sums" | awk -v a="$asset" '{ f = $2; sub(/^\.\//, "", f) } f == a { print $1 }')"
  if [ -z "$hex" ]; then
    echo "error: no checksum for $asset in SHASUMS256.txt" >&2
    exit 1
  fi
  sri="sha256-$(printf '%s' "$hex" | xxd -r -p | base64 | tr -d '\n')"
  echo "  $system: $sri"

  # Only rewrite the line inside the `hashes = { ... };` block.
  awk -v sys="$system" -v sri="$sri" '
    /hashes = \{/ { inh = 1 }
    inh && index($0, "\"" sys "\" =") { sub(/=.*/, "= \"" sri "\";") }
    inh && /\};/ { inh = 0 }
    { print }
  ' "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
done

sed -E "s/^([[:space:]]*version = )\"[^\"]+\";/\1\"${version}\";/" "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
cp "$tmp" "$flake"

output updated true
