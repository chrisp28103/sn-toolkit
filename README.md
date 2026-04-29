# sn-toolkit (Claude Code marketplace)

This repo is a Claude Code plugin marketplace. It publishes one plugin:

- **[sn-toolkit](sn-toolkit/)** -- ServiceNow dev kit: 21 slash commands, 2 subagents, 5 hooks, 4 rules, Agent API wrapper, DPAPI credential storage. Full docs in [sn-toolkit/README.md](sn-toolkit/README.md).

## Prerequisites

The plugin is a layer over the **sn-scriptsync** + **SN Utils** stack -- without them, every slash command times out. You need:

- **An IDE that supports VS Code extensions** -- VS Code, Cursor, Windsurf, VSCodium, etc. The IDE just hosts `sn-scriptsync`; pure-terminal Claude Code (no IDE running) cannot drive this plugin.
- **`sn-scriptsync` extension** -- the critical piece (search "sn-scriptsync" in the VS Code Marketplace or your IDE's equivalent). Creates the bridge between your local file system and the SN Utils browser extension.
- **SN Utils** browser extension for Chrome / Edge (search Chrome Web Store / Edge Add-ons).

Nice to have:

- **Windows** -- only required for `/sn-toolkit:creds` and `/sn-toolkit:compare`, which use DPAPI-encrypted REST credentials. The core sn-scriptsync / Agent API flow runs through the browser bridge and works on any OS that can run PowerShell + the prerequisites above.

Install the plugin via the Claude Code extension's Manage Plugins UI -- see below.

## Install

Install via the Claude Code extension in your IDE (VS Code / Cursor / Windsurf / etc.):

1. In the Claude Code chat, type `/plugin` and pick **Manage plugins** from the menu. (Equivalent to clicking **Manage plugins** under the **Customize** section of the Claude Code panel.)
2. In the dialog: **Marketplaces** tab -> paste `https://github.com/chrisp28103/sn-toolkit.git` into the input -> click **Add**.
3. **Plugins** tab -> toggle **sn-toolkit@infocenter** on.
4. Restart your IDE so the SessionStart hook fires.

Then add the required permissions block to `~/.claude/settings.json` and you're ready to bootstrap an SN workspace. See [sn-toolkit/README.md](sn-toolkit/README.md) for the full install + permissions walkthrough and the complete command list.

## Repo layout

```
.claude-plugin/marketplace.json   -- marketplace manifest (points at ./sn-toolkit)
sn-toolkit/                       -- the plugin itself (commands, hooks, agents, rules, bin)
sn-toolkit/README.md              -- full plugin documentation
```

## Updates

The Manage Plugins UI has no in-place update yet, so the cleanest path is delete + reinstall:

1. `/plugin` -> **Manage plugins** -> **Plugins** tab -> trash icon next to **sn-toolkit@infocenter**.
2. Restart your IDE.
3. `/plugin` -> **Manage plugins** -> **Plugins** tab -> toggle **sn-toolkit@infocenter** on (marketplace entry persists).
4. Restart your IDE. New version is live.

All workspaces using the plugin pick up the new version on the next session start.
