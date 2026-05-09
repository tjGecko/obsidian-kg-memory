---
name: kg-init
description: Initialize the KG vault directory structure. Creates _index, _timeline, _dashboard, and the notes/sources/topics folders. Seeds the state file.
---

# kg-init — Initialize Knowledge Graph Vault

## Activation

- When `<vault>/kg/` does not exist
- On explicit `/kg-init` command

## Purpose

Bootstrap an empty vault into a working KG. Idempotent — safe to re-run; never overwrites existing files.

## Procedure

### 1. Resolve vault location

- `$KG_VAULT` if set, else `~/Documents/KG-Vault`
- If the parent directory doesn't exist, fail with a clear error pointing the user at `INSTALL.md`.

### 2. Create the directory tree

```
<vault>/kg/
├── _index.md
├── _timeline.md
├── _dashboard.md
├── notes/
├── sources/
└── topics/
```

Use `mkdir -p` semantics — no error if folders already exist.

### 3. Seed the index files

For each missing index file, write the corresponding template from `~/.claude/skills/kg-memory/templates/`:
- `_index.md` ← `templates/_index.md`
- `_timeline.md` ← `templates/_timeline.md`
- `_dashboard.md` ← `templates/_dashboard.md`

Substitute `{{created}}` and `{{updated}}` with today's date.

### 4. Seed the state file

If `~/.claude/kg_state.json` doesn't exist, write:

```json
{
  "schema_version": 1,
  "vault_path": "<resolved vault path>",
  "last_full_update": null,
  "cards": {},
  "stats": {
    "notes": 0,
    "sources": 0,
    "topics": 0,
    "total_pages": 3
  }
}
```

If the file exists, merge missing keys but never overwrite existing values.

### 5. Print a confirmation

```
KG initialized at <vault>/kg/
- 3 index files created
- 0 notes / 0 sources / 0 topics
- State file: ~/.claude/kg_state.json

Try: /kg-add-note "your first thought here"
```

## Verification

- All directories exist under `<vault>/kg/`
- `_index.md`, `_timeline.md`, `_dashboard.md` are present and have valid frontmatter
- `~/.claude/kg_state.json` exists and parses as JSON

## Notes

- Safe to re-run after a vault relocation — pass `--vault <new-path>` to update `$KG_VAULT` references.
- If the user has an existing vault with content, `kg-init` will not touch it. Use `/kg-update` to bring an existing vault under management.
