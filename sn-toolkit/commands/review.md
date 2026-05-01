---
description: Review all scripts in a ServiceNow table type for best practices, security, and performance. Fans out to parallel SN Reviewer agents per script and applies confidence scoring (>=80) to filter noise. Use when the user asks to code-review or audit scripts against standards for an entire table type.
model: sonnet
effort: medium
allowed-tools: [Read, Glob, Grep, Bash]
---

$ARGUMENTS should specify the table type to review (e.g., "sys_script_include" or "sp_widget").

## Cost note

This command spawns N parallel SN Reviewer agents for an N-script review (capped at 10 parallel). Token cost scales linearly with the number of scripts -- expect ~5-10x cost vs. a sequential walk. The benefit is per-finding confidence scoring (threshold 80) that drops most noise. For a quick sanity check on a single script, prefer invoking the SN Reviewer agent directly.

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

### 1. Query records

Save + read back per conventions.md "Canonical Query-and-Save Snippet":

```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "sys_scope.scope=<YOUR_SCOPE>^active=true"
    fields = "sys_id,name,script"
    limit = 100
}
```

If more than 10 scripts come back, ask the user whether to review all or filter to a subset (e.g., recently modified, named pattern). Reviewing 100 scripts in parallel is feasible but expensive; default cap is 10.

### 2. Fan out: parallel SN Reviewer agents (one per script)

Spawn `SN Reviewer` agents in parallel via the Task tool -- one Agent invocation per script, all in a single message for true parallelism. Each agent:
- Reads `.claude/rules/sn-scripting.md` and `.claude/rules/conventions.md`.
- Reads the target script content (from the saved query JSON, not console output).
- Returns findings as a JSON array: `[{file, line, severity, finding, fix}, ...]`.

Severity values: `critical` (runtime errors / security), `warning` (standards deviations), `style` (cosmetic).

Aggregate the per-script JSON arrays into a single flat list of findings, each tagged with the script's `name` and `sys_id`.

### 3. Confidence scoring (per finding)

For each aggregated finding, score 0-100 against this rubric:
- **0** -- false positive (the pattern matched but the surrounding context makes it correct)
- **25** -- somewhat suspicious but defensible
- **50** -- moderate confidence the finding is real
- **75** -- highly confident
- **100** -- absolutely certain bug/violation

Score each finding inline (model judgment, no separate sub-agent call -- this saves a token-cost roundtrip vs. the marketplace `code-review` plugin). Be honest -- false positives are common in pattern-based review, and the threshold filter is what makes this command actionable.

### 4. Filter and report

Drop any finding scoring < 80. If zero findings remain, say so explicitly ("All N scripts reviewed; no findings >=80 confidence. The codebase looks clean against current rules.") -- do not pad with low-confidence noise.

Group remaining findings by severity:

```
# /sn-toolkit:review report -- <table> in <scope>

Reviewed N scripts. M findings >=80 confidence.

## Critical (X)
- `<script_name>` (sys_id `<id>`):
  - Line 42: <finding>
    Fix: <fix>

## Warning (Y)
- ...

## Style (Z)
- ...
```

If a script has no findings >=80, omit it from the report (don't list "no issues found" per script -- that's noise).

### 5. Anti-patterns to watch for (rule reminder for the SN Reviewer agents)

The reviewer agents already know these from `sn-scripting.md`, but call out high-signal ones in your aggregation step:
- `var` instead of `let`/`const`
- Direct property access (`gr.name`) instead of `getValue()` (except journal fields)
- `gs.nowDateTime()` or other forbidden scoped-app APIs
- Generic GlideRecord variable names (`gr` instead of `grUser`)
- Missing error handling on integration calls
- `getRowCount()` for existence checks
- GlideRecord queries inside loops
- String concatenation instead of template literals
- Widget client scripts using IIFE instead of Angular DI

## Notes

- The 80-threshold is hardcoded in this command per the marketplace `code-review` pattern. If you want a noisier-but-broader pass, invoke `SN Reviewer` directly instead of this command.
- Findings below 80 are NOT discarded silently -- they're available to the model in context. If the user asks "what other issues?", the model can pull from the unfiltered set.
- This command is read-only. It reports; it does not edit scripts.
