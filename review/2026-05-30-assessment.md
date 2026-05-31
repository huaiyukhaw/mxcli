# mxcli Assessment — 2026-05-30

> **Scope.** A point-in-time review of this fork (`huaiyukhaw/mxcli`, upstream `mendixlabs/mxcli`)
> focused on two questions: (1) how extensible/accurate is mxcli for *building* Mendix apps, and
> (2) how reliably can an LLM (Claude Code) *drive* mxcli.
>
> **Evidence rule.** Every capability claim cites a fact in the code (`file:line`) or a doc path.
> Where prose docs disagree with the code, the code wins and the discrepancy is flagged. This
> document was produced by a direct audit, not by trusting summaries — see §0 for why that matters.

---

## 0. Read this first: corrections to "common knowledge"

A first exploration pass (sub-agent summaries) produced claims that a citation check disproved.
These are corrected up front because they change the conclusions:

| Claim seen in prose / summaries | Reality in code | Citation |
|---|---|---|
| "47 of 52 metamodel domains not implemented" | **Stale.** The executor ships **93 non-test command-handler files** covering far more than 5 domains (JSON structures, import/export mappings, JavaScript actions, data transformers, image collections, fragments, agent editor, contracts, …). | `CLAUDE.md:503` (the stale line) vs. `ls mdl/executor/cmd_*.go` (93 non-test files) |
| "No 'did you mean?' suggestions in errors" | **False.** Suggestion hints exist in validation. | `mdl/executor/validate.go:220-222`; `mdl/executor/validate_widgets.go:135` |
| "~11 skills" | **53** skills in the Mendix bundle alone. | `ls .claude/skills/mendix/*.md` → 53 |

Takeaway: when judging mxcli capability, audit `mdl/executor/cmd_*.go`, `mdl/grammar/domains/*.g4`,
and `mdl-examples/` — not the narrative in `CLAUDE.md` or the proposals, which lag the code.

---

## 1. Executive summary

mxcli is a Go-native "SQL for Mendix models": an MDL language (ANTLR4 grammar → AST → visitor →
executor → backend → BSON) that reads and mutates `.mpr` files offline, wrapped in a deliberate
agentic layer (skills, slash commands, LSP, linter). It is unusually mature.

Three themes govern its fitness for the user's goals:

- **LLM authoring reliability** — *why Claude writes invalid MDL.* Two distinct causes with two
  distinct fixes (§3): **Bucket A** = the construct exists but Claude assumed the wrong syntax →
  fix with skills/examples/error messages; **Bucket B** = the construct genuinely isn't supported →
  fix by implementing it. Diagnosing which bucket a failure falls in is the single highest-leverage
  habit, and the tooling to do that diagnosis already exists (`mxcli check`).
- **Accuracy** — BSON serialization is hand-written with no automated "does it open in Studio Pro?"
  gate, so a class of bugs is silent until Studio Pro rejects the file (§5).
- **Coverage** — broad but uneven; a precise "still genuinely missing" list is in §3 Bucket B / §5.

---

## 2. Architecture at a glance

Pipeline (each stage is a real package):

`mdl/grammar/*.g4` (+ 9 domain grammars in `mdl/grammar/domains/`) → `mdl/ast/` → `mdl/visitor/`
→ `mdl/executor/cmd_*.go` → `mdl/backend/` interfaces → `mdl/backend/mpr/` → `sdk/mpr/` (BSON).

- **Statement shape** is `(ddlStatement | dqlStatement | utilityStatement)` — i.e. `create`/`alter`/
  `drop` (DDL), `select`/`show`/`describe` (DQL), plus utilities — see `mdl/grammar/MDLParser.g4:39`
  and `:46-49`.
- **Grammar is modular**: 9 domain files (`Agent`, `Catalog`, `DomainModel`, `Microflow`, `Page`,
  `Security`, `Service`, `Settings`, `Workflow`) — `ls mdl/grammar/domains/*.g4`. **A document type
  with no domain grammar cannot be written at all** — this is the cleanest signal of Bucket B.
- **Backend abstraction** keeps BSON out of the executor; a Mock backend backs unit tests
  (`mdl/backend/mock/`, `mdl/backend/mpr/`).
