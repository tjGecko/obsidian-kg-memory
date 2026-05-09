---
tldr: "Live Dataview queries aggregating all KG data"
created: "{{created}}"
updated: "{{updated}}"
type: index
status: stable
words: 0
---

# Knowledge Graph Dashboard

> Requires the **Dataview** community plugin. Settings → Community plugins → Browse → Dataview.

## Notes

```dataview
TABLE tldr AS "TLDR", topics AS "Topics", captured_via AS "Captured via", updated AS "Updated"
FROM "kg/notes"
WHERE type = "note"
SORT updated DESC
LIMIT 25
```

## Sources

```dataview
TABLE tldr AS "TLDR", source_type AS "Type", url AS "URL", accessed AS "Accessed"
FROM "kg/sources"
WHERE type = "source"
SORT accessed DESC
LIMIT 25
```

## Topics by page count

```dataview
TABLE page_count AS "Pages", depth AS "Depth", aliases AS "Aliases"
FROM "kg/topics"
WHERE type = "topic"
SORT page_count DESC
```

## Recent activity (all card types)

```dataview
TABLE type AS "Type", tldr AS "TLDR", updated AS "Updated"
FROM "kg"
WHERE updated AND type != "index"
SORT updated DESC
LIMIT 20
```

## Status breakdown

```dataview
TABLE length(rows) AS "Count"
FROM "kg"
WHERE type AND type != "index"
GROUP BY status
```

## Topic health

### Too broad (page_count > 7)

```dataview
LIST page_count
FROM "kg/topics"
WHERE page_count > 7
SORT page_count DESC
```

### Too narrow (page_count < 2)

```dataview
LIST page_count
FROM "kg/topics"
WHERE page_count < 2
SORT page_count ASC
```

## Source types

```dataview
TABLE length(rows) AS "Count"
FROM "kg/sources"
WHERE type = "source"
GROUP BY source_type
```
