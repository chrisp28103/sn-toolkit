# sn-toolkit (Claude Code marketplace)

This repo is a Claude Code plugin marketplace. It publishes one plugin:

- **[sn-toolkit](sn-toolkit/)** -- ServiceNow dev kit: 27 slash commands, 1 skill, 3 subagents, 7 hooks, 4 rules, Agent API wrapper, DPAPI credential storage, official-docs lookup. Full docs in [sn-toolkit/README.md](sn-toolkit/README.md).

## Prerequisites

The plugin is a layer over the **sn-scriptsync** + **SN Utils** stack -- without them, every slash command times out. You need:

- **An IDE that supports VS Code extensions** -- VS Code, Cursor, Windsurf, VSCodium, etc. The IDE hosts `sn-scriptsync`; pure-terminal Claude Code (with no VS-Code-style IDE running anywhere) cannot drive this plugin.
- **`sn-scriptsync` extension** -- the critical piece (search "sn-scriptsync" in the VS Code Marketplace or your IDE's equivalent). Creates the bridge between your local file system and the SN Utils browser extension.
- **SN Utils** browser extension for Chrome / Edge (search Chrome Web Store / Edge Add-ons).
- **Claude Code** -- either the **VS Code extension** OR the **native CLI** (`claude` on PATH, run from the IDE's integrated terminal so it shares the sn-scriptsync workspace). Both surfaces drive this plugin identically.

Nice to have:

- **Windows** -- only required for `/sn-toolkit:creds` and `/sn-toolkit:compare`, which use DPAPI-encrypted REST credentials. The core sn-scriptsync / Agent API flow runs through the browser bridge and works on any OS that can run PowerShell + the prerequisites above.

Install the plugin via either the VS Code extension's Manage Plugins UI **or** the native CLI's `/plugin` slash command -- see below.

## Install

You can drive Claude Code from two surfaces; the install steps are identical from either, because `/plugin` is a Claude Code primitive that talks to the same plugin system in both:

### Method A -- VS Code extension (Manage Plugins UI)

1. In the Claude Code chat, type `/plugin` and pick **Manage plugins** from the menu. (Equivalent to clicking **Manage plugins** under the **Customize** section of the Claude Code panel.)
2. In the dialog: **Marketplaces** tab -> paste `https://github.com/chrisp28103/sn-toolkit.git` into the input -> click **Add**.
3. **Plugins** tab -> toggle **sn-toolkit@infocenter** on.
4. Restart your IDE so the SessionStart hook fires.

### Method B -- Native CLI in your IDE's integrated terminal

Same flow, no IDE-extension required (handy if you prefer the CLI, or if your IDE's Claude Code extension lags the CLI on features). The CLI binary is `claude` -- run it inside the IDE's integrated terminal so the cwd shares the sn-scriptsync workspace.

1. Open the IDE's integrated terminal (still requires VS-Code-style IDE for sn-scriptsync to be running) and start a CLI session: `claude`.
2. In the CLI session, type `/plugin` -> **Manage plugins** -> **Marketplaces** tab -> paste `https://github.com/chrisp28103/sn-toolkit.git` -> **Add**.
3. **Plugins** tab -> toggle **sn-toolkit@infocenter** on.
4. Exit and re-launch `claude` (or just `/exit` and start a new session) so the SessionStart hook fires.

Either method writes to the same `~/.claude/plugins/` cache, so plugin state is shared.

Then add the required permissions block to `~/.claude/settings.json` and you're ready to bootstrap an SN workspace. See [sn-toolkit/README.md](sn-toolkit/README.md) for the full install + permissions walkthrough and the complete command list.

## Repo layout

```
.claude-plugin/marketplace.json   -- marketplace manifest (points at ./sn-toolkit)
sn-toolkit/                       -- the plugin itself (commands, hooks, agents, rules, bin)
sn-toolkit/README.md              -- full plugin documentation
```

## Updates

First, terminology. "Claude Code" ships as **two separate products** that are easy to confuse:

- **Claude Code CLI** -- the `claude` command-line binary. Install it from npm/Anthropic and run it in your IDE's integrated terminal (`claude`). Interactive `/plugin` menu, `/reload-plugins`, autocomplete -- all live here.
- **Claude Code VS Code extension** -- a chat panel installed from the VS Code Marketplace. Lives in the VS Code sidebar, has its own **Manage Plugins** UI under **Customize**.

They share `~/.claude/plugins/` (so a plugin installed in one is visible in the other) but they are **not** the same UI. The features available in each differ.

**Run all plugin updates from the Claude Code CLI**, not from the Claude Code VS Code extension.

Why: the **Enable auto-update** toggle (Marketplaces tab) and the **Update now** button (Plugins tab) only exist in the CLI's interactive `/plugin` UI. The VS Code extension's Manage Plugins panel exposes neither -- to update from the extension you have to uninstall the plugin, restart VS Code, reinstall the plugin, then restart VS Code again. Run `claude` in your IDE's integrated terminal once and you skip that dance forever. Updates you make in the CLI are immediately visible to the extension's chat panel on its next session start.

Three paths, in order of "best":

### 1. Auto-update on the marketplace (one-time, set and forget) -- CLI only

Third-party marketplaces have auto-update **disabled by default**. Turn it on once from the CLI:

1. Open your IDE's integrated terminal and run `claude` (the **Claude Code CLI**).
2. In the CLI, type `/plugin` -> **Marketplaces** tab -> select **infocenter** -> **Enable auto-update**.
3. Done. Every CLI session start now polls for new sn-toolkit versions and installs them automatically. `/reload-plugins` activates them mid-session with no IDE restart.

The Claude Code VS Code extension's Manage Plugins panel does not expose this toggle.

### 2. One-click "Update now" via UI -- CLI only

When auto-update is off, or you want to force a refresh:

1. Open your IDE's integrated terminal and run `claude` (the **Claude Code CLI**).
2. In the CLI, type `/plugin` -> **Plugins** tab -> select **sn-toolkit @ infocenter**.
3. Click **Update now**.
4. `/reload-plugins` to activate in the current session.

The Claude Code VS Code extension's Manage Plugins panel does not expose this button.

### 3. Direct slash commands (works in either product)

If you only have the Claude Code VS Code extension's chat panel open, this path still works -- the slash commands are universal:

```
/plugin uninstall sn-toolkit@infocenter
/plugin install sn-toolkit@infocenter
/reload-plugins
```

No IDE restart required -- `/reload-plugins` activates the new version in the current session.

All three paths end in the same place. Paths 1 and 2 (CLI-only) are strongly preferred; reach for path 3 only if you can't open a CLI session in the integrated terminal.
