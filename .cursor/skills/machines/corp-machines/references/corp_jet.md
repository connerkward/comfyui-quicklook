# Jet

- **Hostname:** jet@DESKTOP-53KPGUP.us624.corpintra.net
- **Hardware:** NVIDIA RTX 4090 GPU workstation
- **OS:** Windows
- **Location:** Office
- **Availability:** Always on
- **Role:** GPU workhorse. ComfyUI, ML training, GPU-accelerated tasks.
- **MDM:** Corp-managed
- **Network:** Corp only. VPN; no Tailscale. Proxy `http://smtcig000049.us624.corpintra.net:3128` (auth via User env `HTTP_PROXY`/`HTTPS_PROXY`; format `http://USERNAME:PASSWORD@smtcig000049.us624.corpintra.net:3128`). PowerShell `[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://...", "User")` for headless.
- **Storage:** OneDrive N/A on Jet (corp OneDrive is macOS path). ComfyUI/local paths per project.
- **Tools → MCP:**
  - ComfyUI: TBD
  - Ollama: —
  - Python, CUDA, GPU drivers, winget, choco, scoop: —
- **Notes:** Slow internet — avoid large downloads. Use for GPU compute only.
