---
name: design-system
description: Implementation rules for frontend design: token architecture, typography, motion, color semantics, backgrounds. Use with design when building components, pages, or design systems.
---

# Design system

Apply with **design** when implementing UI: components, pages, or design systems. Every color, type, and motion choice should trace back to these rules.

## Token architecture

All colors map to a small set of primitives. No random hex values.

- **Foreground**: Text hierarchy (primary, secondary, muted).
- **Background**: Surface elevation (base, raised, overlay).
- **Border**: Separation hierarchy (subtle, default, emphasis).
- **Brand**: Identity and primary accent.
- **Semantic**: Destructive, warning, success (and optional info).

Use tokens in code (CSS variables, theme objects); never hardcode hex for UI.

## Typography

- **Hierarchy**: Headlines — heavier weight, tighter letter-spacing for presence. Body — comfortable weight for readability. Labels/UI — medium weight, works at smaller sizes. Data — monospace, `tabular-nums` for alignment.
- Combine size, weight, and letter-spacing so hierarchy is clear at a glance. If you squint and can't tell headline from body, hierarchy is too weak.
- **Fonts**: Distinctive, non-generic (avoid Arial, Inter). Pair a display font with a refined body font.
- **Data**: Numbers, IDs, codes, timestamps in monospace with `tabular-nums`. Mono signals "this is data."

## Motion

- **Micro-interactions** (hover, focus): ~150ms. Feel instant.
- **Larger transitions** (modals, panels): 200–250ms.
- **Easing**: Smooth deceleration (ease-out variants). Avoid spring/bounce in professional UIs.
- Prefer CSS-only for HTML; use Motion library for React when available. One well-orchestrated moment (e.g. staggered page load with animation-delay) creates more delight than scattered micro-interactions. Use scroll-triggering and hover states that surprise.

## Color and anti-generic

- **Palette from domain**: Colors should feel like they came *from* the product's world, not applied on top.
- **Beyond temperature**: Consider quiet vs loud, dense vs spacious, serious vs playful, geometric vs organic — not just warm/cool.
- **Color carries meaning**: Gray builds structure; color communicates status, action, emphasis, identity. Unmotivated color is noise. One accent used with intention beats five colors used without thought.

## Backgrounds and detail

Create atmosphere and depth; avoid flat default fills. Match the chosen aesthetic:

- Gradient meshes, noise textures, geometric patterns.
- Layered transparencies, dramatic shadows, decorative borders.
- Grain overlays where they fit the look.

Apply contextual effects that support the overall direction, not decoration for its own sake.
