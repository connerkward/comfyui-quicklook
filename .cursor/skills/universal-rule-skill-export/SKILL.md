---
name: universal-rule-skill-export
description: Automates the export of rules and skills to .agent, .claude, and .cursor directories.
---

# Universal Rule/Skill Export

This skill manages the synchronization of rules and skills across different agent configurations (`.agent`, `.claude`, `.cursor`).

## Usage

When you say:
> "Export rules and skills"

Or:
> "Sync agent configuration"

You should run the `export_config.py` script located in this directory.

## Instructions

1.  **Source of Truth**:
    *   Rules: `/Users/CONWARD/dev/central/rules`
    *   Skills: `/Users/CONWARD/dev/central/skills`

2.  **Destinations**:
    *   Antigravity: `/Users/CONWARD/dev/central/.agent`
    *   Claude: `/Users/CONWARD/dev/central/.claude`
    *   Cursor: `/Users/CONWARD/dev/central/.cursor`

3.  **Action**:
    *   Execute `python3 /Users/CONWARD/dev/central/skills/universal-rule-skill-export/export_config.py`

## Sync rules and skills into another repo

After cloning a repo (or when opening a repo that should use central’s rules/skills), copy central’s `.cursor/rules` and `.cursor/skills` into that repo:

```bash
python3 /path/to/central/skills/universal-rule-skill-export/sync_to_repo.py [target_dir]
```

- **target_dir**: repo to update (default: current directory). Use the cloned repo’s path.
- Script finds central from its own location (works when run from central or from a synced copy inside another repo’s `.cursor/skills/...`).
- Overwrites `target_dir/.cursor/rules` and `target_dir/.cursor/skills` with central’s contents.
