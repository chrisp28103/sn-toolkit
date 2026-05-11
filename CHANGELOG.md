# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.17.0] - 2026-05-11

### Fixed
- `bin/bootstrap-project.ps1` `-OutputDir` default was `$env:USERPROFILE\Documents\ServiceNow`, which silently bypasses OneDrive's Known Folder Move redirect of the Documents folder. On OneDrive-redirected machines new projects landed in the unredirected `C:\Users\<user>\Documents\ServiceNow` rather than the user's actual OneDrive Documents tree. Default is now empty; the script resolves via `Read-Host` prompt when run from an interactive shell, or falls back to `[Environment]::GetFolderPath('MyDocuments')\ServiceNow` silently when `[Console]::IsInputRedirected` is true (Claude tool calls, CI, piped input). `GetFolderPath('MyDocuments')` is the OneDrive-aware API.
- `CLAUDE.md.template` directory-structure block hardcoded both `__SCOPE__/` and `global/` lines, so when `-Scope global` was passed (OOB engagements) the generated CLAUDE.md rendered `global/` twice. Replaced both lines with a single `__SCOPE_DIR_BLOCK__` placeholder; `bin/bootstrap-project.ps1` now substitutes either a one-line block (`Scope=global`) or a two-line block (custom scope + `global/`) before writing the file.

### Changed
- `/sn-toolkit:new-project` skill inserts a new step asking the user where to create the project via `AskUserQuestion` and passes the answer to `bootstrap-project.ps1` as `-OutputDir`. Rationale: bootstrap runs under a redirected stdin when invoked as a Claude tool call, which suppresses the script's interactive prompt and would silently use the default. Surfacing the choice in the skill keeps the plugin folder-layout-agnostic across teammates. Subsequent steps renumbered; examples updated to show explicit `-OutputDir` plus a no-arg standalone-interactive case.

## [1.16.1] - 2026-05-04

### Fixed
- `bin/sn-agent-api.ps1` `ConvertTo-JsonValue` helper used `return if ($val) { "true" } else { "false" }`, which is PS7-only syntax. On Windows PowerShell 5.1 it raised "the term 'if' is not recognized" and broke any command whose `Params` hashtable contained a boolean (notably `switch_context` with `reloadTab=$true`). Rewritten as `if ($val) { return "true" } else { return "false" }`. Verified against zerovector PROD on 2026-05-04. Non-boolean param paths are unchanged.

## [1.16.0] - 2026-05-01

### Added
- `/sn-toolkit:claude-md-audit` -- new command that audits CLAUDE.md drift against the live instance via `query_records`. Checks that referenced tables, scopes, and script names exist on the instance and reports stale references grouped by severity (Critical = not found, Warning = inactive, Info = unverifiable).
- `agents/sn-platform-admin.md` -- new SN Platform Admin agent, a role-specific counterpart to `sn-explorer`. Focuses on instance-level concerns: ACLs, domain separation, `sys_properties`, user criteria, update sets, approval routing, email intake. Dispatched when the user asks about platform-wide config rather than scoped-app scripting.

### Changed
- `/sn-toolkit:review` refactored to fan out parallel `SN Reviewer` agents (one per script, capped at 10) with per-finding confidence scoring (0-100, threshold 80). Findings below 80 are dropped from the report. Documents the ~5-10x token cost increase inline; the tradeoff is actionable-only output.
- `hooks/tool-guard.ps1` PostToolUse now scans `.js` and `.html` files in the SN workspace for security patterns after each edit and surfaces findings to Claude via exit 2 stderr (advisory, does not reverse the edit). Patterns: `gs.evaluate()`, bare `eval()`, `queryNoDomain()`, dynamic `gs.include()` with string concatenation, `setRedirectURL()` with a variable, `ng-bind-html` without `$sce.trustAsHtml`.
- `hooks/session-checkpoint.ps1` Stop handler now emits `decision: block` (preventing session exit) when the scriptsync queue has pending file writes or an unread async error. Previously these conditions only emitted a `systemMessage` warning while allowing exit. A `stop_hook_active` guard prevents infinite blocking: the hook exits cleanly if it has already fired once on the current Stop turn.

## [1.15.2] - 2026-05-01