- **Codegen emits *types only*** from reflection data (`internal/codegen/`, `generated/metamodel/`,
  `reference/mendixmodellib/reflection-data/`). Parsers, visitor rules, and handlers are hand-written
  — so adding a construct is mostly manual work, not generated.
- **Catalog**: SQLite metadata queryable via `select … from CATALOG.*` (`mdl/catalog/tables.go`).
- **Version awareness**: `sdk/versions/mendix-{9,10,11}.yaml` + `checkFeature()`
  (`mdl/executor/cmd_features.go:17`) + `show features`.

**Scale (verified counts):** 93 non-test executor handlers + 104 handler test files;
321 `_test.go` files repo-wide; 43 example scripts in `mdl-examples/doctype-tests/`; 65 regression
scripts in `mdl-examples/bug-tests/`; 53 Mendix skills + 10 Mendix slash commands; 90 proposal docs
in `docs/11-proposals/`.

---

## 3. Why Claude writes invalid MDL (the core question)

When Claude + mxcli produces an invalid script, the failure is almost always one of two kinds.
**Diagnose the bucket first** — the fix is completely different.

### Decision aid

```
MDL rejected (mxcli check fails)
        │
        ├─ Is the construct in the grammar/handler?
        │   (grep mdl/grammar/domains/*.g4 and mdl/executor/cmd_*.go)
        │
        ├── YES → Bucket A: Claude assumed wrong syntax.
        │         Fix = better skill / example / error message. No Go code needed.
        │
        └── NO  → Bucket B: mxcli genuinely can't express it.
                  Fix = implement it (grammar→AST→visitor→executor→backend), or
                        tell Claude to use a supported alternative.
```

`mxcli check script.mdl` (`cmd/mxcli/cmd_check.go`) is the right first move every time — it parses
and validates without a project, and with `-p app.mpr --references` also resolves names.

### Bucket A — Misunderstanding (fix with skills / examples / error messages)

The grammar supports it; Claude guessed wrong. mxcli already has substantial guardrails here, which
means the *remaining* failures are gaps in coverage of those guardrails, not missing machinery:

- **Validation that already nudges the model toward correct syntax:**
  - Enumeration/module-prefix mistakes produce an actionable hint, including a literal "Did you mean"
    — `mdl/executor/validate.go:220-222`.
  - Widget-name typos get a "did you mean `X`?" suggestion — `mdl/executor/validate_widgets.go:135`.
  - Microflow body validation (variable scope, returns) — `mdl/executor/cmd_microflows_builder_validate.go`.
  - LSP surfaces the same semantic checks in-editor — `cmd/mxcli/lsp_diagnostics.go:143` (`runSemanticCheck`), `:184` (`parseSemanticCheckOutput`).
  - Typed errors carry structure for precise messaging — `mdl/errors/errors.go` (`NotFoundError`,
    `AlreadyExistsError`, `ValidationError`, `UnsupportedError`, `BackendError`).
- **Skills that already teach syntax & error recovery** (`.claude/skills/mendix/`, 53 files): e.g.
  `cheatsheet-errors.md`, `cheatsheet-variables.md`, `check-syntax.md`, `validation-microflows.md`,
  `resolve-forward-references.md`, `write-microflows.md`, `write-nanoflows.md`, `create-page.md`,
  `json-structures-and-mappings.md`.

**Where Bucket A still bites (the improvement target):** coverage is uneven. There are 93 handlers
but only 43 example scripts (`mdl-examples/doctype-tests/`), so some shipped commands have no
canonical example for Claude to pattern-match against, and some `UnsupportedError` messages state
*what* failed without showing the *correct* form. The cheapest, highest-yield fix for the user's
exact pain is therefore: **(a) one canonical example per handler, (b) a skill per shipped document
type, and (c) richer error messages that print a minimal correct snippet** — not new engine work.

### Bucket B — Genuinely unsupported (needs implementation)

Real Mendix constructs that have **no domain grammar and no dedicated handler**, so Claude *cannot*
produce valid MDL no matter how it's prompted. Verified absent (no `cmd_*.go` handler file; no
matching domain grammar):

