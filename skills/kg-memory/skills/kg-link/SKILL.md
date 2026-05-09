---
name: kg-link
description: Maintain bidirectional WikiLinks across all KG cards. Ensures topics list their member cards, cards list their topics, and broken links are detected.
---

# kg-link — Bidirectional Link Maintenance

## Activation

- Called by `kg-add-note` and `kg-add-source` after writing a new card
- On explicit `/kg-link` command
- During `/kg-update`

## Purpose

Keep WikiLinks bidirectional and consistent across the vault. If card A's frontmatter says `topics: [foo]`, then `topics/foo.md` must list A in its Pages section. If A's body links to source B, B's Related must link back to A.

## Procedure

### 1. Identify scope

- `--card <path>` → only process links touching this card (default for callers).
- `--all` → process the entire vault (default for `/kg-link`).
- `--validate` → only check, don't write.

### 2. For each card in scope, gather its declared links

- **Topic links** — every slug in frontmatter `topics:`.
- **Body WikiLinks** — every `[[target]]` in the body.

### 3. For each topic link, ensure the topic page lists the card

Open `<vault>/kg/topics/<slug>.md`. In the Pages section table, ensure there's a row for this card. If missing, insert it. Ordering: most recently updated first.

### 4. For each body WikiLink, ensure the target lists this card

Open the target card. In its Related section, ensure there's a `[[<source-card>]]` entry. If missing, insert with a brief note about the relationship.

### 5. Validate links

For every WikiLink encountered:
- **Resolved** — target file exists → OK.
- **Broken** — target file doesn't exist → check for typo (Levenshtein distance ≤2 against existing slugs); if a likely match found, fix in place; otherwise report.
- **Self-link** — card links to itself → remove.
- **Duplicate** — same target listed twice in one card → remove duplicate.

### 6. Report

```
Link Maintenance Report:
  ✓ <N> links verified
  + <M> links added (forward + reciprocal)
  ⚠ <K> broken links (auto-fixed: J, manual review: K-J)
  - <L> duplicate links removed
```

## Flags

- `--validate` — Read-only validation; don't modify.
- `--card <path>` — Limit scope to a single card and its neighbors.
- `--dry-run` — Show what would change without writing.
- `--strict` — Treat any broken link as an error (exit non-zero).

## Verification

- For every `topics:` entry on every card, the topic page's Pages section lists the card.
- For every `[[link]]` in a card body, the target's Related section links back.
- No card links to itself.
- No card has the same WikiLink twice.

## Notes

- The Pages table on a topic page is a **derived** view — `kg-link` and `kg-topics` regenerate it from frontmatter. Manual edits to that table will be overwritten.
- The Related section on note/source cards is **authored** — agents append, but never delete user-written entries unless they're broken.
- Auto-fix only kicks in for unambiguous typos (Levenshtein ≤2 with exactly one candidate). Anything else gets reported, not changed.
