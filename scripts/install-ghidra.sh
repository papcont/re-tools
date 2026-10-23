#!/bin/bash
# Installs a prebuilt Ghidra zip from a release of papcont/re-tools and registers it with REA.
#
# Cloud sessions cannot download the official release assets from
# NationalSecurityAgency/ghidra, but release assets of repos attached to the
# session work. So the official zip is attached once, by hand, to a release of
# this repo (tag ghidra-<version>), and this script fetches it from there.
# Much faster than scripts/build-ghidra.sh (~12 min).
#
# Usage: scripts/install-ghidra.sh [version]   (default 12.1.4)
set -euo pipefail

VERSION="${1:-12.1.4}"
REPO="${REPO:-papcont/re-tools}"
TAG="ghidra-${VERSION}"
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"

command -v java >/dev/null || { echo "a JDK 21+ is required" >&2; exit 1; }

url="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/$TAG" | python3 -c '
import json, sys
assets = [a for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".zip")]
print(assets[0]["browser_download_url"] if assets else "")')"
[ -n "$url" ] || { echo "no .zip asset in release $TAG of $REPO" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 3 -o "$tmp/ghidra.zip" "$url"
mkdir -p "$TOOLS_DIR"
# The zip holds a single top-level directory, e.g. ghidra_12.1.4_PUBLIC.
dir="$(unzip -Z1 "$tmp/ghidra.zip" | awk -F/ 'NR == 1 { print $1 }')"
rm -rf "${TOOLS_DIR:?}/$dir"
unzip -q "$tmp/ghidra.zip" -d "$TOOLS_DIR"
export GHIDRA_INSTALL_DIR="$TOOLS_DIR/$dir"
echo "GHIDRA_INSTALL_DIR=$GHIDRA_INSTALL_DIR"

if command -v rea >/dev/null; then
  rea doctor --provider ghidra
  # Re-running setup writes GHIDRA_INSTALL_DIR and JAVA_HOME into the MCP registration.
  rea setup --all-detected --yes >/dev/null
  echo "REA MCP registration updated; restart Claude Code to load it."
fi
