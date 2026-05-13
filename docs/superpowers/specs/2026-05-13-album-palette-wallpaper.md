# Album Palette Wallpaper

## Goal

Add a bundled wallpaper that derives its visual palette from the current Now Playing artwork and exposes three selectable styles:

- Ambient Bloom
- Spectrum Ribbons
- Particle Field

## Behavior

- When Now Playing provides artwork data, Luno extracts a stable four-color palette.
- If artwork is missing or unreadable, the last valid palette stays active; a built-in fallback is used before any artwork is seen.
- Wallpaper colors transition smoothly when the track artwork changes.
- The new wallpaper still supports the existing audio reactive toggle behavior through its `audioBindings`.
- Parameter changes from the Library UI continue to apply live without requiring Apply.

## Non-Goals

- No per-wallpaper custom palette editor.
- No new external dependencies.
- No broad refactor of Now Playing or wallpaper window ownership.
