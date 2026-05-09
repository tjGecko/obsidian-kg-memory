---
name: kg-session
description: Manage KG state across a Claude Code session. Loads index on start, tracks card-affecting work during, runs kg-update on end if needed.
---

# kg-session — Session Lifecycle

## Activation

- Automatically at Claude Code session start
- Automatically at session end
- Integrates with the parent `kg-memory` skill

## Purpose

Make KG maintenance invisible. Load context on start, track changes during, and refresh on end — all without interrupting the user.

## Session start protocol

### 1. Verify vault exists

If `<vault>/kg/_index.md` doesn't exist, surface a one-line suggestion to run `/kg-init`. Don't block — the user might be working in a non-KG context.

### 2. Load index into context

Read `_index.md`. Store in working memory:
- Total notes / sources / topics
- Top 10 topics by page_count
- 5 most recently updated cards

This costs ~1500–2000 tokens up front but saves many small reads later.

### 3. Initialize session tracker

In-memory list:
- `cards_created: []`
- `cards_modified: []`
- `topics_touched: set()`

## During work

When other skills create or modify cards, they append to the session tracker. This is bookkeeping only — no user-visible action.

## Session end protocol

### 1. Decide if update is needed

| Condition | Action |
|---|---|
| Tracker is empty | Skip — nothing to update. |
| Only `cards_modified`, no new topics | Run `kg-link --card <each>` quickly; skip full update. |
| New cards or new topics | Run `/kg-update`. |

### 2. Run kg-update if needed

Invoke `/kg-update` synchronously (it's incremental — fast).

### 3. Append timeline entry

Append a one-line entry to `_timeline.md`:

```markdown
## YYYY-MM-DD

- Session — <N> notes, <M> sources captured. Topics touched: [a, b, c].
```

Skip the line if the session tracker is empty.

### 4. Save state

Make sure `~/.claude/kg_state.json` reflects the session's writes (in case `kg-update` was skipped).

## Notes

- Session lifecycle should be **invisible**. Never print status messages on session start or end unless something needs the user's attention.
- If the user appears to be doing focused work in a non-KG context (e.g., editing code in another repo), don't bother capturing — wait for explicit `/kg-add-*` calls.
- The cost of a full `kg-update` is bounded by changed cards, not vault size. Even with a 1000-card vault, an update touching 5 cards finishes in under a second.
