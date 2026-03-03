# Desky

- **Hostname:** conner@desky (tailscale), conner@desky.local (home-lan)
- **SSH:** Key-based only (`~/.ssh/id_ed25519`). Tailscale SSH not supported on Windows. Use `ssh desky` (configured in `~/.ssh/config`).
- **Role:** Personal always-on hub. Tailscale peer.
- **Hardware:** Windows 10, i7-2600K, 32GB, GTX 960. No MDM.
- **Availability:** Always on
- **Storage:** Syncthing (ideas-syncthing): creative projects, archives; no ComfyUI output here. GDrive/Comfy if used: Windows path per project. Emby media: `E:\Media\{Movies,TV,Music,Other,Downloads}`.
- **Python:** 3.11.9 (`C:\Users\conner\AppData\Local\Programs\Python\Python311\python.exe`), also system default
- **Tools:** aria2c, yt-dlp, ffmpeg (`C:\tools` on PATH), piactl (`C:\Program Files\Private Internet Access\` on PATH)
- **Services:** Emby Server (`http://desky:8096`, `https://emby.tilapia-micro.ts.net`), Jellyfin (`http://desky:8097`), Plex Media Server (`http://desky:32400/web`), Plexamp (music), PIA VPN
- **Projects:** `C:\Users\conner\exp-notes-indexing\` — Apple Notes → Graphiti/Kuzu knowledge graph. Kuzu DB at `graphiti_notes.kuzu/`. Has checkpoint resume.
- **Tools → MCP:**
