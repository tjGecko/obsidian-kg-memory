---
name: kg-add-note
description: File a captured thought, transcript, or journal entry as a note card in the KG vault. Generates frontmatter, extracts topic candidates, runs link maintenance.
---

# kg-add-note — Create a Note Card

## Activation

- On explicit `/kg-add-note <text>` command
- Auto-suggested when the user shares unstructured text that reads like a captured thought (declarative, no embedded question, no clear request)

## Purpose

Turn captured user content into a `note` card with proper frontmatter, topic links, and bidirectional connections.

## Procedure

### 1. Gather inputs

- **content** — the text to file. May come from the command argument, an open editor, an Aqua Voice transcript, or the conversation context.
- **captured_via** — defaults to `claude-code`. Set to `aqua-voice` if the input includes Aqua Voice's signature (e.g., wrapped in voice-style punctuation), `hermes` if filed via Hermes, `manual` if the user typed it, `import` if from a file.

### 2. Extract a TLDR

Generate a single sentence ≤150 characters summarizing the note. If the note is already short (one sentence), use it as the TLDR with light cleanup.

### 3. Generate the slug

- Extract a 3–5 word phrase capturing the main subject.
- Apply slug rules from [`docs/SCHEMA.md`](../../../../docs/SCHEMA.md#slug-rules): lowercase, hyphenated, singular, drop stop words.
- Prefix with today's date: `YYYY-MM-DD-<slug>`.
- If the slug already exists in `notes/`, append a `-2`, `-3`, etc.

### 4. Extract topic candidates

Per [`CARD-RULES.md`](../../../../docs/CARD-RULES.md#topic-candidate-extraction):
- Noun phrases appearing ≥2 times or in a heading.
- Proper nouns and named entities.
- Drop generic words and short tokens.
- Apply slug rules.

### 5. Hand candidates to kg-topics

Call `kg-topics` with the candidate list. It returns the canonical, normalized topic slugs (some may have merged into existing topics, some may be new).

### 6. Write the note file

Use `templates/note.md`. Path: `<vault>/kg/notes/YYYY-MM-DD-<slug>.md`.

Required frontmatter:
```yaml
---
tldr: "<extracted tldr>"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
type: note
topics: [normalized-topic-slugs]
status: draft
words: <count of body, frontmatter excluded>
captured_via: <enum>
---
```

Body structure (omit empty sections):
```markdown
# <Title — derived from TLDR>

> [!tldr] <TLDR text>

## Note
<the captured content, lightly cleaned for readability>

## Related
- [[topics/<topic-slug>]]
```

### 7. Run kg-link

Invoke `kg-link --card notes/<slug>` so the new card appears in each linked topic's Pages section.

### 8. Update state and timeline

- Bump `stats.notes` and `stats.total_pages` in `~/.claude/kg_state.json`.
- Append a line to `_timeline.md` under today's date heading: `- Note: [[notes/YYYY-MM-DD-<slug>]] — <tldr>`.

### 9. Confirm to user

```
Note filed: kg/notes/YYYY-MM-DD-<slug>.md
Topics: [topic-a], [topic-b]  (1 new, 1 existing)
```

## Flags

- `--captured-via <enum>` — Override the auto-detected value.
- `--no-link` — Skip the `kg-link` step (useful when batch-importing many notes; run `/kg-link` once at the end).
- `--draft-only` — Skip topic extraction. Faster; topics get backfilled by `/kg-update`.

## Verification

- File exists at the expected path with valid frontmatter.
- All topics in the `topics:` array have corresponding files in `<vault>/kg/topics/`.
- `_timeline.md` has the new entry.
- `kg_state.json` counts incremented.

## Notes

- Don't refuse to file because the content is short or unclear. Stub TLDRs are fine — `status: draft` flags them for later review.
- If the same content (text-identical) is already filed, log and skip rather than create a duplicate.
- For very long content (>2000 words) — file the note with a compact body and store the full original at `<vault>/kg/notes/_attachments/<slug>.txt`, set `original_text_path` in frontmatter.
