# sn-toolkit (Claude Code marketplace)

This repo is a Claude Code plugin marketplace. It publishes one plugin:

- **[sn-toolkit](sn-toolkit/)** -- ServiceNow dev kit: 21 slash commands, 2 subagents, 5 hooks, 4 rules, Agent API wrapper, DPAPI credential storage. Full docs in [sn-toolkit/README.md](sn-toolkit/README.md).

## Prerequisites

The plugin is a layer over the **sn-scriptsync** + **SN Utils** stack -- without them, every slash command times out. You need:

- **VS Code** (sn-scriptsync runs as a VS Code extension; no CLI mode exists)
- **sn-scriptsync** VS Code extension (search VS Code Marketplace)
- **SN Utils** browser extension for Chrome / Edge (search Chrome Web Store / Edge Add-ons)
- **Windows** (DPAPI credential storage is Windows-only)

Install the plugin via the VS Code extension's Manage Plugins UI -- see below.

## Install

Install via the Claude Code extension in VS Code (Manage Plugins UI):

1. Open the Claude Code panel -> Customize -> **Manage plugins**.
2. **Marketplaces** tab -> **Add marketplace** -> paste `https://github.com/chrisp28103/sn-toolkit.git`.
3. **Plugins** tab -> toggle **sn-toolkit@infocenter** on.
4. Restart VS Code so the SessionStart hook fires.

Then add the required permissions block to `~/.claude/settings.json` and you're ready to bootstrap an SN workspace. See [sn-toolkit/README.md](sn-toolkit/README.md) for the full install + permissions walkthrough and the complete command list.

## Repo layout

```
.claude-plugin/marketplace.json   -- marketplace manifest (points at ./sn-toolkit)
sn-toolkit/                       -- the plugin itself (commands, hooks, agents, rules, bin)
sn-toolkit/README.md              -- full plugin documentation
```

## Updates

The Manage Plugins UI has no in-place update yet, so the cleanest path is delete + reinstall:

1. Manage plugins -> **Plugins** tab -> trash icon next to **sn-toolkit@infocenter**.
2. Restart VS Code.
3. Manage plugins -> **Plugins** tab -> toggle **sn-toolkit@infocenter** on (marketplace entry persists).
4. Restart VS Code. New version is live.

All workspaces using the plugin pick up the new version on the next session start.
