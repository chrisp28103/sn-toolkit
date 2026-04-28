# sn-toolkit

A Claude Code plugin that turns any workspace into a ServiceNow development environment. Ships the Agent API wrapper, credential management, session hooks, slash commands, and subagents as shared infrastructure -- no per-project duplication.

## What's in the box

- **22 slash commands** covering the full SN dev loop:
  - **Connect / inventory**: `start`, `end`, `creds`, `list`, `view-response`, `refresh`, `new-project`
  - **Read**: `pull`, `export`, `review`, `audit`
  - **Write**: `create` (schema-aware pre-flight), `update` (single-field + batch), `widget` (preview+refresh loop), `sync-push` (flush + drain + error-check)
  - **Session context**: `switch` (update set / app scope / domain), `start` (surfaces active context)
  - **Visual debugging**: `inspect` (activate tab + `/tn` + screenshot), `attach` (upload files to any record)
  - **Planning**: `refine` (SN-flavored 4-D prompt refiner -- forces naming table/scope/update-set/domain before work), `refine-prompt` (general-purpose 4-D refiner for non-SN prompts)
  - **Operations**: `monitor` (use with `/loop 5m`), `diagnose`
- **2 subagents**: `sn-explorer` (deep instance exploration) and `sn-reviewer` (code-review against SN scripting standards).
- **5 hooks**: SessionStart (auto-connect to SN), PreToolUse/PostToolUse (block BOM-writes, validate encoding on sn-scriptsync files), Stop (async error check), PostCompact (re-inject session scratchpad).
- **2 bin scripts on PATH** while the plugin is enabled:
  - `sn-agent-api.ps1` -- thin PowerShell wrapper around SN Utils' Agent API (the browser-extension bridge)
  - `sn-credentials.ps1` -- DPAPI-encrypted credential storage for instance auth
- **4 rules** (markdown files with frontmatter `paths:` globs): `conventions.md`, `sn-scripting.md`, `sn-testing.md`, `sn-ui-components.md`. Reference these from your project CLAUDE.md.
- **Autocomplete type defs** in `autocomplete/` for VS Code IntelliSense on ServiceNow APIs -- reference via `jsconfig.json`.

## Prerequisites

This plugin is a thin layer over the **sn-scriptsync** + **SN Utils** stack. Without them, every slash command will time out -- they are **not optional**.

| Requirement | Notes |
|-------------|-------|
| **VS Code** | `sn-scriptsync` runs as a VS Code extension. There is no standalone / CLI mode. Pure-terminal Claude Code without VS Code running cannot drive this plugin. |
| **`sn-scriptsync` VS Code extension** | Search "sn-scriptsync" in the VS Code Marketplace. Provides the local file-sync server and the Agent API request/response watcher under `instances/<instance>/agent/`. |
| **SN Utils browser extension** | Chrome / Edge. Search "SN Utils" in the Chrome Web Store or Edge Add-ons. Exposes the helper tab in your SN instance; activate per-instance by typing `/token` in the SN URL. |
| **Windows** | The DPAPI credential store (`sn-credentials.ps1`) is Windows-only. macOS / Linux are not currently supported. |
| **Claude Code (VS Code extension)** | Install and run Claude Code via its VS Code extension. The Manage Plugins UI -- which is how you install this plugin -- is part of that extension. The CLI alone won't work since the plugin requires VS Code at runtime anyway. |

Install all four before proceeding.

## Install

### 1. Add the marketplace + install the plugin (VS Code Manage Plugins UI)

Install via the Claude Code extension in VS Code:

1. Open the Claude Code panel in VS Code.
2. Click the **Customize** menu (gear / overflow icon at the top of the panel) and choose **Manage plugins**.
3. In the **Manage Plugins** dialog, switch to the **Marketplaces** tab and click **Add marketplace**. Paste:
   ```
   https://github.com/chrisp28103/sn-toolkit.git
   ```
4. Switch to the **Plugins** tab, find **sn-toolkit@infocenter**, and toggle it **on**.
5. Restart VS Code (or reload the window) so the SessionStart hook fires on the next Claude Code session.

For local plugin development (before publishing), use a local path instead of the GitHub URL in step 3 (e.g. `<absolute-path-to-this-repo>`).

### 2. Add required permissions to `~/.claude/settings.json`

Plugins cannot ship `permissions.allow` entries (Claude Code limitation: plugin-level `settings.json` only supports `agent` and `subagentStatusLine`). Add this block to your **user-level** `~/.claude/settings.json` one time:

```json
{
  "permissions": {
    "allow": [
      "Bash(powershell.exe:*sn-agent-api.ps1*)",
      "Bash(powershell.exe:*sn-credentials.ps1*)",
      "Bash(powershell.exe:Get-Content*)",
      "Bash(powershell.exe:Get-ChildItem*)",
      "Bash(powershell.exe:Select-String*)",
      "Bash(powershell.exe:Test-Path*)",
      "Bash(powershell.exe:Get-Item*)",
      "Bash(powershell.exe:Start-Sleep*)",
      "Skill(sn-toolkit:*)",
      "Skill(sn-toolkit:*:*)"
    ],
    "deny": [
      "Read(credentials/**)",
      "Read(agentinstructions.md)",
      "Read(audit.log)",
      "Read(debug.log)"
    ]
  }
}
```

