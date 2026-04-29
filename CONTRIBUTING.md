# Contributing to sn-toolkit

Thanks for your interest! sn-toolkit is a Claude Code plugin for ServiceNow development. Contributions are welcome -- bug reports, feature ideas, and pull requests.

## Reporting bugs

Open an issue using the **Bug report** template. Helpful details:

- sn-toolkit version (`cat sn-toolkit/.claude-plugin/plugin.json`)
- Claude Code version (`claude --version`)
- ServiceNow instance type (PDI / scoped app / domain-separated)
- The slash command or skill that failed
- Relevant output from `get_last_error` or `~/.sn-toolkit/logs/`

## Suggesting features

Open an issue describing the use case. The toolkit is intentionally narrow -- it targets the SN dev loop (Agent API + scriptsync + DPAPI creds). Features that broaden scope outside that loop will likely be declined.

## Pull requests

1. Fork and create a branch from `main`.
2. Keep PRs focused -- one logical change per PR.
3. Bump `sn-toolkit/.claude-plugin/plugin.json` `version` per [SemVer](https://semver.org):
   - **patch** (1.x.Y) -- bug fixes, doc-only changes
   - **minor** (1.X.0) -- new commands/skills/agents, backwards-compatible
   - **major** (X.0.0) -- breaking changes to command behavior, hook contracts, or file conventions
4. Add a `CHANGELOG.md` entry under the new version.
5. Test against a real ServiceNow PDI before submitting.

## Code conventions

- **PowerShell scripts** (`bin/*.ps1`): Windows PowerShell 5.1 compatible. No `&&` / `||` / ternary / null-coalescing operators.
- **ASCII-only** in any file that gets pushed to a ServiceNow instance (commands, agents, rules). The plugin enforces this in its own hooks for downstream projects -- contributions to the plugin itself should follow the same rule for consistency.
- **No client/instance-specific values.** Use generic placeholders like `x_<vendor>_<app>` (or `<scope>`) and `<instance>` in all examples -- not real scope prefixes or instance hostnames.

## License

By contributing, you agree your contributions will be licensed under the [MIT License](LICENSE).
