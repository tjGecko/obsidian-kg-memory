# Architecture

This document explains how the pieces of the stack fit together and why each one is here.

## Layers

The stack has four layers. Each layer can be replaced independently as long as the next layer up still gets what it needs.

```
┌──────────────────────────────────────────────────────────────┐
│  4. Memory layer   →  Obsidian vault (Markdown + frontmatter)│
├──────────────────────────────────────────────────────────────┤
│  3. Skill layer    →  kg-memory skills (this repo)           │
├──────────────────────────────────────────────────────────────┤
│  2. Agent layer    →  Claude Code  +  Hermes Agent (Codex)   │
├──────────────────────────────────────────────────────────────┤
│  1. Input layer    →  Aqua Voice (speech-to-text)            │
└──────────────────────────────────────────────────────────────┘
```

### 1. Input layer — Aqua Voice

System-wide speech-to-text. Triggered by a hotkey, transcribes whatever the user says into the active text field — could be a Claude Code prompt, a Hermes session, an Obsidian note, an email, anywhere. Removes typing as a barrier.

**Why this and not Apple Dictation?** Aqua Voice is significantly more accurate, supports custom vocabularies (project names, jargon), and allows light command/edit grammar.

### 2. Agent layer — Claude Code + Hermes (with Codex/GPT-5.5)

Two agents installed side by side because they have different strengths:

- **Claude Code** — Best for long-running structured tasks: maintaining the KG, multi-file edits, careful reasoning. This is where the kg-memory skills run.
- **Hermes Agent** — A NousResearch agent that wraps the OpenAI Codex CLI and runs against GPT-5.5. Best for fast back-and-forth Q&A, drafting, and tasks where a different style of reasoning helps.

Both agents read and write the same Obsidian vault, so memory captured by one is visible to the other. Only Claude Code carries the structured kg-memory skills (since skills are a Claude Code feature); Hermes interacts with the vault as plain files.

### 3. Skill layer — kg-memory (this repo)

A Claude Code skill set that turns the vault into a knowledge graph. Three card types (`note`, `source`, `topic`), well-defined frontmatter schema, deduplication rules, and a small set of operations:

| Skill | Purpose |
|---|---|
| `/kg-init` | Bootstrap a vault: create folders + seed `_index.md`, `_dashboard.md`, `_timeline.md` |
| `/kg-add-note` | File a captured thought or transcript as a note card |
| `/kg-add-source` | File an external resource (URL, article, book, podcast) as a source card |
| `/kg-topics` | Normalize, dedupe, and health-check topic pages |
| `/kg-link` | Maintain bidirectional WikiLinks between cards |
| `/kg-query` | Token-budget-aware traversal to answer questions from the KG |
| `/kg-update` | Incremental refresh after a batch of changes |

The skill SKILL.md files describe activation triggers so Claude Code can invoke them automatically (e.g., on session start, after a vault edit). See [`docs/CARD-RULES.md`](docs/CARD-RULES.md) for the rules and [`docs/SCHEMA.md`](docs/SCHEMA.md) for the field spec.

### 4. Memory layer — Obsidian vault

```
<vault>/kg/
├── _index.md          # Master index — entry point
├── _timeline.md       # Chronological activity log
├── _dashboard.md      # Dataview queries (live aggregates)
├── notes/             # Captured thoughts, transcripts, journal entries
├── sources/           # External references (URLs, books, podcasts, PDFs)
└── topics/            # Topic aggregation pages
```

Plain Markdown with YAML frontmatter. Nothing here is locked to any vendor — if you uninstall every tool above, the vault is still readable in any text editor.

The Dataview plugin powers `_dashboard.md` (it queries frontmatter across all cards and renders tables).

## Data flow

### Capturing a thought
1. User presses Aqua Voice hotkey, dictates: "Note about the bird feeder — chickadees only show up at sunrise."
2. Aqua Voice transcribes into the active Claude Code prompt.
3. User sends. Claude Code recognizes a capture intent and invokes `/kg-add-note`.
4. The skill creates `<vault>/kg/notes/2026-05-09-bird-feeder.md` with frontmatter (`tldr`, `topics`, `captured_via: aqua-voice`, etc.).
5. `kg-topics` runs — sees `bird-feeder` is a candidate topic, either creates `topics/bird-feeder.md` or links to an existing one.
6. `kg-link` adds a backlink from `topics/bird-feeder.md` → the new note.

### Filing an article
1. User shares a URL with the agent.
2. Agent fetches a summary and invokes `/kg-add-source`.
3. Source card created at `<vault>/kg/sources/<slug>.md` with `url`, `source_type`, `accessed`, and an extracted TLDR.
4. Same topic + link flow as a note.

### Asking a question
1. User asks: "What did I capture last week about the bird feeder?"
2. Claude Code invokes `/kg-query`.
3. Query reads `_index.md` first (cheap), ranks topic/note candidates by relevance to the query, then reads only the top matches in full (`words` frontmatter guides budget).
4. Returns answer with WikiLink citations.

## State files

| Path | Purpose |
|---|---|
| `~/.claude/kg_state.json` | Tracks last-update timestamps, source hashes, totals |
| `~/.claude/skills/kg-memory/` | Where the skill files live after install |
| `~/.hermes/config.yaml` | Hermes agent config (model, providers) |
| `~/.hermes/.env` | Hermes secrets (OpenAI API key) — never committed |
| `<vault>/kg/` | The vault content itself |

## Why three card types and not seven

The original kg-superpowers system this is derived from has seven card types (repo, code-entity, transcript, etc.) tuned for software-engineering work. For personal knowledge management we only need three:

- **note** — anything the user captures themselves
- **source** — anything the user references from outside
- **topic** — the connective tissue

If the user later wants `source_type: "code-repo"` or `note.captured_via: "transcript"` we extend frontmatter rather than introducing new card types. Fewer types = fewer rules = easier to keep clean.

## Optional Hermes server features

Hermes supports a webhook server (port 8765) and a streaming API server (port 8642) for use as an OpenAI-compatible endpoint. **Both are disabled in the default config** for a single-user setup. Re-enable them only if integrating Hermes into another tool. See `config/hermes-config.example.yaml`.
