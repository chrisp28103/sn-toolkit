---
description: Create a new ServiceNow record (Script Include, Business Rule, Client Script, Widget, etc.). Use when the user asks to create or add a new SN record of any type.
model: sonnet
effort: medium
allowed-tools: [Read, Bash]
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

$ARGUMENTS should describe what to create (e.g., "Script Include called MyNewUtils" or "Business Rule on tp_job").

## Steps

1. Verify connection:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "check_connection"
$r.result | ConvertTo-Json
```

2. **Pre-flight: fetch table metadata** (detects mandatory / reference fields so we don't fumble the create call):
```powershell
$meta = & $api -InstanceDir $instanceDir -Command "get_table_metadata" -Params @{
    table = "<TABLE>"
}
$meta.result.columns | ConvertTo-Json -Depth 4
```

Scan the columns for:
- Fields where `mandatory: true` (must be populated)
- Fields where `type: "reference"` (need a parent sys_id -- see step 3)
- Fields where `default` is set (use the default unless overriding)

The response is cached in `{instance}/{scope}/{table}/structure.json` -- subsequent creates of the same table can skip this step.

3. **If mandatory references exist, fetch parent options**:
```powershell
$opts = & $api -InstanceDir $instanceDir -Command "get_parent_options" -Params @{
    table = "<REFERENCE_TABLE>"     # e.g. 'sys_ws_definition' for REST API operations
    scope = "<YOUR_SCOPE>"
    nameField = "name"
    limit = 50
}
$opts.result.options | Format-Table
```

Common reference-parent pairs:

| Creating | Reference field | Parent table |
|----------|-----------------|--------------|
| REST API Operation (`sys_ws_operation`) | `web_service_definition` | `sys_ws_definition` |
| Business Rule (`sys_script`) | `collection` | `sys_db_object` |
| UI Action (`sys_ui_action`) | `table` | `sys_db_object` |
| Client Script (`sys_client_script`) | `table` | `sys_db_object` |

If zero options exist, OFFER TWO paths:
- **A)** Create the parent first via another `create_artifact` call, then use its sys_id.
- **B)** Open a pre-filled form in the browser: `https://<instance>/<parent_table>.do?sys_id=-1&sysparm_query=name=<suggested>^active=true`.

4. Check if the name already exists (local + remote):
```powershell
$chk = & $api -InstanceDir $instanceDir -Command "check_name_exists_remote" -Params @{
    table = "<TABLE>"; name = "<NAME>"
}
$chk.result | ConvertTo-Json
```

5. Create the artifact (ALWAYS include `scope = "<YOUR_SCOPE>"`):

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

**UI Action (requires `table`):**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "sys_ui_action"; scope = "<YOUR_SCOPE>"
    fields = @{ name = "<Name>"; table = "<target_table>"; action_name = "<action_name>"; script = "<script>"; active = "true"; ui_type = "10" }
}
```

**Widget:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "sp_widget"; scope = "<YOUR_SCOPE>"
    fields = @{ name = "<Name>"; id = "<widget-id>"; script = "<server>"; client_script = "<client>"; template = "<html>"; css = "<scss>" }
}
```

**Story (rm_story) -- acceptance_criteria is HTML, not markdown:**
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "rm_story"; scope = "global"
    fields = @{
        name = "<Short Description>"
        short_description = "<Short Description>"
        description = "<Plain text>"
        acceptance_criteria = "<b>AC:</b><ul><li>Item 1</li><li>Item 2</li></ul>"
        state = "1"        # 1 = Ready, -7 = Ready for Testing, 3 = Complete
        priority = "2"
    }
}
```

6. Check for errors: `& $api -InstanceDir $instanceDir -Command "get_last_error"`

7. Provide the sys_id from the response to the user.

## Important

- ALWAYS include `scope = "<YOUR_SCOPE>"` -- without it, records land in global scope
- For GLOBAL-scope work, always be on a specific update set (never Default). Use `/sn-toolkit:switch updateset ...` first.
- Boolean / choice fields are STRINGS in the payload: `"true"`, `"-7"`, `"100"`.
- For complex records with mandatory references (BRs, UI Actions, REST Operations), do steps 2 + 3 BEFORE step 5 to avoid "missing required field" errors.
- Don't create configuration-field files (`.collection.js`, `.when.js`, `.active.js`) -- those are scalars, put them in the `fields` payload.
- UI Actions and Client Scripts that need to run in UX workspaces (RecruitPro / TradePro / etc.) require `ui_type = "10"`.
