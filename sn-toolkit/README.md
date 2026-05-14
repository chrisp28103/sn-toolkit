# sn-toolkit

A Claude Code plugin that turns any workspace into a ServiceNow development environment. Ships the Agent API wrapper, credential management, session hooks, slash commands, and subagents as shared infrastructure -- no per-project duplication.

## What's in the box

- **27 slash commands** covering the full SN dev loop:
  - **Connect / inventory**: `start`, `end`, `creds`, `list`, `view-response`, `refresh`, `new-project`
  - **Read**: `pull`, `export`, `review`, `audit`
  - **Write**: `create` (schema-aware pre-flight), `update` (single-field + batch), `widget` (preview+refresh loop), `sync-push` (flush + drain + error-check)
  - **Session context**: `switch` (update set / app scope / domain), `start` (surfaces active context)
  - **Visual debugging**: `inspect` (activate tab + `/tn` + screenshot), `attach` (upload files to any record)
  - **Planning**: `refine-prompt` (Lyra 4-D prompt refiner -- works for any vague request, including ServiceNow ones; forces naming goal/audience/output/constraints before work)
  - **Documentation**: `spec` (topic-agnostic two-part specification builder -- Part A functional + Part B technical, rendered to PDF; supports `--with-sn-pulls` for SN-anchored Part B), `docs-setup` (one-time opt-in clone of the official SN docs mirror), `docs-sync` (refresh that mirror)
  - **Operations**: `monitor` (use with `/loop 5m`), `diagnose`
- **1 skill**: `sn-toolkit:docs` -- intent-triggered lookup against the official ServiceNow docs at github.com/servicenow/servicenowdocs (Apache 2.0). Three-tier lazy load (search -> peek -> read) keeps token usage minimal; works with or without the local cache.
- **3 subagents**: `sn-explorer` (deep instance exploration, also consults the docs mirror for platform questions), `sn-reviewer` (code-review against SN scripting standards), and `sn-platform-admin` (instance-level concerns: ACLs, domain separation, sys_properties, update sets, email).
- **7 hooks**: SessionStart x2 (auto-connect to SN, keep sn-scriptsync multi-instance patch alive across extension auto-updates), UserPromptSubmit (inject active SN instance pin into every prompt), PreToolUse/PostToolUse (block BOM-writes, validate encoding on sn-scriptsync files), Stop (async error check), PostCompact (re-inject session scratchpad).
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

## Multi-instance routing (v1.18.0+)

`sn-scriptsync` upstream allows exactly one helper-tab WebSocket connection at a time. A second `/token` from another instance closes the first with `"Max connection"`. If you work across `dev`, `prod`, `staging`, or hop between client tenants, that meant serial context-switching, one instance at a time -- painful when an AI agent is driving.

v1.18.0 lifts that limit. **Two or more helper tabs can stay connected simultaneously**, each routed to its own instance by `instance.url`. From a single Claude Code session you can query DEV and PROD in parallel, promote a script from one to the other in a single turn, or run `/sn-toolkit:compare` as a fan-out instead of a serial flip-flop.

### How it works -- two layers

| Layer | What it does | Where it lives |
|---|---|---|
| **Transport** (patch) | Removes the singleton guard in `sn-scriptsync`'s WebSocket server. Stamps each helper-tab connection with its source `instance.url`. Routes outbound messages by URL; falls back to broadcast for legacy messages without instance info. Filters error relay so `_last_error.json` only lands in the source folder. | `bin/apply-snscriptsync-patch.ps1` -- patches the installed extension's `extension.js`. Anchored by string literals (not line numbers), idempotent, reversible via `-Revert`. |
| **Intent** (pin) | Per-project record of which instance the current Claude conversation should target for *writes*. Injected as `[Active SN instance: <name>]` into every prompt by a `UserPromptSubmit` hook, so the pin survives across turns and compaction. | `.claude/project.json` -> `"instance": "<name>"`. Read by `hooks/inject-instance-context.ps1`. |

