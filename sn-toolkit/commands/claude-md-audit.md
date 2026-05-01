---
description: Audit CLAUDE.md against the live ServiceNow instance -- flag stale references (tables, scopes, sys_ids, file paths) that no longer exist. Use to catch CLAUDE.md drift after schema changes, scope renames, or deprecation cycles.
model: sonnet
effort: medium
allowed-tools: [Read, Glob, Grep, Bash]
---

## Purpose

CLAUDE.md is loaded into every session. When it references tables/scopes/scripts/sys_ids that no longer exist (renamed, deactivated, deprecated), every session starts with stale guidance. This command audits CLAUDE.md against the live instance and reports what's drifted.

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

1. **Discover all CLAUDE.md files** in the project. Glob for `**/CLAUDE.md` and `**/.claude.local.md`. Read each.

2. **Extract verifiable references** from each CLAUDE.md. Categorize:
   - **Tables** -- patterns like `x_icir_*` (scoped tables), `sys_*` (system tables), or any `\b[a-z_]+_table\b` mention. Also extract from agent-API examples like `table = 'X'`.
   - **Scopes** -- patterns like `x_[a-z]+_[a-z_]+` or any explicit `scope: X` mention.
   - **Sys IDs** -- 32-char hex strings (canonical sys_id format).
   - **File paths** -- relative paths under `docs/`, `scripts/`, `instances/`, `zerovectordev/`.
   - **Script/widget/BR names** -- look for backticked identifiers near "Business Rule", "Script Include", "Widget", "Client Script", "Scheduled Job".

3. **Verify each reference against the instance** (read-only via `query_records`):
   - Tables: query `sys_db_object` for `name=<table>` -- exists?
   - Scopes: query `sys_scope` for `scope=<scope>` -- exists, and is `active=true`?
   - Sys IDs: query the appropriate table (if known from context) for `sys_id=<id>` -- exists?
   - Scripts/widgets/BRs by name: query `sys_script_include` / `sp_widget` / `sys_script` for `name=<name>` AND `sys_scope.scope=<project_scope>` -- exists, `active=true`?
   - File paths: just stat them locally.

4. **Save query results to JSON**, read back, aggregate findings (anti-truncation pattern per `conventions.md`).

5. **Output a drift report** grouped by severity:
   - **Stale (Critical)** -- references that DO NOT EXIST on the instance / disk. Most actionable.
   - **Inactive (Warning)** -- references that exist but are `active=false` (deprecated soft-deleted records).
   - **Unverified (Info)** -- references the audit could not check (ambiguous category, missing context to know which table to look in). Surface them so the user can manually verify.

6. **Per finding, report:**
   - The exact line of CLAUDE.md (with line number) where the reference appears.
   - The reference itself (table name, scope, sys_id, path).
   - Why it's flagged (e.g., "table not found in sys_db_object", "scope active=false", "file does not exist").
   - Suggested remediation (e.g., "remove this line", "rename to <new>", "document the deprecation").

7. **Do NOT auto-edit CLAUDE.md.** Report only -- the user decides what to fix.

## Output format

```
# CLAUDE.md Drift Audit -- <date>

## Stale (Critical)
- `CLAUDE.md:42` -- table `x_icir_old_thing` not found in sys_db_object. Remove or rename.
- `docs/architecture/overview.md:17` -- script include `LegacyHelper` not found in scope x_icir_zero_vector. Remove reference.

## Inactive (Warning)
- `CLAUDE.md:108` -- scope `x_icir_deprecated` is active=false. Confirm whether the reference is intentional (historical context) or stale.

## Unverified (Info)
- `CLAUDE.md:55` -- sys_id `abc123...` referenced without a table context. Manually verify.

Total: N stale, M inactive, K unverified.
```

## Notes

- Reading CLAUDE.md is free (already in session context). The cost is the API queries.
- Cap queries at 50 per audit run -- if more references found, batch and report progress.
- This command is read-only -- no `update_record`, no `sync_now`. Pure audit.
- Output is informational; the user runs `/sn-toolkit:end` or manually edits CLAUDE.md to apply fixes.
