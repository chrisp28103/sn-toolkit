---
description: Update a ServiceNow record directly via the Agent API -- one field or many, no file sync. Use for targeted single-field updates (work notes, state changes), multi-field batches (widget server+client+template+css), or any time you want to change a live record without going through the scriptsync file layer.
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

$ARGUMENTS can take several forms:

**Single-field update:**
- `<table> <sys_id-or-number> <field> "<new content>"`
- Example: `incident INC0010020 work_notes "Resolved via runbook R-1234"`

**State change:**
- `rm_story STRY0012345 state -7` (ready for testing)

**Multi-field batch (widget):**
- `sp_widget <sys_id> --batch script=<file1> client_script=<file2> template=<file3>`

## Why this exists

Agent API has `update_record` (single field) and `update_record_batch` (multiple fields). Both bypass the file-sync debounce and execute immediately. Previously this pattern was buried inside `pull.md` / `widget.md` -- this skill surfaces it as a first-class operation so it's the obvious tool for targeted updates.

**Do NOT use this skill for**: creating new records (`/sn-toolkit:create`), editing scripts you want version-controlled locally (edit the synced file instead and let scriptsync push).

**DO use it for**:
- Work notes / comments / journal fields on any table
- State transitions (state, approval, assigned_to, etc.)
- Bulk updating multiple widget code fields in one call
- Scripted / programmatic updates where you don't want a file round-trip

## Step 1: Parse arguments and resolve sys_id

If the caller passed a number (INC..., STRY..., EST...) instead of a sys_id, resolve it first:

```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "number=<NUMBER>"
    fields = "sys_id,number,short_description,state"
    limit = 1
}
$sysId = $r.result.records[0].sys_id
```

## Step 2a: Single-field update

```powershell
$r = & $api -InstanceDir $instanceDir -Command "update_record" -Params @{
    table = "<TABLE>"
    sys_id = "<SYS_ID>"
    field = "<FIELD_NAME>"
    content = "<NEW_CONTENT>"
}
$r | ConvertTo-Json -Depth 5
```

Required params: `table`, `sys_id`, `field`, `content`. (NOT `fields`. Common fumble.)

## Step 2b: Multi-field batch update

```powershell
$r = & $api -InstanceDir $instanceDir -Command "update_record_batch" -Params @{
    table = "sp_widget"
    sys_id = "<SYS_ID>"
    fields = @{
        script = "<server script>"
        client_script = "<client script>"
        template = "<html>"
        css = "<scss>"
    }
}
$r | ConvertTo-Json -Depth 5
```

Required params: `table`, `sys_id`, `fields` (hashtable). Use this instead of multiple `update_record` calls when updating >1 field on the same record -- it's one API round trip.

## Step 3: Verify persistence (silent-ACL guard)

REST APIs can return success with zero persistence (ACL denied silently). Always verify:

```powershell
$check = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "sys_id=<SYS_ID>"
    fields = "sys_id,<FIELD>,sys_updated_on,sys_updated_by"
    limit = 1
}
$check.result.records[0] | ConvertTo-Json
```

Confirm:
- `sys_updated_on` is recent (within the last minute)
- `sys_updated_by` is the expected user
- The field value matches what was sent

If any of those don't match, FLAG it -- likely a silent ACL failure. Check scope/domain context (`/sn-toolkit:switch`), run a background script as an escalation, or ask the user to confirm they have write access.

## Step 4: Check for async errors

```powershell
$err = & $api -InstanceDir $instanceDir -Command "get_last_error"
$err.result | ConvertTo-Json
```

## Step 5: Report

- Table + number + fields updated
- Old value (if the verification query captured it) and new value
- `sys_updated_on` / `sys_updated_by` proof of persistence

## Field-type quick reference

| Field type | Behavior |
|-----------|----------|
| **Journal** (`work_notes`, `comments`) | APPENDS -- sending new content adds a new journal entry, does not replace prior entries. |
| **String / HTML** (`description`, `short_description`, `acceptance_criteria`) | OVERWRITES -- new content replaces the full field value. |
| **Reference** (e.g. `assigned_to`) | Set the REFERENCED sys_id, not a display value. |
| **Choice** (e.g. `state`, `priority`) | Set the VALUE (e.g. `"-7"`), not the display label (`"Ready for Testing"`). Query `sys_choice` if unsure. |
| **HTML** (`acceptance_criteria`, rich text) | Accepts HTML tags (`<b>`, `<ul>`, `<li>`). Markdown is NOT rendered. |

## Gotchas

- **Param names for single-field update are `field` and `content`, NOT `fields`.** Easy to fumble, especially copying from batch syntax.
- **State values are strings** -- send `"-7"`, not `-7`.
- **HTML fields don't render markdown.** Use `<ul><li>...</li></ul>`, not `- ...`.
- **Workflow / BRs fire.** `update_record` writes via the Table API, which runs Business Rules and Workflows. If you need to bypass them, use a background script with `setWorkflow(false)` -- not this skill.
