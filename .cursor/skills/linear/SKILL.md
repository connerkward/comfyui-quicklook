---
name: linear
description: Mechanics and policy for Linear issue operations via MCP (find/claim/report/close). Use when doing Linear work.
---

# Linear (issue operations)

**Workspace:** Personal + Corporate teams.

**Policy:** Lifecycle Backlog → Todo → In Progress → Done. Do not mark Done without testing and an Agent Test Report comment. Add agent-tested; add human-requested when confidence is low or human review needed.

**Prereqs:** Linear MCP available. Prefer `claude.ai Linear` (cloud connector) tools; fall back to local `linear` MCP tools on auth errors. Use list_issues, update_issue, create_comment (or client’s tool names).

**Find:** `list_issues(state: "Todo", label: "machine:<this-machine>")`; fallback `label: "agent"`.
**Claim:** `update_issue(id, state: "In Progress")`; `create_comment(issueId, body: "Picked up by agent on <machine> at <ISO-8601>")`.
**Close:** Test first. Comment with Agent Test Report (what, how, confidence, human review yes/no). Then `update_issue(state: "Done", labels: ["agent-tested"])`; add human-requested if low confidence. When adding human-requested, end the comment with: `> ⚠️ human-requested — please add \`human-tested\` label after you verify.`
**Human review:** When a human verifies a `human-requested` issue, `update_issue(labels: ["human-tested"])`. This closes the loop — human-requested without human-tested means unverified.
**Blocked:** `create_comment` reason; `update_issue(state: "Backlog")`.

**Labels:** machine:workyheavy|worky|jet|desky|lappy; tool:gpu|claude-code|cursor|antigravity|copilot|cline; agent-tested, agent-executed, human-requested, agent-requested, human-tested.

**Description format:** Standard markdown with real newlines (never escaped `\n`). `##` for sections, `-` for bullets, `[]` for checklists. Keep concise. Agent test reports go in a comment via `create_comment`, not in the description — use format: `## Agent Test Report\n- What:\n- How:\n- Confidence:\n- Human review needed:`
