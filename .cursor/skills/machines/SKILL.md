---
name: context
description: Fleet and environment context. Use at agent boot or when you need machine, network, or storage topology. Load corp, personal, or both.
---

# Context (Orchestrator)

Determine scope:
- **Corp:** Work machine or corp-only task → [corp/SKILL.md](corp/SKILL.md).
- **Personal:** Personal machines or personal-only task → [personal/SKILL.md](personal/SKILL.md).
- **Fleet (full topology):** Load both [corp/SKILL.md](corp/SKILL.md) and [personal/SKILL.md](personal/SKILL.md).

By default, load only the **machine doc** for current host. Load networks/ or storage/ or linear only when the task needs them.

**Task skills:** [../linear/](../linear/), [../git/](../git/), [../python/](../python/), [../docs-compressor/](../docs-compressor/).