Without this, Claude will prompt for approval every time it invokes the Agent API or runs a plugin slash command (e.g. `/sn-toolkit:start`, `/sn-toolkit:end`).

## Bootstrap a new SN workspace

The point of the bootstrap is **wiring up the connection** between the VS Code sn-scriptsync extension and a ServiceNow instance through the SN Utils browser helper tab. Once that bridge exists, the Agent API rides on top of it and every slash command / hook / agent in this plugin resolves to the right instance automatically.

Custom scope is optional -- supply it only when you're building on a scoped app. For OOB work, global-scope edits, platform exploration, or figuring out the instance before committing to a scope, skip it (it defaults to `global`).

From inside any Claude Code session (with this plugin installed):

```
/sn-toolkit:new-project <name> <instance>                # exploratory / OOB / global
/sn-toolkit:new-project <name> <instance> <scope>        # custom scoped app
```

Examples:

```
/sn-toolkit:new-project aha ahadev
/sn-toolkit:new-project aha ahadev x_icir_aha
```

After the bootstrap finishes:

1. Open the newly-created workspace as your IDE root.
2. Run `/sn-toolkit:creds` to store the SN username/password (DPAPI-encrypted, gitignored).
3. Click the **sn-scriptsync** item in the VS Code status bar and point it at `instances/<instance>/`.
4. In the browser, open the target SN instance and type `/token` into the URL to activate the SN Utils helper tab -- this is the bridge the Agent API uses.
5. Run `/sn-toolkit:start` to verify the round-trip (server running + browser connected).

At that point you're live: every plugin command operates against that instance.

### Standalone bootstrap (no Claude session yet)

First-time setup on a new machine, or if Claude isn't installed:
```powershell
powershell.exe -File "%USERPROFILE%\.claude\plugins\cache\infocenter\sn-toolkit\<version>\bin\bootstrap-project.ps1" -Name "<name>" -Instance "<instance>"
```

Check `~/.claude/plugins/installed_plugins.json` for the exact installed version. Append `-Scope "<x_foo_bar>"` only when you already know the custom scope.

## Project layout the plugin expects

After bootstrap, every SN project workspace looks like:
```
<project>/
|-- <instance>/                        (sn-scriptsync sync dir -- writes here flow to SN)
|-- instances/<instance>/              (Agent API local-only workspace)
|   `-- agent/{requests,responses,tmp}/
|-- scratch/                           (debug artifacts, session-notes.md)
|-- credentials/                       (DPAPI-encrypted, gitignored)
|-- docs/{architecture,context,reference,requirements}/
|-- .claude/
|   |-- settings.local.json            (user-specific overrides, gitignored)
|   `-- rules/                         (project-specific rules only; generic rules live in this plugin)
`-- CLAUDE.md                          (project overview + $api/$instanceDir defs)
```

Hooks auto-detect the instance by reading `<project>/instances/<first-subdir>/`, so they work identically in every workspace without any project-level config.

## Updating the plugin

The Manage Plugins UI doesn't expose an in-place update yet, so the most reliable workflow is delete + reinstall:

1. Customize -> **Manage plugins** -> **Plugins** tab.
2. Click the trash icon next to **sn-toolkit@infocenter** to uninstall.
3. Restart VS Code.
4. Open Manage Plugins again, find sn-toolkit in the **Plugins** tab, toggle it on (the marketplace entry persists, so you don't need to re-add it).
5. Restart VS Code one more time. New version is live.

All workspaces using the plugin pick up the update on next session start. No per-project sync required.

## Teammate distribution

Push this directory to a git repo, then share:
- The marketplace URL: `https://github.com/chrisp28103/sn-toolkit.git`
- The permissions block above (for `~/.claude/settings.json`)
- The bootstrap invocation

Teammates add the marketplace and install the plugin via VS Code's **Manage Plugins** UI (Customize -> Manage plugins -> Marketplaces tab), paste the permissions block once, and are ready to bootstrap their own SN workspaces.

## Why a plugin instead of copying `.claude/` per project?

Prior approach: a template directory (`sn-toolkit/`) was copy-duplicated into each new SN workspace via a bootstrap script. This produced per-project `.claude/` copies that drifted from the template whenever infrastructure changed, and teammates had no easy way to pick up updates.

Plugin-based approach: the `.claude/` infrastructure (hooks, commands, agents, bin scripts) lives in exactly one place -- this repo -- and every workspace loads it dynamically. Updates propagate the next time anyone reinstalls the plugin via Manage Plugins. Drift is structurally impossible.
