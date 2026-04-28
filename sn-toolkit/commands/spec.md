---
description: Produce a stakeholder-grade two-part specification document set (Part A Functional + Part B Technical) for any topic. Topic-agnostic. Walks the user through scoping, optional ServiceNow artifact pulls (--with-sn-pulls), drafting, ASCII-validating, and rendering to PDF via headless Chrome. Use when the user says "write specs for X", "build a functional + technical spec", or wants durable feature documentation matching the proven Part A/B PDF format.
model: sonnet
effort: high
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

This command produces two PDFs (Part A functional + Part B technical) for a single feature/topic. It is **topic-agnostic** -- works for ServiceNow features, generic software features, processes, integrations, or any subject that benefits from a stakeholder-grade Part A + developer-grade Part B pair.

`$ARGUMENTS` may include:
- A topic slug (e.g. `route-stops`) -- if missing, ask the user.
- `--with-sn-pulls` -- enables the optional ServiceNow artifact-extraction phase before drafting Part B. Skip for non-SN topics.
- `--part a` or `--part b` -- only produce one part. Default is both.

If $ARGUMENTS is empty, ask: "What feature or topic should I spec? (e.g. `csat-surveys`, `route-stops`, `sso-onboarding`) Optional flags: `--with-sn-pulls`, `--part a|b`."

## Phase 0: Bootstrap (one-time per project)

Check whether the project already has `docs/specifications/_template/` populated:

```bash
ls docs/specifications/_template/spec-template.html 2>/dev/null
```

If missing, copy the templates from the plugin into the project:

```bash
mkdir -p docs/specifications/_template
cp "${CLAUDE_PLUGIN_ROOT}/templates/spec/spec-template.html" docs/specifications/_template/
cp "${CLAUDE_PLUGIN_ROOT}/templates/spec/spec-styles.css" docs/specifications/_template/
cp "${CLAUDE_PLUGIN_ROOT}/templates/spec/render.ps1" docs/specifications/_template/
cp "${CLAUDE_PLUGIN_ROOT}/templates/spec/README.md" docs/specifications/_template/
```

If the project already has these files, **do not overwrite them** -- the project may have local style tweaks worth preserving. Tell the user the templates already exist.

## Phase 1: Scope and Outline

Confirm with the user before drafting:

1. **Topic title** -- the human-readable feature name (e.g. "CSAT Surveys", "Route Stops & Checklists").
2. **Subtitle** -- one-line elevator description.
3. **Project / scope label** -- what goes in the cover-meta line (e.g. "Zero Vector (x_icir_zero_vector)" or "TradePro Mobile" or "Internal -- Platform Team").
4. **Version + date** -- default to `1.0` and today's date if unspecified.
5. **Part A or Part B or both** -- default both.
6. **Section outline** -- propose section titles for each part. Use the recommended outlines below as a starting point; tailor to the topic. Do not draft body content yet -- get the outline approved first.

### Recommended Part A outline (functional, stakeholder-facing, ~6-12 pages)

1. Overview / problem this solves
2. Roles and responsibilities
3. End-to-end lifecycle (with diagram)
4. Detailed workflow steps
5. Business rules and edge cases
6. Configuration / admin surface
7. Reporting / observability
8. Future considerations / open questions

### Recommended Part B outline (technical, developer-facing, ~8-16 pages)

1. System overview / architecture diagram
2. Data model (tables, fields, choice values)
3. Server-side artifacts (or backend logic for non-SN topics)
4. Client-side artifacts (or frontend / UI layer)
5. Integrations / external surfaces
6. Security model (ACLs, roles, domain visibility, or auth model for non-SN)
7. Operational notes (deployment, rollback, observability)
8. Known gaps / technical debt
9. References (sys_ids, file paths, related docs)

Tailor freely. Drop or merge sections that do not apply to the topic. Do not pad.

## Phase 2: Authoring data (optional, --with-sn-pulls only)

If the user passed `--with-sn-pulls`, pull current SN artifact state into `scratch/fresh-<slug>-*.json` before drafting Part B. This anchors the technical spec to reality at draft time.

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup". For each artifact in scope, run:

```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"; query = "<encoded_query>"; fields = "<comma_separated>"
}
$r.result | ConvertTo-Json -Depth 8 | Out-File -Encoding ASCII "scratch/fresh-<slug>-<artifact>.json"
```

Confirm the artifact list with the user first (Script Includes, BRs, Client Scripts, Widgets, Scheduled Jobs, UI Pages, UI Policies, table dictionaries -- whichever apply).

**Anti-truncation:** Never copy script bodies from console output -- always read from the JSON file via `Read` tool. See [project CLAUDE.md] critical rule 6.

For non-SN topics, skip this phase entirely. The drafter should rely on whatever source-of-truth the user points to (codebase, design docs, runtime config).

## Phase 3: Scaffold the spec files

For each part being produced, copy the template and substitute the cover-block placeholders:

```bash
mkdir -p docs/specifications/<slug>

# Part A (skip if --part b)
cp docs/specifications/_template/spec-template.html \
   docs/specifications/<slug>/<slug>-part-a-functional.html

# Part B (skip if --part a)
cp docs/specifications/_template/spec-template.html \
   docs/specifications/<slug>/<slug>-part-b-technical.html
```

