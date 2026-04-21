---
description: Full Service Portal widget development loop -- create, preview, edit, sync. Use when the user asks to create, edit, or preview a Service Portal widget, or mentions sp_widget/portal widget work.
---

See `docs/reference/agent-api-cheatsheet.md` for command quick-reference.

$ARGUMENTS should describe the widget to create or edit.

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

## Create New Widget

1. Verify connection: `& $api -InstanceDir $instanceDir -Command "check_connection"`
2. Check update set (MANDATORY)
3. Create widget with all 4 fields via `create_artifact`:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "create_artifact" -Params @{
    table = "sp_widget"; scope = "<YOUR_SCOPE>"
    fields = @{ name = "<Name>"; id = "<widget-id>"; script = "<server>"; client_script = "<client>"; template = "<html>"; css = "<scss>" }
}
```
4. Open preview: `& $api -InstanceDir $instanceDir -Command "open_in_browser" -Params @{ table = "sp_widget"; name = "<widget-id>" }`
5. Make file changes in the scriptsync workspace
6. Flush changes: `& $api -InstanceDir $instanceDir -Command "sync_now"`
7. Refresh preview: `& $api -InstanceDir $instanceDir -Command "refresh_preview" -Params @{ table = "sp_widget"; name = "<widget-id>" }`

## Edit Existing Widget

1. Run freshness check (MANDATORY -- compare instance `sys_updated_on` vs local file timestamp)
2. If stale, pull latest from instance before editing
3. Edit local files in `<YOUR_INSTANCE>/<YOUR_SCOPE>/sp_widget/<WidgetName>/`
4. For fields without local files, use `update_record` or `update_record_batch`
5. `sync_now` + `refresh_preview` + `get_last_error`

## Key Gotchas
- Widget folders may be PARTIALLY synced -- check which files actually exist locally
- `server.update({...})` does NOT merge args into `input` -- set on `c.data` first, call with no args
- `spModal` styles must go in theme CSS (`tpm_mobile_theme`), not widget CSS
- SN SCSS compiler does NOT support `env()` -- use hardcoded px values
