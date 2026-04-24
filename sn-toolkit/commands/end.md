---
description: End-of-session wrap-up -- update status trackers for next session continuity. Use when the user says "wrap up", "end session", "that's it for today", or is winding down SN work.
model: sonnet
effort: medium
allowed-tools: [Read, Edit, Write, Bash]
---

## Steps

1. Discover all context files by listing `docs/context/`. Read each one relevant to the work done this session.

2. For each relevant context file, update:
   - "Last Updated" date
   - "Last Session Summary" with what was accomplished
   - Any new methods/functions added (with category and description)
   - Any new widgets, pages, or artifacts created
   - Key design decisions made
   - Any bugs discovered

3. Move completed items from "UP NEXT" to "DONE".

4. Add any new items surfaced during the session to "UP NEXT".

5. If utility class methods changed, update the Method Inventory table in the relevant context file.

6. Save all updated files.

7. Commit all pending changes (staged + untracked non-ignored files) with a descriptive message summarizing the session's work. Do NOT push.

8. Summarize what was updated for the user.

9. Generate a **Next Session Pickup Prompt** -- a copy-pasteable message the user can send to start the next conversation. Rules:
   - Keep it under 150 words -- just enough to orient a fresh context
   - Structure: one line stating the goal/focus, then a short bullet list of where things left off (what's done, what's next, any blockers)
   - Reference specific context files to read (e.g., "Read docs/context/mobile-app-status.md") rather than restating their contents -- let the new session load context from files, not from the prompt
   - Do NOT include background project info, architecture explanations, or anything already in CLAUDE.md or context files
   - Include the relevant `/sn-toolkit:start` invocation if SN work is expected
   - **Format as a fenced code block so the user can copy it directly**
   - **Density rules (critical -- user pastes this into plain-text notes):**
     - NO blank lines anywhere inside the fence. Every line has content.
     - NO sub-bullets or nested indentation -- flat single-level list.
     - Commands inline with their trigger, not on separate lines (e.g. `When next batch previewed, run: /sn-toolkit:start then: powershell ...`)
     - Markdown bolding (`**...**`) is fine for section leads but use sparingly -- only where a plain-text reader would benefit from the emphasis.
     - One short sentence per bullet. If a bullet needs two sentences, split it into two bullets.