### Changed
- Update-the-plugin docs corrected (third pass) to surface the **Update now** button in the `/plugin` UI action menu. Previous v1.15.1 docs claimed the only paths were marketplace-level auto-update or direct slash commands; the UI actually has a one-click **Update now** action when you select an installed plugin in the **Plugins** tab. Both READMEs now document three paths in order: (1) marketplace auto-update one-time toggle, (2) **Update now** UI button on demand, (3) direct `/plugin uninstall` + `/plugin install` + `/reload-plugins` slash commands. Note added that `/plugin update` is not a slash subcommand even though "update now" is a UI action.

## [1.15.1] - 2026-05-01

### Changed
- Update-the-plugin docs in both READMEs rewritten. The previous "uninstall via Manage Plugins UI trash icon -> restart IDE -> toggle on -> restart IDE" flow was replaced with two cleaner paths: (1) **enable auto-update** on the `infocenter` marketplace once via `/plugin -> Marketplaces -> Enable auto-update`, after which new versions install automatically at session start and a `/reload-plugins` activates them mid-session with no restart; (2) **direct CLI commands** `/plugin uninstall sn-toolkit@infocenter` + `/plugin install sn-toolkit@infocenter` + `/reload-plugins` for manual / forced updates. `/plugin update` does not exist as a Claude Code slash command -- both READMEs now explain why and what to use instead.

## [1.15.0] - 2026-05-01

