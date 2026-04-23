---
description: Visual + technical-name debugging for ServiceNow forms, widgets, or workspaces. Activates the tab, toggles technical field names via /tn, takes a screenshot, optionally uploads it to a record. Use when the user says "show me the form", "what's the field name for X", debug a UI issue, or needs a visual snapshot.
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

$ARGUMENTS should describe what to inspect, e.g.:
- `form incident INC0010020` (record form)
- `widget tpm-clock` (widget preview)
- `workspace TradePro` (any URL)
- `url https://<instance>/sp?id=my_page`

Optional extras:
- `--attach <table>:<sys_id>` to attach the screenshot to a record
- `--no-tn` to skip the technical-name toggle

## Why this exists

Debugging SN forms often stalls on "what's the actual field name" (label != technical name) and "what does this look like in the user's browser right now?" This skill chains three Agent API calls -- `activate_tab`, `run_slash_command /tn`, `take_screenshot` -- into one pass so Claude can see the form with technical names visible.

## Step 1: Resolve the URL

Map $ARGUMENTS to a URL pattern:

| Argument | URL pattern |
|----------|-------------|
| `form <table> <number\|sys_id>` | Query `<table>` for the record, build `/<table>.do?sys_id=<sys_id>` |
| `widget <widget-id>` | `/$sp.do?id=sp-preview&sys_id=<sys_id>` (lookup sp_widget by id) |
| `workspace <name>` | `/now/workspace/<workspace-url-name>` (ask user if unclear) |
| `url <full-url>` | Use as-is |

## Step 2: Activate the tab (reload for freshness)

```powershell
$r = & $api -InstanceDir $instanceDir -Command "activate_tab" -Params @{
    url = "<URL_FROM_STEP_1>"
    reload = $true
    waitForLoad = $true
    openIfNotFound = $true
}
$r.result | ConvertTo-Json
```

`waitForLoad = $true` is critical -- without it, the screenshot may capture a blank page.

## Step 3: Toggle technical names (unless --no-tn)

```powershell
$r = & $api -InstanceDir $instanceDir -Command "run_slash_command" -Params @{
    command = "/tn"
    url = "<URL_FROM_STEP_1>"
    autoRun = $true
}
```

`/tn` toggles technical field names on the form. If user specified `--no-tn`, skip this step (some workspace UX pages don't support /tn and it's a no-op).

Only DOCUMENTED slash commands should be invoked here: `/tn`, `/bg`, `/token`, `/sn`, `/xml`. Never invent commands.

## Step 4: Take the screenshot

```powershell
$r = & $api -InstanceDir $instanceDir -Command "take_screenshot" -Params @{
    url = "<URL_FROM_STEP_1>"
    fileName = "inspect_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
}
$r.result | ConvertTo-Json
```

Save the returned absolute `filePath` -- step 5 and Claude's post-inspection read both need it.

If the response is a permission error, tell the user:
> "Please click the SN Utils extension icon on the target tab to grant screenshot permission, then ask me to retry."

## Step 5: Optionally attach to a record

If $ARGUMENTS includes `--attach <table>:<sys_id>`:

```powershell
$r = & $api -InstanceDir $instanceDir -Command "upload_attachment" -Params @{
    table = "<TABLE>"
    sys_id = "<RECORD_SYS_ID>"
    filePath = "<ABSOLUTE_PATH_FROM_STEP_4>"
}
$r.result | ConvertTo-Json
```

Use the ABSOLUTE `filePath` from the `take_screenshot` response, NOT a relative path. Relative paths resolve against the instance folder, not the workspace root.

## Step 6: Read the screenshot and report

Claude should then Read the screenshot file (the Read tool supports PNG natively as a vision input) and describe what's visible -- which is the whole point of this skill.

Report concisely:
- One line on what's shown (e.g. "Incident form INC0010020, technical names visible")
- Any field names now readable that weren't before (from /tn toggle)
- If attached: the attachment sys_id so the user can reference it
- Absolute path to the saved screenshot

## Gotchas

- First screenshot of a session requires user action -- they must click the SN Utils extension icon on the target tab once.
- `/tn` only affects classic UI forms. Workspace forms ignore it.
- `upload_attachment` needs the ABSOLUTE path from `take_screenshot`. Passing a relative path silently resolves into the instance folder and fails.
- `waitForLoad` on `activate_tab` is essential -- skip it and the screenshot captures a half-loaded page.
