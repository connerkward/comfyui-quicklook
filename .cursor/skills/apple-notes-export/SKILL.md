---
name: apple-notes-export
description: Export Apple Notes from NoteStore.sqlite via protobuf decoding. Use when user wants to export, back up, or extract Apple Notes data.
---

# Apple Notes Export

Export notes directly from the Apple Notes SQLite database by decoding protobuf blobs. Zero dependencies (stdlib only), ~2s for ~1800 notes.

## Tool

**Repository:** `~/dev/notesutils` (clone of [dunhamsteve/notesutils](https://github.com/dunhamsteve/notesutils))

**Database location:** `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`

## Scripts

| Script | Output | Notes |
|--------|--------|-------|
| `notes2html` | HTML per note + media | Full fidelity: tables, drawings, images, links |
| `notes2bear` | `.bearbk` zip | Bear backup format, no tables |
| `notes2quiver` | Quiver notebook | Quiver app format |

## Usage

```bash
# HTML export (recommended)
python3 ~/dev/notesutils/notes2html --title <dest_dir>

# With inline SVG drawings
python3 ~/dev/notesutils/notes2html --svg --title <dest_dir>
```

Flags:
- `--title` — name files by note title instead of UUID
- `--svg` — render drawings as inline SVG instead of fallback JPG

## How It Works

1. Opens `NoteStore.sqlite` directly (read-only copy made to dest)
2. Queries `ziccloudsyncingobject` for attachments (drawings, tables, images, URLs)
3. Queries `zicnotedata` for note bodies
4. Each note body: `ZDATA` → zlib decompress → protobuf decode → HTML render
5. Encrypted notes (`zcryptotag is not null`) are skipped

## Performance

~1,800 notes in ~2 seconds, 44MB output (HTML + media).

## Integration with exp-notes-indexing

The HTML output can replace the previous markdown export used by `~/dev/exp-notes-indexing`. To convert HTML to plain text for Graphiti ingestion, strip tags or use the protobuf text directly from the parsed `s_doc` schema.
