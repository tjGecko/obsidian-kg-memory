---
name: kg-add-source
description: File an external reference (URL, article, book, podcast, PDF, video) as a source card in the KG vault. Fetches metadata, extracts a TLDR, runs topic and link maintenance.
---

# kg-add-source — Create a Source Card

## Activation

- On explicit `/kg-add-source <url-or-reference>` command
- Auto-suggested when the user shares a URL with intent to save (e.g., "save this", "add this", "let's keep this")

## Purpose

Turn an external reference into a `source` card with metadata, takeaways, and topic links.

## Procedure

### 1. Identify the source

Inputs vary:
- A URL → fetch the page, extract title + author + date + summary.
- A book reference (`title` by `author`) → ask user to confirm fields, no fetch.
- A podcast episode → ask for show + episode number + URL.
- A PDF or local file → read it directly.

### 2. Determine `source_type`

| Heuristic | Type |
|---|---|
| `youtube.com`, `vimeo.com`, `*.mp4` | `video` |
| `*.pdf` | `pdf` |
| Podcast platforms (Apple Podcasts, Spotify, Overcast, RSS feed) | `podcast` |
| `github.com/<user>/<repo>` | `code-repo` |
| ISBN / `goodreads.com` / explicit book reference | `book` |
| Everything else web | `article` |

### 3. Extract metadata

For URLs, fetch and parse:
- `title` (page title or `og:title`)
- `author` (`og:author`, byline, or `<meta name="author">`)
- `published` (`article:published_time`, dateline)
- A 2–3 sentence summary

For non-web sources, prompt the user for missing fields.

### 4. Generate the slug

- Base: a short phrase from the title (3–5 words).
- Apply slug rules.
- Sources don't get a date prefix — use just the slug. If a slug collision happens, suffix with `-2` etc.

### 5. Extract takeaways

Pull 2–5 key points from the content (or ask the user for them, if the content isn't accessible). These go in the body. Don't try to summarize exhaustively — the user will skim and add their own takeaways over time.

### 6. Extract topic candidates and call kg-topics

Same protocol as `kg-add-note` step 4–5.

### 7. Write the source file

Use `templates/source.md`. Path: `<vault>/kg/sources/<slug>.md`.

```yaml
---
tldr: "<extracted tldr>"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
type: source
topics: [normalized-topic-slugs]
status: draft
words: <body word count>
url: "<canonical url>"
source_type: <enum>
accessed: "YYYY-MM-DD"
author: "<author or empty>"
published: "<date or empty>"
---
```

Body:
```markdown
# <Title>

> [!tldr] <TLDR text>

## Summary
<2–3 sentence summary>

## Takeaways
- Key point 1
- Key point 2

## Related
- [[topics/<topic-slug>]]
```

### 8. Run kg-link, update state and timeline

Same as `kg-add-note` steps 7–8. Counter is `stats.sources`.

### 9. Confirm to user

```
Source filed: kg/sources/<slug>.md
URL: <url>
Topics: [topic-a], [topic-b]
```

## Flags

- `--type <source_type>` — Override auto-detected type.
- `--no-fetch` — Don't fetch the URL; user provides title and summary directly.
- `--archive` — Also save a Wayback snapshot URL into `archive_url`.

## Verification

- File exists with valid frontmatter.
- `url` is canonical (lowercased domain, no tracking params).
- All linked topics exist.
- `_timeline.md` has the new entry.

## Notes

- For `code-repo` sources, do **not** auto-clone or index the repo. That's a different workflow — this skill just files the reference.
- If the URL is paywalled or fetch fails, ask the user for title + author + summary rather than failing silently.
- Tracking parameters (utm_*, fbclid, gclid, etc.) get stripped from `url` before storing.
