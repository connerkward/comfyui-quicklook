# ComfyQL

macOS viewer for ComfyUI PNG workflow metadata. Right-click a ComfyUI-generated PNG in Finder → **Open With → ComfyQL** to see a split panel: image on the left, workflow metadata on the right.

Non-ComfyUI PNGs are passed straight to Preview.app.

## Requirements

- macOS 13+ (arm64)
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
git clone https://github.com/connerkward/comfyui-quicklook.git
cd comfyui-quicklook
make install
```

This builds and copies `ComfyQL.app` to `~/Applications/` and registers it with Launch Services.

> **First run:** macOS may warn about an unidentified developer. Right-click `ComfyQL.app` → Open, or run:
> ```bash
> xattr -dr com.apple.quarantine ~/Applications/ComfyQL.app
> ```

## Usage

**Finder:** Right-click any ComfyUI PNG → Open With → ComfyQL

**Terminal:**
```bash
open -a ComfyQL /path/to/ComfyUI_image.png
```

## How it works

ComfyUI embeds workflow JSON in PNG `tEXt`/`iTXt` chunks (keys: `workflow`, `prompt`). ComfyQL reads these chunks at open time and renders a split panel via WKWebView — image (left) + node summary and raw JSON tabs (right). If no ComfyUI chunks are found, the file opens in Preview.app.

## Uninstall

```bash
make uninstall
```

## Build targets

| Target | Description |
|--------|-------------|
| `make` | Build app |
| `make install` | Build + copy to `~/Applications/` |
| `make test` | Open most recent ComfyUI output PNG |
| `make uninstall` | Remove from `~/Applications/` |
| `make clean` | Remove build artifacts |

## Note on Quick Look

macOS 26 requires Developer ID code signing for Quick Look extensions, which blocks ad-hoc signed third-party plugins. ComfyQL works as a standalone "Open With" viewer instead — no signing required.
