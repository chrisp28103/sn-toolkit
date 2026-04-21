---
description: Bootstrap a new ServiceNow client/project workspace using the plugin-provided bootstrap script. Use when the user asks to start a new SN project, bootstrap a workspace, or set up a new client.
---

$ARGUMENTS should contain the project name, scope, and instance (e.g., `"aha x_icir_aha ahadev"`).

## Steps

1. Run the bootstrap script. It's on PATH from the plugin's bin/:
```powershell
bootstrap-project.ps1 -Name "<name>" -Scope "<scope>" -Instance "<instance>"
```

2. Open the new project folder as your workspace in the IDE. The bootstrap script prints the exact path when it finishes.

3. In the new workspace, run `/sn-toolkit:creds` to configure the instance credentials.

4. Connect sn-scriptsync to the `instances/<instance>` directory (click the sn-scriptsync status-bar item in VS Code, confirm the target dir).

5. Optionally run `/sn-toolkit:refresh` if your project provides a `scripts/refresh-architecture.ps1` to build the initial architecture catalog.

## Example

To create a workspace for American Heart Association:
```powershell
bootstrap-project.ps1 -Name "aha" -Scope "x_icir_aha" -Instance "ahadev"
```

## Standalone use (no Claude session running)

If you want to bootstrap a new workspace BEFORE opening any Claude session (e.g., a teammate's first-time setup), invoke the script by its full plugin-install path. See the plugin README for the exact path format on your machine.
