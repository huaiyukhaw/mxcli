# fork-tools/

Personal tooling for this fork of `huaiyukhaw/mxcli`. Adds nothing to upstream behaviour — it only
makes mxcli's existing skill docs **discoverable** by Claude Code.

## The problem this solves

mxcli ships its skills as flat markdown:

- `.claude/skills/*.md` (repo/dev skills)
- `.claude/skills/mendix/*.md` (52 MDL skills)

Claude Code only **auto-discovers** skills shaped as `.claude/skills/<name>/SKILL.md` with a
`description` in YAML frontmatter. The flat files are *not* discovered, so Claude only learned about
the ~13 skills explicitly named in `CLAUDE.md`; the rest of the catalogue was invisible and Claude
would proceed without the right reference (a common cause of invalid MDL).

## What's here

| File | Purpose |
|------|---------|
| `skill-descriptions.tsv` | Curated `name` + `description` for every skill. **Source of truth for descriptions.** Edit this. |
| `generate-skillmd.sh` | Wraps each flat skill into a discoverable `.claude/skills/<name>/SKILL.md`. Idempotent & safe. |
| `install-global.sh` | One-liner that installs the skills into `~/.claude/skills` (every project on this machine). |
| `REGENERATE-SKILLS-PROMPT.md` | Mechanical steps + an LLM prompt to refresh after the maintainer adds skills. |

## What it generated

`.claude/skills/<name>/SKILL.md` for all **61** skills (8 dev + 1 `implement-mdl-bson-storage` +
52 `mendix-*`). Each file = curated `name`/`description` frontmatter + the flat source's body
inlined. Mendix skills are prefixed `mendix-` to avoid clashing with the dev skills (e.g.
`debug-bson` vs `mendix-debug-bson`).

```bash
fork-tools/generate-skillmd.sh            # (re)generate into .claude/skills/  (project scope)
fork-tools/generate-skillmd.sh --check    # audit: list flat sources missing a description
fork-tools/install-global.sh              # install into ~/.claude/skills (every project)
fork-tools/install-global.sh /custom/dir  # ...or a custom personal skills dir
```

Global install is the recommended setup for personal use: run `fork-tools/install-global.sh` once,
and these skills are discoverable in every Mendix project you open — re-run it after pulling new
skills from upstream. It only touches its own marker-tagged directories, so other personal skills in
`~/.claude/skills` are left alone.

## Design choices (so it stays sync-friendly)

- **Flat sources are never modified.** The script reads them; it does not rename or edit them. So
  `git merge`/rebase from upstream stays clean for the source files.
- **Idempotent regeneration.** Each generated `SKILL.md` carries a marker comment; a re-run removes
  only marker-tagged directories before regenerating. It never deletes anything it didn't create.
- **Descriptions live in the manifest, not the generated files** — so re-running after the
  maintainer edits a skill's *content* preserves your curated "Use when…" triggers.
- **Tooling is isolated in `fork-tools/`** (a directory that doesn't exist upstream), the same
  fork-safety pattern as `fork-review/`.

## When the maintainer adds new skills

1. `fork-tools/generate-skillmd.sh --check` → lists any flat skill with no description.
2. Add a line to `skill-descriptions.tsv` (or paste the prompt in `REGENERATE-SKILLS-PROMPT.md`
   to have Claude write the descriptions).
3. `fork-tools/generate-skillmd.sh` → regenerates the discoverable tree.

## Note on the generated directories

The `.claude/skills/<name>/` directories are a **generated artifact** committed for convenience so
the branch works out of the box. They can be regenerated at any time from the flat sources +
manifest. If you'd rather not track them, add `\.claude/skills/*/SKILL.md` to `.git/info/exclude`
(local, untracked) and just run the script after each clone/sync.
