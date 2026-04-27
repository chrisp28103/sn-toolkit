---
description: Compare any set of ServiceNow records across two instances (e.g. DEV vs PROD) via a JSON spec. Use when the user asks "what's different between DEV and PROD for X", wants a pre-go-live discrepancy audit, or needs to verify parity for groups, roles, ACLs, scripts, or any other table.
model: sonnet
effort: medium
allowed-tools: [Read, Bash, Write]
---

$ARGUMENTS should be the path to a JSON comparison spec. If omitted, ask the user.

## What this does

Runs `sn-compare.ps1` against a JSON spec describing what to compare. The spec lists one or more (table, fields, match_key, query) entries. The script queries both instances via REST, builds a three-way set diff (A-only / B-only / both-with-field-diffs), and writes a markdown report to the path declared in `spec.output`.

## Spec format

```json
{
  "instance_a": "dev",
  "instance_b": "prod",
  "output": "docs/context/<filename>.md",
  "specs": [
    {
      "label": "human-readable label",
      "table": "sys_user_group",
      "fields": ["name", "description", "manager", "active", "sys_domain.name"],
      "match_key": "name",
      "query": "active=true"
    },
    {
      "label": "Group->Role grants",
      "table": "sys_group_has_role",
      "fields": ["group", "role", "inherited"],
      "match_key": ["group", "role"],
      "query": "group.sys_domain.name=global"
    }
  ]
}
```

- `match_key` can be a string (single field) or an array (composite). Matching uses `display_value`, so logical equivalence is preserved across instances even when sys_ids differ.
- `query` is a standard `sysparm_query` string. Empty / omitted = no filter.
- Reference fields (manager, group, role, sys_domain) compare on display_value; sys_id divergence is reported alongside but does not flag as a diff.
- Hard limit: 10,000 rows per instance per spec entry. Hitting the limit emits a `**WARNING**` line in the report.

## Steps

1. **Resolve the spec path** from `$ARGUMENTS`. If empty, ask the user "Path to the comparison spec?"

2. **Validate the spec exists** and is valid JSON:
```powershell
Test-Path '<SPEC_PATH>'
Get-Content '<SPEC_PATH>' -Raw | ConvertFrom-Json | Out-Null
```

3. **Run the comparison.** Both instances must already have credentials stored (`sn-credentials.ps1 -Action store -Instance dev|prod -Username "..."`); the script fails fast otherwise.
```powershell
& sn-compare.ps1 -SpecPath '<SPEC_PATH>'
```

4. **Read the produced report** (path from `spec.output`) and surface a tight summary to the user:
   - For each spec: total A / total B / A-only / B-only / differing
   - Flag any `**WARNING**` lines (truncation, etc.)
   - Point them at the full report file

5. **Recommend next steps** based on what the diff shows:
   - A-only items: candidates to migrate into B (often via update set or manual create)
   - B-only items: drift -- decide whether to keep, retire, or backport into A
   - Field diffs: per-record judgement; some are intentional (env-specific config), some are drift

## Common spec recipes

- **Compare scoped Script Includes**: `table=sys_script_include`, `match_key=name`, `query=sys_scope.scope=<your_scope>`, `fields=name,api_name,active,access,script`
- **Compare Business Rules in scope**: `table=sys_script`, `match_key=name`, same scope filter, `fields=name,collection,when,order,active,script`
- **Compare ACLs for a table**: `table=sys_security_acl`, `match_key=[operation,name]`, `query=name=<table_name>`, `fields=operation,name,roles,script,active`
- **Compare scoped data**: any `x_<scope>_<table>`, `match_key=number` (or whatever your business key is)

## Notes

- Skill is read-only on both instances. No writes, no commits, no remediation.
- Report uses ASCII only.
- For cross-domain audits, decide whether to filter by `sys_domain.name` in the query or leave broad and let the report tell you who lives where.
