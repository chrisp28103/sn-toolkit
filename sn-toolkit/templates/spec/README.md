# Spec Doc Authoring Guide

Each feature spec ships as a two-part HTML + PDF:

- **Part A -- Functional Guide** (stakeholder-facing narrative)
- **Part B -- Technical Specification** (developer/admin reference)

HTML is the editable source of truth; PDFs are rendered artifacts committed alongside.

The `/sn-toolkit:spec` command scaffolds these files for you. This README is the manual fallback / authoring reference.

## Files in this folder

| File | Purpose |
|------|---------|
| `spec-styles.css` | Shared print stylesheet. Tuned for US Letter via headless Chrome. |
| `spec-template.html` | Boilerplate HTML shell. Copy + rename + fill in. |
| `render.ps1` | Headless-browser HTML -> PDF renderer. |

## Quick start (manual)

1. Copy `spec-template.html` to `<feature>/<feature>-part-a-functional.html` (or `-part-b-technical.html`).
2. Edit the placeholders in the `<header class="cover">` block: `{{TITLE}}`, `{{PART_LABEL}}` ("Part A -- Functional" or "Part B -- Technical"), `{{SUBTITLE}}`, `{{VERSION}}`, `{{DATE}}`, `{{PROJECT}}`.
3. Replace the Table of Contents `<ol>` and the body `<section>` elements with real content.
4. Render:

   ```bash
   powershell.exe -ExecutionPolicy Bypass -File <project>/docs/specifications/_template/render.ps1 \
     -InputHtml <project>/docs/specifications/<feature>/<feature>-part-a-functional.html
   ```

5. The PDF lands next to the HTML with the same basename.

## Style primitives (see `spec-styles.css`)

- `<section class="spec-section" id="sN">` with `.page-break` on the class to force a new page
- `<h1 class="section-title"><span class="section-num">N.</span> Title</h1>`
- `<div class="functional-ref">Functional: Section X</div>` for Part B cross-refs
- `<table class="spec-table">` for data tables; add `.role-table` for role/description layouts
- `<ol class="steps">` with `<span class="step-title">` for numbered how-it-works lists
- `<div class="lifecycle">...<div class="step">Step</div><div class="arrow">&rarr;</div>...</div>` for inline process rows
- `<div class="callout why|note|accent">` for "Why This Matters" and neutral notes
- `<div class="figure"><div class="figure-body"><svg>...</svg></div><div class="caption">Figure N -- ...</div></div>`

## Conventions

- ASCII only. No em/en dashes in prose -- use `--`. No curly quotes.
- Cover meta uses the ASCII `|` pipe as separator (already in template). Do not switch back to `&bull;`.
- Doc footer uses `--` instead of `&mdash;` (already in template).
- Lifecycle arrows can use `&rarr;` HTML entities -- they resolve to Unicode that Chrome renders consistently. Do not use entities in prose; prefer ASCII where it reads naturally.
- Diagrams: author in your tool of choice (Mermaid, Excalidraw, draw.io) and export to SVG, then inline the SVG into the HTML so the PDF does not depend on JS.
- Version + date update on every substantive revision.
- Cross-link Part B sections to their Part A counterparts via the `.functional-ref` line.
- Table header rows render as ALL CAPS automatically via `text-transform: uppercase` on `.spec-table thead th`. Do not override per-doc.

## Pre-render ASCII guard

Before rendering, run a non-ASCII check on the HTML:

```bash
# returns zero matches if the file is clean
grep -P "[^\x00-\x7F]" <feature>/<file>.html
```

If this returns lines, replace the offending characters with ASCII equivalents (`--`, `'`, `"`, `|`).

## Recommended Part A section outline (functional)

1. Overview / problem this solves
2. Roles and responsibilities
3. End-to-end lifecycle (with diagram)
4. Detailed workflow steps
5. Business rules and edge cases
6. Configuration / admin surface
7. Reporting / observability
8. Future considerations / open questions

## Recommended Part B section outline (technical)

1. System overview / architecture diagram
2. Data model (tables, fields, choice values)
3. Server-side artifacts (Script Includes, BRs, Scheduled Jobs, etc.)
4. Client-side artifacts (Client Scripts, UI Policies, Widgets)
5. Integrations / external surfaces
6. Security model (ACLs, roles, domain visibility)
7. Operational notes (deployment, rollback, observability)
8. Known gaps / technical debt
9. References (sys_ids, file paths, related KIs)
