# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
