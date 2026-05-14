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

2. Ask the user where to create the project (which parent directory). Use AskUserQuestion. Suggested default: `[Environment]::GetFolderPath('MyDocuments')` joined with `ServiceNow` (OneDrive-aware on Windows). Common alternates: `~/code/`, `~/projects/servicenow/`, a client-specific dropbox folder, etc. Pass the user's answer as `-OutputDir` in the next step.

   Rationale: bootstrap runs under a redirected stdin (this is a Claude tool call), so the script's interactive prompt is suppressed and it would silently use the default. Asking here surfaces the choice to the user and keeps the plugin folder-layout-agnostic across teammates.

3. Run the bootstrap script. It's on PATH from the plugin's bin/:
```powershell
bootstrap-project.ps1 -Name "<name>" -Instance "<instance>" -OutputDir "<chosen-parent-dir>"
# Add -Scope "<scope>" only if the user supplied one
```

4. Open the new project folder as your workspace in the IDE. The bootstrap script prints the exact path when it finishes.

5. In the new workspace, run `/sn-toolkit:creds` to configure the instance credentials.

6. Connect sn-scriptsync to the `instances/<instance>` directory (click the sn-scriptsync status-bar item in VS Code, confirm the target dir).

7. Apply the sn-scriptsync multi-instance patch (idempotent -- no-ops if already applied). Without this, only one helper tab can connect at a time:
   ```powershell
   apply-snscriptsync-patch.ps1
   ```
   The patcher is on PATH from the plugin's `bin/`. After it runs, toggle the sn-scriptsync status-bar item (or reload the window) so the running WS server picks up the patched code. Skip this step if you already patched sn-scriptsync in another workspace today -- the patch is per-extension-install, not per-project.

8. Pin the active instance for this project. Writes to `.claude/project.json`'s `instance` field; the UserPromptSubmit hook reads it on every prompt:
   ```
   /sn-toolkit:instance <instance>
   ```

9. Open the SN Utils helper tab in the browser on the target instance (type `/token` in ServiceNow). This is the bridge that the Agent API uses.

10. Run `/sn-toolkit:start` to verify the round-trip (scriptsync server + browser connection).

11. Optionally run `/sn-toolkit:refresh` if your project provides a `scripts/refresh-architecture.ps1` to build the initial architecture catalog.

## Examples

Exploring an instance with no scope commitment yet (most common):
```powershell
bootstrap-project.ps1 -Name "aha" -Instance "ahadev" -OutputDir "C:\Users\me\OneDrive\Documents\ServiceNow"
```

Building on a known custom scope:
```powershell
bootstrap-project.ps1 -Name "aha" -Instance "ahadev" -Scope "x_icir_aha" -OutputDir "C:\Users\me\OneDrive\Documents\ServiceNow"
```

Run without `-OutputDir` (standalone interactive use, e.g., a teammate in a plain PowerShell window):
```powershell
bootstrap-project.ps1 -Name "aha" -Instance "ahadev"
# Script will prompt: "Where should this project be created? Default: <MyDocuments>\ServiceNow"
```

## Why scope is optional

The bootstrap's primary job is wiring up the VS Code sn-scriptsync extension to the target SN instance via the browser helper tab. Scope only matters once you're creating records in a specific scoped app; for OOB work, domain exploration, global-scope edits, or early instance discovery, `global` (the default) is correct and can stay.

If you later commit to a custom scope, edit `.claude/project.json` to set `"scope": "x_..."` and update the CLAUDE.md header accordingly -- nothing in the workspace scaffolding needs to be regenerated.

## Standalone use (no Claude session running)

If you want to bootstrap a new workspace BEFORE opening any Claude session (e.g., a teammate's first-time setup), invoke the script by its full plugin-install path. See the plugin README for the exact path format on your machine.

When invoked from an interactive PowerShell window with no `-OutputDir`, the script prompts for the parent directory and offers `[Environment]::GetFolderPath('MyDocuments')\ServiceNow` as the default -- which respects OneDrive's Documents-folder redirect. Press Enter to accept, or paste a different path.
