# review/

Personal assessment notes for `huaiyukhaw/mxcli`. **Not part of upstream** (`mendixlabs/mxcli`).

## Why this folder exists

This is a personal fork that periodically syncs from the official Mendix-maintained repo. To keep
those syncs (`git merge`/rebase from upstream) conflict-free, **all review notes live here, in a
top-level directory that does not exist upstream**. New files in a new directory can't collide with
upstream changes.

## Sync-safety rule

- **Never edit upstream-tracked files** for these reviews (no `docs/`, `CLAUDE.md`, `.claude/`,
  `README.md`, source). Only add files under `review/`.
- If you'd rather these notes never enter git history, exclude them locally via `.git/info/exclude`
  (which is **not** tracked) instead of `.gitignore` (which is). Default here is to commit them on a
  branch so they're versioned.

## Contents

- **`TEMPLATE.md`** — reusable assessment skeleton: the evidence rule, the 3-axis audit
  methodology, the section structure, and a paste-ready re-run prompt.
- **`YYYY-MM-DD-assessment.md`** — dated assessments. Newest is authoritative; older ones are
  history.

## Index of assessments

| Date | File | Notes |
|------|------|-------|
| 2026-05-30 | [`2026-05-30-assessment.md`](2026-05-30-assessment.md) | First review. Themes: LLM authoring reliability (Bucket A vs B), BSON accuracy gate, uneven coverage. Corrected the stale "47/52 domains" figure. |

## How to re-run

Paste the re-run prompt at the bottom of `TEMPLATE.md` into Claude Code, or just say *"refresh the
fork assessment."* It will run the audit and drop a new dated file here. Re-verify counts/citations
after each upstream sync — the code moves faster than the prose docs.

## When you're ready to actually implement something

Pick a recommendation from the latest assessment, then:

1. Re-confirm it's still open against the latest upstream (check `mdl/executor/cmd_*.go` and
   `mdl/grammar/domains/*.g4`, not the prose).
2. For a real feature, consider promoting it into a proper `docs/11-proposals/` proposal (that *is*
   an upstream-tracked area — fine when you intend to contribute upstream), or keep planning notes
   here if they're personal-only.
3. Implement per `.claude/skills/implement-mdl-feature.md`; validate with `mxcli check` + `mx check`.