| Mendix document type | Evidence it's missing | Real-world frequency |
|---|---|---|
| **Rules** (`microflows$rule`) | no `cmd_rules.go` | 55 across 3 sample apps — `docs/11-proposals/PROPOSAL_missing_capabilities.md` |
| **Message definitions** | no dedicated handler | 33 — same proposal |
| **Regular expressions** | no handler, no grammar match | 16 — same proposal |
| **Scheduled events** | no `cmd_scheduledevents.go` (only referenced incidentally in `cmd_structure.go`/`cmd_settings.go`) | — |
| **Menu documents** | no handler/grammar | 7 — same proposal |
| **Building blocks** | no handler/grammar | — (`docs/11-proposals/show-describe-building-blocks.md`) |
| **Queues** | no dedicated handler | 5 — same proposal |

**Already supported (do NOT mistake for Bucket B):** JSON structures (`cmd_jsonstructures.go`,
example `mdl-examples/doctype-tests/20-json-structure-examples.mdl`), import/export mappings
(`cmd_import_mappings.go`, `cmd_export_mappings.go`, example `21-import-export-mapping-examples.mdl`),
published REST services (example `22-published-rest-service-examples.mdl`), data transformers
(`cmd_datatransformer.go`, example `23-…`), workflows (example `24-…`), JavaScript actions
(`cmd_javascript_actions.go`), agent editor (`cmd_agenteditor_*.go`, examples `27-`/`28-`).

**Shallow (supported but read-only or partial)** — Claude can read but not author:
- **Layouts**: SHOW only — `mdl/executor/cmd_layouts.go:15` defines `listLayouts` and nothing else
  (matches `docs/01-project/MDL_FEATURE_MATRIX.md` row: SHOW=Y, CREATE/ALTER/DROP=N).
- Many types lack `CREATE OR MODIFY` and Starlark/catalog dimensions — see the matrix's own
  "Gaps and Priorities" section.

---

## 4. What's covered (strengths)

- **Deep, well-tested domains**: entities/associations, enumerations, microflows (60+ activities,
  builders split across `cmd_microflows_builder_*.go`), nanoflows, pages/snippets, security, OData,
  workflows, navigation, project settings; plus external SQL / import / connector generation. Cross-
  checked against the 17-dimension `docs/01-project/MDL_FEATURE_MATRIX.md`.
- **Newer handlers** beyond the "core 5": JSON structures, import/export mappings, JavaScript
  actions, data transformers, image collections, fragments, agent editor, contracts, business
  events, db connections, languages, constants, folders (all present as `cmd_*.go`).
- **Testing breadth**: 321 `_test.go` files; 104 executor handler tests (MockBackend-based); 43
  example scripts; 65 regression scripts in `mdl-examples/bug-tests/`.
- **Agentic surface**: 53 Mendix skills, 10 slash commands, LSP + VS Code extension, version-gating
  via `sdk/versions/*.yaml` + `checkFeature` + `show features`.
- **Self-documentation**: `CLAUDE.md` operating manual, the feature matrix, `docs-site/`, and 90
  proposals — though note §0: the prose lags the code, so verify before quoting.

---

## 5. Gaps

### Accuracy (highest risk)
BSON serialization is hand-written with no schema validation. Storage-name vs qualified-name
mismatches, inverted `ParentPointer`/`ChildPointer` semantics, and numeric field-width bugs are
**silent** — they surface only as `TypeCacheUnknownTypeException` / CE0463 / CE0066 when Studio Pro
opens the file. Recent history confirms the pattern: commits fixing #583 and #585 ("parse numeric
BSON fields across all numeric widths") in `git log`. There is **no CI gate that opens a generated
`.mpr` in Studio Pro / mxbuild across Mendix versions**, and widget templates are pinned to roughly
one minor version. Existing proposals already scope a fix: `docs/11-proposals/BSON_SCHEMA_REGISTRY_PROPOSAL.md`,
`UNIFIED_SCHEMA_REGISTRY.md`, `PROPOSAL_schema_extract.md`, `PROPOSAL_mcp_bson_benchmark.md`,
`docs/plans/2026-03-22-bson-discover-tool-design.md`.

### Coverage (corrected; see §3 Bucket B)
Genuinely missing: rules, message definitions, regular expressions, scheduled events, menu
documents, building blocks, queues. Plus missing matrix dimensions (`CREATE OR MODIFY`, catalog
tables, Starlark APIs) for several shipped types. The `docs/11-proposals/show-describe-*.md` series
already scopes most of these.

