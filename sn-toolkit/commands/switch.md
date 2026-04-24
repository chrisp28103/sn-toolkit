---
description: Switch ServiceNow session context -- update set, application scope, or DOMAIN. Use when the user needs to change update set, scope, or domain; when queries return 0 rows unexpectedly (often a domain visibility issue); or when the user says "switch to X update set" / "expand domain scope".
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

$ARGUMENTS should describe the target context, e.g.:
- `updateset STRY0012345 - My Feature`
- `scope x_icir_zero_vector`
- `domain global`
- `domain Excel` (or any domain name)

## Why this exists

ServiceNow sessions have THREE independent context layers. Queries and record updates respect them all:
- **Update set** (`sys_update_set`) -- captures your changes for promotion
- **Application scope** (`sys_scope`) -- scoping context for created records
- **Domain** (`domain`) -- multi-tenant visibility filter (MSP / domain-separated instances)

If a query returns zero rows even though the record exists, the top suspect is domain. The session user may be pinned to `global` while the record lives below. `switch_context` with `switchType: 'domain'` expands visibility.

## Step 1: Parse $ARGUMENTS

Extract `<switchType>` (one of `updateset`, `scope`/`application`, `domain`) and `<name-or-value>`.

## Step 2: Resolve the sys_id for the target

Different tables, same pattern:

**Update set:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "sys_update_set"
    query = "name=<NAME>^state=in progress"
    fields = "sys_id,name,state,sys_scope.scope"
    limit = 5
}
```

**Application scope:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "sys_scope"
    query = "scope=<SCOPE_NAME>"
    fields = "sys_id,scope,name,version"
    limit = 1
}
```

**Domain:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "domain"
    query = "name=<DOMAIN_NAME>"
    fields = "sys_id,name,description,active"
    limit = 5
}
```

If zero results for update set: offer to create one (format: `STRY00#### - Short Description` if the user references a story).

If multiple results: show them and ask the user to pick.

## Step 3: Switch the context

```powershell
$r = & $api -InstanceDir $instanceDir -Command "switch_context" -Params @{
    switchType = "<updateset|application|domain>"
    value = "<SYS_ID_FROM_STEP_2>"
    reloadTab = $true
    tabUrl = "https://*.service-now.com/*"
}
$r.result | ConvertTo-Json
```

`reloadTab = $true` is the default and the right default -- ServiceNow's Concourse Picker needs the tab to reload before new scope/domain filters take effect. Without it, the browser session will show the OLD context until a manual refresh.

## Step 4: Verify

For update set / scope: `get_instance_info` shows the active picker state.
For domain: re-run the query that returned zero rows and confirm it now returns results.

## Step 5: Report

One-line summary:
- `Switched to update set "STRY0012345 - My Feature"` (with sys_id)
- `Switched to domain "Excel"; previous "global" expanded`

## Gotchas

- `switch_context` affects the BROWSER session (the SN Utils helper tab), which is where subsequent Agent API calls execute. It does NOT change the PowerShell / VS Code process.
- Domain switching only works on domain-separated instances. If `domain` table has zero active records, the instance is single-domain and this is a no-op.
- If `switch_context` returns success but queries still show the old behavior, re-check the browser tab loaded properly (`activate_tab` with `reload: $true` as a fallback).
- For GLOBAL scope work, always prefer an explicit update set (never the Default update set). If the user references a story, format the update set name as `STRY00#### - Short Description`.
