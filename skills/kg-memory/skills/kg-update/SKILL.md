---
name: kg-update
description: Incremental refresh of the KG. Detects changed cards, re-runs topic extraction and link maintenance only on what's changed, then refreshes index and timeline.
---

# kg-update — Incremental KG Refresh

## Activation

- On explicit `/kg-update` command
- Automatically at session end if any cards were created or modified during the session (via `kg-session`)
- After a batch import (e.g., bulk note migration)

## Purpose

Keep the KG consistent without re-processing everything. Only touches cards whose content changed since the last update.

## Procedure

### 1. Load state

Read `~/.claude/kg_state.json` for last-known card hashes and timestamps.

### 2. Detect changed cards

For each card in `<vault>/kg/notes/`, `<vault>/kg/sources/`, `<vault>/kg/topics/`:
- Compute SHA256 of the file contents.
- Compare to stored hash in state.
- If different → mark for reprocessing.
- If same → skip.

For files not yet in state → mark as new.

For cards in state but not on disk → mark as deleted.

### 3. Reprocess changed cards

For each changed or new card:
- Re-extract topic candidates from the body.
- Hand to `kg-topics` for normalization.
- If the resulting topic list differs from what's in frontmatter, update the frontmatter.
- Bump `updated` field if body changed (don't bump for trivial frontmatter-only edits).

For each deleted card:
- Find topics that listed it; remove the entry from those topic pages.
- Decrement `page_count`.
- Remove from state.

### 4. Re-check topics

Run `kg-topics` to:
- Recompute `page_count` on all topics.
- Detect any newly orphaned, narrow, or broad topics.
- Apply normalization to any new candidate slugs.

### 5. Refresh links

Run `kg-link --all --validate`. Auto-fix unambiguous broken links. Report the rest.

### 6. Update _index.md

Regenerate stats and tables:
- Note count, source count, topic count, total pages.
- Recently updated cards (top 10 by `updated` desc).
- Topic table sorted by `page_count` desc.

### 7. Append to _timeline.md

Add a single entry:

```markdown
## YYYY-MM-DD

- /kg-update — <N> cards reprocessed, <M> topics affected, <K> links fixed
```

If individual cards were reprocessed for substantive reasons (not just hash recomputation), list them.

### 8. Save state

Write updated `~/.claude/kg_state.json`:
- Hash and timestamp for every card.
- New `last_full_update` timestamp.
- Updated `stats` totals.

### 9. Print summary

```
KG Update Summary:
  Cards reprocessed: N (of M total)
  Topics: created N, merged K, orphaned J
  Links: added L, fixed X, broken Y (manual review needed)
  Time: Ts
```

## Flags

- `--force` — Reprocess every card regardless of hash match.
- `--dry-run` — Show what would change without writing.
- `--validate-only` — Only run `kg-link --validate` and report; don't modify anything.
- `--cards-only` — Skip topic and link maintenance; only refresh hashes and stats.

## Verification

- `kg_state.json` `total_pages` matches the file count under `<vault>/kg/`.
- No card has a stored hash that differs from its current content.
- `_index.md` stats match live counts.
- No broken WikiLinks (or all reported in the summary).

## Notes

- Idempotent. Running twice in a row should produce no changes the second time.
- Safe to interrupt — partial state is recoverable; the next run picks up unfinished work.
- If the vault path changed, `--rebase <new-vault>` updates `vault_path` in state and re-walks.
