# sn-toolkit (Claude Code marketplace)

This repo is a Claude Code plugin marketplace. It publishes one plugin:

- **[sn-toolkit](sn-toolkit/)** -- ServiceNow dev kit: 26 slash commands, 1 skill, 2 subagents, 5 hooks, 4 rules, Agent API wrapper, DPAPI credential storage, official-docs lookup. Full docs in [sn-toolkit/README.md](sn-toolkit/README.md).

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

Claude Code's `/plugin` UI has an **Update now** button -- skip the trash-icon-and-reinstall dance entirely. Three paths, in order of "best":

### 1. Auto-update on the marketplace (one-time, set and forget)

Third-party marketplaces have auto-update **disabled by default**. Turn it on once:

1. `/plugin` -> **Marketplaces** tab -> select **infocenter** -> **Enable auto-update**.
2. Done. Every Claude Code session start now polls for new sn-toolkit versions and installs them automatically. `/reload-plugins` activates them mid-session with no IDE restart.

### 2. One-click "Update now" via UI

When auto-update is off, or you want to force a refresh:

1. `/plugin` -> **Plugins** tab -> select **sn-toolkit @ infocenter**.
2. Click **Update now**.
3. `/reload-plugins` to activate in the current session.

### 3. Direct slash commands (scripting, or if you prefer typing)

```
/plugin uninstall sn-toolkit@infocenter
/plugin install sn-toolkit@infocenter
/reload-plugins
```

All three paths end in the same place. `/reload-plugins` activates the new version in the current session -- no fresh chat, no IDE reload.
