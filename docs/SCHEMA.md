# KG Card Schema

Every card in the vault is a Markdown file with a YAML frontmatter block. The frontmatter is the contract — agents read it to decide what to do, and the `tldr` field is what gets surfaced when an agent needs to scan many cards quickly.

## Common fields (every card)

| Field | Type | Required | Purpose |
|---|---|---|---|
| `tldr` | string, ≤150 chars | yes | One-sentence summary. **Primary agent steering field.** Read first, always. |
| `created` | `YYYY-MM-DD` | yes | First write date. Never changes. |
| `updated` | `YYYY-MM-DD` | yes | Last meaningful edit. |
| `type` | enum: `note` \| `source` \| `topic` \| `index` | yes | Card class. |
| `topics` | `[slug, slug]` | yes | Topic slugs this card belongs to. Empty array allowed for orphans, but `kg-topics` will flag them. |
| `status` | enum: `draft` \| `reviewed` \| `stable` | yes | Lifecycle marker. New cards start `draft`. |
| `words` | integer | yes | Word count of the body (frontmatter excluded). Used for token budgeting. |

## `note` card extension

Captured user content — thoughts, transcripts, journal entries, dictated reminders.

| Field | Type | Required | Purpose |
|---|---|---|---|
| `captured_via` | enum: `aqua-voice` \| `manual` \| `hermes` \| `claude-code` \| `import` | yes | How the content entered the vault. |
| `original_text_path` | string | no | Path to a raw transcript or import source, if applicable. |
| `author` | string | no | Defaults to vault owner; set if quoting another person. |
| `mood` | string | no | Optional tag for journal-style notes. |

**File path:** `<vault>/kg/notes/YYYY-MM-DD-<slug>.md` (date prefix keeps the directory chronologically sortable in Finder/Obsidian).

## `source` card extension

External references — URLs, articles, books, podcasts, PDFs, videos.

| Field | Type | Required | Purpose |
|---|---|---|---|
| `url` | string | yes (if web) | Canonical URL. |
| `source_type` | enum: `article` \| `video` \| `book` \| `podcast` \| `pdf` \| `code-repo` \| `other` | yes | Drives default outline structure. |
| `accessed` | `YYYY-MM-DD` | yes | When the user first read/watched/heard it. |
| `author` | string | no | Source author(s), comma-separated. |
| `published` | `YYYY-MM-DD` or year | no | Original publication date if known. |
| `archive_url` | string | no | Link to a Wayback or local mirror, in case the original disappears. |

**File path:** `<vault>/kg/sources/<slug>.md` (no date prefix — sources are addressed by content, not date).

## `topic` card extension

The connective tissue. Topic cards aggregate notes and sources, and link to related topics.

| Field | Type | Required | Purpose |
|---|---|---|---|
| `aliases` | `[name, name]` | no | Alternative names that should resolve here. Used by `kg-topics` deduplication. |
| `depth` | integer 0–2 | yes | 0 = broad domain, 1 = sub-domain, 2 = specific concept. See [`CARD-RULES.md`](CARD-RULES.md#topic-hierarchy). |
| `page_count` | integer | yes | Live count of cards linking here. Maintained by `kg-topics`. |
| `parent_topics` | `[slug]` | no | If `depth > 0`, the broader topic(s) this nests under. |

**File path:** `<vault>/kg/topics/<slug>.md`. Slug is hyphenated, lowercase, singular (`bird-feeder`, not `bird-feeders` or `Bird Feeder`).

## `index` card extension

System-managed pages: `_index.md`, `_timeline.md`, `_dashboard.md`. Users don't typically edit these directly.

| Field | Type | Required | Purpose |
|---|---|---|---|
| `tldr` | string | yes | Short description of what this index represents. |
| (no other extensions) |

## Body structure

After the frontmatter, every card body follows this skeleton (sections without content are omitted, not left empty):

```markdown
# Title

> [!tldr] Restate the tldr field as a callout for human readability.

## Overview
2–3 sentences on what this is and why it's in the vault.

## Body
Content. For notes: the captured text. For sources: the user's takeaways + relevant
quotes. For topics: prose introducing the topic, then a Pages table.

## Related
- [[notes/2026-05-09-bird-feeder]] — captured note
- [[topics/birds]] — parent topic
- [[sources/audubon-feeder-guide]] — referenced source
```

## Slug rules

| Rule | Example |
|---|---|
| Lowercase only | `Bird Feeder` → `bird-feeder` |
| Spaces → hyphens | `real time audio` → `real-time-audio` |
| Singular form | `microservices` → `microservice` |
| Drop stop words from start | `the-art-of-debugging` → `art-of-debugging` |
| Note slug includes date | `bird-feeder` → `2026-05-09-bird-feeder` |

`kg-topics` enforces these on every run.

## Why these fields and not more

Every required field has a job an agent does with it. `tldr` for ranking, `words` for budgeting, `source_hash` (added during indexing operations) for change detection, `topics` for traversal. Optional fields are only added when a user or agent has actual data — empty fields are noise.
