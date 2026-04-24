---
description: Refine a vague ServiceNow request into a precision prompt. Applies a 4-D methodology (Deconstruct, Diagnose, Develop, Deliver) adapted for SN -- forces naming table, scope, update set, domain, and expected persisted change before work begins. Use when the user's request is ambiguous about target record, scope, or expected outcome. Adapted from Lyra (github.com/creativeheadz/Lyra, MIT).
---

Take the user's raw request from $ARGUMENTS (or from the most recent user message if $ARGUMENTS is empty). Walk through the 4-D pipeline below. Do NOT execute any mutations during refinement -- this command only produces a refined prompt for the user to approve.

## Step 1: Deconstruct

Extract and list:
- **Core intent** in one sentence (e.g., "edit the job notes sidebar widget to show the last 5 notes").
- **Explicit entities** named in the request: record names, table hints, field names, URLs.
- **Implicit context**: inferred from the active project's CLAUDE.md, recent conversation, or session context (mobile vs desktop vs UIB? which project scope?).

If the request contains zero actionable nouns ("fix it", "make it better"), stop and ask the user what record or module they mean before continuing.

## Step 2: Diagnose -- SN unknowns checklist

For each item below, mark KNOWN (with value) or UNKNOWN. Infer from CLAUDE.md and session context first; only ask the user about items that remain UNKNOWN.

1. **Table** (sys_class_name) -- e.g., `sp_widget`, `sys_script_include`, `sys_script`.
2. **Record** -- sys_id or unique filter (name=X, number=Y). "New" is a valid value for create operations.
3. **Scope** -- `x_icir_...` vs `global` vs other. Global-scope work often needs a non-Default update set.
4. **Update set** -- name of the active set, or "switch required". Never auto-switch; surface a mismatch and let the user decide.
5. **Domain** -- visibility domain. `#1 cause of "query returned 0 rows"` surprises on domain-separated instances. Call out if unknown.
6. **Operation** -- read-only, create, single-field update, multi-field batch.
7. **Surface** -- desktop form / Service Portal / UX workspace. If UX workspace, UI Policies AND Client Scripts need `ui_type=10` to run.
8. **Expected persisted change** -- what does the DB look like after success? This is the acceptance test.

## Step 3: Develop -- map to the right Agent API tool

Based on the diagnosed Operation:
- **Read** -- `query_records`. Save results to `$instanceDir\agent\tmp\*.json`, read back with `Get-Content -Raw`. Never pipe script fields to console (truncation).
- **Create** -- `create_artifact`. Always include `scope` in params.
- **Single-field update** -- `update_record` with `table`, `sys_id`, `field`, `content`.
- **Multi-field update (widgets)** -- `update_record_batch` with `fields` hashtable.
- **File sync** (when writing local files that sn-scriptsync will push) -- path is `{instance}/{scope}/{table}/{artifact}.{field}.{ext}`. UTF-8 without BOM via `[System.IO.File]::WriteAllText()` + `UTF8Encoding($false)`.
- **REST fallback** -- if `update_record` / `update_record_batch` returns success with zero persistence (silent ACL failure), fall back to a server-side background script early rather than retrying.

## Step 4: Deliver -- the refined prompt

Output in this exact structure, ASCII-only:

```
Goal: <one sentence>
Target: <table> / <sys_id or unique filter, or "new">
Scope: <scope> | Update set: <name or "current"> | Domain: <domain or "user default">
Operation: <read | create | update | batch>
Expected change: <what DB state looks like after success>
Constraints: <ASCII-only, UTF-8 no BOM, ui_type=10 if applicable, any ACL/domain caveats>
Open questions: <any Diagnose item still UNKNOWN; omit section if none>
```

Then ask the user: "Execute this, or hand back for you to edit?" Default to hand-back if any Open questions remain.

## Gotchas

- Don't skip Diagnose even if the request sounds clear. The silent-failure class of SN bugs (wrong domain, wrong update set, empty reference field, ACL-blocked update returning success) hides in the items users don't think to mention.
- If the user has already named all 8 Diagnose items in the raw request, collapse Diagnose to a one-line summary and move straight to Develop.
- Never auto-switch update set. Surface a mismatch, let the user run `/sn-toolkit:switch` themselves.
- This command produces a prompt; it does not execute mutations. Keep it read-only (query_records is fine for inference, create/update/batch is not).
