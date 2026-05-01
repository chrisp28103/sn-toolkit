# sn-toolkit

A Claude Code plugin that turns any workspace into a ServiceNow development environment. Ships the Agent API wrapper, credential management, session hooks, slash commands, and subagents as shared infrastructure -- no per-project duplication.

## What's in the box

- **26 slash commands** covering the full SN dev loop:
  - **Connect / inventory**: `start`, `end`, `creds`, `list`, `view-response`, `refresh`, `new-project`
  - **Read**: `pull`, `export`, `review`, `audit`
  - **Write**: `create` (schema-aware pre-flight), `update` (single-field + batch), `widget` (preview+refresh loop), `sync-push` (flush + drain + error-check)
  - **Session context**: `switch` (update set / app scope / domain), `start` (surfaces active context)
  - **Visual debugging**: `inspect` (activate tab + `/tn` + screenshot), `attach` (upload files to any record)
  - **Planning**: `refine` (SN-flavored 4-D prompt refiner -- forces naming table/scope/update-set/domain before work), `refine-prompt` (general-purpose 4-D refiner for non-SN prompts)
  - **Documentation**: `spec` (topic-agnostic two-part specification builder -- Part A functional + Part B technical, rendered to PDF; supports `--with-sn-pulls` for SN-anchored Part B), `docs-setup` (one-time opt-in clone of the official SN docs mirror), `docs-sync` (refresh that mirror)
  - **Operations**: `monitor` (use with `/loop 5m`), `diagnose`
- **1 skill**: `sn-toolkit:docs` -- intent-triggered lookup against the official ServiceNow docs at github.com/servicenow/servicenowdocs (Apache 2.0). Three-tier lazy load (search -> peek -> read) keeps token usage minimal; works with or without the local cache.
- **2 subagents**: `sn-explorer` (deep instance exploration, also consults the docs mirror for platform questions) and `sn-reviewer` (code-review against SN scripting standards).
- **5 hooks**: SessionStart (auto-connect to SN), PreToolUse/PostToolUse (block BOM-writes, validate encoding on sn-scriptsync files), Stop (async error check), PostCompact (re-inject session scratchpad).
- **3 bin scripts on PATH** while the plugin is enabled:
  - `sn-agent-api.ps1` -- thin PowerShell wrapper around SN Utils' Agent API (the browser-extension bridge)
  - `sn-credentials.ps1` -- DPAPI-encrypted credential storage for instance auth
  - `sn-docs.ps1` -- search/peek/read against the official ServiceNow docs mirror; uses ripgrep when on PATH, falls back to PowerShell `Select-String` otherwise
- **4 rules** (markdown files with frontmatter `paths:` globs): `conventions.md`, `sn-scripting.md`, `sn-testing.md`, `sn-ui-components.md`. Reference these from your project CLAUDE.md.
- **Autocomplete type defs** in `autocomplete/` for VS Code IntelliSense on ServiceNow APIs -- reference via `jsconfig.json`.

## Prerequisites

This plugin is a thin layer over the **sn-scriptsync** + **SN Utils** stack. Without them, every slash command will time out -- they are **not optional**.

**Required:**