Replace the `{{...}}` placeholders in each new file using the `Edit` tool:

| Placeholder | Replace with |
|-------------|--------------|
| `{{TITLE}}` | Topic title from Phase 1 |
| `{{PART_LABEL}}` | "Part A -- Functional" or "Part B -- Technical" |
| `{{SUBTITLE}}` | Subtitle from Phase 1 |
| `{{VERSION}}` | Version (default `1.0`) |
| `{{DATE}}` | Today's date (`YYYY-MM-DD`) |
| `{{PROJECT}}` | Project / scope label from Phase 1 |

Then replace the example TOC `<ol>` and the example `<section>` blocks with the agreed Phase 1 outline (skeleton only -- empty section bodies are fine for now).

## Phase 4: Draft Part A (functional)

Goal: a stakeholder-facing narrative -- the kind of doc a product owner, executive, or new joiner could read end-to-end and walk away knowing what the feature does, who uses it, and why.

Style:
- Prose paragraphs over bullet vomit. Bullets are fine for enumerations, not arguments.
- Each section opens with a brief intro paragraph before tables/lists.
- Use `<div class="callout why">` for "Why This Matters" notes that explain non-obvious design decisions.
- Use `<div class="lifecycle">` blocks to render process rows visually.
- Use `<table class="spec-table role-table">` for role responsibility tables.
- Use `<ol class="steps">` for numbered how-it-works walkthroughs (with `<span class="step-title">`).

ASCII-only. No `&bull;`, no `&mdash;` in prose. The lifecycle `&rarr;` arrows are fine -- they resolve to Unicode at render time.

## Phase 5: Draft Part B (technical)

Goal: a developer/admin reference -- the kind of doc a new engineer or platform admin can use to understand, extend, debug, or operate the feature.

Style:
- Cross-link each section to its Part A counterpart via `<div class="functional-ref">Functional: Section N</div>`.
- Tables for data model fields (one row per field), with `<code>` wrapping field/table names.
- Code blocks via `<pre>...</pre>` for representative scripts -- short snippets, not full file dumps.
- Document **sys_ids and file paths** for every named artifact -- this is what makes the doc useful 6 months later.
- Section titled "Known Gaps" is mandatory. List anything that's intentionally disabled, partially built, or known-broken with `active=false` flags.

If you ran `--with-sn-pulls` in Phase 2, draft from the `scratch/fresh-<slug>-*.json` files via `Read`. Never paraphrase from memory of the codebase.

## Phase 6: ASCII guard + render

Before rendering, run the ASCII guard on each HTML file:

```bash
grep -P "[^\x00-\x7F]" docs/specifications/<slug>/<slug>-part-a-functional.html
grep -P "[^\x00-\x7F]" docs/specifications/<slug>/<slug>-part-b-technical.html
```

Both must return zero matches. If they don't, fix the offending character (em/en dash, curly quote, bullet) before rendering.

Render each part:

```bash
powershell.exe -ExecutionPolicy Bypass \
  -File docs/specifications/_template/render.ps1 \
  -InputHtml docs/specifications/<slug>/<slug>-part-a-functional.html

powershell.exe -ExecutionPolicy Bypass \
  -File docs/specifications/_template/render.ps1 \
  -InputHtml docs/specifications/<slug>/<slug>-part-b-technical.html
```

PDFs land next to the HTML with the same basename.

## Phase 7: Final report

Tell the user:
- Files written (HTML + PDF paths).
- Page counts (run `Get-Item` on each PDF, divide rough byte size by ~30KB to estimate pages, or just open the PDF).
- Any sections you flagged as "verify before sign-off" -- e.g. choice values you couldn't pull, ACLs you couldn't query.
- Suggested next step: review pass, feedback round, or sign-off.

Do not commit, do not push. Spec docs are deliverables; the user decides when to commit.

## Gotchas

- **Do not auto-overwrite an existing spec folder.** If `docs/specifications/<slug>/` already exists with content, ask the user first -- they may be revising and want their content preserved. Default to "show me the diff" rather than blowing it away.
- **Do not invent sys_ids, table names, or field counts** for SN topics. If a fact isn't in `scratch/fresh-*` or the user didn't tell you, mark it as `<TBD>` in the HTML and call it out in Phase 7. Inventing facts is the fastest way to lose stakeholder trust.
- **Do not pad to hit page counts.** A clear 6-page Part A beats a padded 12-page one. The recommended ranges are guidance, not targets.
- **Do not use the `&bull;` separator** in cover-meta -- the template ships with `|` for a reason (ASCII safety). Same for `&mdash;` in the doc-footer (`--` instead).
- **Do not modify the shared `spec-styles.css` per-doc.** If a style tweak is genuinely needed, do it project-wide so all specs stay visually consistent.
- **Do not render with `--no-pdf-header-footer`.** Chrome's per-page header + page-counter footer is intentional; matches the established standard.
- **Verify before each render** that the HTML's `<link rel="stylesheet" href="../_template/spec-styles.css" />` path resolves -- it assumes the spec lives one folder deep under `docs/specifications/`.
