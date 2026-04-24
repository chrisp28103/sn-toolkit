---
description: Bootstrap a new ServiceNow client/project workspace using the plugin-provided bootstrap script. Use when the user asks to start a new SN project, bootstrap a workspace, or set up a new client. Core value is standing up the VS Code sn-scriptsync <-> instance connection (via the SN Utils browser helper tab); custom scope is optional.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

$ARGUMENTS should contain the project name and instance, and optionally a custom scope:
- `aha ahadev` -- OOB / global / exploratory work, no custom scope
- `aha ahadev x_icir_aha` -- building a custom scoped app
- `aha ahadev --scope x_icir_aha` -- named-arg form, equivalent to above

## Steps

1. Parse `<name>` and `<instance>` from $ARGUMENTS. Parse optional `<scope>` (3rd positional or `--scope <value>`). If scope was not provided, omit the `-Scope` argument below so the bootstrap script uses its default (`global`).

2. Run the bootstrap script. It's on PATH from the plugin's bin/:
```powershell
bootstrap-project.ps1 -Name "<name>" -Instance "<instance>"
# Add -Scope "<scope>" only if the user supplied one
```

3. Open the new project folder as your workspace in the IDE. The bootstrap script prints the exact path when it finishes.

4. In the new workspace, run `/sn-toolkit:creds` to configure the instance credentials.

5. Connect sn-scriptsync to the `instances/<instance>` directory (click the sn-scriptsync status-bar item in VS Code, confirm the target dir).

6. Open the SN Utils helper tab in the browser on the target instance (type `/token` in ServiceNow). This is the bridge that the Agent API uses.

7. Run `/sn-toolkit:start` to verify the round-trip (scriptsync server + browser connection).

8. Optionally run `/sn-toolkit:refresh` if your project provides a `scripts/refresh-architecture.ps1` to build the initial architecture catalog.

## Examples

Exploring an instance with no scope commitment yet (most common):
```powershell
bootstrap-project.ps1 -Name "aha" -Instance "ahadev"
```

Building on a known custom scope:
```powershell
bootstrap-project.ps1 -Name "aha" -Instance "ahadev" -Scope "x_icir_aha"
```

## Why scope is optional

The bootstrap's primary job is wiring up the VS Code sn-scriptsync extension to the target SN instance via the browser helper tab. Scope only matters once you're creating records in a specific scoped app; for OOB work, domain exploration, global-scope edits, or early instance discovery, `global` (the default) is correct and can stay.

If you later commit to a custom scope, edit `.claude/project.json` to set `"scope": "x_..."` and update the CLAUDE.md header accordingly -- nothing in the workspace scaffolding needs to be regenerated.

## Standalone use (no Claude session running)

If you want to bootstrap a new workspace BEFORE opening any Claude session (e.g., a teammate's first-time setup), invoke the script by its full plugin-install path. See the plugin README for the exact path format on your machine.
