---
name: docs
description: Doc authoring, compression, and frontmatter. Use when creating, editing, or compressing docs; or marking files human-reviewed.
---

- **One place per fact.** Everywhere else: "See X." DRY.
- **Prefer generated over written.** Script from one source → output; change source once.
- **Code as truth.** Link, don't summarize. Minimize nesting; short files.
- **Minimalism:** Only necessary code/signatures; avoid prose and greetings. High information-to-token ratio.
- **De-verbosify:** Remove passive voice, "I will now...". Bulleted technical lists.

**Human-reviewed frontmatter:** Add or update at top of Markdown: `human-reviewed-at: YYYY-MM-DD`, `human-reviewed-by: <human-id>`. If frontmatter exists, only add/update those two keys; preserve others. If none, insert new block. human-id e.g. connerward (ask if not provided).
