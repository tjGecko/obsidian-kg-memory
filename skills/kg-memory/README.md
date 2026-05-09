# kg-memory — Knowledge Graph Skills for Claude Code

A generic, work-independent skill set that incrementally builds a knowledge graph in any Obsidian vault. Three card types (`note`, `source`, `topic`), strict frontmatter schema, and a small set of skills that grow the graph as a byproduct of normal use.

## Install

```bash
# From the repo root, run the installer step:
./install/07-kg-init.sh

# Or, by hand:
cp -R skills/kg-memory ~/.claude/skills/
```

This copies the skill files into Claude Code's skills directory. The skills activate automatically on every Claude Code session.

## First-time setup

```bash
# 1. Set the vault path (default: ~/Documents/KG-Vault)
export KG_VAULT="$HOME/Documents/KG-Vault"

# 2. Initialize the vault structure
claude /kg-init
```

`/kg-init` creates:
```
$KG_VAULT/kg/
├── _index.md          # Master index
├── _timeline.md       # Chronological log
├── _dashboard.md      # Dataview queries
├── notes/
├── sources/
└── topics/
```

It also seeds `~/.claude/kg_state.json` with empty state.

## Skills

| Skill | Command | Purpose |
|---|---|---|
| `kg-init` | `/kg-init` | Bootstrap the vault structure and state file |
| `kg-add-note` | `/kg-add-note` | File a captured thought as a note card |
| `kg-add-source` | `/kg-add-source` | File an external resource as a source card |
| `kg-topics` | `/kg-topics` | Normalize, dedupe, and health-check topics |
| `kg-link` | `/kg-link` | Maintain bidirectional WikiLinks |
| `kg-query` | `/kg-query` | Token-budget-aware traversal |
| `kg-update` | `/kg-update` | Incremental refresh after a batch of changes |
| `kg-session` | (auto) | Session lifecycle — runs at start/end |

## Schema and rules

The full spec lives at the repo root:
- [`../../docs/SCHEMA.md`](../../docs/SCHEMA.md) — frontmatter spec
- [`../../docs/CARD-RULES.md`](../../docs/CARD-RULES.md) — how cards combine

## Environment

| Var | Default | Purpose |
|---|---|---|
| `KG_VAULT` | `~/Documents/KG-Vault` | Path to the Obsidian vault |
| `KG_STATE` | `~/.claude/kg_state.json` | State file location |

## Dataview plugin

`_dashboard.md` uses the Dataview plugin to render live queries. Install it from Obsidian → Settings → Community plugins → Browse → Dataview.

## Why generic

The original system this is derived from was tuned for software-engineering work (cards for git repos, code entities, transcripts of dev meetings). This version drops everything project-specific. The three card types — note, source, topic — cover any personal knowledge management use case.