### Agentic loop
No single autonomous **validate → diagnose → fix → re-check** command/skill that chains
`mxcli check --references` with `mx check` and feeds structured fixes back. Today the model must
manually consult the cheatsheet skills. Existing proposals: `PROPOSAL_llm_mdl_assistance.md`,
`PROPOSAL_agentic_architecture_improvements.md`, `PROPOSAL_version_aware_agent_support.md`,
`PROPOSAL_project_brain.md`, `proposal-eval-framework.md`.

---

## 6. Planned work already in the repo (don't duplicate)

| Gap (this doc) | Already proposed in-repo |
|---|---|
| BSON accuracy gate | `BSON_SCHEMA_REGISTRY_PROPOSAL.md`, `UNIFIED_SCHEMA_REGISTRY.md`, `PROPOSAL_schema_extract.md`, `PROPOSAL_mcp_bson_benchmark.md`, `docs/plans/2026-03-22-bson-discover-tool-design.md` |
| Rules / scheduled events / message defs / regex / menus / building blocks / queues | `show-describe-rules.md`, `show-describe-scheduled-events.md`, `show-describe-message-definitions.md`, `show-describe-regular-expressions.md`, `show-describe-menu-documents.md`, `show-describe-building-blocks.md`, `show-describe-queues.md` |
| Autonomous agentic fix loop | `PROPOSAL_llm_mdl_assistance.md`, `PROPOSAL_agentic_architecture_improvements.md`, `proposal-eval-framework.md` |
| Missing-capabilities baseline | `PROPOSAL_missing_capabilities.md` (gap data from 3 real Mendix 11.6.3 apps) |
| Open TODOs (multi-version, custom-widget plugin, extensions skill, page-flow viz) | `docs/todo.md` |

---

## 7. Prioritized recommendations

Ordered to attack the user's stated pain (Claude writing invalid MDL) first.

1. **Close Bucket A coverage — skills/examples/error-messages for shipped features.** *(Highest yield,
   lowest cost; no engine work.)* Ensure every `mdl/executor/cmd_*.go` handler has (a) one canonical
   `mdl-examples/doctype-tests/` example and (b) a `.claude/skills/mendix/` skill; extend
   `UnsupportedError`/`ValidationError` messages to print a minimal correct snippet and "did you
   mean?" where feasible (build on `validate.go:220`, `validate_widgets.go:135`). *Effort: S–M, incremental.*
2. **BSON accuracy gate.** Verify `$Type` and numeric field-widths against
   `reference/mendixmodellib/reflection-data/`, plus a headless `mx check` regression harness across
   Mendix 9/10/11 in CI. Builds on the schema-registry proposals; would have caught #583/#585 automatically. *Effort: M–L.*
3. **Autonomous `/validate-and-fix` skill/command.** Chain `mxcli check --references` → classify
   error (Bucket A vs B) → apply fix or report → re-check. Automates §3's decision aid. *Effort: M.*
4. **Implement genuinely-missing high-value types (Bucket B).** Start with **rules** and **scheduled
   events** (frequent, well-defined in reflection data) per the `show-describe-*` proposals, using
   the `.claude/skills/implement-mdl-feature.md` layer-by-layer recipe. *Effort: M each.*
5. **Fill matrix dimensions for shipped features** (`CREATE OR MODIFY`, catalog tables, Starlark
   APIs). Cheap ergonomics wins per `MDL_FEATURE_MATRIX.md` §"Gaps and Priorities". *Effort: S each.*

---

## 8. How to act on this in the fork

1. Pick a recommendation from §7.
2. Re-confirm it's still open against the **latest upstream** (`mendixlabs/mxcli`) — the prose lags
   the code, so check `mdl/executor/cmd_*.go` and `mdl/grammar/domains/*.g4` before starting.
3. Branch, implement per `.claude/skills/implement-mdl-feature.md` (grammar → AST → visitor →
   executor → backend → tests → example → skill).
4. Validate with `mxcli check` (+ `--references`) and `mx check` against a real project before PR.

---

*Generated for the fork. To refresh, see `review/TEMPLATE.md`. Counts and citations verified
against the working tree on 2026-05-30; re-verify after syncing upstream.*
