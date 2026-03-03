# Worky

- **Hostname:** CONWARD@worky (Tailscale)
- **Hardware:** Apple M1 Mac Pro
- **OS:** macOS
- **Location:** Home
- **Availability:** Always on
- **Role:** Always-on daemon. Jump host to Jet via corp VPN.
- **MDM:** Mercedes-Benz via Jamf. Netskope/CrowdStrike. Corp VPN (Netskope) always-on; Tailscale coexists. Tailscale DNS disabled so Netskope handles `.corpintra.net`. Reach Jet via corp VPN.
- **Network:** Tailscale `100.102.238.125`. Home LAN. SSH enabled and accessible via Tailscale (Remote Login enabled).
- **Storage:** OneDrive `~/Library/CloudStorage/OneDrive-Mercedes-Benz(corpdir.onmicrosoft.com)/`. Large binaries, Teams exports, w-all/, archives. `.app` bundles sync as dirs—zip before sharing.
- **Tools → MCP:**
  - Claude Code (headless): TBD
  - Cline: TBD
  - GitHub Copilot (corporate only): —
  - Git, GitHub CLI, Python 3, Node.js, Homebrew: —
- **Notes:** Ideal for long-running agent tasks. Bridge to Jet.
