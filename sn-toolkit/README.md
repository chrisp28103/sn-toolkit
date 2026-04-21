# sn-toolkit

A Claude Code plugin that turns any workspace into a ServiceNow scoped-app development environment. Ships the Agent API wrapper, credential management, session hooks, slash commands, and subagents as shared infrastructure -- no per-project duplication.

## What's in the box

- **16 slash commands** (`/sn-toolkit:start`, `/sn-toolkit:end`, `/sn-toolkit:widget`, `/sn-toolkit:pull`, `/sn-toolkit:creds`, etc.) covering the full SN dev loop: connect, query, create, edit, widget preview, session wrap-up, health monitoring.
- **2 subagents**: `sn-explorer` (deep instance exploration) and `sn-reviewer` (code-review against SN scripting standards).
- **5 hooks**: SessionStart (auto-connect to SN), PreToolUse/PostToolUse (block BOM-writes, validate encoding on sn-scriptsync files), Stop (async error check), PostCompact (re-inject session scratchpad).
- **2 bin scripts on PATH** while the plugin is enabled:
  - `sn-agent-api.ps1` -- thin PowerShell wrapper around SN Utils' Agent API (the browser-extension bridge)
  - `sn-credentials.ps1` -- DPAPI-encrypted credential storage for instance auth
- **4 rules** (markdown files with frontmatter `paths:` globs): `conventions.md`, `sn-scripting.md`, `sn-testing.md`, `sn-ui-components.md`. Reference these from your project CLAUDE.md.
- **Autocomplete type defs** in `autocomplete/` for VS Code IntelliSense on ServiceNow APIs -- reference via `jsconfig.json`.

## Install

### 1. Add the marketplace + install the plugin

```
/plugin marketplace add https://github.com/chrisp28103/sn-toolkit.git
/plugin install sn-toolkit@infocenter
```

For local development (before publishing):
```
/plugin marketplace add <absolute-path-to-this-repo>
/plugin install sn-toolkit@infocenter
```

Reload your Claude session so SessionStart hooks can fire.

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
      "Bash(powershell.exe:Start-Sleep*)"
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

Without this, Claude will prompt for approval every time it invokes the Agent API.

## Bootstrap a new SN workspace

From inside any Claude Code session (with this plugin installed):
```
/sn-toolkit:new-project <name> <scope> <instance>
```

Example:
```
/sn-toolkit:new-project aha x_icir_aha ahadev
```

Then open the newly-created workspace as your IDE root and run `/sn-toolkit:creds` to configure credentials.

### Standalone bootstrap (no Claude session yet)

First-time setup on a new machine, or if Claude isn't installed:
```powershell
powershell.exe -File "%USERPROFILE%\.claude\plugins\cache\infocenter\sn-toolkit\<version>\bin\bootstrap-project.ps1" -Name "<name>" -Scope "<scope>" -Instance "<instance>"
```

Check `~/.claude/plugins/installed_plugins.json` for the exact installed version.

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

Pull new versions:
```
/plugin update sn-toolkit@infocenter
```

All workspaces using the plugin pick up the update on next session start. No per-project sync required.

## Teammate distribution

Push this directory to a git repo, then share:
- The marketplace URL: `https://github.com/chrisp28103/sn-toolkit.git`
- The permissions block above (for `~/.claude/settings.json`)
- The bootstrap invocation

Teammates run `/plugin marketplace add ...`, `/plugin install sn-toolkit@infocenter`, paste the permissions block once, and are ready to bootstrap their own SN workspaces.

## Why a plugin instead of copying `.claude/` per project?

Prior approach: a template directory (`sn-toolkit/`) was copy-duplicated into each new SN workspace via a bootstrap script. This produced per-project `.claude/` copies that drifted from the template whenever infrastructure changed, and teammates had no easy way to pick up updates.

Plugin-based approach: the `.claude/` infrastructure (hooks, commands, agents, bin scripts) lives in exactly one place -- this repo -- and every workspace loads it dynamically. Updates propagate via `/plugin update`. Drift is structurally impossible.
