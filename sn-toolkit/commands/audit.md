---
description: Audit all records in a ServiceNow update set by querying sys_update_xml. Use when the user asks to audit, review, or list the contents of an update set.
model: sonnet
effort: medium
allowed-tools: [Read, Glob, Grep, Bash]
---

$ARGUMENTS should contain the update set name or sys_id.

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

1. Find the update set (save + read back per conventions.md "Canonical Query-and-Save Snippet"):
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "sys_update_set"
    query = "name=<UPDATE_SET_NAME>^state=in progress"
    fields = "sys_id,name,state,description"
    limit = 5
}
```

2. Query all update XML entries for that update set:
```powershell
$usSysId = "<SYS_ID from step 1>"
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "sys_update_xml"
    query = "update_set=$usSysId^ORDERBYname"
    fields = "sys_id,name,type,action,target_name"
    limit = 500
}
```

3. Present a summary table grouped by type (Script Include, Business Rule, Widget, etc.) with action (INSERT/UPDATE).
