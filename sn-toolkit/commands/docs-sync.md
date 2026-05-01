---
description: Refresh the local ServiceNow docs mirror. Runs an incremental git pull on $env:LOCALAPPDATA\sn-toolkit\servicenow-docs\. Use when the user wants the docs cache up to date (the upstream repo regenerates daily). No-op if the cache has not been set up yet -- prompts the user to run /sn-toolkit:docs-setup first.
model: sonnet
effort: low
allowed-tools: [Bash]
---

## Steps

1. Check cache state:
```bash
sn-docs.ps1 status
```

2. If `cache_present: no`, tell the user:
   *"No local cache yet. Run `/sn-toolkit:docs-setup` once to create it (~150 MB, opt-in)."*
   Stop here.

3. If `cache_present: yes`, refresh:
```bash
sn-docs.ps1 sync
```

4. Report the new head sha and last-sync timestamp from the trailing status block.
