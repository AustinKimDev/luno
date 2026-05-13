# Settings UI Redesign — Manual QA Checklist

Date: 2026-05-13

## Sections

- [ ] Sidebar shows three top-level rows: `Library`, `Now Playing`, `Audio Reactor`.
- [ ] `Now Playing` is expandable and shows three children: `Basic`, `Appearance`, `Reactivity`.
- [ ] Clicking the group header (`Now Playing`) does NOT change the detail view.
- [ ] Clicking each leaf swaps the detail view to the correct section.
- [ ] Initial selection on app launch is `Library`.

## Library

- [ ] Package popup lists all installed `.luno` packages.
- [ ] Display popup lists `All Displays` plus each attached screen.
- [ ] Preset name field defaults to `Default` for a new package, or the saved preset name.
- [ ] Apply / Save / Import / Export buttons work as before.

## Now Playing › Basic

- [ ] Enable widget toggle persists across restart.
- [ ] Style popup shows Album-art dominant, Compact bar, Minimal.
- [ ] React to music toggle persists across restart.
- [ ] Keep visible while paused toggle persists across restart.

## Now Playing › Appearance

- [ ] Preset popup lists Default / Vivid / Minimal / Neon / Mono, plus a disabled "Custom" item.
- [ ] Selecting a preset updates all sliders/colors/popups to match.
- [ ] Modifying any slider/popup/color flips the popup selection to "Custom".
- [ ] Corner radius slider range 0..28 — verify lower and upper bounds applied to widget.
- [ ] Padding slider range 8..24 — visible inside the widget body.
- [ ] Border width slider range 0..6.
- [ ] Border opacity slider shows percent label.
- [ ] Title weight and Subtitle weight popups list 6 weights.
- [ ] Text / Accent / Glow color wells open the system color picker.
- [ ] All shape/typography/color changes persist across restart.

## Now Playing › Reactivity

- [ ] Master intensity slider shows percent label.
- [ ] When master is 0, per-effect sliders are disabled (and visibly dimmed).
- [ ] When master is non-zero, per-effect sliders are enabled.
- [ ] Each per-effect slider (Glow / Scale / Border) affects only its corresponding effect on the widget.
- [ ] All four sliders persist across restart.

## Audio Reactor

- [ ] All controls behave as before (no behavioral regression).

## Widget Behavior

- [ ] Default appearance matches the pre-redesign look.
- [ ] Vivid preset renders with thicker border and pink accent.
- [ ] Neon preset renders with cyan glow on bass.
- [ ] Bass pulse animates only the effects whose per-effect weights are non-zero.
- [ ] Glow does not clip into the window edge at high intensities (window margin 48 should suffice).
