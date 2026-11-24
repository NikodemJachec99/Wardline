#!/usr/bin/env bash
# Copies every skill from .agents/skills/ (committed, Agent Skills standard)
# to .claude/skills/ (local, git-ignored), because Claude Code only reads
# .claude/skills/. Runs automatically as a Claude Code SessionStart hook
# (.claude/settings.json); safe to run by hand any time.
#
#   bash tools/sync-agent-skills.sh
#
# Edit skills only in .agents/skills/. The copy is overwritten on every run.
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
src="$root/.agents/skills"
dst="$root/.claude/skills"

[ -d "$src" ] || exit 0
mkdir -p "$dst"

# Remove copies of skills that no longer exist in .agents/skills/.
for d in "$dst"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  [ -f "$src/$name/SKILL.md" ] || rm -rf "${dst:?}/$name"
done

for d in "$src"/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name="$(basename "$d")"
  rm -rf "${dst:?}/$name"
  cp -R "$src/$name" "$dst/$name"
done
