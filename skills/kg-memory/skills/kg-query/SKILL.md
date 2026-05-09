---
name: kg-query
description: Navigate the KG to answer a user question. Token-budget-aware traversal that starts at the index, ranks topics and cards by relevance, and reads only what's needed to answer.
---

# kg-query — Knowledge Graph Navigation

## Activation

- On explicit `/kg-query <question>` command
- When the user asks a question whose answer is likely in their captured notes/sources
- When context from prior captures would help answer the user's current request

## Purpose

Find the answer in the KG without loading the whole vault. Optimize for tokens by using `tldr` and `words` fields to decide what to read in full.

## Traversal protocol

### Step 1 — Read the index

Read `<vault>/kg/_index.md`. This gives:
- Topic table with TLDRs and page counts
- Note count, source count
- Last update timestamp

The index is small (always < 2000 words). Read it whole.

### Step 2 — Rank candidates

Score each topic and recent card by relevance:
- Query terms in `tldr` → high signal
- Query terms in slug → medium signal
- Query terms in `aliases` → medium signal
- Recency (`updated` field) → tie-breaker, weight by 1/days_since_update

Take the top 5 topics and top 5 cards.

### Step 3 — Read TLDRs first

For each candidate, read just the frontmatter and the `> [!tldr]` callout. This is cheap (~50 tokens per card).

If the answer is now obvious, stop and answer.

### Step 4 — Selectively read full bodies

For the top 1–3 candidates whose TLDR suggests they hold the answer:
- Check `words` field. If `words > 1000`, read only Overview + Body sections.
- If `words ≤ 1000`, read whole.
- Follow Related links if the card cites another that's likely relevant.

### Step 5 — Synthesize and cite

Answer the user's question. Cite sources using WikiLinks: `[[notes/2026-05-09-bird-feeder]]`. State confidence:
- **high** — direct match in a card body
- **medium** — inferred across 2+ cards
- **low** — sparse data; suggest the user capture more

## Token budget guidelines

| Query intent | Budget | Behavior |
|---|---|---|
| Quick lookup ("did I save anything about X?") | ~2000 words | Index + 2–3 TLDRs |
| Research ("what do I know about X?") | ~5000 words | Index + 5 TLDRs + 2 full reads + Related follow-up |
| Deep dive ("everything about X") | ~10000 words | Index + 10 TLDRs + 5 full reads + 2 levels of Related |

Default to quick lookup. Escalate only if the user explicitly asks for depth.

## Query strategies

### Breadth-first ("what do I have?")
1. Read `_index.md`.
2. List depth-0 and depth-1 topics with page counts.
3. Group and report.

### Depth-first ("how does X work?" / "what did I conclude about X?")
1. Read `_index.md`, find best topic match.
2. Open the topic page; read its Pages table.
3. Read top 2 cards in full.
4. Synthesize.

### Cross-cutting ("which sources mention X?")
1. Read `_index.md`.
2. Filter sources by topic match.
3. Read TLDRs of all matching sources.
4. Report list with TLDRs.

### Gap analysis ("what's missing?")
1. Run `/kg-topics --report` to see broad/narrow/orphaned topics.
2. List topics with `page_count == 1` (single witness — opportunity to capture more).
3. Suggest captures.

## Output

Direct answer to the user, with:
- WikiLink citations
- Confidence label
- Optional follow-up suggestions ("want me to capture this answer as a note?")

## Notes

- Always check `_index.md` first. Never skip it.
- If the KG has nothing relevant, say so plainly — don't fabricate. Suggest `/kg-add-note` if the user wants to start capturing.
- Query results are not stored. If the user wants to keep an answer, they must explicitly file it.
