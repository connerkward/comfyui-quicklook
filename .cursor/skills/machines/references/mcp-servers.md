# MCP Servers

All MCP servers (cloud and local) are **deferred via ToolSearch** — zero token cost until invoked. Cursor loads MCP tools eagerly (~15-20k tokens/session).

- **Global config**: `~/.claude/settings.local.json` — loads for ALL sessions regardless of cwd
- **Project-level config**: `.claude/settings.local.json` in project dir — only loads in that project
- **Cloud connectors**: Managed by Anthropic, not in settings files

## Cloud MCP Connectors (Anthropic-managed)

| Connector | Purpose |
|---|---|
| claude.ai/Figma | Design context, screenshots, variables, code connect |
| claude.ai/Linear | Issue tracking — preferred over local Linear MCP |

## Local MCP Servers (Global)

Source: `~/.claude/settings.local.json`

| Server | Runner | Auth / Deps | Notes |
|---|---|---|---|
| Linear (local) | `npx mcp-remote` | OAuth (browser) | Fallback for cloud connector |
| Context7 | `npx @upstash/context7-mcp` | None | |
| Docker | `uvx docker-mcp` | Docker must be running | |
| GitHub | `npx @modelcontextprotocol/server-github` | PAT from `gh auth token` | |
| XcodeBuildMCP | `npx xcodebuildmcp` | Xcode 16+ | |
| Unity | `npx mcp-unity-server` | Unity plugin required | |
| Blender | `uvx blender-mcp` | Blender addon required | |
| TouchDesigner | `npx touchdesigner-mcp-server` | TD plugin required | |
| DaVinci Resolve | Local venv `~/dev/davinci-resolve-mcp` | Resolve running | |
| ComfyUI worky-heavy | Local venv `~/dev/comfyui-mcp-server` | `localhost:8188` | |
| ComfyUI Jet | Local venv `~/dev/comfyui-mcp-server` | `DESKTOP-53KPGUP.us624.corpintra.net:8188` | Corp network only |
| Apple Notes | Bun `~/dev/mcp-apple-notes/index.ts` | macOS Notes.app access | Search, read, create notes |
