---
description: One-time opt-in setup for the local ServiceNow docs mirror. Clones github.com/servicenow/servicenowdocs (~150 MB, shallow + blobless) to $env:LOCALAPPDATA\sn-toolkit\servicenow-docs\ so subsequent /sn-toolkit:docs lookups run offline against ripgrep. Idempotent -- re-running on an existing cache does a fast incremental git pull. Use when the user wants fast offline ServiceNow docs lookup.
model: sonnet
effort: low
allowed-tools: [Bash]
---

## What this does

Mirrors the ServiceNow official docs repo locally so the `sn-toolkit:docs` skill can ripgrep across it. Without this setup, the skill still works -- it falls back to one HTTP fetch per file via raw.githubusercontent.com -- but the cache makes search exhaustive and offline.

## Steps

1. Tell the user what's about to happen:
   - Clone target: `$env:LOCALAPPDATA\sn-toolkit\servicenow-docs\`
   - One-time download: ~150 MB (shallow + blobless, so significantly less than a full clone)
   - Source: https://github.com/servicenow/servicenowdocs (Apache 2.0)
   - No background refresh -- user runs `/sn-toolkit:docs-sync` manually when they want updates.

2. Run sync:
```bash
sn-docs.ps1 sync
```

3. After it returns, verify:
```bash
sn-docs.ps1 status
```
Confirm `cache_present: yes` and report the cache size + head sha to the user.

4. Suggest a smoke-test query so the user sees it work:
   *"Try: ask me 'how does ACL evaluation order work in ServiceNow?' -- the `sn-toolkit:docs` skill should now answer from local cache."*

## Failure modes

- `git: command not found` -> git must be on PATH. Tell user to install git.
- Network error during clone -> proxy/firewall issue. The skill still works without the cache via webfetch fallback.
- Disk-space error -> need ~200 MB free in `$env:LOCALAPPDATA\sn-toolkit\`.
