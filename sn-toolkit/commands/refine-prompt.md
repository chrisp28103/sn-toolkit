---
description: Refine any vague prompt into a precision prompt using Lyra's 4-D methodology (Deconstruct, Diagnose, Develop, Deliver). Use for any vague request -- general coding, research, advisory, tooling, writing, analysis, ServiceNow work. Adapted from Lyra (github.com/creativeheadz/Lyra, MIT).
---

Take the user's raw request from $ARGUMENTS (or from the most recent user message if $ARGUMENTS is empty). Walk through the 4-D pipeline below. Do NOT execute any work during refinement -- this command only produces a refined prompt for the user to approve.

Refinement is proportional to task complexity. Trivial question -> skip to answer. Moderate -> collapse to a 3-line summary. Complex / ambiguous -> full 4-D pipeline. Do not over-structure simple questions.

## Step 1: Deconstruct

Extract and list:
- **Core intent** in one sentence (what does the user actually want -- information, a decision, code, a document, a recommendation?).
- **Explicit entities**: tools, libraries, file paths, URLs, people, concrete nouns the user named.
- **Implicit context**: inferred from CLAUDE.md, recent conversation, session state, the user's role or domain.
- **Output type**: text answer, code change, research report, recommendation, structured data.

If the request contains zero actionable nouns ("fix it", "make it better", "help me"), stop and ask what subject or target before continuing.

## Step 2: Diagnose -- universal unknowns checklist

For each item below, mark KNOWN (with value) or UNKNOWN. Infer from context first; only ask the user about items that remain UNKNOWN and matter for the deliverable.

1. **Audience / role** -- who consumes the output (user themselves, teammate, stakeholder, future-you). Affects tone and depth.
2. **Task type** -- question, implementation, review, research, decision-support, creative, analysis, writing.
3. **Depth** -- quick answer vs. thorough investigation vs. production-ready deliverable.
4. **Format + length** -- bullets, prose, table, code, diagram. Approximate length cap.
5. **Success criteria** -- how will the user judge the answer correct or useful? Objective check, subjective fit, test passes, cited sources.
6. **Scope boundaries** -- what's explicitly OUT of scope? Prevents drift.
7. **Assumptions policy** -- may the model make reasonable assumptions, or should it pause and ask?
8. **Verification** -- can the model self-verify (run a test, check a file, cite a source), or is this best-effort?

## Step 3: Develop -- choose technique

Based on task type, pick one or more:
- **Role framing** -- "act as a [senior Go engineer / product manager / security reviewer / technical writer]". Good for advice and review tasks.
- **Step-by-step** -- explicitly request ordered reasoning for complex analysis or debugging.
- **Few-shot** -- provide 1-2 concrete examples of desired output shape for structured or format-sensitive tasks.
- **Constraint listing** -- enumerate hard constraints up front (length, format, must-use / must-avoid).
- **Verification step** -- ask the model to self-check (run a test, cite a source, list assumptions surfaced).
- **Research delegation** -- for open-ended research, suggest a subagent (Explore, general-purpose, or a specialized one like claude-code-guide) with a focused prompt and word limit.
- **Plain Q&A** -- for simple factual questions, no technique needed; just answer.

## Step 4: Deliver -- the refined prompt

Output in this exact structure, ASCII-only:

```
Goal: <one sentence, concrete>
Task type: <question | implementation | review | research | decision | creative | analysis | writing>
Audience: <who the output is for>
Output: <format + approximate length>
Constraints: <hard rules -- format, length, what to avoid, must-include>
Technique: <role framing / step-by-step / few-shot / delegate to subagent X / plain Q&A>
Success criteria: <how to judge the answer>
Scope OUT: <explicitly excluded>
Open questions: <any Diagnose item still UNKNOWN that blocks a good answer; omit section if none>
```

Then ask: "Execute this, or hand back for you to edit?" Default to hand-back if any Open questions remain.

## Gotchas

- Don't over-structure trivial questions. "What's the capital of France" does not need a 10-line refined prompt; just answer.
- If the user has already named Goal + Audience + Output + Constraints in the raw request, collapse to a one-line summary and skip to the answer.
- For ServiceNow-specific requests (tables, records, update sets, scopes, widgets, BRs, domains), incorporate those concepts into the Diagnose step -- name target table, scope, update set, domain, and expected persisted change before drafting the refined prompt.
- This command produces a prompt; it does not execute work. Read-only research (grep, read files, web fetch) is fine for inference; mutations are not.
