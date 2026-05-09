# Obsidian KG Memory + Mac Agent Stack

A personal knowledge-graph memory system that lives in an Obsidian vault and is maintained by AI coding agents. Includes:

1. **`skills/kg-memory/`** — A generic, work-independent Claude Code skill set that incrementally builds a knowledge graph in any Obsidian vault. Three card types (`note`, `source`, `topic`), strict schema, and rules for how cards combine and link.
2. **`install/`** — One-shot macOS installer scripts that set up the full agent stack on a fresh Mac: Aqua Voice (speech-to-text), Hermes Agent (NousResearch) wired to OpenAI Codex with GPT-5.5, Claude Code, Obsidian + Dataview, and the KG vault itself.
3. **`docs/`** — Schema spec, card-combination rules, a plain-English cheatsheet, and a helper runbook for guiding non-technical users over a remote Claude Code session.

## Why this exists

Most "AI memory" systems lock data into a vendor's database. This one stores everything as plain Markdown files with YAML frontmatter inside Obsidian — searchable, portable, and inspectable by a human. AI agents read and write the cards using a small set of skills, so the knowledge graph grows as a byproduct of normal use rather than as a separate chore.

## Quick start (macOS)

```bash
git clone https://github.com/tjGecko/obsidian-kg-memory.git
cd obsidian-kg-memory
./install/install-mac.sh
```

The installer is idempotent — re-running it skips anything already installed. See [`INSTALL.md`](INSTALL.md) for what each step does and how to run individual pieces.

## What gets installed

| Component | Purpose | Source |
|---|---|---|
| Homebrew, Node 20+, Python 3.11+ | Prereqs | brew, official |
| Claude Code CLI | Anthropic agent (primary KG operator) | npm `@anthropic-ai/claude-code` |
| OpenAI Codex CLI | OpenAI agent runtime | npm `@openai/codex` |
| Hermes Agent | NousResearch agent wrapping Codex with GPT-5.5 | curl install from `nousresearch/hermes-agent` |
| Aqua Voice | System-wide speech-to-text | direct `.dmg` from aquavoice.com |
| Obsidian + Dataview plugin | Vault UI + live queries | brew cask |
| KG Memory skills | This repo's skill set, copied to `~/.claude/skills/` | `install/07-kg-init.sh` |

## How the pieces work together

```
   ┌─────────────┐   speech     ┌─────────────────┐
   │ Aqua Voice  │─────────────▶│ Any text field  │
   └─────────────┘              │ (Claude/Hermes/ │
                                │  Obsidian)      │
                                └────────┬────────┘
                                         │ prompts
                          ┌──────────────┴──────────────┐
                          ▼                             ▼
                 ┌────────────────┐           ┌──────────────────┐
                 │  Claude Code   │           │   Hermes Agent   │
                 │  (Anthropic)   │           │  (Codex / GPT-5.5)│
                 └────────┬───────┘           └────────┬─────────┘
                          │  reads/writes              │  reads/writes
                          ▼                            ▼
                 ┌──────────────────────────────────────────┐
                 │      Obsidian Vault — KG cards           │
                 │  notes/  sources/  topics/  _index.md    │
                 └──────────────────────────────────────────┘
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design.

## For non-technical users

If someone is setting this up for a parent, sibling, or friend:

- [`docs/MOM-CHEATSHEET.md`](docs/MOM-CHEATSHEET.md) — Plain-English daily-use guide
- [`docs/HELPER-RUNBOOK.md`](docs/HELPER-RUNBOOK.md) — How to guide them remotely via a shared Claude Code session

## Card schema and rules

- [`docs/SCHEMA.md`](docs/SCHEMA.md) — Frontmatter spec for each card type
- [`docs/CARD-RULES.md`](docs/CARD-RULES.md) — How cards combine, dedupe, and link

## License

MIT — see [`LICENSE`](LICENSE).
