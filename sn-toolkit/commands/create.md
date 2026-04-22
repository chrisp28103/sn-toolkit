---
description: Create a new ServiceNow record (Script Include, Business Rule, Client Script, Widget, etc.). Use when the user asks to create or add a new SN record of any type.
---

See `docs/reference/agent-api-cheatsheet.md` for command quick-reference.

$ARGUMENTS should describe what to create (e.g., "Script Include called MyNewUtils" or "Business Rule on tp_job").

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

## Steps

1. Verify connection:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "check_connection"
$r.result | ConvertTo-Json
```

2. Check if the name already exists:
```powershell
$chk = & $api -InstanceDir $instanceDir -Command "check_name_exists_remote" -Params @{
    table = "<TABLE>"; name = "<NAME>"
}
$chk.result | ConvertTo-Json
```

3. Create the artifact (ALWAYS include `scope = "<YOUR_SCOPE>"`):

**Script Include:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "sys_script_include"; scope = "<YOUR_SCOPE>"
    fields = @{ name = "<Name>"; script = "<script>"; active = "true"; access = "package_private"; client_callable = "false" }
}
```

**Business Rule:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "sys_script"; scope = "<YOUR_SCOPE>"
    fields = @{ name = "<Name>"; collection = "<target_table>"; script = "<script>"; active = "true"; when = "before"; action_insert = "true"; action_update = "true"; order = "100" }
}
```

**Widget:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "sp_widget"; scope = "<YOUR_SCOPE>"
    fields = @{ name = "<Name>"; id = "<widget-id>"; script = "<server>"; client_script = "<client>"; template = "<html>"; css = "<scss>" }
}
```

4. Check for errors: `& $api -InstanceDir $instanceDir -Command "get_last_error"`

5. Provide the sys_id from the response to the user.

## Important
- ALWAYS include `scope = "<YOUR_SCOPE>"` -- without it, records land in global scope
- For complex records (BRs, Client Scripts), ask user which table before creating
- Use `get_parent_options` to find reference field values if needed
