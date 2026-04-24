# sn-toolkit (Claude Code marketplace)

This repo is a Claude Code plugin marketplace. It publishes one plugin:

- **[sn-toolkit](sn-toolkit/)** -- ServiceNow scoped-app dev kit: 21 slash commands, 2 subagents, 5 hooks, 4 rules, Agent API wrapper, DPAPI credential storage. Full docs in [sn-toolkit/README.md](sn-toolkit/README.md).

## Install

From inside any Claude Code session:

```
/plugin marketplace add https://github.com/chrisp28103/sn-toolkit.git
/plugin install sn-toolkit@infocenter
```

Then add the required permissions block to `~/.claude/settings.json` and you're ready to bootstrap an SN workspace. See [sn-toolkit/README.md](sn-toolkit/README.md) for the full install + permissions walkthrough and the complete command list.

## Repo layout

```
.claude-plugin/marketplace.json   -- marketplace manifest (points at ./sn-toolkit)
sn-toolkit/                       -- the plugin itself (commands, hooks, agents, rules, bin)
sn-toolkit/README.md              -- full plugin documentation
```

## Updates

```
/plugin update sn-toolkit@infocenter
```

All workspaces using the plugin pick up the new version on the next session start.
