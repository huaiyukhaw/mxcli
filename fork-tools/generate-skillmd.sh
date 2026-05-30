#!/usr/bin/env bash
#
# generate-skillmd.sh — make mxcli's flat skill docs discoverable as Claude Code Agent Skills.
#
# Claude Code only auto-discovers skills shaped as `<root>/<name>/SKILL.md` with YAML
# frontmatter (the `description` is what Claude reads to decide when to load a skill).
# mxcli ships its skills as flat `.md` files (e.g. .claude/skills/mendix/write-microflows.md),
# which are NOT discovered. This script wraps each flat source into a discoverable
# `<root>/<name>/SKILL.md`, pulling a curated description from fork-tools/skill-descriptions.tsv.
#
# It is IDEMPOTENT and SAFE: it only ever removes/overwrites directories it created itself
# (tagged with a marker), and it never modifies the upstream-tracked flat source files.
#
# Usage:
#   fork-tools/generate-skillmd.sh                 # generate into .claude/skills/ (project scope)
#   fork-tools/generate-skillmd.sh --dest ~/.claude/skills   # personal/global scope
#   fork-tools/generate-skillmd.sh --check         # audit only: list sources missing a manifest entry
#
# After the repo maintainer adds new flat skills, add their descriptions to the manifest
# (see fork-tools/REGENERATE-SKILLS-PROMPT.md) and re-run this script.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/fork-tools/skill-descriptions.tsv"
DEST="$REPO_ROOT/.claude/skills"
CHECK_ONLY=0
MARKER="<!-- generated-by: fork-tools/generate-skillmd.sh (edit fork-tools/skill-descriptions.tsv, not this file) -->"

# Source skill globs (relative to repo root). README.md is an index, not a skill.
SOURCE_GLOBS=(
  ".claude/skills/*.md"
  ".claude/skills/mendix/*.md"
)
# Extensionless source files that are real skills (missing a .md extension upstream).
EXTRA_SOURCES=(
  ".claude/skills/implement-mdl-bson"
)

# ---- args ----
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }

# ---- 1. audit: which source skills are missing a manifest entry? ----
# Collect manifest source paths.
manifest_sources() { grep -vE '^\s*(#|$)' "$MANIFEST" | awk -F '\t' '{print $2}'; }

all_sources() {
  cd "$REPO_ROOT"
  for g in "${SOURCE_GLOBS[@]}"; do
    for f in $g; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in README.md) continue ;; esac
      echo "$f"
    done
  done
  for f in "${EXTRA_SOURCES[@]}"; do [ -e "$REPO_ROOT/$f" ] && echo "$f"; done
}

missing=0
while IFS= read -r src; do
  if ! manifest_sources | grep -qxF "$src"; then
    echo "MISSING from manifest: $src" >&2
    missing=$((missing+1))
  fi
done < <(all_sources)

if [ "$missing" -gt 0 ]; then
  echo "" >&2
  echo "$missing source skill(s) have no description in $MANIFEST." >&2
  echo "Add them (see fork-tools/REGENERATE-SKILLS-PROMPT.md), then re-run." >&2
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  [ "$missing" -eq 0 ] && echo "All source skills are covered by the manifest. ✓"
  exit 0
fi

# ---- 2. clean previously generated dirs (only those carrying our marker) ----
if [ -d "$DEST" ]; then
  while IFS= read -r skillfile; do
    if grep -qF "$MARKER" "$skillfile" 2>/dev/null; then
      rm -rf "$(dirname "$skillfile")"
    fi
  done < <(find "$DEST" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null)
fi

# ---- 3. generate <DEST>/<name>/SKILL.md from each manifest entry ----
mkdir -p "$DEST"
count=0
while IFS=$'\t' read -r name src desc; do
  # skip comments / blanks
  case "$name" in ''|\#*) continue ;; esac
  [ -n "$src" ] && [ -n "$desc" ] || { echo "bad manifest line for '$name'" >&2; continue; }
  abssrc="$REPO_ROOT/$src"
  if [ ! -f "$abssrc" ]; then
    echo "WARN: source missing, skipping '$name' ($src)" >&2
    continue
  fi
  outdir="$DEST/$name"
  mkdir -p "$outdir"
  {
    printf '%s\n' "---"
    printf 'name: %s\n' "$name"
    # description is single-line in the manifest; emit as a quoted scalar (escape double quotes)
    printf 'description: "%s"\n' "$(printf '%s' "$desc" | sed 's/"/\\"/g')"
    printf '%s\n' "---"
    printf '%s\n\n' "$MARKER"
    # inline the source body, stripping any pre-existing leading YAML frontmatter
    awk 'BEGIN{infm=0; done=0}
         NR==1 && $0=="---" {infm=1; next}
         infm==1 && $0=="---" {infm=0; done=1; next}
         infm==1 {next}
         {print}' "$abssrc"
  } > "$outdir/SKILL.md"
  count=$((count+1))
done < "$MANIFEST"

echo "Generated $count discoverable skills into: $DEST"
echo "Each <name>/SKILL.md inlines its flat source and adds a curated description."
[ "$missing" -gt 0 ] && echo "NOTE: $missing source(s) were skipped (no manifest entry) — see warnings above."
exit 0
