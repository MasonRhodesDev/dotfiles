---
description: When the user has to correct Claude's behavior, automatically record a memory so the mistake isn't repeated.
---

## Trigger

Any time the user has to correct you — undoing a change you made, telling you that was wrong, saying you should have done something differently, expressing frustration at a repeated mistake — record a memory **before responding further**.

## What to record

Write a concise entry to the most relevant memory file under `~/.claude/projects/-home-mason-AI-HOME/memory/`. If the correction is about debugging/diagnostic approach or tool assumptions, use `feedback_debugging.md`. If no existing file fits, create one.

Each entry should capture:
1. **What you did wrong** — specific action, not vague
2. **What the correct approach is** — the rule going forward
3. **Why** — so future sessions understand the intent, not just the rule

## Format

Append to the file with a `---` separator and a bold header summarizing the lesson. Keep it short — two to five sentences.

## Important

- Do this even if the user doesn't explicitly ask you to record a memory
- Do this *especially* when the user seems frustrated
- Don't ask for permission — just do it, then confirm you recorded it
- The goal is that the same mistake should never happen twice across sessions
