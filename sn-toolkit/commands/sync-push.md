---
description: Flush pending sn-scriptsync file writes to the instance, poll until the queue drains, and verify no async errors. Use after editing widget/script files when you want a single atomic "did my changes land" confirmation instead of manually chaining sync_now + get_sync_status + get_last_error.
model: sonnet
effort: low
allowed-tools: [Bash]
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

## Why this exists

The sn-scriptsync file-sync loop is async: editing a local file queues a push, `sync_now` flushes the queue, but the actual instance write happens milliseconds-to-seconds later. Errors (ACL, compile, connection) surface via `get_last_error`. The canonical "verify my changes are live" sequence is three API calls -- this command wraps them so you don't have to remember the order or the timing.

## Step 1: Flush the queue

```powershell
$r = & $api -InstanceDir $instanceDir -Command "sync_now"
$r.result | ConvertTo-Json -Compress
```

If `sync_now` itself errors, stop and report -- nothing was pushed.

## Step 2: Poll until drained (up to 5 tries, ~1s apart)

```powershell
$drained = $false
for ($i = 0; $i -lt 5; $i++) {
    Start-Sleep -Milliseconds 1000
    $s = & $api -InstanceDir $instanceDir -Command "get_sync_status"
    $pending = [int]$s.result.pendingCount
    if ($pending -eq 0) { $drained = $true; break }
}
$s.result | ConvertTo-Json -Compress
```

If `$drained` stays false after 5 tries, report the pending files from `$s.result.pendingFiles` -- the queue is stuck and the user should investigate (most often: scriptsync server paused, or a malformed filename the server rejected).

If `isPaused` is true in any poll response, stop and tell the user to unpause (sn-scriptsync VS Code status bar icon).

## Step 3: Check for async errors

```powershell
$err = & $api -InstanceDir $instanceDir -Command "get_last_error"
$err.result | ConvertTo-Json -Compress
```

Non-null means a server-side error fired during the push (ACL, compile failure, BR throwing). Surface the full error to the user.

## Step 4: Report

One-line summary on success: `Flushed N file(s), queue drained, no errors.`

On stuck queue or error: full details, no guessing. Include the stuck file names or the error message verbatim.

## When NOT to use this

- **Read-only work**: if you're only querying (`/sn-toolkit:pull`, `/sn-toolkit:list`), the Stop hook already checks for async errors at end of turn. No need to invoke this.
- **Inside a loop/batch**: don't call `/sn-toolkit:sync-push` between every file write -- the queue is designed to batch. Write all your files first, then sync-push once at the end.
- **Agent API direct mutations** (`update_record`, `create_artifact`): those are synchronous, not queued. `sync_now` is a no-op for them, though the `get_last_error` check at the end still covers server-side issues.

## Gotchas

- `get_sync_status` pending count can briefly flap 0 -> 1 -> 0 during rapid edits. The 5-iteration poll smooths that.
- If `pendingCount` stays stuck at the same N across iterations, the server isn't dequeuing -- usually a sync-server crash or paused state. The status bar icon in VS Code is authoritative.
- `Start-Sleep -Milliseconds 1000` is fine for interactive use; do not raise this in `/loop`-fired contexts.