### Added
- New `sn-toolkit:docs` skill: lazy-loaded lookup against the official ServiceNow docs repo at github.com/servicenow/servicenowdocs (Apache 2.0, ~154 MB, pure markdown, AI-optimized -- no images). Three-tier flow mirrors `fluent:now-sdk-explain`: status -> search/list -> peek -> read. Skill body holds zero doc content; all bulk lives on disk or arrives via single-file webfetch.
- New `bin/sn-docs.ps1` CLI on PATH with subcommands `sync | status | list | search | peek | read | webfetch | help`. Token-disciplined output: search caps hits at -Max (default 30), peek returns head + H2 outline (never full body), read only used after peek confirms relevance.
- New `/sn-toolkit:docs-setup` slash command: explicit opt-in setup that clones servicenow/servicenowdocs to `$env:LOCALAPPDATA\sn-toolkit\servicenow-docs\` via `git clone --depth 1 --filter=blob:none` (shallow + blobless). Idempotent.
- New `/sn-toolkit:docs-sync` slash command: user-initiated cache refresh via incremental `git pull --ff-only`.
- `agents/sn-explorer.md` now consults `sn-docs` for ServiceNow platform/API/convention questions before answering, with citation to the GitHub source.

### Changed
- **Both READMEs** rewritten to document two install/update methods side by side: VS Code extension Manage Plugins UI, and native `claude` CLI run from the IDE's integrated terminal. `/plugin` is a Claude Code primitive; both surfaces share the same `~/.claude/plugins/` cache and drive this plugin identically. CLI flow avoids IDE restarts -- a fresh `claude` session is enough.
- `bin/sn-docs.ps1` `search`: prefers ripgrep when on PATH (sub-second on the ~200 MB cache), falls back to PowerShell `Select-String` automatically when not (works everywhere, slower). Uses `--path-separator /` so the post-processing prefix-strip doesn't corrupt markdown escapes (`\(`, `\_`) inside snippet content.
- `bin/sn-docs.ps1` `sync`: tolerant of Windows-specific clone quirks -- enables `core.longpaths=true` for paths exceeding MAX_PATH and `core.ignorecase=true` for case-collision warnings on the `markdown/security-management/` subtree. If 40+ product areas check out (real-world: all 50 are present), checkout warnings are surfaced but treated as non-fatal.

### Design notes
- Cache is **opt-in only**. A fresh plugin install never auto-clones. The skill works immediately without the cache via `webfetch` fallback (one HTTP fetch per file from raw.githubusercontent.com); local cache is a deliberate user-initiated upgrade for offline + ripgrep speed.
- **No background refresh** -- no cron, no SessionStart pull, no auto-anything. Staleness reported by `sn-docs status` but never acted on.
- Plugin manifest description updated `24 slash commands` -> `26 slash commands` and gains "official-docs lookup skill".
- Default branch of upstream repo is `australia` (release family), not `main` -- citation URLs and webfetch base hard-coded to that.

## [1.14.0] - 2026-04-30

### Added
- Scriptsync target-pivot guard in `hooks/tool-guard.ps1`: `PreToolUse` now blocks `Edit` and `Write` on sync-workspace files when the live SN helper-tab instance does not match the path-implied instance. Prevents cross-instance writes when the user flips scriptsync's browser tab mid-session (e.g. dev -> prod for UAT). Probe result is cached for 30s so edit bursts pay the cost once; the hook hard-blocks on probe failure rather than soft-warning.
- New helpers in `hooks/_common.ps1`: `Get-PathImpliedInstance` (derives instance name from file path), `Get-CachedLiveInstance` / `Set-CachedLiveInstance` / `Clear-CachedLiveInstance` (30s TTL cache), `Invoke-LiveInstanceProbe` (queries `sys_properties.instance_name` live via the Agent API).
- `hooks/session-start.ps1` now wipes the pivot cache at every session start so each new Claude Code session probes fresh rather than inheriting a stale reading.
- `rules/conventions.md` documents the guard behavior, the hard-block-on-probe-failure decision, and bypass paths (flip scriptsync back, or use Agent API with explicit `-InstanceDir`).

### Changed
- `hooks/hooks.json` PreToolUse matcher extended from `Bash|Write` to `Bash|Write|Edit`; hook timeout raised 5s -> 8s to accommodate the live probe (4s) plus overhead.

## [1.13.1] - 2026-04-29

### Changed
- `/sn-toolkit:start` no longer redundantly verifies the SN connection when the SessionStart hook has already done it. Step 1 (`check_connection`) and Step 3 (`clear_last_error`) now skip when the SessionStart additionalContext snapshot in conversation already shows `server=True, browser=True, errors cleared`; the skill only runs them when the snapshot is missing, stale (post-compaction), or shows either flag false.
- `/sn-toolkit:start` Step 4 dropped the redundant `get_instance_info` call. Step 2 already establishes instance identity from `_settings.json` + `sys_properties`, so Step 4 now only queries the active update-set preference -- the unique value it actually contributes.
- README and manifest descriptions corrected from "23 slash commands" to "24" (root README was even further behind at 21). The actual file count was already 24 at v1.13.0; this resyncs the user-facing description text.

## [1.13.0] - 2026-04-28

### Added
- `/sn-toolkit:spec` -- topic-agnostic two-part specification document builder. Walks the user through producing a stakeholder-grade Part A (functional) + Part B (technical) HTML/PDF spec pair, modeled on the field-tested CSAT / Google Docs / Candidate Uniqueness deliverables. Optional `--with-sn-pulls` anchors Part B to live SN artifact state via Agent API extraction into `scratch/fresh-*`; non-SN topics skip cleanly.
- `templates/spec/` -- `spec-template.html`, `spec-styles.css`, `render.ps1`, `README.md` shipped from the plugin and auto-copied into the project's `docs/specifications/_template/` on first run.

### Changed
- README command count 22 -> 23, new "Documentation" category surfaces the `spec` command.
- Spec template CSS variables renamed `--zv-*` -> `--spec-*` for topic-agnostic positioning.
- Cover-meta separator switched from `&bull;` to ASCII `|`; doc-footer separator switched from `&mdash;` to `--`.

## [1.12.1] - 2026-04-28

### Fixed
- SessionStart hook reported false-negative `server=False, browser=False` when the agent watcher or helper-tab websocket was mid-handshake at the exact moment Claude Code spawned, leaving Claude convinced the SN connection was down for the rest of the session. The hook now retries once with a 2s gap before reporting failure, uses a 5s per-call timeout (down from 15s) to bound worst-case session start, and reframes the additionalContext message as a snapshot with an explicit instruction to Claude to re-verify via `check_connection` before deferring SN work.

## [1.12.0] - 2026-04-27

### Added
- `/sn-toolkit:start` now verifies the live instance the browser helper tab is connected to against the configured `InstanceDir`. Queries `sys_properties` for `instance_name` + `instance_id` and stops with a clear warning on mismatch. `instance_id` is cached on first run for GUID-level verification, defeating clone-name collisions.

## [1.11.0] - 2026-04-27

### Added
- Two cross-cutting rules added to `conventions.md` (loaded for all SN paths via path globs):
  - **Table scope vs record scope** -- documents that OOB tables like `sys_security_acl`, `sys_homepage_destination_rule`, `user_criteria`, `sys_properties` commonly carry records belonging to scoped apps via `record.sys_scope`. Update set capture follows record scope, not table scope.
  - **No silent REST fallback when Agent API fails** -- when `create_artifact` / `update_record` returns success without effect, stop and surface the issue rather than pivoting to direct `Invoke-RestMethod`.

## [1.10.0] - 2026-04-27

### Added
- `/sn-toolkit:compare` -- spec-driven cross-instance compare. Reads a JSON spec listing `(table, fields, match_key, query)` entries, queries both instances via REST + DPAPI creds, emits a markdown report with three-way set diff per spec entry. Reference fields compare on `display_value` to avoid false positives from cross-instance sys_id divergence. Composite match keys supported.

## [1.9.0] - 2026-04-24

### Added
- `/sn-toolkit:refine-prompt` -- general-purpose Lyra 4-D prompt refiner (sibling of `/sn-toolkit:refine`, for non-ServiceNow contexts).

### Changed
- README permissions block updated to include `Skill(sn-toolkit:*)`.

## [1.8.0] - 2026-04-24

### Added
- Root README so the GitHub homepage renders correctly.

### Changed
- Bootstrap is now scope-optional.
- BOM guard hook fixed (greedy match no longer false-positives on quoted patterns in commit messages or heredocs).
- Command definitions slimmed down.

## [1.7.0] - 2026-04-24

### Changed
- Galaxy-brain pass: across-the-board polish on commands, agents, and rules.

## [1.6.0] - 2026-04-24

### Added
- `/sn-toolkit:refine` -- ServiceNow-flavored Lyra 4-D prompt refiner. Forces naming target table, scope, update set, domain, and expected persisted change before work begins.

## [1.5.0] - 2026-04-23

### Added
- 11 previously-unused Agent API commands exposed as skills (galaxy-brain pass).

## [1.4.0] - 2026-04-23

### Changed
- Plugin made instance-agnostic. Stripped Zero Vector-specific hardcoded values throughout commands and agents; now uses generic `x_icir_*` and `{instance}` placeholders.
- Doc-comment examples in `sn-agent-api.ps1` updated to match.

## [1.3.1] - 2026-04-22

### Changed
- `/sn-toolkit:end` produces a denser pickup-prompt format.

## [1.3.0] - 2026-04-21

### Removed
- Update-set guard dropped from `/sn-toolkit:create`, `/sn-toolkit:pull`, `/sn-toolkit:widget`. Users manage their own update sets.

## [1.2.0] - 2026-04-21

### Added
- `sn-credentials.ps1`: `-Action store` implemented.

### Fixed
- `/sn-toolkit:creds` now functions end-to-end.

## [1.1.0] - 2026-04-21

### Fixed
- `sn-credentials.ps1` path resolution.
- De-hardcoded URLs (now derive from `InstanceDir` / settings).

## [1.0.0] - 2026-04-21

### Added
- Initial sn-toolkit plugin release.
- 21 slash commands, 2 subagents (Explorer, Reviewer), 5 hooks, 4 rules.
- `sn-agent-api.ps1` -- Agent API wrapper.
- `sn-credentials.ps1` -- DPAPI-encrypted credential storage.
- `bootstrap-project.ps1` -- new SN workspace scaffolding.

[1.17.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.17.0
[1.16.1]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.16.1
[1.16.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.16.0
[1.15.2]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.15.2
[1.15.1]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.15.1
[1.15.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.15.0
[1.14.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.14.0
[1.13.1]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.13.1
[1.13.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.13.0
[1.12.1]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.12.1
[1.12.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.12.0
[1.11.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.11.0
[1.10.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.10.0
[1.9.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.9.0
[1.8.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.8.0
[1.7.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.7.0
[1.6.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.6.0
[1.5.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.5.0
[1.4.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.4.0
[1.3.1]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.3.1
[1.3.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.3.0
[1.2.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.2.0
[1.1.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.1.0
[1.0.0]: https://github.com/chrisp28103/sn-toolkit/releases/tag/v1.0.0
