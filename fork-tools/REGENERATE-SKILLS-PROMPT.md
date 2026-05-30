# Reusable prompt — refresh discoverable skills after an upstream sync

The mxcli maintainer ships skills as flat markdown (`.claude/skills/*.md`,
`.claude/skills/mendix/*.md`). Those are **not** auto-discovered by Claude Code, which only
loads skills shaped as `.claude/skills/<name>/SKILL.md` with a `description` in YAML frontmatter.

`fork-tools/generate-skillmd.sh` wraps each flat skill into a discoverable `SKILL.md`, using
curated descriptions from `fork-tools/skill-descriptions.tsv`. When the maintainer **adds new
skills**, you only need to add their descriptions to the manifest and re-run the script.

## Fast path (no LLM needed — mechanical)

```bash
# 1. See which new flat skills lack a description entry:
fork-tools/generate-skillmd.sh --check

# 2. Add a line per missing skill to fork-tools/skill-descriptions.tsv (TAB-separated):
#    <skill-name><TAB><source-path><TAB><description>
#    - name: lowercase-hyphen; prefix mendix- for skills under .claude/skills/mendix/
#    - description: lead with "Use when…" (this is what Claude matches on)

# 3. Regenerate the discoverable tree:
fork-tools/generate-skillmd.sh
```

## LLM path — paste this to Claude Code

> Run `fork-tools/generate-skillmd.sh --check` to list any flat skill sources that are missing
> from `fork-tools/skill-descriptions.tsv`. For each missing skill: read its source file
> (the path printed by `--check`), then add one TAB-separated line to the manifest with
> `<skill-name>\t<source-path>\t<description>`. Naming rules: lowercase letters/digits/hyphens;
> prefix `mendix-` for sources under `.claude/skills/mendix/`; pick a name that does not collide
> with an existing directory in `.claude/skills/`. Write the description in third person, leading
> with "Use when…", capturing both *what* the skill does and *when* to reach for it (this text is
> what Claude uses to auto-select the skill; keep the combined text well under 1500 chars). When
> every source is covered, run `fork-tools/generate-skillmd.sh` and confirm the new
> `.claude/skills/<name>/SKILL.md` directories were created. Do not edit the flat source files.

## Install to a different scope

```bash
# Project scope (default) — committed to this branch, discovered for this repo:
fork-tools/generate-skillmd.sh

# Personal/global scope — discovered in every project on this machine, never committed:
fork-tools/generate-skillmd.sh --dest ~/.claude/skills
```

## Notes

- The script is **idempotent and safe**: it only removes/overwrites directories it generated
  (tagged with a marker comment) and never touches the flat upstream sources.
- Descriptions live in `skill-descriptions.tsv`, not in the generated files — so a re-run after
  the maintainer edits a skill's *content* keeps your curated descriptions intact.
- Re-run after every `git merge`/rebase from upstream that adds or renames skills.
