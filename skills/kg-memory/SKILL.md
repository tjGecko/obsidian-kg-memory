---
name: kg-memory
description: Knowledge graph memory system for Obsidian. Activates every Claude Code session. On session start, loads vault index. During work, captures notes/sources as the user generates them. On session end, refreshes topics and links.
---

# kg-memory — Knowledge Graph Skills

## Activation

This skill activates every Claude Code session. On session start it loads the KG index for context. It also activates explicitly when the user runs any `/kg-*` command.

## Purpose

Maintain a knowledge graph of the user's notes, references, and topics inside an Obsidian vault. The vault is plain Markdown — the agent's job is to keep the structure consistent (frontmatter, links, topic dedup) so the user can browse and search without thinking about file layout.

## Vault location

Resolve in this order:
1. `$KG_VAULT` environment variable
2. `~/Documents/KG-Vault` (default)

Cards live under `<vault>/kg/`. State lives at `~/.claude/kg_state.json`.

## Session protocol

### On session start
1. Check if `<vault>/kg/_index.md` exists. If not, suggest `/kg-init` and stop.
2. Read `_index.md` for current totals (notes, sources, topics).
3. Hold the index in working context for the session.

### During work
- When the user shares text that looks like a captured thought (a paragraph or two with no question), offer to file it as a note via `/kg-add-note`.
- When the user shares a URL or asks to "save this", file as a source via `/kg-add-source`.
- When the user asks a question about something they've captured, use `/kg-query` rather than re-asking the user.

### On session end
- If any cards were created or modified, run `/kg-update` to refresh topics, links, and the index.
- Append a one-line entry to `_timeline.md`.

## Sub-skills

| Skill | Command | Purpose |
|---|---|---|
| [kg-init](skills/kg-init/SKILL.md) | `/kg-init` | Initialize vault structure |
| [kg-add-note](skills/kg-add-note/SKILL.md) | `/kg-add-note` | Create a note card |
| [kg-add-source](skills/kg-add-source/SKILL.md) | `/kg-add-source` | Create a source card |
| [kg-topics](skills/kg-topics/SKILL.md) | `/kg-topics` | Topic management & health |
| [kg-link](skills/kg-link/SKILL.md) | `/kg-link` | Bidirectional linking |
| [kg-query](skills/kg-query/SKILL.md) | `/kg-query` | Navigate the KG |
| [kg-update](skills/kg-update/SKILL.md) | `/kg-update` | Incremental refresh |
| [kg-session](skills/kg-session/SKILL.md) | (auto) | Session lifecycle |

## Frontmatter schema (base)

Every card has these fields. See [`../../docs/SCHEMA.md`](../../docs/SCHEMA.md) for the per-type extensions.

```yaml
---
tldr: "<150 chars — primary agent steering field>"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
type: note | source | topic | index
topics: [topic-slug-a, topic-slug-b]
status: draft | reviewed | stable
words: NNN
---
```

## Card combination rules

The full rules live at [`../../docs/CARD-RULES.md`](../../docs/CARD-RULES.md). The shortest possible summary:

1. One card, one subject.
2. Topics are discovered (extracted then normalized), not declared.
3. Links are bidirectional — `kg-link` enforces.
4. Read `tldr` and `words` before reading bodies.
5. New cards start `draft` and stay there unless the user reviews.

## Key principles

1. **Lightweight by default.** Don't interrupt the user to extract. Capture as a byproduct.
2. **Generic.** No assumptions about the user's domain (engineering, cooking, music — all the same).
3. **Token-aware.** Always check `words` before reading a card.
4. **DRY topics.** Normalize aggressively. Better to merge a few real distinctions than maintain a sprawl.
5. **Plain Markdown.** Anything an agent writes must be readable in a text editor without the agent.
