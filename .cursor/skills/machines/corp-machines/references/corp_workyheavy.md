# WorkyHeavy

- **Hostname:** CONWARD@worky-heavy (Tailscale)
- **Hardware:** Apple M3 Max, 36GB RAM
- **OS:** macOS 26.3 (Tahoe)
- **Location:** Mobile (daily driver)
- **Availability:** When in use
- **Role:** Primary dev machine. Orchestrates work across other machines.
- **MDM:** Mercedes-Benz via Jamf. Netskope VPN always-on, CrowdStrike Falcon. Cannot remove MDM. Tailscale coexists (system extension). Tailscale DNS disabled (`--accept-dns=false`) so Netskope handles corp DNS.
- **Storage:** OneDrive `~/Library/CloudStorage/OneDrive-Mercedes-Benz(corpdir.onmicrosoft.com)/`. GDrive (Comfy) `~/Library/CloudStorage/GoogleDrive-*/My Drive/ideas-comfy-shared/` (read-only; output always local).
- **Services:**
  - `com.conward.daily-card-server` — Spaced-repetition daily card (hooks + HSK 1 Chinese). Port 8000, auto-restart. Repo: [connerkward/exp-daily-card](https://github.com/connerkward/exp-daily-card). LaunchAgent + 8am notification (`com.conward.daily-card-notify`).
- **Tools → MCP:**
  - Claude Code: Linear, Desktop Commander, Chrome, iMessages, Office, Apple Notes, Figma, Spotify, PDF Tools
  - Cline: —
  - Cursor: —
  - GitHub Copilot (corporate only): —
  - Homebrew: —
