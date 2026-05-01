---
name: docs
description: Use whenever the user asks about ServiceNow platform behavior, APIs, conventions, or any topic likely covered by the official ServiceNow documentation -- ACLs, GlideRecord, business rules, REST APIs, UX framework, scoped applications, security, etc. Searches the local mirror of github.com/servicenow/servicenowdocs via the sn-docs CLI on PATH. Pass a topic to search directly, or omit to browse product areas.
argument-hint: "[query]"
---

## Usage

IMPORTANT: _Never_ open a full topic without first viewing the summary via `sn-docs peek`! This prevents you from accidentally opening the wrong topic and wasting context space.

This skill wraps the `sn-docs` CLI which mirrors the official servicenow/servicenowdocs repo. Cache is opt-in -- the skill works in either mode.

## Step 1 -- Check cache state (always first)

```bash
powershell.exe -NoProfile -File sn-docs.ps1 status
```

(All `sn-docs` calls in this skill use `powershell.exe -NoProfile -File sn-docs.ps1 <command>`. Replace `sn-docs.ps1` with the full path if it is not yet on PATH.)

Branch on the `cache_present:` line in stdout:
- **`cache_present: yes`** -- use the fast path: `search` -> `peek` -> `read`, all local.
- **`cache_present: no`** -- use the fallback path: `list` for discovery via GitHub API, `peek`/`read` will auto-fetch from raw.githubusercontent.com per file. After answering, surface this one-line opt-in suggestion **at most once per session**: *"For faster offline lookup, run `/sn-toolkit:docs-setup` once to mirror the docs locally (~150 MB)."*

## Step 2 -- Discover candidate paths

**With cache:** ripgrep is fast and exhaustive.
```bash
sn-docs search "<query>" [-Area <product-area>]
```
Returns `path:lineno:snippet` -- review the snippets to pick the right doc.

**Without cache:** narrow by area first (cheap), then peek individual files.
```bash
sn-docs list                    # see all 50 product areas
sn-docs list <area>             # list .md files under that area
```
Common areas: `now-platform`, `api-reference`, `platform-administration`, `it-service-management`, `application-development`.

## Step 3 -- Peek before reading

```bash
sn-docs peek <path>
```
Returns the first 30 lines + H2 outline. **Verbatim rule (from now-sdk-explain): "Never open a full topic without first viewing the summary via peek -- this prevents wasting context space."**

If the peek looks irrelevant, go back to step 2 with a different search/path. Do NOT call `read` until peek confirms relevance.

## Step 4 -- Read full only when relevant

```bash
sn-docs read <path>
```
Returns the full markdown. Use the content to answer the user's question.

## Step 5 -- Cite the source

When answering, link to the GitHub source so the user can open the canonical doc.
The repo's default branch is `australia` (release family), NOT `main`:
`https://github.com/servicenow/servicenowdocs/blob/australia/<path>`

The `peek` output's `source:` line gives you this URL pre-built -- copy it directly.

## What to search for

- **Platform APIs** -- `GlideRecord`, `GlideAjax`, `GlideForm`, `GlideUser`, `GlideSystem`
- **Security** -- `ACL`, `evaluation order`, `before query business rule`, `domain separation`
- **Server-side** -- `business rule`, `script include`, `scheduled job`, `flow designer`
- **Client-side** -- `client script`, `UI policy`, `UI action`, `catalog client script`
- **REST/integrations** -- `Table API`, `Scripted REST API`, `OAuth`, `MID Server`
- **UX framework** -- `UI Builder`, `now experience`, `workspace`, `record producer`

## If the CLI errors

- `cache_present: no` after attempting search -> instruct user to run `/sn-toolkit:docs-setup`, OR fall through to `list`/`peek`/`read` which work without the cache.
- `git: command not found` -> git is required for sync; user needs git on PATH.
- `ripgrep (rg) not found` -> rg ships with Claude Code; if missing the user's install is incomplete.
- HTTP errors during webfetch -> network/proxy issue or the path is wrong; double-check via `sn-docs list <area>`.

## Important constraints

- The repo is updated daily via automated builds, but THIS SKILL NEVER auto-syncs. Cache refresh is user-initiated only via `/sn-toolkit:docs-sync`. Stale cache (>30 days) is reported by `sn-docs status` but never acted on -- a cache that's a few weeks old is fine for almost all platform topics.
- Output is ASCII-clean. Do not paste raw doc content into ServiceNow scripts/work-notes (it may contain non-ASCII -- per project rule #1, all SN-bound content must be ASCII).
