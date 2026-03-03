---
name: media-download
description: Download torrents/YouTube to Desky via PIA VPN, organize into media library (Emby/Plex/Jellyfin). Use when user provides a magnet link, .torrent URL, or YouTube URL for download.
---

# Media Download (Desky)

Download media via torrent or YouTube to Desky, organize into media library. Three frontends serve the same files: Emby (primary, port 8096), Plex (+ Plexamp for music), and Jellyfin (port 8097). All downloads go through PIA VPN.

## Prerequisites (one-time setup on Desky)

1. **PIA VPN:** Install from privateinternetaccess.com, login via GUI once, verify: `piactl get connectionstate`
2. **Tools to `C:\tools` on PATH:** aria2c.exe, yt-dlp.exe, ffmpeg.exe (direct downloads, no installer)
3. **Emby Server:** `http://desky:8096` (installed at `C:\Emby-Server\`). Also via Tailscale: `https://emby.tilapia-micro.ts.net`
4. **Plex Media Server:** `http://desky:32400/web`. Point at same `E:\Media\*` paths. Requires Plex account.
5. **Plexamp:** Install on client devices. Requires Plex Pass for full features. Connects to Plex server's music library.
6. **Jellyfin:** `http://desky:8097`. FOSS, no account/license needed.
7. **Media directories:** Run `Get-PSDrive -PSProvider FileSystem` to pick drive with most free space, then create:

```
E:\Media\Movies
E:\Media\TV
E:\Media\Music
E:\Media\Other
E:\Media\Downloads
```


## Emby Library Paths

| Type | Path | Naming |
|------|------|--------|
| Movie | `E:\Media\Movies` | `Movie Name (Year)\Movie Name (Year).ext` |
| TV | `E:\Media\TV` | `Show Name\Season 01\Show Name - S01E01.ext` |
| Music | `E:\Media\Music` | `Artist\Album (Year)\01 - Track.ext` |
| Other | `E:\Media\Other` | Flat |

Staging: `E:\Media\Downloads`

## Workflow

### 1. Classify

Determine type from URL/name patterns:
- `S\d{2}E\d{2}` or season/episode keywords → **TV**
- Year + codec keywords (x264, BluRay, 1080p) → **Movie**
- FLAC, MP3, album, discography → **Music**
- Otherwise → **Other** (or ask user if ambiguous)

### 2. Verify VPN

```
ssh desky 'powershell -Command "piactl get connectionstate"'
```

Must return `Connected`. If not:

```
ssh desky 'powershell -Command "piactl connect"'
```

Poll every 5s for up to 30s. **Never download without VPN confirmed.**

### 3. Download

**Torrent:**
```
ssh desky 'powershell -Command "aria2c --dir=\"E:\Media\Downloads\" --seed-time=0 \"<magnet-or-url>\""'
```

**YouTube video:**
```
ssh desky 'powershell -Command "yt-dlp -f \"bestvideo[height<=1080]+bestaudio/best\" --merge-output-format mkv -o \"E:\Media\Downloads\%(title)s.%(ext)s\" \"<url>\""'
```

**YouTube music:**
```
ssh desky 'powershell -Command "yt-dlp --extract-audio --audio-format mp3 -o \"E:\Media\Downloads\%(title)s.%(ext)s\" \"<url>\""'
```

### 4. Organize

1. Rename from scene naming to Emby-friendly naming (strip dots, brackets, codec tags)
2. Sanitize Windows filenames (strip `:*?"<>|`)
3. Move from `Downloads` staging to correct library path
4. Trigger library scans (all frontends index the same files):
```
# Emby
ssh desky 'powershell -Command "Invoke-RestMethod -Method POST -Uri \"http://localhost:8096/Library/Refresh?api_key=$env:EMBY_API_KEY\""'
# Plex
ssh desky 'powershell -Command "Invoke-RestMethod -Method GET -Uri \"http://localhost:32400/library/sections/all/refresh?X-Plex-Token=$env:PLEX_TOKEN\""'
# Jellyfin
ssh desky 'powershell -Command "Invoke-RestMethod -Method POST -Uri \"http://localhost:8097/Library/Refresh\" -Headers @{\"X-Emby-Token\"=\"$env:JELLYFIN_API_KEY\"}"'
```

### 5. Report

Confirm to user: file path, size, Emby library location.

## Remote Execution

- SSH: `ssh desky 'powershell -Command "..."'`
- Quoting: single quotes outer (bash), double quotes inner (PowerShell), backslash-escape inner doubles
- Long downloads: wrap in `Start-Job` so SSH disconnect doesn't kill the process, then poll job status

## Edge Cases

- **VPN drop:** aria2c and yt-dlp both support resume; re-verify VPN before retrying
- **Disk space:** Check before starting: `Get-PSDrive <letter> | Select-Object Free`
- **API keys:** Stored as env vars on Desky (`EMBY_API_KEY`, `PLEX_TOKEN`, `JELLYFIN_API_KEY`), never in scripts or commits
- **Seeding:** `--seed-time=0` stops seeding immediately after download completes
- **Filename sanitization:** Strip `:*?"<>|` from filenames for Windows compatibility
