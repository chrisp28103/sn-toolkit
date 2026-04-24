---
description: Attach a local file (screenshot, document, PDF, log, etc.) to a ServiceNow record as an attachment. Use when the user says "attach this to INC...", "upload X as evidence to story Y", or wants to persist a file against a record.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

$ARGUMENTS should contain the record target and the file path, e.g.:
- `rm_story abc123... /path/to/screenshot.png`
- `incident INC0010020 scratch/failure.log`
- `x_icir_zero_vector_dealmaker EST002601 scratch/quote-before.png`

## Why this exists

The `upload_attachment` Agent API command is one of the least-used capabilities in the wrapper, but it's the cleanest way to persist evidence (screenshots, logs, spec PDFs) on a record. Pair it with `/sn-toolkit:inspect` for visual-verification trails on stories or defects.

## Step 1: Parse arguments

Extract three fields from $ARGUMENTS:
- `<table>` -- e.g. `rm_story`, `incident`, `x_icir_zero_vector_dealmaker`
- `<record-identifier>` -- either a sys_id (32 hex chars) or a number (e.g. `INC0010020`, `STRY0012345`, `EST002601`)
- `<file-path>` -- absolute path preferred; relative will resolve against the instance folder, which is usually NOT what you want.

## Step 2: Resolve sys_id if user passed a number

Skip if $ARGUMENTS already has a 32-char hex sys_id.

```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "number=<NUMBER>"
    fields = "sys_id,number,short_description"
    limit = 1
}
$sysId = $r.result.records[0].sys_id
```

## Step 3: Normalize the file path to ABSOLUTE

If the path is relative, resolve it against the WORKSPACE root (not the instance folder):

```powershell
$absPath = Resolve-Path "<USER_PROVIDED_PATH>" -ErrorAction Stop | Select-Object -ExpandProperty Path
Test-Path $absPath
```

If the file doesn't exist, stop and tell the user.

## Step 4: Upload

```powershell
$r = & $api -InstanceDir $instanceDir -Command "upload_attachment" -Params @{
    table = "<TABLE>"
    sys_id = "<SYS_ID>"
    filePath = "$absPath"
}
$r.result | ConvertTo-Json
```

Content type is auto-detected from the file extension (png, jpg, pdf, json, zip, etc.). Override with an explicit `contentType` param only when the extension is ambiguous.

## Step 5: Verify + report

Check the response `result.uploaded` is `true` and `result.attachment.sys_id` is populated.

Report:
- Attachment sys_id
- File size (from `result.attachment.size_bytes`)
- A direct link: `https://<instance>.service-now.com/sys_attachment.do?sys_id=<ATTACHMENT_SYS_ID>`

## Common use cases

- **Story evidence**: attach a `/sn-toolkit:inspect` screenshot to an rm_story for QA handoff.
- **Defect reproduction**: attach a log file to the incident after a repro.
- **Widget review**: attach before/after screenshots to a story for code-review visibility.

## Gotchas

- Path resolution is finicky: `upload_attachment` resolves relative paths against `{instance}/`, not the workspace root. ALWAYS pass absolute.
- Workspace boundary: the extension blocks paths outside the workspace. Copy the file into `scratch/` first if it lives elsewhere.
- Permission / connection: `upload_attachment` is a remote command -- needs the SN Utils helper tab open.
