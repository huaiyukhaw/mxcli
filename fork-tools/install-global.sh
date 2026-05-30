#!/usr/bin/env bash
#
# install-global.sh — install all mxcli skills into your PERSONAL skills directory
# (~/.claude/skills by default) so Claude Code discovers them in EVERY project on this machine,
# not just this repo.
#
# This is a thin wrapper around generate-skillmd.sh --dest. It is idempotent and safe:
# it only removes/overwrites skill directories it generated itself (marker-tagged), so any
# other personal skills you already have in ~/.claude/skills are left untouched.
#
# Usage:
#   fork-tools/install-global.sh                 # -> ~/.claude/skills
#   fork-tools/install-global.sh /custom/path    # -> /custom/path
#
# Re-run after pulling new skills from upstream (see REGENERATE-SKILLS-PROMPT.md).

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/.claude/skills}"

echo "Installing mxcli skills into: $DEST"
"$DIR/generate-skillmd.sh" --dest "$DEST"
echo
echo "Done. These skills are now discoverable by Claude Code in any project on this machine."
echo "To remove them later, delete the marker-tagged directories under $DEST"
echo "(each generated SKILL.md contains: 'generated-by: fork-tools/generate-skillmd.sh')."