These are deliberately separate. The transport patch is per-extension-install (one machine, one patch). The intent pin is per-project (different projects can target different instances). Read operations don't need a pin -- they target whatever instance the file path or `-InstanceDir` argument names. The pin only governs ambiguous writes.

### One-time setup per machine

`apply-snscriptsync-patch.ps1` ships on PATH while the plugin is enabled. The bootstrap (`/sn-toolkit:new-project`) runs it automatically on step 7. To apply manually:

```powershell
apply-snscriptsync-patch.ps1            # apply (creates extension.js.bak first)
apply-snscriptsync-patch.ps1 -DryRun    # show what would change, no write
apply-snscriptsync-patch.ps1 -Revert    # restore the unpatched extension
```

After applying, **toggle the sn-scriptsync status-bar item off and on** (or reload the IDE window). The on-disk file is patched, but the running WS server is still pre-patch until it restarts.

A `SessionStart` hook (`hooks/scriptsync-patch-check.ps1`) counts the patch markers in the live `extension.js` every time a Claude session starts. If `sn-scriptsync` auto-updated and the markers are gone, the hook reapplies the patch silently and emits a one-line banner notice telling you to reload the extension. If the markers are partially present (upstream refactored an anchor block), the hook surfaces a red warning and does NOT auto-fix -- the anchors in `apply-snscriptsync-patch.ps1` need to be updated to match the new shape.

### Per-conversation use

The `/sn-toolkit:instance` skill manages the pin:

```
/sn-toolkit:instance                # list instances, show current, prompt to pick
/sn-toolkit:instance dev            # pin to instances/dev/
/sn-toolkit:instance show           # display current pin only, no write
```

The chosen name is written to `.claude/project.json`'s `instance` field. Every subsequent prompt arrives with `[Active SN instance: dev] -- pushes/edits/creates should target this instance unless the user explicitly says otherwise.` injected as a system reminder.

Switching mid-session is just `/sn-toolkit:instance <other-name>`. The pin takes effect on the NEXT prompt (the current turn already happened).

### Workspace layout for multi-instance

