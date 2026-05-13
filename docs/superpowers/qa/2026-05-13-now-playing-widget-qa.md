# Now Playing Widget - Manual QA Checklist

Date: 2026-05-13
Tester: ____________
macOS version: ____________

## Setup

- [ ] Build via `scripts/build-app.sh` and launch `.build/artifacts/Luno.app`.
- [ ] Open Library window. Confirm "Now Playing widget" section appears with Enable / Style / Reactivity / Keep visible toggles.

## First-run permission

- [ ] Toggle "Enable widget" ON with no music playing.
- [ ] Start Apple Music. Expect macOS Automation permission dialog. Accept.
- [ ] Expect widget to appear within ~2 seconds.

## Apple Music (full metadata case)

- [ ] Play a classical track that has a composer (for example, Debussy - Clair de Lune).
- [ ] Verify title, artist, album, composer all show.
- [ ] Verify album artwork displays.
- [ ] Hover. Verify play/pause/skip controls appear.
- [ ] Click pause. Verify widget shows paused state. Wait 5 seconds. Verify widget fades out.
- [ ] Click play. Verify widget fades back in.
- [ ] Switch tracks. Verify metadata updates within 1 second.

## Spotify

- [ ] Open Spotify, play any track.
- [ ] Verify title, artist, album show. Composer line should be hidden because Spotify does not provide composer.
- [ ] Verify artwork loads from URL. It may take a moment on the first track.
- [ ] Verify hover controls work.
- [ ] If you encounter an ad, verify widget shows "Advertisement" and controls are disabled.

## Source switching

- [ ] Play Apple Music. Verify Apple Music is shown.
- [ ] Pause Apple Music. Within 2 seconds, start Spotify.
- [ ] Verify widget switches to Spotify within ~2 seconds without flicker.

## MediaRemote fallback (browser/YouTube)

- [ ] Quit Apple Music and Spotify.
- [ ] Play audio in Safari, such as YouTube.
- [ ] Verify widget either shows the YouTube tab info or stays hidden, depending on macOS 15 MediaRemote behavior.
- [ ] If shown, verify controls are visually disabled. MediaRemote is read-only in this design.

## Style switching

- [ ] In Library, switch to Style A. Verify widget grows to 180x216 with large artwork.
- [ ] Switch to Style B. Verify horizontal bar 280x72.
- [ ] Switch to Style C. Verify minimal 240x52. Composer line is absent.

## Drag and persistence

- [ ] Drag widget to a different corner.
- [ ] Quit and relaunch Luno. Verify widget reopens at the new position.

## Multi-display

- [ ] Connect a second display. Drag widget to it.
- [ ] Disconnect the second display. Verify widget reappears on the primary display, clamped on screen.

## Reactivity

- [ ] With "React to music" ON, verify the album artwork pulses with the beat and the border glows with the bass.
- [ ] Turn off "React to music". Verify widget becomes still.

## Sleep/wake

- [ ] Put Mac to sleep with music playing. Wake. Verify widget is correct within 5 seconds.

## Permission denial path

- [ ] Reset Automation permission for Luno in System Settings > Privacy > Automation.
- [ ] Re-enable widget. Deny the dialog.
- [ ] Verify widget shows a "Permission needed ->" hint or stays hidden if no other source is playing.

## Resource sanity

- [ ] In Activity Monitor, observe Luno's CPU usage during normal playback. Confirm < 3% sustained.
