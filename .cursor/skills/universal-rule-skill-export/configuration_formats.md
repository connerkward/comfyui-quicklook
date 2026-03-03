# Agent Configuration Formats

This document outlines the configuration formats and structures for **Antigravity** (`.agent`), **Claude** (`.claude`), and **Cursor** (`.cursor`) as observed in the current environment.

All three systems share a common concept of **Rules** and **Skills**, but implementation details vary.

---

## 1. Antigravity (`.agent`)

Antigravity appears to use a directory-centric approach for rules and a shared format for skills.

### Directory Structure
```
.agent/
├── rules/
│   └── [rule-name]/       # Rules are directories
│       └── RULE.md        # The actual rule content
├── skills/
│   └── [skill-name]/
│       └── SKILL.md       # Skill definition
└── workflows/             # Workflow definitions
```

### Rule Format (`RULE.md`)
Rules are defined in `RULE.md` files within a subdirectory named after the rule category or name.

**Frontmatter:**
```yaml
---
trigger: always_on      # When the rule is active
description: "..."      # Brief description
globs: ["**/*"]         # File patterns to match
---
```

### Skill Format (`SKILL.md`)
Skills are defined in `SKILL.md` files within a subdirectory. This format appears to be the "source of truth" extended to other agents.

**Frontmatter:**
```yaml
---
name: [skill-name]
description: "..."
---
```

---

## 2. Claude (`.claude`)

Claude uses a flat-file structure for rules and supports a local settings file.

### Directory Structure
```
.claude/
├── rules/
│   └── [rule-name]-rule.md  # Rules are flat Markdown files
├── skills/
│   └── [skill-name]/        # Mirrored from .agent
│       └── SKILL.md
└── settings.local.json      # Local configuration (permissions, etc.)
```

### Rule Format (`*-rule.md`)
Rules are standalone Markdown files. The frontmatter includes detailed metadata, likely following the Model Context Protocol (MCP) or similar standard.

**Frontmatter:**
```yaml
---
name: "software-engineering-rule"
id: "se-rule-01"
description: "..."
globs: ["**/*"]
applyTo: ["**/*"]
alwaysApply: true
priority: "high"
human-reviewed-at: YYYY-MM-DD
human-reviewed-by: [username]
---
```

---

## 3. Cursor (`.cursor`)

Cursor follows a similar structure to Claude but utilizes the `.mdc` extension for rules.

### Directory Structure
```
.cursor/
├── rules/
│   └── [rule-name].mdc      # Rules use .mdc extension
├── skills/
│   └── [skill-name]/        # Mirrored from .agent
│       └── SKILL.md
```

### Rule Format (`*.mdc`)
`.mdc` (Markdown Configuration?) files appear to be functionally identical to the `.md` rules used by Claude in this environment, sharing the same detailed frontmatter.

**Frontmatter:**
```yaml
---
name: "software-engineering-rule"
id: "se-rule-01"
description: "..."
globs: ["**/*"]
applyTo: ["**/*"]
alwaysApply: true
priority: "high"
---
```

---

## Summary Comparison

| Feature | Antigravity (`.agent`) | Claude (`.claude`) | Cursor (`.cursor`) |
| :--- | :--- | :--- | :--- |
| **Rule Structure** | Directory (`rules/[name]/RULE.md`) | Flat File (`rules/[name].md`) | Flat File (`rules/[name].mdc`) |
| **Rule Extension** | `.md` | `.md` | `.mdc` |
| **Key Frontmatter** | `trigger` | `applyTo`, `priority`, `id` | `applyTo`, `priority`, `id` |
| **Skill Format** | `skills/[name]/SKILL.md` | Same | Same |
