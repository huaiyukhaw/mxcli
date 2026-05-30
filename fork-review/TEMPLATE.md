# mxcli Fork Assessment — TEMPLATE

> Copy this file to `fork-review/YYYY-MM-DD-assessment.md` and fill it in. This template encodes the
> methodology and the evidence rule so each re-run is consistent and trustworthy.

## The evidence rule (non-negotiable)

- **Every capability claim cites a fact** in the code (`file:line`) or a doc path.
- **Code beats prose.** Where `CLAUDE.md`, the feature matrix, or proposals disagree with the
  handlers/grammar, the code is authoritative — and the discrepancy is flagged in §0.
- **No assumptions, no hallucination.** If you can't cite it, don't claim it.

## Methodology — 3-axis audit

Run these fact-gathering steps before writing a word. They are the source of every count/citation.

```bash
# Axis 1 — capability surface (what mxcli can express)
ls mdl/executor/cmd_*.go | grep -v _test | wc -l        # non-test handlers
ls mdl/grammar/domains/*.g4                             # which domains are parseable at all
grep -ril "<construct>" mdl/executor/cmd_*.go           # is a given type handled?

# Axis 2 — LLM authoring reliability (why invalid MDL happens)
ls .claude/skills/mendix/*.md      | wc -l               # skills coverage
ls mdl-examples/doctype-tests/*.mdl | wc -l              # canonical examples
ls mdl-examples/bug-tests/         | wc -l               # regression coverage
grep -rn "did you mean\|Did you mean" mdl/executor/      # existing self-correction hints
sed -n '1,160p' mdl/errors/errors.go                     # error types available for messaging

# Axis 3 — accuracy & testing (does output actually open in Studio Pro)
git log --oneline -20                                    # recent fixes (BSON width, type names…)
ls sdk/versions/*.yaml                                   # version-gating registry
ls docs/11-proposals/*.md ; ls docs/plans/*.md ; cat docs/todo.md   # planned work
```

Always classify failures into **Bucket A** (construct exists → skill/example/error-message gap) vs
**Bucket B** (no grammar/handler → implementation gap). A type with no `mdl/grammar/domains/*.g4`
rule and no `cmd_*.go` handler is Bucket B by definition.

## Section skeleton (mirror the dated assessment)

0. **Corrections to "common knowledge"** — table of prose-vs-code discrepancies found this run.
1. **Executive summary** — the 2–3 themes that matter this run.
2. **Architecture at a glance** — pipeline + verified counts, each cited.
3. **Why Claude writes invalid MDL** — decision aid + Bucket A (with the still-biting gaps) +
   Bucket B (verified-missing table with citations) + Shallow/read-only list.
4. **What's covered (strengths)** — re-derived from handlers + matrix, cited.
5. **Gaps** — Accuracy / Coverage / Agentic loop, each with citations + linked proposals.
6. **Planned work already in the repo** — gap → existing proposal/plan/TODO mapping (don't duplicate).
7. **Prioritized recommendations** — ordered by leverage; each names effort + the proposal it builds
   on + the `implement-mdl-feature.md` layers it touches.
8. **How to act on this in the fork** — pick → re-confirm vs upstream → branch → implement → validate.

## Re-run prompt (paste to Claude Code)

> Explore the mxcli repo and refresh the fork assessment. Follow `fork-review/TEMPLATE.md`: run the
> 3-axis audit, obey the evidence rule (cite `file:line`, code beats prose, flag stale docs),
> classify invalid-MDL causes into Bucket A vs B, and save the result to
> `fork-review/YYYY-MM-DD-assessment.md`. Do **not** edit any upstream-tracked file — only add files
> under `fork-review/`, so the fork stays cleanly syncable from `mendixlabs/mxcli`.
