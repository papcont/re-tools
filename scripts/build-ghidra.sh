#!/bin/bash
# Builds Ghidra from source in a Claude Code cloud session and registers it with REA.
#
# Cloud sessions cannot download GitHub release assets or raw files of repos that
# are not attached to the session, but anonymous git clones of public repos work.
# So: clone ghidra + ghidra-data, seed the downloads that would come from
# github.com/.../raw, fetch the rest, and build with Maven Central routed through
# Google's mirror (repo.maven.apache.org answers HTTP 429 from cloud sessions).
#
# Usage: scripts/build-ghidra.sh [version]   (default 12.1.4, ~12 min on 4 cores)
set -euo pipefail

VERSION="${1:-12.1.4}"
SRC_ROOT="${SRC_ROOT:-$HOME/src}"
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GHIDRA_SRC="$SRC_ROOT/ghidra"
DATA_SRC="$SRC_ROOT/ghidra-data"
# The jgrapht jar contains non-ASCII class names; without UTF-8 the SBOM step fails.
export LANG=C.UTF-8 LC_ALL=C.UTF-8

command -v javac >/dev/null || { echo "a full JDK 21+ (javac) is required" >&2; exit 1; }

mkdir -p "$SRC_ROOT" "$TOOLS_DIR"
[ -d "$GHIDRA_SRC/.git" ] || GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 \
  --branch "Ghidra_${VERSION}_build" https://github.com/NationalSecurityAgency/ghidra "$GHIDRA_SRC"
[ -d "$DATA_SRC/.git" ] || GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 \
  --branch "Ghidra_${VERSION}" https://github.com/NationalSecurityAgency/ghidra-data "$DATA_SRC"

cd "$GHIDRA_SRC"
# fetchDependencies.gradle skips any file already present with the expected SHA-256,
# so seeding from ghidra-data keeps its integrity checks intact.
mkdir -p dependencies/downloads
cp "$DATA_SRC/lib/java-sarif-2.1-modified.jar" "$DATA_SRC/Debugger/dbgmodel.tlb" \
  "$DATA_SRC"/FunctionID/*.fidb dependencies/downloads/

# Unreachable but unneeded for REA: the PostgreSQL source tarball (optional BSim
# server rebuild) and Eclipse CDT (GhidraDev development setup). Skip whatever
# cannot be downloaded instead of aborting; every file that is used is hash-checked.
python3 - <<'EOF'
s = open('gradle/support/fetchDependencies.gradle').read()
s = s.replace('''		download(it.url, file)
		if (!OFFLINE) {
			assert(it.sha256.equals(generateHash(file)));
		}''', '''		try {
			download(it.url, file)
			assert(it.sha256.equals(generateHash(file)));
		} catch (Throwable t) {
			println "MISSING: " + it.name + " <- " + it.url
			file.delete()
		}''')
s = s.replace('''deps.each {
	def copier''', '''deps.findAll { new File(DOWNLOADS_DIR, it.name).exists() }.each {
	def copier''')
open('gradle/support/fetchDependencies.lenient.gradle', 'w').write(s)
EOF

MIRROR="$HERE/gradle/maven-mirror.gradle"
# The fetch script ends by configuring the whole build, which can fail on Maven
# Central rate limits; the downloads it needs are done by then, so ignore that.
./gradlew -I gradle/support/fetchDependencies.lenient.gradle -I "$MIRROR" \
  -DhideDownloadProgress --console=plain | grep -E "MISSING|^URL" || true
./gradlew -I "$MIRROR" buildGhidra --console=plain -q

zip="$(ls -t build/dist/ghidra_"${VERSION}"_DEV_*_linux_x86_64.zip | head -1)"
rm -rf "$TOOLS_DIR/ghidra_${VERSION}_DEV"
unzip -q "$zip" -d "$TOOLS_DIR"
export GHIDRA_INSTALL_DIR="$TOOLS_DIR/ghidra_${VERSION}_DEV"
echo "Built $zip"
echo "GHIDRA_INSTALL_DIR=$GHIDRA_INSTALL_DIR"

if command -v rea >/dev/null; then
  rea doctor --provider ghidra
  # Re-running setup writes GHIDRA_INSTALL_DIR and JAVA_HOME into the MCP registration.
  rea setup --all-detected --yes >/dev/null
  echo "REA MCP registration updated; restart Claude Code to load it."
fi
