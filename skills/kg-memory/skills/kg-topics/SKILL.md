---
name: kg-topics
description: Normalize topic slugs, deduplicate overlapping topics, create or update topic aggregation pages, and run log(N) health checks. Returns canonical topic slugs to callers.
---

# kg-topics — Topic Management & Health

## Activation

- Called by `kg-add-note` and `kg-add-source` after topic-candidate extraction
- On explicit `/kg-topics` command
- During `/kg-update`

## Purpose

Normalize topic candidates, deduplicate overlapping topics, maintain topic aggregation pages, and report health using log(N) bounds.

## Procedure

### 1. Normalize candidates

For each input candidate, apply slug rules:

| Rule | Example |
|---|---|
| Lowercase | `Bird Feeder` → `bird-feeder` |
| Spaces → hyphens | `real time audio` → `real-time-audio` |
| Singular form | `microservices` → `microservice` |
| Drop leading stop words | `the-art-of-debugging` → `art-of-debugging` |
| Tense → noun form | `detecting` → `detection` |
| Abbreviation expansion (with alias) | `ml` → `machine-learning` (alias `ml`) |

### 2. Deduplicate against existing topics

For each normalized candidate, check `<vault>/kg/topics/`:

| Pattern | Action |
|---|---|
| Exact match | use existing slug |
| Match against `aliases` of an existing topic | use canonical slug |
| Substring overlap with existing (broader has <3 pages) | merge candidate into broader, return broader slug |
| Substring overlap with existing (broader has ≥3 pages) | create child, link `parent_topics` |
| Semantic overlap (`audio-processing` vs `sound-processing`) | merge, prefer alphabetical for canonical |
| No match | create new topic page |

### 3. Create or update topic pages

For each topic that needs writing or updating, use `templates/topic.md`. Path: `<vault>/kg/topics/<slug>.md`.

```yaml
---
tldr: "<short description of topic in user's vault context>"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
type: topic
topics: []
aliases: [alt-name-1, alt-name-2]
status: draft
words: NNN
depth: 0 | 1 | 2
page_count: N
parent_topics: [parent-slug]
---

# <Topic Name>

> [!tldr] <TLDR>

## Overview
<short prose introducing the topic in this vault's context>

## Pages

| Card | Type | TLDR |
|---|---|---|
| [[notes/2026-05-09-bird-feeder]] | note | TLDR text |
| [[sources/audubon-feeder-guide]] | source | TLDR text |

## Related Topics
- [[topics/birds]] — parent
- [[topics/squirrel-deterrent]] — sibling
```

The Pages table is regenerated on every `kg-topics` run from the actual cards that link here.

### 4. Assign depth

- New topics default to `depth: 1`.
- A user can promote (`--promote <slug>`) or demote (`--demote <slug>`).
- Depth 0 is reserved for broad domains. Don't auto-create at depth 0.
- Depth 2 is the floor — never auto-create at depth 3+.

### 5. Recompute page_count

For each topic, `page_count = number of cards whose frontmatter `topics:` includes this slug or any alias`.

### 6. Run health check

For N total cards in the vault:

| Status | Condition |
|---|---|
| ✓ healthy | `2 ≤ page_count ≤ √N` |
| ⚠ too broad | `page_count > N/2` — flag for splitting |
| ⚠ too narrow | `page_count < 2` — flag for merging |
| ✗ orphaned | `page_count == 0` — flag for removal (unless `pinned: true`) |

Print:
```
Topic Health Report (N=<total cards>):
  ✓ <count> healthy
  ⚠ <count> too broad: [slug-a, slug-b]
  ⚠ <count> too narrow: [slug-c]
  ✗ <count> orphaned: [slug-d]
```

### 7. Update _index.md

Refresh the Topics table in `<vault>/kg/_index.md`.

## Flags

- `--report` — Health report only; don't modify files.
- `--merge <slug-a> <slug-b>` — Manually merge `slug-b` into `slug-a`.
- `--split <slug>` — Interactively split a too-broad topic.
- `--promote <slug>` — Move topic up one depth level.
- `--demote <slug>` — Move topic down one depth level.

## Output

Returns the canonical slug list to the caller. For example, given input candidates `[bird-feeders, BirdFeeder, chickadee]`, returns `[bird-feeder, chickadee]`.

## Verification

- All topic slugs follow normalization rules.
- No two topics have the same slug or alias collision.
- Every topic file's `page_count` matches the live count.
- No broken WikiLinks in topic pages.
