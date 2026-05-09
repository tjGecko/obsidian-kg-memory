# Card Rules — How Cards Combine

This is the operational logic agents follow when adding, linking, and merging cards. The schema in [`SCHEMA.md`](SCHEMA.md) defines what a card looks like; this document defines what to do with one.

## The five rules

1. **One card, one subject.** A note about both a bird feeder and a recipe is two notes, not one.
2. **Topics are discovered, not declared.** Agents propose topic candidates from card content; `kg-topics` decides whether to create a new topic, merge into an existing one, or normalize the slug.
3. **Links are bidirectional.** If A links to B, B must link back to A. `kg-link` enforces this.
4. **Cheap fields first, expensive ones later.** Agents read `tldr` and `words` before reading body content. They read full bodies only when query relevance justifies the tokens.
5. **Drafts are fine.** New cards start `status: draft`. Agents shouldn't refuse to write because content is incomplete — they should write and move on.

## When to create which card

| Input | Create |
|---|---|
| User dictates a thought | `note` |
| User pastes a URL with "save this" | `source` |
| User asks a question that has no answer in the KG | nothing — answer the question, optionally suggest the user capture the answer as a note |
| Two existing notes are clearly about the same theme but no topic exists yet | `topic` (then add it to both notes' `topics` field, run `kg-link`) |

## Adding a new card

`kg-add-note` and `kg-add-source` follow the same protocol:

1. **Generate the slug.** Apply the rules in [`SCHEMA.md#slug-rules`](SCHEMA.md#slug-rules). For notes, prefix with `YYYY-MM-DD`.
2. **Write the file.** Use the appropriate template from `skills/kg-memory/templates/`. Compute `words`. Set `status: draft`.
3. **Extract topic candidates** from the body (see [Topic candidate extraction](#topic-candidate-extraction)).
4. **Hand candidates to `kg-topics`** for normalization.
5. **Run `kg-link`** to create bidirectional links.
6. **Update `_index.md`** stats.
7. **Append to `_timeline.md`** with a one-line entry.

Idempotency: if a card with the same slug already exists, the agent reads it first. If `tldr` and topics match, it's a duplicate — log and skip. Otherwise, it's a meaningful update — merge content, bump `updated`, re-run topic extraction.

## Topic candidate extraction

When extracting candidates from a card body:

- Take noun phrases that appear ≥2 times, or once in a heading.
- Take proper nouns and named entities.
- Drop generic words (`thing`, `stuff`, `idea`, `today`, `note`).
- Drop words shorter than 3 characters.
- Apply slug rules.

Output is a list of candidate slugs. Hand the list to `kg-topics` — never write the topic field directly without normalization.

## Topic hierarchy (depth)

Topics are organized into a shallow three-level hierarchy:

| Depth | Meaning | Example |
|---|---|---|
| 0 | Broad domain | `birds`, `cooking`, `health`, `family` |
| 1 | Sub-domain | `bird-feeder`, `baking`, `cardio`, `grandkids` |
| 2 | Specific concept | `chickadee-behavior`, `sourdough-starter`, `interval-training` |

Rules:
- A new topic defaults to depth 1. The user (or `kg-topics --suggest`) can promote/demote.
- `parent_topics` must reference a topic of strictly lower depth.
- Don't go deeper than depth 2. If you find yourself wanting depth 3, the depth-2 topic is too narrow — most likely the right move is to leave the concept inside the body of a note rather than promote it.

## Deduplication

`kg-topics` checks for these on every run:

| Pattern | Action |
|---|---|
| Exact slug match after normalization | merge — keep the older card, append `aliases` |
| Substring overlap (`bird` ⊂ `bird-feeder`) and broader has <3 pages | merge into more specific |
| Substring overlap and broader has ≥3 pages | keep both, link as parent/child |
| Semantic overlap (`audio-processing` vs `sound-processing`) | merge under canonical name (alphabetical wins ties), other becomes alias |
| Plural/singular variant | merge into singular |
| Tense variant (`detecting` vs `detection`) | merge into noun form |

When merging, all backlinks from both cards are unioned and pointed at the survivor.

## Health check (log N bounds)

For a vault with N total cards:

- A topic with `page_count > N/2` is **too broad** — flag for splitting (`/kg-topics --split <slug>`).
- A topic with `page_count < 2` is **too narrow** — flag for merging into parent or removal.
- A topic with `page_count == 0` is **orphaned** — remove unless explicitly pinned (frontmatter `pinned: true`).
- The healthy range is `2 ≤ page_count ≤ √N`.

Run `/kg-topics --report` to see the current health snapshot. The dashboard surfaces the same data live via Dataview.

## Linking rules

`kg-link` walks every card and ensures:

- Every entry in a card's `topics` array has the card listed in the topic's Pages section.
- Every WikiLink in a body's Related section has a reciprocal link in the target.
- A card's body cannot WikiLink to itself.
- Broken links (target file doesn't exist) are reported and either auto-fixed (slug typo) or flagged for human review.

## What `kg-update` does

`/kg-update` runs the full incremental cycle:

1. Scan vault for changed files (compare `updated` field + a stored hash in `~/.claude/kg_state.json`).
2. For each changed card, re-extract topic candidates and hand to `kg-topics`.
3. Run `kg-link` to refresh bidirectional links.
4. Recompute `page_count` on all topics.
5. Run health check, report broad/narrow/orphaned topics.
6. Refresh `_index.md` stats and `_timeline.md`.

`kg-update` is safe to run any time. It only writes to cards whose state changed.

## Tradeoffs the rules make

- **Three card types instead of seven.** Less expressive, but no card-type bikeshedding for users.
- **Topics auto-merged on substring overlap.** Loses occasional precision, gains consistent navigation.
- **Drafts stay drafts forever by default.** Better than blocking on a `status: stable` review the user will never do.
- **No automatic deletion.** Even orphaned topics are flagged, not removed. Deletion is always an explicit user action.