| Requirement | Notes |
|-------------|-------|
| **An IDE that supports VS Code extensions** | VS Code, Cursor, Windsurf, VSCodium, etc. What matters is that the `sn-scriptsync` extension can run somewhere. Pure-terminal Claude Code with **no** VS-Code-style IDE running anywhere cannot drive this plugin -- something has to host sn-scriptsync. |
| **`sn-scriptsync` extension** | The critical piece. Search "sn-scriptsync" in the VS Code Marketplace (or your IDE's equivalent). Creates the bridge between your local file system and the SN Utils browser extension, and serves the Agent API request/response loop under `instances/<instance>/agent/`. |
| **SN Utils browser extension** | Chrome / Edge. Search "SN Utils" in the Chrome Web Store or Edge Add-ons. Exposes the helper tab in your SN instance; activate per-instance by typing `/token` in the SN URL. |
| **Claude Code -- extension OR native CLI** | Two equivalent surfaces. **Extension**: install Claude Code via your IDE's extension panel and use the Claude Code chat panel. **Native CLI**: install `claude` (https://claude.com/claude-code) and run it from the IDE's integrated terminal so it shares the sn-scriptsync workspace. Both expose the same `/plugin` slash command, write to the same `~/.claude/plugins/` cache, and drive this plugin identically. Pick whichever you prefer; you can also use both side-by-side. |

**Nice to have:**

| Capability | Notes |
|------------|-------|
| **Windows** | Only matters if you want `/sn-toolkit:creds` (encrypted username/password storage via DPAPI) and `/sn-toolkit:compare` (direct REST diff between two instances). Both call `sn-credentials.ps1`, which uses Windows DPAPI. The core development loop (sn-scriptsync + Agent API + every other slash command) authenticates through the SN Utils browser session and is OS-agnostic -- so on macOS / Linux you lose the REST-cred features but everything else works. |

Install the required items before proceeding.

## Install

### 1. Add the marketplace + install the plugin

`/plugin` is a Claude Code primitive -- it works identically from the VS Code extension panel and from the native CLI. Pick whichever surface you use day-to-day; both write to the same `~/.claude/plugins/` cache, so plugin state is shared.

#### Method A -- VS Code extension (Manage Plugins UI)

1. **Open the Manage Plugins dialog.** Easiest path: in the Claude Code chat input, type `/plugin` and select **Manage plugins** from the autocomplete menu. (Alternative: open the Claude Code panel in your IDE, scroll to the **Customize** section, and click **Manage plugins** there.)
2. **Add the marketplace.** In the dialog, switch to the **Marketplaces** tab. Paste the URL into the `GitHub repo, URL, or path...` input and click **Add**:
   ```
   https://github.com/chrisp28103/sn-toolkit.git
   ```
3. **Enable the plugin.** Switch to the **Plugins** tab, find **sn-toolkit@infocenter** in the INSTALLED list, and toggle it **on**.
4. **Restart your IDE** (or reload the window) so the SessionStart hook fires on the next Claude Code session.

#### Method B -- Native CLI in the IDE's integrated terminal

If you have the native `claude` CLI on PATH (and you should -- it ships with extra capabilities not yet wired into the extension), this is faster and avoids the GUI:

1. **Open the IDE's integrated terminal** in any folder you want to work from. (Still requires a VS-Code-style IDE for sn-scriptsync to run somewhere; the terminal just gives `claude` a workspace cwd to share.)
2. **Start a CLI session**: `claude`
3. In the CLI session, type `/plugin` -> **Manage plugins** -> **Marketplaces** tab -> paste `https://github.com/chrisp28103/sn-toolkit.git` -> **Add**.
4. **Plugins** tab -> toggle **sn-toolkit@infocenter** on.
5. `/exit` and re-launch `claude` so the SessionStart hook fires. (The CLI doesn't need a full IDE restart -- just a fresh CLI session.) **Note:** if you also have the VS Code extension running, its existing chat panels won't see the new plugin until you start a fresh chat in them.

For local plugin development (before publishing), paste an absolute path to this repo into the marketplace input instead of the GitHub URL. Works from either method.

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

The point of the bootstrap is **wiring up the connection** between the `sn-scriptsync` extension (running in your IDE) and a ServiceNow instance through the SN Utils browser helper tab. Once that bridge exists, the Agent API rides on top of it and every slash command / hook / agent in this plugin resolves to the right instance automatically.

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
3. Click the **sn-scriptsync** item in your IDE's status bar and point it at `instances/<instance>/`.
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

There's no `/plugin update` slash command in Claude Code, but you don't need one. Two clean paths:

### Recommended -- enable auto-update on the marketplace (one-time)

Third-party marketplaces (like `infocenter`) have auto-update **disabled by default** -- official Anthropic marketplaces have it on by default, but ours doesn't until you turn it on. Do this once per machine:

1. In any Claude Code session, type `/plugin` -> **Marketplaces** tab.
2. Select **infocenter** from the list.
3. Click **Enable auto-update**.

That's it. Every Claude Code session start now polls `marketplace.json` from this repo, detects new versions, and installs them automatically. When a new version is detected mid-flow, Claude Code shows a one-line notification telling you to run `/reload-plugins`, which activates the new version in the current session -- no IDE restart, no fresh chat.

If you want to globally opt out of auto-update, set `DISABLE_AUTOUPDATER=1` in your environment. If you want plugin auto-updates without Claude Code itself updating, set `FORCE_AUTOUPDATE_PLUGINS=1`.

### Manual -- direct CLI commands (when auto-update is off, or to force-update mid-session)

These bypass the Manage Plugins menu entirely. Identical behavior in the extension and the native CLI:

```
/plugin uninstall sn-toolkit@infocenter
/plugin install sn-toolkit@infocenter
/reload-plugins
```

`/reload-plugins` activates the new version in the current session, so you don't need to start a new chat, restart your CLI, or reload the IDE window. The marketplace entry persists across uninstall, so you don't have to re-add it.

### Why not `/plugin update`?

Claude Code's `/plugin` command exposes `install`, `uninstall`, `enable`, `disable`, and `marketplace add/remove/update/list` -- but no `update` for plugins themselves. The `marketplace update` subcommand only refreshes marketplace metadata; the plugin-level update path is auto-update + `/reload-plugins`, or the manual uninstall + install pair above. (If/when Anthropic adds a direct `/plugin update`, this section will get shorter.)

All workspaces using the plugin pick up the new version on the next session start regardless of which path you used. No per-project sync required.

## Why a plugin instead of copying `.claude/` per project?

Prior approach: a template directory (`sn-toolkit/`) was copy-duplicated into each new SN workspace via a bootstrap script. This produced per-project `.claude/` copies that drifted from the template whenever infrastructure changed, and teammates had no easy way to pick up updates.

Plugin-based approach: the `.claude/` infrastructure (hooks, commands, agents, bin scripts) lives in exactly one place -- this repo -- and every workspace loads it dynamically. Updates propagate the next time anyone reinstalls the plugin via Manage Plugins. Drift is structurally impossible.