```
<project>/
|-- instances/
|   |-- dev/
|   |   |-- _settings.json          (sn-scriptsync workspace settings)
|   |   `-- agent/{requests,responses}/
|   `-- prod/
|       |-- _settings.json
|       `-- agent/{requests,responses}/
|-- .claude/
|   `-- project.json                (contains "instance": "dev")
`-- CLAUDE.md
```

Each `instances/<name>/` is its own sn-scriptsync workspace. Connect sn-scriptsync to **one** of them at a time per IDE window, OR run two IDE windows pointed at different instance dirs, OR (the original motivation) connect a single IDE workspace to multiple instances by having multiple browser helper tabs open -- each tab's `_token` succeeds because the patch removed the singleton guard.

### Daily workflow examples

**Dev -> Prod parity audit, parallel fan-out:**
```
/sn-toolkit:instance dev                                    # pin writes to dev
/sn-toolkit:compare <spec>                                  # queries BOTH instances in parallel via separate helper tabs
```

**Hot-fix promote in one turn (galaxy brain):**
```
/sn-toolkit:instance dev                                    # write target is dev
/sn-toolkit:update <table> <sys_id> <field> <new-content>   # lands in dev
# verify the change is good, then:
/sn-toolkit:instance prod                                   # flip pin
/sn-toolkit:update <table> <sys_id> <field> <new-content>   # lands in prod
```

**Cross-instance debugging:**
```
/sn-toolkit:pull <record-name>                              # pulls from current pin (dev)
# look at the script, find a referenced table that exists in prod but not dev
/sn-toolkit:instance prod
/sn-toolkit:pull <related-record>                           # pulls from prod
# now you have both side-by-side without context-switching helper tabs
```

### When things break

| Symptom | Cause | Fix |
|---|---|---|
| Banner notice at session start: "patch was missing... reapplied automatically" | sn-scriptsync auto-updated. Patch was applied to the OLD `extension.js`; the new version has no markers. | Hook already reapplied. Toggle the sn-scriptsync status-bar item off and on to load the patched code into the running WS server. |
| Banner notice: "PARTIAL state (3 / 5 markers)" | Upstream refactored a `wss.on(connection)` / `broadcastToHelperTab` / `relayErrorToAgent` block. Some anchors still match, some don't. | Open `bin/apply-snscriptsync-patch.ps1`, find the anchor string that no longer matches the current `extension.js`, update it, run `apply-snscriptsync-patch.ps1 -DryRun` to confirm, then apply. File an issue with the upstream version number so the plugin's anchors can ship updated. |
| `[sn-instance] .claude/project.json names instance 'X' but instances\X\_settings.json is missing` | Instance dir was renamed/deleted while the pin still references it. | Run `/sn-toolkit:instance` (no args) to re-pick from the current set of instances. |
| Two helper tabs, second one closes with "Max connection" anyway | Patched `extension.js` on disk, but the running server didn't pick it up. | Toggle the sn-scriptsync status bar item, or reload the IDE window. The patcher's stdout reminds you on every apply. |
| Second helper tab connects but `check_connection` from one instance dir times out | The wrong helper tab is bound to that instance's URL. The `_token` request stamps `ws.instanceUrl` -- if you opened the tab pointed at the wrong instance and accepted `/token`, it's stamped wrong. | Close the misbound tab. Re-open it on the correct instance. Type `/token` again to re-identify. |
| Pin says `dev` but write went to `prod` | Pin is **instruction, not enforcement**. The hook prefixes the prompt; Claude reads it and SHOULD honor it, but a tool call that explicitly names `-InstanceDir instances\prod` will still execute. | Use `/sn-toolkit:instance dev` proactively before pushes. Hard enforcement (block prod writes when pin is dev) is planned for a future release via the existing tool-guard hook. |

### Caveats

- **Same-profile cookie jar**: two helper tabs in the same Chrome profile share cookies. If both instances use the same SSO host, you could authenticate to one and inadvertently be authenticated to the other. **Use separate Chrome profiles per instance** when working across security boundaries.
- **`extension.js.bak` is the rollback**: the patcher backs up the original on first apply and never overwrites the backup. `-Revert` always restores the byte-exact original.
- **Per-extension-install, not per-project**: the patch lives in `~/.vscode/extensions/arnoudkooicom.sn-scriptsync-<ver>/out/extension.js` (or the Antigravity equivalent). One patch covers every project on the machine. You don't need to re-patch when switching workspaces.
- **The pin is INSTRUCTION, not enforcement**: Claude reads `[Active SN instance: X]` as guidance. If you're collaborating with a model that decides to override it, the tool call still executes. Keep an eye on outputs that name the wrong instance.

### Credits

The multi-instance routing patch was designed by Matthew (independent contributor) and contributed back. v1.18.0 ports it into the plugin's `bin/` and reconciles the skills/hooks layer with sn-toolkit's existing instance-resolution stack (`Resolve-SnInstance`, `.claude/project.json.instance`). The original standalone kit lives separately and the upstream `sn-scriptsync` extension is unmodified at source -- only the installed compiled file is patched.

## Updating the plugin

First, terminology. "Claude Code" ships as **two separate products** that are easy to confuse:

- **Claude Code CLI** -- the `claude` command-line binary. Install from npm/Anthropic and run it in your IDE's integrated terminal (`claude`). Interactive `/plugin` menu, `/reload-plugins`, autocomplete -- all live here.
- **Claude Code VS Code extension** -- a chat panel installed from the VS Code Marketplace. Lives in the VS Code sidebar; has its own **Manage Plugins** UI under **Customize**.

They share `~/.claude/plugins/` (a plugin installed in one is visible in the other) but they are **not** the same UI. The features available in each differ -- and plugin updates is one of those differences.

**Run all plugin updates from the Claude Code CLI**, not from the Claude Code VS Code extension.

Why this matters: the **Enable auto-update** toggle (Marketplaces tab) and the **Update now** button (Plugins tab) only exist in the Claude Code CLI's interactive `/plugin` UI. The VS Code extension's Manage Plugins panel exposes neither -- to update from the extension you have to uninstall the plugin, restart VS Code, reinstall the plugin, then restart VS Code again. Open the integrated terminal, run `claude` once, and you skip the dance forever. Updates you make from the CLI propagate immediately to the extension's chat panel (next session start picks them up).

Three paths, all converging on the same outcome. Pick whichever fits your workflow.

### 1. Auto-update on the marketplace (recommended, one-time) -- CLI only

Third-party marketplaces (like `infocenter`) ship with auto-update **disabled by default** -- official Anthropic marketplaces have it on, but ours doesn't until you flip it. Do this once per machine:

1. Open your IDE's integrated terminal and run `claude` (the **Claude Code CLI**).
2. In the CLI, type `/plugin` -> **Marketplaces** tab.
3. Select **infocenter**.
4. **Enable auto-update**.

After that, every CLI session start polls `marketplace.json` from this repo, detects new versions, and installs them. `/reload-plugins` activates the update in the current session -- no IDE restart, no fresh chat.

Global opt-out: `DISABLE_AUTOUPDATER=1` in your env. Plugin updates only (skip Claude Code itself): `FORCE_AUTOUPDATE_PLUGINS=1`.

The Claude Code VS Code extension's Manage Plugins panel does not expose the **Enable auto-update** toggle -- this path is reachable only from the Claude Code CLI.

### 2. One-click "Update now" via the UI -- CLI only

When auto-update is off, or to force a refresh on demand:

1. Open your IDE's integrated terminal and run `claude` (the **Claude Code CLI**).
2. In the CLI, type `/plugin` -> **Plugins** tab -> select **sn-toolkit @ infocenter**.
3. Click **Update now** in the action menu.
4. Run `/reload-plugins` to activate in the current session.

The **Update now** action lives in the Claude Code CLI's interactive `/plugin` menu. The Claude Code VS Code extension's Manage Plugins panel does not expose this button.

### 3. Direct slash commands (works in either product)

If you can't open a CLI session in the integrated terminal, the slash commands still work from the Claude Code VS Code extension's chat panel:

```
/plugin uninstall sn-toolkit@infocenter
/plugin install sn-toolkit@infocenter
/reload-plugins
```

The marketplace entry persists across uninstall, so the second command pulls from the cached marketplace metadata. No IDE restart required -- `/reload-plugins` activates the new version in place.

### A note on `/plugin update`

Claude Code's `/plugin` slash command does not include an `update` subcommand. Update is a UI button (path 2) and a marketplace-level toggle (path 1), not a slash subcommand. The slash-command level only exposes `install`, `uninstall`, `enable`, `disable`, and `marketplace add/remove/update/list`.

All three paths write to `~/.claude/plugins/cache/...`, so workspaces pick up the new version on next session start regardless of which path you used. No per-project sync required.

## Why a plugin instead of copying `.claude/` per project?

Prior approach: a template directory (`sn-toolkit/`) was copy-duplicated into each new SN workspace via a bootstrap script. This produced per-project `.claude/` copies that drifted from the template whenever infrastructure changed, and teammates had no easy way to pick up updates.

Plugin-based approach: the `.claude/` infrastructure (hooks, commands, agents, bin scripts) lives in exactly one place -- this repo -- and every workspace loads it dynamically. Updates propagate via the marketplace auto-update toggle (or any of the update paths above). Drift is structurally impossible.
