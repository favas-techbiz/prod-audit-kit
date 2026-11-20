#!/usr/bin/env bash
# Manual installer for Production Audit Kit (alternative to the plugin install).
# Usage: ./install/install.sh            -> installs for all projects (~/.claude)
#        ./install/install.sh /path/repo -> installs into one project (<repo>/.claude)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/plugins/prod-audit-kit"
TARGET="${1:-$HOME}/.claude"

mkdir -p "$TARGET/agents" "$TARGET/skills" "$TARGET/prod-audit/checklists"
cp "$SRC"/agents/*.md "$TARGET/agents/"
for s in prod-audit prod-fix; do
  rm -rf "$TARGET/skills/$s"
  cp -R "$SRC/skills/$s" "$TARGET/skills/$s"
done
echo "Installed Production Audit Kit into $TARGET"
echo "Put your own checklists in $TARGET/prod-audit/checklists/ (kept across updates)."
echo "Restart Claude Code, then type /prod-audit"
